import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {exportGodotData,collectTables} from './export_godot_data.mjs';
const temp=await fs.mkdtemp(path.join(os.tmpdir(),'dragon-godot-export-'));
let checks=0;const ok=name=>{checks++;console.log('ok',name);};
try{
 const manifest=await exportGodotData(temp),tables=collectTables();
 assert.equal(Object.keys(tables.zones).length,23);assert.equal(tables.stats.MAX_LEVEL,2000);assert.equal(tables.quests.filter(q=>q.main).length,41);
 for(const id of ['s_namek_dragon','s_super_dragon','s_cereal_dragon','t_ui_avatar'])assert.ok(tables.quests.some(q=>q.id===id));
 assert.equal(tables.characters.goku.name,'Gokan');assert.equal(tables.schema.version,6);assert.equal(tables.narrative.talk_range,4.5);assert.ok(tables.narrative.talk_replies.shenron);assert.ok(tables.forms.UITrue);assert.ok(tables.form_looks.SSJ4);
 ok('all loaded story, dragon, form, appearance and renamed content exported');
 const exportedSchema=JSON.parse(await fs.readFile(path.join(temp,'schema.json'),'utf8'));
 assert.equal(exportedSchema.version,7);assert.equal(exportedSchema.slots,10);assert.equal(manifest.schema_version,7);
 const styles=JSON.parse(await fs.readFile(path.join(temp,'fighting_styles.json'),'utf8'));
 assert.deepEqual(styles.order,['turtle','brawler','speedster','crane']);
 for(const profile of Object.values(styles.styles)){assert.equal(profile.combo.length,4);assert.ok(profile.chain_window>0);assert.ok(profile.combo.every(move=>move.id.startsWith(profile.id+'_')));}
 const exportedCharacters=JSON.parse(await fs.readFile(path.join(temp,'characters.json'),'utf8'));
 assert.equal(exportedCharacters.nappa.style,'brawler');assert.equal(exportedCharacters.hit.style,'speedster');assert.equal(exportedCharacters.tien.style,'crane');
 ok('Godot save v7 and four fighting styles exported while classic v6 fixtures remain intact');
 const presentation=JSON.parse(await fs.readFile(path.join(temp,'skill_presentation.json'),'utf8'));
 assert.equal(Object.keys(presentation.skills).length,28);
 for(const id of Object.keys(tables.moves)){const row=presentation.skills[id];assert.ok(row);assert.ok(presentation.sockets.includes(row.socket));assert.ok(row.phases.prepare.audio);assert.ok(row.phases.impact.audio);assert.ok(Number.isFinite(row.hold_min)&&row.hold_min>=0);assert.ok(row.release_window>0);assert.ok(row.recovery>0);assert.equal(row.recovery,row.phases.recovery.duration);}
 assert.equal(presentation.skills.GodKi.availability,'passive');assert.equal(presentation.skills.FusionDance.availability,'not_castable');
 assert.equal(presentation.skills.SpiritBomb.delivery,'instant_ray');ok('every skill has an explicit presentation and availability contract');

 for(const [file,meta] of Object.entries(manifest.files)){const raw=await fs.readFile(path.join(temp,file));assert.equal(raw.byteLength,meta.bytes);assert.equal(createHash('sha256').update(raw).digest('hex'),meta.sha256);JSON.parse(raw);}
 assert.ok(Object.keys(manifest.sources).length>20);ok('manifest hashes every generated table and records source hashes');
 const parity=JSON.parse(await fs.readFile(path.join(temp,'parity.json'),'utf8'));
 assert.equal(Object.keys(parity.zones).length,23);assert.equal(parity.xp.length,2000);assert.equal(parity.xp[1999],0);
 for(const zone of Object.values(parity.zones)){assert.ok(zone.samples.length>=20);assert.ok(zone.samples.every(s=>Number.isFinite(s.height)));assert.equal(typeof zone.props.trees.count,'number');assert.ok(zone.placements.length>0);}
 assert.equal(parity.damage.length,6);assert.ok(parity.damage.every(c=>Number.isFinite(c.damage)));assert.equal(parity.movement.length,6);assert.ok(parity.progression.length>500);assert.deepEqual(parity.saves.map(s=>s.version),[1,2,3,4,5,6]);
 for(const s of parity.saves){assert.deepEqual(JSON.parse(Buffer.from(s.code.slice(4),'base64').toString('utf8')),s.input);assert.equal(s.expected.version,6);assert.equal(s.expected.slots[0].quests.s_dragon_radar.collected.length,3);}
 ok('parity fixtures include all worlds, prop placement, 2000 XP levels and six legacy save codes');
 const before=await fs.readFile(path.join(temp,'manifest.json'),'utf8');await exportGodotData(temp);assert.equal(await fs.readFile(path.join(temp,'manifest.json'),'utf8'),before);
 await exportGodotData(temp,{check:true});await fs.appendFile(path.join(temp,'quests.json'),' ');await assert.rejects(exportGodotData(temp,{check:true}),/Stale generated/);ok('export is deterministic and stale data is detected');
 const project=path.join(temp,'fixture project');await fs.mkdir(path.join(project,'tests'),{recursive:true});await fs.writeFile(path.join(project,'project.godot'),'config_version=5\n');await fs.writeFile(path.join(project,'tests/run_all.gd'),'extends SceneTree\n');
 const fake=path.join(temp,'fake-godot');await fs.writeFile(fake,'#!/bin/sh\nprintf "%s\\n" "$@" >> "$GODOT_RUNNER_LOG"\nexit "${GODOT_FAKE_STATUS:-0}"\n',{mode:0o755});
 const log=path.join(temp,'runner.log');let result=spawnSync('bash',['tools/godot_test.sh','--project',project],{encoding:'utf8',env:{...process.env,GODOT_BIN:fake,GODOT_RUNNER_LOG:log}});assert.equal(result.status,0,result.stderr);
 const args=await fs.readFile(log,'utf8');assert.ok(args.includes(project));assert.ok(args.includes('--headless'));assert.ok(args.includes('--import'));assert.ok(args.includes('res://tests/run_all.gd'));
 result=spawnSync('bash',['tools/godot_test.sh','--project',project],{encoding:'utf8',env:{...process.env,GODOT_BIN:fake,GODOT_RUNNER_LOG:log,GODOT_FAKE_STATUS:'19'}});assert.equal(result.status,19);ok('headless runner quotes paths and propagates failures (stub engine only)');
 console.log(`Godot exporter/runner checks passed: ${checks}. Real engine execution is a separate check.`);
}finally{await fs.rm(temp,{recursive:true,force:true});}
