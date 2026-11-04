#!/usr/bin/env python3
"""Check the delivered sound bank, including deterministic reproduction."""
import hashlib, json, math, struct, wave, importlib.util, sys
sys.dont_write_bytecode = True
from pathlib import Path
root = Path(__file__).resolve().parents[1]
folder = root/'godot/assets/audio/combat'
bank = json.loads((folder/'manifest.json').read_text())['families']
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
        count+=1
catalogue=json.loads((root/'godot/data/skill_presentation.json').read_text())
for skill in catalogue['skills'].values():
    for phase in ['prepare','release','impact']: assert skill['phases'][phase]['audio'] in bank
spec=importlib.util.spec_from_file_location('combat_sound_generator',root/'tools/build_combat_audio.py')
generator=importlib.util.module_from_spec(spec); spec.loader.exec_module(generator)
for family,phase in [('impact_light','cue'),('wave','charge')]:
    key=family if phase=='cue' else family+'_'+phase
    pcm,loop=generator.render(family,phase,1)
    with wave.open(str(folder/bank[key][1]['file'])) as w: assert pcm==w.readframes(w.getnframes())
print(f'Audio verified: {count} WAV assets, {len(bank)} banks; hashes, format, levels, seams, variations and catalogue coverage.')
