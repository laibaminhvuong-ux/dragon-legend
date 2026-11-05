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
 assert.equal(exportedSchema.version,8);assert.equal(exportedSchema.slots,10);assert.equal(manifest.schema_version,8);
 const styles=JSON.parse(await fs.readFile(path.join(temp,'fighting_styles.json'),'utf8'));
 assert.deepEqual(styles.order,['turtle','brawler','speedster','crane']);
 for(const profile of Object.values(styles.styles)){assert.equal(profile.combo.length,4);assert.ok(profile.chain_window>0);assert.ok(profile.combo.every(move=>move.id.startsWith(profile.id+'_')));}
 const exportedCharacters=JSON.parse(await fs.readFile(path.join(temp,'characters.json'),'utf8'));
 assert.equal(exportedCharacters.nappa.style,'brawler');assert.equal(exportedCharacters.hit.style,'speedster');assert.equal(exportedCharacters.tien.style,'crane');
 ok('Godot save v8 and four fighting styles exported while classic v6 fixtures remain intact');
 const origins=JSON.parse(await fs.readFile(path.join(temp,'origins.json'),'utf8'));
 const quests=JSON.parse(await fs.readFile(path.join(temp,'quests.json'),'utf8'));
 const npcs=JSON.parse(await fs.readFile(path.join(temp,'npcs.json'),'utf8'));
 const zones=JSON.parse(await fs.readFile(path.join(temp,'zones.json'),'utf8'));
 const cutscenes=JSON.parse(await fs.readFile(path.join(temp,'cutscenes.json'),'utf8'));
 assert.equal(origins.chapters.length,7);assert.deepEqual(quests.slice(0,7).map(q=>q.id),origins.chapters);
 assert.deepEqual(quests.find(q=>q.id==='m01_arrival').after,[origins.last_quest]);
 assert.equal(new Set(npcs.map(n=>n.id)).size,npcs.length,'NPC ids must be unique');
 for(const id of origins.character_ids){assert.ok(exportedCharacters[id]);assert.ok(styles.order.includes(exportedCharacters[id].style));}
 for(const [i,q] of quests.slice(0,7).entries()){
  assert.equal(q.chapter,i+1);assert.ok(q.main&&q.origins&&q.line==='Origins');assert.ok(npcs.some(n=>n.id===q.giver));
  assert.deepEqual(q.after,i?[origins.chapters[i-1]]:[]);
  for(const s of q.steps){if(s.zone)assert.ok(zones[s.zone],s.zone);if(s.npc)assert.ok(npcs.some(n=>n.id===s.npc),s.npc);
   if(s.type==='defeat'){assert.ok(npcs.some(n=>n.id===s.enemy&&n.boss),s.enemy);assert.ok(cutscenes[s.enemy]?.before?.length&&cutscenes[s.enemy]?.after?.length);}}
 }

 const canon=/\b(?:Goku|Krillin|Bulma|Oolong|Puar|Yamcha|Pilaf|Shu|Jackie Chun|Giran|Nam|Silver|White|Murasaki|Android 8|Blue|Tao|Baba|Gohan|Tien|Chiaotzu|Tambourine|Cymbal|Drum|Piccolo|Korin|Yajirobe|Kami|Popo)\b/;
 for(const id of origins.character_ids)assert.ok(!canon.test(exportedCharacters[id].name),exportedCharacters[id].name);
 for(const q of quests.slice(0,7)){
  for(const text of [q.title,q.offer,q.done,...q.steps.flatMap(s=>[s.text,s.reply??''])])assert.ok(!canon.test(text),text);
  for(const s of q.steps.filter(s=>s.type==='defeat'))for(const lines of Object.values(cutscenes[s.enemy]))for(const [speaker,text] of lines){assert.ok(speaker==='you'||npcs.some(n=>n.id===speaker),speaker);assert.ok(!canon.test(text),text);}
 }
 ok('seven Origins chapters, roster, boss scenes, map references and adult handoff are valid');

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
