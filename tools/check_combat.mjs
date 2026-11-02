import assert from 'node:assert/strict';
import { createGame, emptyIntents } from '../web/src/game/game.js';
import { newSlot } from '../web/src/game/schema.js';
import { defaultLook } from '../web/src/game/look.js';
import { createEvents } from '../web/src/core/events.js';
import { COMBAT as C } from '../web/src/data/combat.js';
const dt=1/60;
const tick=(g,it={},n=1)=>{for(let i=0;i<n;i++)g.update(dt,{...emptyIntents(),...it});};
function fresh(){
  const ev=createEvents(),g=createGame(0,newSlot(defaultLook('Human')),ev);
  g.combat.enemies.forEach((e,i)=>{e.pos={x:80+i*10,y:0,z:80};e.home={...e.pos};});
  g.player.pos={x:0,y:0,z:0};
  const e=g.combat.enemies[0];e.pos={x:0,y:0,z:1.8};e.home={...e.pos};
  return {g,e,ev};
}
let checks=0;const t=(name,fn)=>{fn();checks++;console.log('ok',name);};
t('melee validates range and facing, cooldown prevents repeated hits',()=>{
  const {g,e}=fresh();g.player.yaw=Math.PI;tick(g,{melee:true});assert.equal(e.health,e.maxHealth);
  tick(g,{},25);g.player.yaw=0;tick(g,{melee:true});const hp=e.health;assert.ok(hp<e.maxHealth);
  tick(g,{melee:true});assert.equal(e.health,hp);
  e.pos.z=20;tick(g,{},25);tick(g,{melee:true});assert.equal(e.health,hp);
});
t('real kills grant XP and zeni once and emit defeat',()=>{
  const {g,e,ev}=fresh();let deaths=0;ev.on('enemyDefeated',()=>deaths++);
  const before=g.slot.zeni;
  for(let i=0;i<300&&e.health>0;i++)tick(g,{melee:true,lockOn:i===0});
  assert.equal(e.health,0);assert.equal(deaths,1);assert.ok(g.slot.zeni>before);assert.ok(g.slot.xp>0||g.slot.level>1);
  tick(g,{melee:true},20);assert.equal(deaths,1);
});
t('ki blast uses ki, travels, hits and respects its cooldown',()=>{
  const {g,e}=fresh();e.pos.z=8;e.home={...e.pos};const initial=e.health;
  tick(g,{kiBlast:true});assert.ok(g.player.ki<g.player.maxKi);assert.equal(g.combat.projectiles.length,1);
  tick(g,{kiBlast:true});assert.equal(g.combat.projectiles.length,1);
  tick(g,{},25);assert.ok(e.health<initial);assert.equal(g.combat.projectiles.length,0);
});
t('charged skill hits on release; insufficient ki rejects attacks',()=>{
  const {g,e}=fresh();e.pos.z=9;e.home={...e.pos};
  tick(g,{beam:true},60);assert.equal(e.health,e.maxHealth);assert.ok(g.combat.snapshot().beamCharge>0);
  tick(g);assert.ok(e.health<e.maxHealth);assert.ok(g.combat.snapshot().beamCd>0);
  g.player.ki=0;const count=g.combat.projectiles.length;tick(g,{kiBlast:true});assert.equal(g.combat.projectiles.length,count);
});
t('guard reduces hostile damage and spends ki',()=>{
  const unguarded=fresh(),guarded=fresh();
  tick(unguarded.g,{},46);tick(guarded.g,{block:true},46);
  const raw=unguarded.g.player.maxHealth-unguarded.g.player.health,guard=guarded.g.player.maxHealth-guarded.g.player.health;
  assert.ok(raw>0);assert.ok(guard<raw);assert.ok(guarded.g.player.ki<guarded.g.player.maxKi);
});
t('hostiles leash home, restore health and cannot attack across flight altitude',()=>{
  const {g,e}=fresh();e.health/=2;g.player.pos={x:0,y:30,z:1.8};g.player.flying=true;
  tick(g,{},60);assert.equal(g.player.health,g.player.maxHealth);assert.ok(e.health>e.maxHealth/2);
});
t('death respawns at safe spawn and preserves quest/progression data',()=>{
  const {g}=fresh();g.slot.quests.test={status:'active',step:0};g.player.health=1;
  tick(g,{},48);assert.equal(g.player.health,0);assert.ok(g.combat.snapshot().respawn>0);
  const zeni=g.slot.zeni;tick(g,{},Math.ceil(C.respawnSeconds/dt)+2);
  assert.equal(g.player.health,g.player.maxHealth);assert.equal(g.slot.zeni,zeni);assert.equal(g.slot.quests.test.status,'active');
  assert.equal(g.player.pos.x,g.zone.spawn.x);assert.equal(g.player.pos.z,g.zone.spawn.z);
});
t('locked targets clear on death or range; techniques require unlocks',()=>{
  const {g,e}=fresh();tick(g,{lockOn:true});assert.equal(g.player.lockTarget,e.id);
  g.player.pos.x=100;tick(g);assert.equal(g.player.lockTarget,null);
  assert.equal(g.combat.setTechnique('Kamehameha'),false);g.slot.moves.push('Kamehameha');assert.equal(g.combat.setTechnique('Kamehameha'),true);
});
t('transformations require race quest unlocks and revert when ki runs out',()=>{
  const {g}=fresh();tick(g,{transform:true});assert.equal(g.player.form,'');
  g.slot.race='Saiyan';g.slot.level=25;g.slot.forms=['SSJ'];g.refreshDerived(true);tick(g,{transform:true});assert.equal(g.player.form,'SSJ');
  const strength=g.player.strength;g.player.ki=0;tick(g);assert.equal(g.player.form,'');assert.ok(g.player.strength<strength);
});
console.log(`${checks} combat checks passed`);
