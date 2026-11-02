import assert from 'node:assert/strict';
import { createGame,emptyIntents } from '../web/src/game/game.js';
import { createStory } from '../web/src/game/story.js';
import { newSlot,migrate,SCHEMA_VERSION } from '../web/src/game/schema.js';
import { defaultLook } from '../web/src/game/look.js';
import { createEvents } from '../web/src/core/events.js';
import { INSTINCT_AVATAR as A,canManifestAvatar } from '../web/src/data/avatar.js';
import { MOVES } from '../web/src/data/moves.js';
const dt=1/60;let checks=0;
const test=(name,fn)=>{fn();checks++;console.log('ok',name);};
function fresh(race='Saiyan'){
  const slot=newSlot(defaultLook(race));slot.level=2000;slot.forms=['UIPerfected','UITrue','UIOmen'];slot.moves=[A.id,'GodKi'];slot.loadout.formPath='instinct';slot.story.items.instinctMastery=1;
  const ev=createEvents(),g=createGame(0,slot,ev);g.selectForm('UIPerfected');
  g.combat.enemies.forEach((e,i)=>{e.pos={x:80+i*5,y:0,z:80};e.home={...e.pos};});
  assert.ok(g.combat.setTechnique(A.id));const messages=[];ev.on('notify',e=>messages.push(e.text));
  return {slot,g,ev,messages};
}
const tick=(g,it={},n=1)=>{for(let i=0;i<n;i++)g.update(dt,{...emptyIntents(),...it});};
const activate=g=>{tick(g,{beam:true},2);tick(g);};
test('Avatar requires a learned move, level/path and a full UI form',()=>{
  for(const race of ['Saiyan','HalfSaiyan']){
    const {g,slot}=fresh(race);assert.ok(canManifestAvatar(slot,g.player));
    for(const form of ['','UIOmen','SSJ']){g.player.form=form;activate(g);assert.equal(g.combat.snapshot().avatar.active,false);}
    g.player.form='UIPerfected';slot.loadout.formPath='ego';activate(g);assert.equal(g.combat.snapshot().avatar.active,false);
    slot.loadout.formPath='instinct';slot.level=1999;assert.equal(canManifestAvatar(slot,g.player),false);
    slot.level=2000;slot.moves=[];assert.equal(g.combat.setTechnique(A.id),false);assert.equal(canManifestAvatar(slot,g.player),false);
  }
});
test('activation spends scaled ki once and starts its own duration/cooldown',()=>{
  const {g}=fresh(),p=g.player,ki=p.ki;activate(g);
  const state=g.combat.snapshot().avatar;assert.ok(state.active);assert.ok(state.remaining<=A.duration && state.remaining>A.duration-.1);
  assert.ok(state.cooldown>A.cooldown-.1);assert.ok(ki-p.ki>=MOVES[A.id].kiCost*p.kiCostScale);
  assert.equal(g.combat.projectiles.length,0,'Avatar is not a disguised projectile');
});
test('Avatar delivers real forward area hits without hitting behind the player',()=>{
  const {g,ev}=fresh(),[front,second,behind]=g.combat.enemies;
  for(const [e,x,z]of [[front,0,8],[second,2,9],[behind,0,-6]]){e.pos={x,y:0,z};e.home={...e.pos};e.maxHealth=e.health=1e6;}
  let damage=0,pulses=0;ev.on('damage',e=>{if(e.id!==g.player.id)damage++;});ev.on('avatarStrike',()=>pulses++);
  activate(g);const first=front.health;assert.ok(first<front.maxHealth);assert.ok(second.health<second.maxHealth);assert.equal(behind.health,behind.maxHealth);
  tick(g,{},60);assert.ok(front.health<first);assert.ok(damage>=4&&pulses>=2);assert.equal(behind.health,behind.maxHealth);
});
test('insufficient ki rejects activation without starting its cooldown',()=>{
  const {g,messages}=fresh();g.player.ki=MOVES[A.id].kiCost*g.player.kiCostScale/2;const before=g.player.ki;
  activate(g);assert.equal(g.combat.snapshot().avatar.active,false);assert.equal(g.combat.snapshot().avatar.cooldown,0);
  assert.ok(before-g.player.ki<100,'only normal transformation drain was charged');assert.ok(messages.some(m=>m.includes('Not enough ki')));
});
test('Avatar lasts 60 seconds and its 120-second cooldown survives technique swaps',()=>{
  assert.equal(A.duration,60);assert.equal(A.cooldown,120);
  const {g}=fresh();activate(g);
  // Sustain the required UI form so this checks the Avatar timer, not ki exhaustion.
  tick(g,{charge:true},Math.floor(59/dt));assert.equal(g.combat.snapshot().avatar.active,true);
  assert.ok(g.combat.snapshot().avatar.remaining>0 && g.combat.snapshot().avatar.remaining<=1);
  tick(g,{charge:true},Math.ceil(1/dt)+1);assert.equal(g.combat.snapshot().avatar.active,false);
  assert.ok(g.combat.snapshot().avatar.cooldown>59 && g.combat.snapshot().avatar.cooldown<=60);
  g.combat.setTechnique('EnergyWave');g.combat.setTechnique(A.id);activate(g);assert.equal(g.combat.snapshot().avatar.active,false);
  tick(g,{charge:true},Math.ceil(59/dt));assert.ok(g.combat.snapshot().avatar.cooldown>0);
  tick(g,{charge:true},Math.ceil(2/dt));assert.equal(g.combat.snapshot().avatar.cooldown,0);
  activate(g);assert.equal(g.combat.snapshot().avatar.active,true);
});
test('death, form loss and ki exhaustion cancel the manifestation',()=>{
  for(const reason of ['death','form','ki']){
    const {g}=fresh();activate(g);
    if(reason==='death')g.player.health=0;
    if(reason==='form')g.selectForm('');
    if(reason==='ki')g.player.ki=0;
    tick(g);assert.equal(g.combat.snapshot().avatar.active,false);assert.ok(g.combat.snapshot().avatar.cooldown>0);
  }
});
test('Moro mastery unlock quest requires training in full UI and persists the learned ability',()=>{
  const {slot}=fresh();slot.zone='earth_plains';slot.position=null;slot.moves=['GodKi'];
  for(const id of ['m35_moro_escape','m37_moro_final','t_ui_moro_mastery'])slot.quests[id]={status:'done',completions:1};
  const g=createGame(0,slot),story=createStory(g);const giver=story.npcs().find(n=>n.id==='merus_earth');assert.ok(giver);
  Object.assign(g.player.pos,{x:giver.x+1,y:giver.y,z:giver.z});assert.ok(story.acceptQuest('t_ui_avatar'));
  story.update(1,{charge:true});assert.equal(slot.quests.t_ui_avatar.t,0,'base-form training cannot progress');
  g.selectForm('UIPerfected');for(let i=0;i<46;i++)story.update(1,{charge:true});
  assert.equal(slot.quests.t_ui_avatar.status,'done');assert.ok(slot.moves.includes(A.id));
  const copy=migrate({version:SCHEMA_VERSION,slots:[structuredClone(g.toSave())],lastSlot:0});
  const restored=createGame(0,copy.slots[0]);assert.ok(restored.combat.availableTechniques().includes(A.id));assert.equal(restored.combat.snapshot().avatar.active,false);
});
console.log(`${checks} Avatar checks passed`);
