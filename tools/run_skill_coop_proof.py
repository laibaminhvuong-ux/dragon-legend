#!/usr/bin/env python3
"""Run actual Godot host/client processes on 127.0.0.1; nonzero when transport is unavailable."""
import argparse, json, os, pathlib, shutil, subprocess, sys, tempfile, time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--godot',default=os.environ.get('GODOT_BIN') or shutil.which('godot') or str(pathlib.Path.home()/'.cache/godot/Godot_v4.7.2-stable_linux.x86_64'))
    p.add_argument('--port',type=int,default=18936)
    p.add_argument('--skip-import',action='store_true',help='Use only when the project was already imported by Godot')
    p.add_argument('--output',type=pathlib.Path,default=pathlib.Path(tempfile.mkdtemp(prefix='dragon-skill-proof-')))
    args=p.parse_args(); args.output.mkdir(parents=True,exist_ok=True); output=args.output.resolve()
    def engine_path(path):
        if args.godot.lower().endswith('.exe') and sys.platform!='win32': return subprocess.check_output(['wslpath','-w',str(path)],text=True).strip()
        return str(path)
    common=[args.godot,'--headless','--path',engine_path(ROOT/'godot'),'res://tests/network/skill_proof.tscn','--']
    children=[]; logs=[]
    try:
        def launch(mode):
            stream=(output/(mode+'.log')).open('w'); logs.append(stream)
            command=common+[f'--mode={mode}',f'--port={args.port}',f'--ready={engine_path(output/"ready.json")}',f'--report={engine_path(output/(mode+".json"))}']
            child=subprocess.Popen(command,stdout=stream,stderr=subprocess.STDOUT); children.append(child); return child
        if not args.skip_import:
            with (output/'import.log').open('w') as stream:
                imported=subprocess.run([args.godot,'--headless','--path',engine_path(ROOT/'godot'),'--editor','--import','--quit'],stdout=stream,stderr=subprocess.STDOUT,timeout=90)
            if imported.returncode: raise RuntimeError(f'Godot import exited {imported.returncode}; inspect import.log')
        host=launch('host'); deadline=time.monotonic()+30
        while not (output/'ready.json').exists():
            if host.poll() is not None: raise RuntimeError(f'Host exited {host.returncode}; inspect {output/"host.log"} (78 means listener unavailable).')
            if time.monotonic()>deadline: raise RuntimeError('Host handshake timed out')
            time.sleep(.05)
        # The ready file may have just been opened; wait for the complete JSON document.
        while True:
            try: json.loads((output/'ready.json').read_text()); break
            except json.JSONDecodeError:
                if time.monotonic()>deadline: raise RuntimeError('Incomplete handshake JSON')
                time.sleep(.02)
        client=launch('client')
        for child in [client,host]:
            code=child.wait(timeout=max(1,deadline-time.monotonic()))
            if code: raise RuntimeError(f'Godot process exited {code}; inspect logs in {output}')
        h=json.loads((output/'host.json').read_text()); c=json.loads((output/'client.json').read_text())
        assert h['passed'] and c['passed'] and h['pid']!=c['pid']
        expected=['KiBlast','EnergyWave','DestructoDisc','WolfFangFist','InstantTransmission','SpiritBomb']
        assert [x['move_id'] for x in h['casts']]==expected and set(c['releases'])==set(expected)
        assert c['late_join_skillState'] and c['self_localisation'] and c['host_actor']==h['actor']
        for cast in h['casts']:
            received=c['releases'][cast['move_id']]
            assert received['actor_id']==h['actor'] and received['sequence']==cast['sequence'] and received['seed']==cast['seed']
        wolf=next(x for x in h['casts'] if x['move_id']=='WolfFangFist')
        for field in ['combo_step','combo_length','strike','finisher']: assert c['releases']['WolfFangFist'][field]==wolf[field]
        for move in ['KiBlast','DestructoDisc']:
            assert c['projectiles'][move]['sequence']==c['releases'][move]['sequence']
        print(f'PASS: separate host/client PIDs {h["pid"]}/{c["pid"]}, all six casts, both projectile contexts, late-join state and self/remote localisation. Evidence: {output}')
        return 0
    except (OSError,RuntimeError,AssertionError,subprocess.TimeoutExpired) as error:
        print(f'FAIL (not a network pass): {error}\nEvidence: {output}',file=sys.stderr); return 1
    finally:
        for child in children:
            if child.poll() is None:
                child.terminate()
                try: child.wait(timeout=3)
                except subprocess.TimeoutExpired: child.kill(); child.wait()
        for stream in logs: stream.close()
if __name__=='__main__': sys.exit(main())
