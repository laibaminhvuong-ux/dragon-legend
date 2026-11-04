#!/usr/bin/env node
// Export evaluated JS content, not source literals: installers and display-name conversion run first.
import fs from 'node:fs/promises';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import * as story from '../web/src/data/story.js';
import * as forms from '../web/src/data/forms.js';
import * as races from '../web/src/data/races.js';
import * as outfits from '../web/src/data/outfits.js';
import * as moves from '../web/src/data/moves.js';
import * as appearance from '../web/src/data/appearance.js';
import * as stats from '../web/src/data/stats.js';
import * as rpg from '../web/src/data/rpg.js';
import * as names from '../web/src/data/names.js';
import * as character from '../web/src/data/character.js';
import * as music from '../web/src/data/music.js';
import {applyGodotAdditions} from './godot_additions.mjs';
import {ZONE_DEFS,ZONE_ORDER} from '../web/src/data/zones.js';
import {ACCESSORIES} from '../web/src/data/accessories.js';
import {COMBAT} from '../web/src/data/combat.js';
import {MOVEMENT} from '../web/src/data/movement.js';
import {CAMERA} from '../web/src/data/camera.js';
import {BOSS_SCENES} from '../web/src/data/cutscenes.js';
import {FORM_LOOKS} from '../web/src/data/form_looks.js';
import {DRAGON_HUNTS,DRAGON_LOOKS,ORB_LOOKS} from '../web/src/data/dragon_hunts.js';
import {KAIOKEN} from '../web/src/data/kaioken.js';
import {INSTINCT_AVATAR} from '../web/src/data/avatar.js';
import {SCHEMA_VERSION,newSlot,migrate} from '../web/src/game/schema.js';
import {defaultLook} from '../web/src/game/look.js';
import * as progression from '../web/src/game/progression.js';
import {ZONES} from '../web/src/game/zones.js';
import {freePosition} from '../web/src/game/placement.js';
import {rng} from '../web/src/game/noise.js';
import {createGame} from '../web/src/game/game.js';
import {stepMovement} from '../web/src/game/movement.js';
import {TUTORIAL_STEPS} from '../web/src/game/tutorial.js';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const digest=value=>createHash('sha256').update(value).digest('hex');
// Only top-level namespace helpers may be omitted. Nested functions/NaN must never silently vanish.
const constants=module=>Object.fromEntries(Object.entries(module).filter(([,v])=>typeof v!=='function'));
function encode(value){return JSON.stringify(value,(_key,v)=>{
 if(typeof v==='function' || typeof v==='undefined' || typeof v==='bigint' || typeof v==='symbol')throw new TypeError('Non-JSON value in Godot table');
 if(typeof v==='number' && !Number.isFinite(v))throw new TypeError('Non-finite number in Godot table');return v;
},2)+'\n';}
function narrativeTables(){
 const source=readFileSync(path.join(root,'web/src/game/story.js'),'utf8');
 const out={talk_range:4.5,pickup_range:2.6};
 for(const key of ['TALK_REPLIES','ITEM_NAMES','AMBIENT']){
  const match=source.match(new RegExp('const '+key+' = (\\{[\\s\\S]*?\\n?\\});'));
  if(!match)throw new Error('Missing story constant '+key);
  const value=vm.runInNewContext('('+match[1]+')',{}, {timeout:1000});names.renameDeep(value);out[key.toLowerCase()]=value;
 }
 return out;
}
export function collectTables(){return {
 narrative:narrativeTables(),
 quests:story.QUESTS,npcs:story.NPCS,characters:story.CHARACTERS,links:story.LINKS,start_zones:story.START_ZONES,
 forms:forms.FORMS,mastery_evolutions:forms.MASTERY_EVOLUTIONS,mastery_tuning:forms.MASTERY_TUNING,
 moves:moves.MOVES,move_order:moves.MOVE_ORDER,races:races.RACES,race_order:races.RACE_ORDER,
 outfits:outfits.OUTFITS,outfit_order:outfits.OUTFIT_ORDER,accessories:ACCESSORIES,zones:ZONE_DEFS,zone_order:ZONE_ORDER,
 stats:constants(stats),combat:COMBAT,movement:MOVEMENT,camera:CAMERA,cutscenes:BOSS_SCENES,form_looks:FORM_LOOKS,
 dragon_hunts:DRAGON_HUNTS,dragon_looks:DRAGON_LOOKS,orb_looks:ORB_LOOKS,kaioken:KAIOKEN,avatar:INSTINCT_AVATAR,
 rpg:constants(rpg),appearance:constants(appearance),names:constants(names),character:constants(character),music:constants(music),
 tutorial_steps:TUTORIAL_STEPS.map(s=>({id:s.id,text:s.text(Object.fromEntries(['jump','dash','flight','ascend','descend','melee','kiBlast','beam','charge','block','lockOn','interact','pause','transform','base'].map(k=>[k,'{'+k+'}'])))})),
 schema:{version:SCHEMA_VERSION,save_code_prefix:'DL1:',slots:stats.SLOT_COUNT,combat_available:story.COMBAT_AVAILABLE},
};}
export function parityFixtures(){
 const zones={};
 for(const [id,def] of Object.entries(ZONE_DEFS)){
  const zone=ZONES[id],random=rng(zone.seed+37),points=[[0,0],[zone.spawn.x,zone.spawn.z],[-zone.size/2,0],[zone.size/2,0],[0,zone.size/2],[zone.size*.4,-zone.size*.42]];
  if(zone.travelPoint)points.push([zone.travelPoint.x,zone.travelPoint.z]);
  for(const p of def.landmarks || []){const at=zone.place(p.x,p.z);points.push([at.x,at.z]);}
  for(let i=0;i<16;i++)points.push([(random()*2-1)*zone.size/2,(random()*2-1)*zone.size/2]);
  if(def.terrain.path)for(const z of [def.terrain.path.from,0,200,def.terrain.path.to]){const p=zone.place(0,z);points.push([p.x,z],[p.x+def.terrain.path.width+3,z]);}
  const props=zone.props();
  zones[id]={seed:zone.seed,spawn:zone.spawn,travel_point:zone.travelPoint,kill_y:zone.killY,
   samples:points.map(([x,z])=>({x,z,height:zone.heightAt(x,z),normal:zone.normalAt(x,z),surface:zone.surfaceAt(x,z),dirt:zone.dirtAt(x,z),forest:zone.forestAt(x,z)})),
   placements:[zone.spawn,zone.travelPoint || zone.spawn,...zone.landmarks.slice(0,3)].map(p=>({input:{x:p.x,z:p.z},expected:freePosition(zone,{x:p.x,z:p.z})})),
   props:Object.fromEntries(['trees','rocks','bushes','stones'].map(k=>[k,{count:props[k].length,first:props[k].slice(0,3)}])),
   near:points.slice(0,4).map(([x,z])=>({x,z,radius:3,expected:props.near(x,z,3)}))};
 }
 const saves=[];
 for(let version=1;version<=SCHEMA_VERSION;version++){
  const slot=newSlot({...defaultLook(version%2?'Saiyan':'HalfSaiyan'),kiColor:6,kiColorHex:'#123abc'},1000);
  slot.level=version<4?73:730;slot.xp=23456;slot.statPoints=9;slot.forms=version<4?['HSSJ','HSSJ2']:['SSJ','SSJ2'];
  slot.quests={m07_vegeta:{status:'done'},s_dragon_radar:{status:'active',step:0,collected:[0,2,5]}};slot.story.flags={shenron:false};
  if(version<6)delete slot.appearance.kiColorHex;if(version<5){delete slot.appearance.kiColor;delete slot.loadout.kaiokenRank;}
  if(version<4){delete slot.formMastery;delete slot.loadout.formPath;}if(version<3)delete slot.loadout.technique;
  const input={version,slots:[slot,null,null],lastSlot:0};saves.push({version,input,code:'DL1:'+Buffer.from(JSON.stringify(input),'utf8').toString('base64'),expected:migrate(structuredClone(input))});
 }
 const progressionCases=[];
 for(const race of races.RACE_ORDER)for(const level of [1,4,149,150,249,250,500,1250,2000]){
  const slot=newSlot(defaultLook(race),1000);slot.level=level;slot.stats={Health:7,Ki:11,Strength:13,KiPower:17,Speed:19};
  for(const form of ['',...races.RACES[race].forms])progressionCases.push({slot,form,derived:progression.derive(slot,form),xp_next:progression.xpToNext(level),forms:progression.formsAtLevel(race,level)});
 }
 const movementCases=[];
 const flat={size:1000,gravity:1,heightAt:()=>0};
 for(const scenario of [
  [{moveX:1,moveZ:1},120], [{dash:true,moveX:1},10], [{flight:true,ascend:true},1], [{charge:true},60], [{jump:true},30], [{flight:true,flyPitch:.8,moveZ:1},1]]){
  const e={pos:{x:0,y:0,z:0},vel:{x:0,y:0,z:0},yaw:0,onGround:true,health:100,ki:80,maxKi:100,kiCostScale:1,runSpeed:8,flying:false,stun:0};
  for(let i=0;i<scenario[1];i++)stepMovement(e,scenario[0],1/60,flat);
  movementCases.push({intents:scenario[0],frames:scenario[1],expected:e});
 }
 const damageCases=[];
 for(const [race,level] of [['Human',1],['Saiyan',1],['Saiyan',500]])for(const blocked of [false,true]){
  const slot=newSlot(defaultLook(race),1000);slot.level=level;
  const log=[];const game=createGame(0,slot,{emit:(event,value)=>{if(event==='damage')log.push(value.amount);}});
  const p=game.player;p.pos={x:0,y:game.zone.heightAt(0,0),z:0};p.yaw=0;
  for(const e of game.combat.enemies){e.pos={x:80,y:0,z:80};e.home={...e.pos};}
  const e=game.combat.enemies[0];e.pos={...p.pos,z:p.pos.z+1.8};e.home={...e.pos};e.health=e.maxHealth=1e6;e.stun=100;e.blocking=blocked;
  game.combat.update(1/60,{melee:true});damageCases.push({race,level,blocked,damage:log[0],ki:e.ki});
 }
 return {format_version:1,damage:damageCases,movement:movementCases,zones,saves,progression:progressionCases,xp:Array.from({length:2000},(_,i)=>progression.xpToNext(i+1))};
}
async function sourceHashes(){
 const out={};for(const folder of ['web/src/data','web/src/game'])for(const name of (await fs.readdir(path.join(root,folder))).sort())if(name.endsWith('.js')){const rel=folder+'/'+name;out[rel]=digest(await fs.readFile(path.join(root,rel)));}
 out['tools/skill_presentation.mjs']=digest(await fs.readFile(path.join(root,'tools/skill_presentation.mjs')));
 out['tools/godot_additions.mjs']=digest(await fs.readFile(path.join(root,'tools/godot_additions.mjs')));
 out['web/src/core/save.js']=digest(await fs.readFile(path.join(root,'web/src/core/save.js')));return out;
}
export async function exportGodotData(outDir,{parity=true,check=false}={}){
 const tables=applyGodotAdditions(collectTables());if(parity)tables.parity=parityFixtures();
 const files={};const encoded={};for(const [name,data] of Object.entries(tables)){const text=encode(data),file=name+'.json';encoded[file]=text;files[file]={sha256:digest(text),bytes:Buffer.byteLength(text),kind:Array.isArray(data)?'array':'object',entries:Array.isArray(data)?data.length:Object.keys(data).length};}
 const manifest={format_version:1,schema_version:SCHEMA_VERSION,source:'web/src (evaluated exports; installed content and display names)',sources:await sourceHashes(),files};encoded['manifest.json']=encode(manifest);
 if(check){for(const [file,text] of Object.entries(encoded)){let actual;try{actual=await fs.readFile(path.join(outDir,file),'utf8');}catch{throw new Error(`Missing generated file: ${file}`);}if(actual!==text)throw new Error(`Stale generated file: ${file}`);}}
 else {await fs.mkdir(outDir,{recursive:true});for(const [file,text] of Object.entries(encoded))await fs.writeFile(path.join(outDir,file),text);}
 return manifest;
}
if(process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href===import.meta.url){
 const args=process.argv.slice(2),option=args.indexOf('--out');
 if(option>=0 && (!args[option+1] || args[option+1].startsWith('--')))throw new Error('--out requires an output directory');
 if(args.includes('--help'))console.log('Usage: node tools/export_godot_data.mjs [--out DIR] [--check] [--no-parity]');
 else {const out=option<0?path.join(root,'godot/data'):path.resolve(args[option+1] || '.');const manifest=await exportGodotData(out,{parity:!args.includes('--no-parity'),check:args.includes('--check')});console.log(`${args.includes('--check')?'Verified':'Exported'} ${Object.keys(manifest.files).length} Godot tables to ${out}`);}
}
