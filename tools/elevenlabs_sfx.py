#!/usr/bin/env python3
"""ElevenLabs sound-effect bank: generate (cached, budget-guarded) and build (stdlib-only DSP).

  python3 tools/elevenlabs_sfx.py generate [--only key,...] [--limit 30000]
  python3 tools/elevenlabs_sfx.py build

`generate` calls the ElevenLabs Sound Effects API once per entry of tools/sfx_prompts.json and caches
the raw 16-bit 44.1 kHz mono PCM under art/elevenlabs/raw/<key>.pcm with <key>.json (prompt, params,
credits charged). Cached takes are never requested again. The API key is read from
~/.config/elevenlabs/api_key at runtime and never printed or written anywhere. Generation stops before
the account's character_count could pass --limit.

`build` turns the cached takes into the shipped banks (no network): trims leading silence and dead
tails on one-shots, crossfades loops into seamless 2 s loops, renders variants _2/_3 by small
pitch/speed shifts plus a slight tilt EQ, then normalizes to the manifest's full-clip RMS targets with a
look-ahead peak limiter. Writes godot/assets/audio/combat/*.wav + manifest.json and
godot/assets/audio/game/*.wav + manifest.json.
"""
import argparse, array, hashlib, json, math, sys, time, urllib.error, urllib.request, wave
from collections import deque
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPTS = ROOT/'tools/sfx_prompts.json'
CACHE = ROOT/'art/elevenlabs/raw'
COMBAT = ROOT/'godot/assets/audio/combat'
GAME = ROOT/'godot/assets/audio/game'
KEY_FILE = Path.home()/'.config/elevenlabs/api_key'
API = 'https://api.elevenlabs.io/v1'
RATE = 44100
LOOP_FRAMES = 88200          # 2.0 s, same as the previous synth loops
LOOP_XFADE = int(0.25*RATE)
NORMALIZATION = {'metric': 'full-clip RMS dBFS (not LUFS)', 'one_shot_target_dbfs': -22, 'loop_target_dbfs': -24,
                 'one_shot_peak_ceiling': .7, 'loop_peak_ceiling': .42}
GAME_TARGETS = {'ui_click': -26, 'ui_confirm': -26, 'ui_back': -26, 'menu_open': -26, 'item_pickup': -24, 'zeni': -24,
                'quest_accept': -24}  # everything else -22
# variant: (resample ratio >1 = higher/shorter, tilt: +brighter / -darker, gain trim dB applied before normalization)
VARIANTS = [(1.0, 0.0), (1.045, 0.25), (0.955, -0.3)]

# ---------------------------------------------------------------- API

def _key():
    return KEY_FILE.read_text().strip()

def _request(path, body=None, query=''):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API+path+query, data=data, method='POST' if data else 'GET',
                                 headers={'xi-api-key': _key(), 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()

def usage():
    delay = 4
    for attempt in range(7):
        try:
            d = json.loads(_request('/user/subscription')); break
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500: raise
            time.sleep(delay); delay *= 2
        except urllib.error.URLError:
            time.sleep(delay); delay *= 2
    else:
        raise RuntimeError('subscription endpoint unavailable')
    return int(d['character_count']), int(d['character_limit'])

def sound(body):
    delay = 4
    for attempt in range(6):
        try:
            return _request('/sound-generation', body, '?output_format=pcm_44100')
        except urllib.error.HTTPError as e:
            detail = e.read()[:400].decode('utf-8', 'replace')
            if e.code == 429 or e.code >= 500:
                print(f'  HTTP {e.code}, retrying in {delay}s', flush=True); time.sleep(delay); delay *= 2; continue
            raise RuntimeError(f'HTTP {e.code}: {detail}') from None
        except urllib.error.URLError as e:
            print(f'  network error {e.reason}, retrying in {delay}s', flush=True); time.sleep(delay); delay *= 2
    raise RuntimeError('gave up after retries')

def entries():
    spec = json.loads(PROMPTS.read_text()); defaults = spec['defaults']
    for group in ('combat', 'game'):
        for key, e in spec[group].items():
            yield group, key, {**defaults, **e}

def generate(only, limit):
    CACHE.mkdir(parents=True, exist_ok=True)
    # The subscription counter lags by tens of seconds, so budget with a conservative 40 credits/second
    # (measured: ~10/s) and also count our own calls locally.
    per_second = 40.; calls = 0; fallbacks = []
    start, _ = usage(); used = start
    print(f'character_count before: {start}', flush=True)
    for group, key, e in entries():
        if only and key not in only: continue
        raw, meta_path = CACHE/f'{key}.pcm', CACHE/f'{key}.json'
        if raw.exists() and meta_path.exists(): continue
        estimate = per_second*e['duration_seconds']
        if used+estimate > limit:
            print(f'STOP: {key} could take character_count {used} past {limit}', flush=True); break
        body = {'text': e['prompt'], 'duration_seconds': e['duration_seconds'], 'prompt_influence': e['prompt_influence'],
                'model_id': e['model_id']}
        if e.get('loop'): body['loop'] = True
        note = ''
        try:
            pcm = sound(body)
        except RuntimeError as err:
            # Fall back once without the optional fields if the API rejects them.
            print(f'  {key}: {err}; retrying without loop/model_id', flush=True)
            body.pop('loop', None); body.pop('model_id', None); note = f'fallback: {err}'[:300]; fallbacks.append(key)
            pcm = sound(body)
        calls += 1; time.sleep(1.5)  # stay well under the rate limit
        raw.write_bytes(pcm)
        reported, _ = usage(); used = max(reported, used+estimate)
        meta_path.write_text(json.dumps({'key': key, 'group': group, 'request': body, 'usage_reported_after': reported,
                                         'duration_seconds': e['duration_seconds'], 'bytes': len(pcm), 'note': note}, indent=2)+'\n')
        print(f'{key}: {len(pcm)} bytes, reported character_count {reported}', flush=True)
    print(f'calls: {calls}; character_count reported now: {usage()[0]} (start {start}); fallbacks: {fallbacks}')

# ---------------------------------------------------------------- DSP (floats in [-1, 1])

def read_raw(key):
    a = array.array('h'); a.frombytes((CACHE/f'{key}.pcm').read_bytes())
    if sys.byteorder != 'little': a.byteswap()
    # pcm_44100 from eleven_text_to_sound_v2 is interleaved 16-bit stereo (byte count = 4 x 44100 x seconds for
    # every take, including near-mono ones), so always downmix to mono.
    return [(a[i]+a[i+1])/65536 for i in range(0, len(a)-1, 2)]

def dc_block(x, circular=False):
    def run(seq, y=0., prev=0.):
        out = []
        for v in seq:
            y = v-prev+.9986*y; prev = v; out.append(y)
        return out
    if circular: return run(x+x)[len(x):]
    return run(x)

def tilt(x, amount, circular=False):
    """amount>0: add highs (x + a*(x-lowpass)); amount<0: blend toward a lowpass."""
    if not amount: return x
    a = .18
    def run(seq):
        lp = 0.; out = []
        for v in seq:
            lp += a*(v-lp)
            out.append(v+amount*(v-lp) if amount > 0 else v*(1+amount)-amount*lp)
        return out
    return run(x+x)[len(x):] if circular else run(x)

def resample(x, ratio, circular=False):
    """Cubic (Catmull-Rom) resampling; ratio>1 shortens and raises pitch."""
    n = len(x)
    if ratio == 1: return x[:]
    m = round(n/ratio) if circular else int((n-1)/ratio)
    step = n/m if circular else ratio
    def at(i):
        return x[i % n] if circular else x[min(max(i, 0), n-1)]
    out = []
    for j in range(m):
        p = j*step; i = int(p); t = p-i
        p0, p1, p2, p3 = at(i-1), at(i), at(i+1), at(i+2)
        out.append(p1+.5*t*(p2-p0+t*(2*p0-5*p1+4*p2-p3+t*(3*(p1-p2)+p3-p0))))
    return out

def block_rms(x, size):
    return [math.sqrt(sum(v*v for v in x[i:i+size])/max(1, len(x[i:i+size]))) for i in range(0, len(x), size)]

def trim_one_shot(x, max_seconds):
    peak = max(abs(v) for v in x) or 1
    start = next((i for i, v in enumerate(x) if abs(v) > peak*.03), 0)
    start = max(0, start-int(.003*RATE))
    x = x[start:start+int(max_seconds*RATE)]
    size = int(.01*RATE); env = block_rms(x, size); top = max(env) or 1
    last = max((i for i, e in enumerate(env) if e > top*10**(-48/20)), default=len(env)-1)
    x = x[:min(len(x), (last+1)*size)]
    fade_in = int(.002*RATE)
    for i in range(min(fade_in, len(x))): x[i] *= i/fade_in
    fade = min(int(.06*RATE), len(x)//4)
    for i in range(fade): x[len(x)-fade+i] *= (1-i/fade)**2
    x[-1] = 0.
    return x

def make_loop(x):
    need = LOOP_FRAMES+LOOP_XFADE
    if len(x) < need:  # short take: shrink the loop to what exists
        length = max(len(x)-LOOP_XFADE, len(x)//2); offset = 0
    else:
        length = LOOP_FRAMES; offset = (len(x)-need)//2
    xf = min(LOOP_XFADE, len(x)-length)
    out = x[offset:offset+length]
    for i in range(xf):
        w = (i+.5)/xf
        out[i] = x[offset+length+i]*math.sqrt(1-w)+x[offset+i]*math.sqrt(w)  # equal power: uncorrelated noise beds
    return out

def limit(x, ceiling, circular=False):
    """Look-ahead brickwall: min-filtered gain over a 3 ms window, 60 ms release, short smoothing."""
    n = len(x); look = int(.003*RATE); rel = 1-math.exp(-1/(.06*RATE))
    src = x+x+x if circular else x
    req = [min(1., ceiling/abs(v)) if v else 1. for v in src]
    m = len(req); g = [1.]*m; dq = deque()
    # sliding minimum over [i-look, i+look]
    for j in range(m+look):
        if j < m:
            while dq and req[dq[-1]] >= req[j]: dq.pop()
            dq.append(j)
        i = j-look
        if i >= 0:
            while dq[0] < i-look: dq.popleft()
            g[i] = req[dq[0]]
    out = []; cur = 1.
    for i in range(m):
        cur = g[i] if g[i] < cur else cur+(g[i]-cur)*rel
        out.append(cur)
    # smooth attack with a moving average of length `look`, still never above the instantaneous need
    acc = sum(out[:look]); smooth = []
    for i in range(m):
        smooth.append(min(acc/look, out[i]))
        acc += (out[i+look] if i+look < m else 1.)-out[i]
    y = [v*gv for v, gv in zip(src, smooth)]
    return y[n:2*n] if circular else y

def rms(x): return math.sqrt(sum(v*v for v in x)/len(x)) or 1e-9

def normalize(x, target_db, ceiling, circular=False):
    target = 10**(target_db/20)
    for _ in range(10):
        g = target/rms(x); x = [v*g for v in x]
        if max(abs(v) for v in x) <= ceiling*.995: break
        x = limit(x, ceiling*.96, circular)
    g = target/rms(x); x = [v*g for v in x]
    return [max(-ceiling, min(ceiling, v)) for v in x]

def to_pcm(x, loop, ceiling):
    top = int(ceiling*32768)-1
    ints = [max(-top, min(top, round(v*32768))) for v in x]
    if loop:  # spread the wrap step over the last 64 samples so the last sample meets the first
        d = ints[0]-ints[-1]; span = min(64, len(ints)//2)
        for k in range(span):
            i = len(ints)-span+k; ints[i] = max(-top, min(top, ints[i]+round(d*(k+1)/span)))
    else:
        ints[-1] = 0
    a = array.array('h', ints)
    if sys.byteorder != 'little': a.byteswap()
    return a.tobytes(), ints

def render(job):
    key, out_dir, loop, max_seconds, target_db, ceiling, variants = job
    base = dc_block(read_raw(key))
    base = make_loop(base) if loop else trim_one_shot(base, max_seconds)
    results = []
    for v, (ratio, tilt_amount) in enumerate(VARIANTS[:variants]):
        x = resample(base, ratio, circular=loop)
        x = tilt(x, tilt_amount, circular=loop)
        if loop: x = dc_block(x, circular=True)
        else:
            fade = min(int(.01*RATE), len(x)//4)
            for i in range(fade): x[len(x)-fade+i] *= 1-i/fade
        x = normalize(x, target_db, ceiling, circular=loop)
        data, ints = to_pcm(x, loop, ceiling)
        name = f'{key}_{v+1}.wav' if variants > 1 else f'{key}.wav'
        with wave.open(str(out_dir/name), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(data)
        peak = max(abs(i) for i in ints)/32768
        r = math.sqrt(sum((i/32768)**2 for i in ints)/len(ints))
        results.append({'file': name, 'loop': loop, 'frames': len(ints), 'rate': RATE, 'peak': round(peak, 7),
                        'rms': round(r, 7), 'sha256': hashlib.sha256((out_dir/name).read_bytes()).hexdigest()})
    return key, results

def build():
    spec = json.loads(PROMPTS.read_text()); jobs = []; missing = []
    for group, key, e in entries():
        if not (CACHE/f'{key}.pcm').exists(): missing.append(key); continue
        loop = bool(e.get('loop'))
        if group == 'combat':
            jobs.append((key, COMBAT, loop, e['duration_seconds'], -24 if loop else -22, .42 if loop else .7, 3))
        else:
            jobs.append((key, GAME, loop, e['duration_seconds'], GAME_TARGETS.get(key, -22), .7, 1))
    if missing: sys.exit(f'missing cached takes (run generate first): {missing}')
    GAME.mkdir(parents=True, exist_ok=True)
    with ProcessPoolExecutor() as pool: done = dict(pool.map(render, jobs))
    source = ('ElevenLabs Sound Effects (eleven_text_to_sound_v2) generated for this project on the owner\'s paid plan; '
              'one take per family from tools/sfx_prompts.json, variants _2/_3 derived by pitch/speed shift and EQ.')
    license_ = 'ElevenLabs Sound Effects output, paid plan: commercial use permitted per ElevenLabs Terms of Service'
    combat = {'version': 2, 'source': source, 'license': license_, 'generator': 'tools/elevenlabs_sfx.py',
              'prompts': 'tools/sfx_prompts.json', 'normalization': NORMALIZATION,
              'families': {k: done[k] for k in spec['combat']}}
    (COMBAT/'manifest.json').write_text(json.dumps(combat, indent=2)+'\n')
    game = {'version': 1, 'source': source, 'license': license_, 'generator': 'tools/elevenlabs_sfx.py',
            'prompts': 'tools/sfx_prompts.json',
            'normalization': {'metric': 'full-clip RMS dBFS (not LUFS)', 'peak_ceiling': .7,
                              'targets_dbfs': {k: GAME_TARGETS.get(k, -22) for k in spec['game']}},
            'sounds': {k: done[k][0] for k in spec['game']}}
    (GAME/'manifest.json').write_text(json.dumps(game, indent=2)+'\n')
    (COMBAT/'SOURCES.md').write_text(
        '# Combat sound bank\n\nGenerated with the ElevenLabs Sound Effects API (`eleven_text_to_sound_v2`) on the project owner\'s paid '
        'plan; commercial use is permitted under the ElevenLabs Terms of Service. One take per family from '
        '`tools/sfx_prompts.json` (generic physical descriptions, no franchise names); `_1` is the processed take, `_2`/`_3` '
        'are about +4.5% / -4.5% pitch-speed shifts with a slight brighter/darker tilt.\n\n'
        'Built by `python3 tools/elevenlabs_sfx.py build` from the raw takes cached in `art/elevenlabs/raw/` (git-ignored; '
        're-running `generate` never re-pays for a cached take). Processing: stereo downmix, DC block, leading-silence trim '
        'and tail fade on one-shots, 0.25 s equal-power crossfade into 2 s seamless loops, then full-clip RMS normalization '
        '(one-shots -22 dBFS, loops -24 dBFS) with a look-ahead limiter to the 0.70 / 0.42 peak ceilings.\n\n'
        'The previous synthesized bank (`tools/build_combat_audio.py`) is superseded; do not re-run it over this folder.\n\n'
        'RMS is not perceptual loudness: a listening pass in game is required.\n')
    print(f'Built {sum(len(done[k]) for k in spec["combat"])} combat WAVs / {len(spec["combat"])} families and {len(spec["game"])} game sounds.')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('command', choices=['generate', 'build', 'usage'])
    p.add_argument('--only', default='', help='comma-separated keys')
    p.add_argument('--limit', type=int, default=30000, help='never let character_count pass this')
    a = p.parse_args()
    if a.command == 'generate': generate({k for k in a.only.split(',') if k}, a.limit)
    elif a.command == 'usage': print('character_count %d / %d' % usage())
    else: build()
