#!/usr/bin/env python3
"""Deterministic original layered sound bank; no external recordings or runtime synthesis.
Physical-model impact transients, filtered air/foley layers, modal bodies, FM energy layers,
and early-reflection tails. Source is original project sound design, not recorded foley.
"""
import argparse,array,hashlib,json,math,pathlib,random,struct,wave
ROOT=pathlib.Path(__file__).resolve().parents[1]
RATE=44100
FAMILIES=['wave','blast','disc','flare','triad','rush','transform','spirit','spiral','lance','galick','flash','heavy','needle','eclipse','heal','sweet','transfer','evade','demon','chime','destroy','focus','avatar','shield','impact']
LEGACY=['impact_light','impact_heavy','kick','guard','swing','landing','flight','transform','charge_loop']
def render(family,phase,variant):
    seed=int.from_bytes(hashlib.sha256(f'{family}:{phase}:{variant}'.encode()).digest()[:8],'little')
    rng=random.Random(seed)
    loop=phase=='charge' or family=='charge_loop'
    percussive=family in ['impact_light','impact_heavy','kick','guard','impact','landing']
    duration=2.0 if loop else (0.22 if percussive else 0.32 if family in ['needle','blast','swing','evade'] else 0.65 if phase=='release' else 0.8)
    if family in ['spirit','eclipse','destroy','avatar','flash'] and not loop:duration=1.25 if phase=='impact' else 0.95
    n=int(duration*RATE); overlap=int(.12*RATE) if loop else 0
    low=0.;mid=0.;slow=0.;phase_a=0.;phase_b=0.;signal=[]
    base={'disc':640,'needle':1200,'wave':170,'galick':135,'spirit':85,'eclipse':64,'destroy':72,'focus':330,'heal':440,'shield':240,'sweet':520,'triad':190,'flash':120,'spiral':520,'transfer':700,'evade':480,'chime':660,'avatar':55,'impact_light':135,'impact_heavy':65,'kick':83,'guard':980,'landing':70}.get(family,120)
    base*=1+(variant-1)*.045
    modes=[(base*rng.uniform(.93,1.08)*r,rng.uniform(.55,.95),rng.uniform(0,math.tau)) for r in [1.,1.47,2.13,3.27,4.91]]
    for i in range(n+overlap):
        t=i/RATE;p=t/duration
        noise=rng.uniform(-1,1);low+=.07*(noise-low);mid+=.35*(noise-mid);slow+=.006*(noise-slow)
        air=mid-low;high=noise-mid
        sweep=1+(2.2*math.exp(-t*25) if percussive else .35*math.sin(t*math.tau*1.5) if loop else (1-p)*.8)
        phase_a+=math.tau*base*sweep/RATE;phase_b+=math.tau*base*1.003/RATE
        modal=sum(a*math.sin(math.tau*f*t+q)*math.exp(-t*(5+j*2)) for j,(f,a,q) in enumerate(modes))*.12
        if percussive and loop:
            # A charge is sustained air/body, not an isolated impact followed by silence.
            value=(math.sin(phase_a)*.12+low*.8+air*.08)*(.85+.15*math.sin(t*math.tau*4))
        elif percussive:
            body=math.sin(phase_a+math.sin(phase_a*.5)*.35)*math.exp(-t*22)*.5
            texture=low*math.exp(-t*16)*1.8+air*math.exp(-t*70)*.4
            if family=='guard':body=modal*math.exp(-t*4);texture=high*math.exp(-t*60)*.15
            value=body+texture+modal*.5
        elif family in ['heal','chime','focus','sweet']:
            value=(math.sin(phase_a)+.35*math.sin(phase_a*1.5)+.22*math.sin(phase_a*2.5))*.15+slow*.8+air*.07
            value*=.8+.2*math.sin(t*math.tau*3)
        elif family in ['swing','evade','flight','transfer','disc']:
            whoosh=math.sin(min(1,p)*math.pi)**2 if not loop else .6+.25*math.sin(t*math.tau*2)
            value=(air*.75+low*1.4+high*.1)*whoosh
            if family=='disc': value+=math.sin(phase_a+math.sin(t*math.tau*25)*2)*.13*(.65+.35*math.sin(t*math.tau*21))
            if family=='transfer': value+=math.sin(phase_a*(1-p*.35))*.15
        else:
            fm=math.sin(phase_a+math.sin(phase_a*.25)*(.8 if loop else 2.0))
            pulse=.7+.3*math.sin(t*math.tau*(8+variant))
            value=(fm*.16+math.sin(phase_b)*.1+low*1.35+air*.16)*pulse+slow*.5
            if family in ['spiral','triad','needle']:value+=math.sin(phase_a*2+math.sin(t*math.tau*31))*air*.32
            if family in ['spirit','eclipse','destroy','avatar','transform']:value+=math.sin(phase_a*.5)*.23+low*.9
        if not loop:
            attack=min(1,t/(.002 if percussive else .012))
            env=attack*max(0,1-p)**(.9 if phase=='impact' else 1.3)
            if not percussive:value*=.6+.4*math.sin(min(1,p)*math.pi)
            value*=env
        signal.append(value)
    if loop:
        output=signal[overlap:n]
        for i in range(overlap):
            x=i/max(1,overlap-1)
            output.append(signal[n+i]*(1-x)+signal[i]*x)
        output[-1]=output[0]
    else:
        output=signal[:n]
        # Small asymmetric early reflections add a room/impact tail without a reverb wall.
        source=output[:]
        for delay,gain in [(int(.023*RATE),.16),(int(.047*RATE),.09),(int(.081*RATE),.045)]:
            for i in range(delay,n):output[i]+=source[i-delay]*gain
        fade=min(int(.012*RATE),n//4)
        for i in range(fade):output[-fade+i]*=1-i/max(1,fade-1)
        output[0]=output[-1]=0.
    # Full-clip RMS targets are explicit (not LUFS). Compress only excessive crest factors.
    target=10**((-24 if loop else -22)/20)
    ceiling=.42 if loop else .7
    for _ in range(8):
        rms=math.sqrt(sum(x*x for x in output)/len(output)) or 1
        gain=target/rms
        output=[x*gain for x in output]
        peak=max(abs(x) for x in output)
        if peak<=ceiling: break
        output=[ceiling*math.tanh(x/ceiling) for x in output]
    peak=max(abs(x) for x in output) or 1
    if peak>ceiling: output=[x*ceiling/peak for x in output]
    pcm=array.array('h',(round(x*32767) for x in output))
    if struct.pack('=H',1)!=struct.pack('<H',1):pcm.byteswap()
    return pcm.tobytes(),loop

def build(out):
    out.mkdir(parents=True,exist_ok=True)
    sounds={}
    keys=[(f,p) for f in FAMILIES for p in ['charge','release','impact']]+[(f,'cue') for f in LEGACY if f not in FAMILIES]
    for family,phase in keys:
        key=family if phase=='cue' else family+'_'+phase
        sounds[key]=[]
        for variant in range(3):
            data,loop=render(family,phase,variant)
            file=f'{key}_{variant+1}.wav'
            with wave.open(str(out/file),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(data)
            samples=array.array('h');samples.frombytes(data)
            peak=max(abs(x) for x in samples)/32768
            rms=math.sqrt(sum((x/32768)**2 for x in samples)/len(samples))
            sounds[key].append({'file':file,'loop':loop,'frames':len(samples),'rate':RATE,'peak':round(peak,7),'rms':round(rms,7),'sha256':hashlib.sha256((out/file).read_bytes()).hexdigest()})
    manifest={'version':1,'source':'Original project sound design: offline modal/transient/noise/FM layers and early reflections. No external recordings.','license':'CC0-1.0','generator':'tools/build_combat_audio.py','normalization':{'metric':'full-clip RMS dBFS (not LUFS)','one_shot_target_dbfs':-22,'loop_target_dbfs':-24,'one_shot_peak_ceiling':.7,'loop_peak_ceiling':.42},'families':sounds}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (out/'SOURCES.md').write_text('# Combat sound bank\n\nOriginal project audio rendered by `tools/build_combat_audio.py`. CC0-1.0. No third-party samples are included. These are designed/synthesized assets, not recorded human foley. The generator, seed, hashes, loop flags, frames, RMS and peaks are recorded for reproducibility.\n\nFull-clip RMS normalization: one-shots -22 dBFS, loops -24 dBFS, with crest compression and peak ceilings. RMS is not perceptual LUFS; listening is required.\n\nThree variations per family/phase; runtime playback uses the WAV bank instead of synthesizing six cues. Listening review in the game is required; sample counts or tests do not establish aesthetic quality.\n')
    print(f'Rendered {sum(map(len,sounds.values()))} original WAV assets across {len(sounds)} phase/family banks.')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=pathlib.Path,default=ROOT/'godot/assets/audio/combat');args=parser.parse_args();build(args.out)
