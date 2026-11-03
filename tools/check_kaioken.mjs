import assert from 'node:assert/strict';
import {createGame,emptyIntents} from '../web/src/game/game.js';
import {newSlot,migrate} from '../web/src/game/schema.js';
import {defaultLook} from '../web/src/game/look.js';
import {KAIOKEN as K} from '../web/src/data/kaioken.js';
import {RACES} from '../web/src/data/races.js';
import {createEvents} from '../web/src/core/events.js';
let n=0;const test=(name,fn)=>{fn();n++;console.log('ok',name);};
function fresh(race='Saiyan',learned=true){
 const slot=newSlot(defaultLook(race));slot.level=2000;slot.forms=[...RACES[race].forms];slot.stats.Ki=5000;slot.loadout.testAllPaths=true;if(learned)slot.moves.push('Kaioken');
 const events=createEvents(),g=createGame(0,slot,events);for(const e of g.combat.enemies)e.health=0;
 g.player.pos={x:0,y:0,z:0};g.player.yaw=0;g.player.onGround=true;return {g,events};
}
const tick=(g,it={},dt=1/60)=>g.update(dt,{...emptyIntents(),...it});
test('learning and intensity gates include old unlocked forms',()=>{
 const {g}=fresh('Saiyan',false);g.slot.forms=[];assert.deepEqual(g.kaioken.ranks(),[]);assert.match(g.kaioken.toggle(),/Learn/);
 g.slot.forms.push('Kaioken');assert.deepEqual(g.kaioken.ranks(),[2]);assert.match(g.kaioken.select(10),/training/);
 g.slot.forms.push('Kaioken10');assert.deepEqual(g.kaioken.ranks(),[2,10]);assert.equal(g.kaioken.select(10),null);
 const p=migrate({version:4,slots:[g.toSave()]});assert.equal(p.slots[0].loadout.kaiokenRank,10);
});
test('both Saiyan races layer over every non-Kaioken form without replacing it or beam',()=>{
 for(const race of ['Saiyan','HalfSaiyan'])for(const form of RACES[race].forms.filter(f=>!f.startsWith('Kaioken'))){
  const {g}=fresh(race);assert.equal(g.selectForm(form),null);const equipped=g.combat.snapshot().technique;
  assert.equal(g.kaioken.toggle(),null);assert.equal(g.player.form,form);assert.equal(g.combat.snapshot().technique,equipped);assert.equal(g.kaioken.multiplier(),2);
  assert.match(g.hud().formName,/\+ Kaiyoken x2/);assert.equal(g.kaioken.toggle(),null);assert.equal(g.player.form,form);
 }
});
test('activation stacks actual melee and Ki damage with Blue form',()=>{
 const normal=fresh(),buff=fresh();normal.g.selectForm('SSJBlue');buff.g.selectForm('SSJBlue');buff.g.kaioken.toggle();
 let a,b;normal.events.on('damage',v=>a=v.amount);buff.events.on('damage',v=>b=v.amount);
 for(const {g} of [normal,buff]){const e=g.combat.enemies[0];e.health=e.maxHealth=1e6;e.pos={x:0,y:0,z:2};e.home={...e.pos};tick(g,{melee:true});tick(g,{kiBlast:true});}
 assert.ok(Math.abs(b-a*2)<=1);assert.equal(buff.g.combat.projectiles[0].damage,normal.g.combat.projectiles[0].damage*2);
 assert.equal(buff.g.hud().powerLevel,normal.g.hud().powerLevel*2);
});
test('x10 unlock has its own multiplier, drain and bounded duration',()=>{
 const {g}=fresh();g.selectForm('SSJBlue');g.kaioken.select(10);assert.equal(g.kaioken.toggle(),null);assert.equal(g.kaioken.multiplier(),10);
 const hp=g.player.health,ki=g.player.ki;tick(g);assert.ok(g.player.health<hp);assert.ok(g.player.ki<ki);
 for(let i=0;i<601;i++)tick(g,{charge:true});assert.equal(g.kaioken.snapshot().active,false);assert.ok(g.kaioken.snapshot().cooldown>0);assert.equal(g.player.form,'SSJBlue');
});
test('cooldown survives equipment/form changes; active state never saves',()=>{
 const {g}=fresh();tick(g,{kaioken:true});assert.equal(g.kaioken.snapshot().active,true);tick(g,{kaioken:true});assert.equal(g.kaioken.snapshot().active,false);
 g.selectForm('SSJ');g.combat.setTechnique('EnergyWave');assert.match(g.kaioken.toggle(),/cooldown/);
 const saved=structuredClone(g.toSave());assert.equal(saved.kaioken,undefined);const resumed=createGame(0,saved);assert.equal(resumed.kaioken.snapshot().active,false);
 for(let i=0;i<Math.ceil(K.cooldown*60)+1;i++)tick(g);assert.equal(g.kaioken.toggle(),null);
});
test('depletion, health strain and death safely stop the overlay',()=>{
 for(const state of ['ki','health','death']){const {g}=fresh();g.kaioken.toggle();if(state==='ki')g.player.ki=0;else g.player.health=state==='death'?0:g.player.maxHealth*K.minHealth;tick(g);assert.equal(g.kaioken.snapshot().active,false);if(state==='death')assert.equal(g.player.health,0);}
});
test('Kaioken cannot multiply its own form; other races keep base technique only',()=>{
 const {g}=fresh();g.selectForm('Kaioken');assert.match(g.kaioken.toggle(),/itself/);g.selectForm('SSJ');g.kaioken.toggle();g.selectForm('Kaioken10');assert.equal(g.kaioken.snapshot().active,false);
 const h=fresh('Human').g;assert.equal(h.kaioken.toggle(),null);h.kaioken.toggle();h.selectForm('PotentialUnleashed');assert.match(h.kaioken.toggle(),/Saiyan/);
});
console.log(`Kaioken checks passed: ${n}`);
