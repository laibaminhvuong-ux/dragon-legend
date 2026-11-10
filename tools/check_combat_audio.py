#!/usr/bin/env python3
"""Check the delivered sound banks (combat + general game sounds): hashes, format, levels, seams, variations,
catalogue coverage, and provenance (deterministic re-render for the old synth bank; prompt coverage for the
ElevenLabs bank, whose takes are not reproducible offline)."""
import hashlib, json, math, struct, wave, importlib.util, sys
sys.dont_write_bytecode = True
from pathlib import Path
root = Path(__file__).resolve().parents[1]
folder = root/'godot/assets/audio/combat'
manifest = json.loads((folder/'manifest.json').read_text())
bank = manifest['families']
count = 0
for family, entries in bank.items():
    assert len(entries)==3, family
    assert len({e['sha256'] for e in entries})==3, family
    for entry in entries:
        path=folder/entry['file']; raw=path.read_bytes()
        assert hashlib.sha256(raw).hexdigest()==entry['sha256'], path
        with wave.open(str(path)) as w:
            assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes())==(1,2,44100,entry['frames'])
            samples=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
        assert max(abs(s) for s in samples)<32760
        assert math.sqrt(sum(s*s for s in samples)/len(samples))>40
        assert abs(samples[-1]-samples[0])<3 if entry['loop'] else abs(samples[-1])<3
        rms_db=20*math.log10(math.sqrt(sum(s*s for s in samples)/len(samples))/32768)
        assert abs(rms_db-(-24 if entry['loop'] else -22))<.25, (family,rms_db)
        ceiling=.42 if entry['loop'] else .7
        assert max(abs(s) for s in samples)/32768<=ceiling+.0001
        count+=1
catalogue=json.loads((root/'godot/data/skill_presentation.json').read_text())
for skill in catalogue['skills'].values():
    for phase in ['prepare','release','impact']: assert skill['phases'][phase]['audio'] in bank
if manifest['generator']=='tools/build_combat_audio.py':
    spec=importlib.util.spec_from_file_location('combat_sound_generator',root/'tools/build_combat_audio.py')
    generator=importlib.util.module_from_spec(spec); spec.loader.exec_module(generator)
    for family,phase in [('impact_light','cue'),('wave','charge')]:
        key=family if phase=='cue' else family+'_'+phase
        pcm,loop=generator.render(family,phase,1)
        with wave.open(str(folder/bank[key][1]['file'])) as w: assert pcm==w.readframes(w.getnframes())
    provenance='deterministic re-render'
else:
    assert manifest['generator']=='tools/elevenlabs_sfx.py', manifest['generator']
    prompts=json.loads((root/'tools/sfx_prompts.json').read_text())
    assert set(prompts['combat'])==set(bank), 'every family needs exactly one prompt'
    for family,entries in bank.items(): assert all(e['loop']==bool(prompts['combat'][family].get('loop')) for e in entries), family
    game_folder=root/'godot/assets/audio/game'; game=json.loads((game_folder/'manifest.json').read_text())
    assert set(game['sounds'])==set(prompts['game']), 'every game sound needs exactly one prompt'
    for key,entry in game['sounds'].items():
        path=game_folder/entry['file']; raw=path.read_bytes()
        assert hashlib.sha256(raw).hexdigest()==entry['sha256'], path
        with wave.open(str(path)) as w:
            assert (w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes())==(1,2,44100,entry['frames'])
            samples=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
        assert abs(samples[-1])<3, path
        rms_db=20*math.log10(math.sqrt(sum(s*s for s in samples)/len(samples))/32768)
        assert abs(rms_db-game['normalization']['targets_dbfs'][key])<.25, (key,rms_db)
        assert max(abs(s) for s in samples)/32768<=game['normalization']['peak_ceiling']+.0001, key
        count+=1
    provenance=f"ElevenLabs prompt coverage, {len(game['sounds'])} game sounds"
print(f'Audio verified: {count} WAV assets, {len(bank)} banks; hashes, format, levels, seams, variations, catalogue coverage and {provenance}.')
