import assert from 'node:assert/strict';
import { createGame, emptyIntents } from '../web/src/game/game.js';
import { createStory } from '../web/src/game/story.js';
import { newSlot, migrate } from '../web/src/game/schema.js';
import { defaultLook } from '../web/src/game/look.js';
import { createEvents } from '../web/src/core/events.js';
import { QUESTS } from '../web/src/data/story.js';
import { ZONES } from '../web/src/game/zones.js';
const dt=1/60;let checks=0;
const t=(name,fn)=>{fn();checks++;console.log('ok',name);};
function session(zone='earth_plains'){
  const ev=createEvents(),slot=newSlot(defaultLook('Saiyan'));slot.zone=zone;
  const game=createGame(0,slot,ev),story=createStory(game,ev),log=[];ev.on('dialogue',d=>log.push(d));
  const tick=(it={})=>{const intents={...emptyIntents(),...it};game.update(dt,intents);story.update(dt,intents);};
  return {game,story,slot,log,tick};
}
function atNpc(s,id){const n=s.story.npcs().find(n=>n.id===id);assert.ok(n);Object.assign(s.game.player.pos,{x:n.x+1,y:n.y,z:n.z});return n;}
t('interaction is discoverable and G opens a choice before accepting',()=>{
  const s=session();atNpc(s,'guide_earth_plains');assert.equal(s.story.interaction().name,'Training Guide');
  s.story.update(dt,{interact:true});assert.equal(s.log.at(-1).kind,'choice');assert.equal(s.slot.quests.hunt_earth_plains,undefined);
  assert.ok(s.story.acceptQuest('hunt_earth_plains'));assert.equal(s.slot.quests.hunt_earth_plains.status,'active');
  Object.assign(s.game.player.pos,{x:150,y:0,z:150});assert.equal(s.story.acceptQuest('m01_arrival'),false);
});
t('patrol quests require actual kills, pay rewards and can repeat',()=>{
  const s=session();atNpc(s,'guide_earth_plains');assert.ok(s.story.acceptQuest('hunt_earth_plains'));
  s.story.update(dt,{interact:true});assert.equal(s.slot.quests.hunt_earth_plains.count,0);
  const before=s.slot.zeni;
  for(const e of [...s.game.combat.enemies]) {
    e.pos={x:0,y:0,z:1.8};e.home={...e.pos};
    for(const other of s.game.combat.enemies)if(other!==e&&other.health>0){other.pos={x:90,y:0,z:90};other.home={...other.pos};}
    Object.assign(s.game.player.pos,{x:0,y:0,z:0});s.game.player.lockTarget=e.id;
    for(let i=0;i<400&&e.health>0;i++)s.tick({melee:true});
    assert.equal(e.health,0,'enemy defeated through real attacks');
  }
  assert.equal(s.slot.quests.hunt_earth_plains.completions,1);assert.ok(s.slot.zeni>before);assert.ok(s.slot.statPoints>0);
  const migrated=migrate({version:2,slots:[structuredClone(s.game.toSave())],lastSlot:0});
  assert.equal(migrated.slots[0].quests.hunt_earth_plains.completions,1);
  atNpc(s,'guide_earth_plains');assert.ok(s.story.acceptQuest('hunt_earth_plains'));assert.equal(s.slot.quests.hunt_earth_plains.count,0);
});
t('all worlds have a reachable guide and grounded combat camp',()=>{
  for(const id of Object.keys(ZONES).filter(id=>ZONES[id].id===id)){
    const s=session(id),guide=s.story.npcs().find(n=>n.id===`guide_${id}`);assert.ok(guide,`${id} guide`);
    assert.ok(guide.y>-100,`${id} guide not in void`);
    for(const npc of s.story.npcs())assert.ok(!s.game.zone.props().near(npc.x,npc.z,.35).some(c=>npc.y<=c.top && Math.hypot(npc.x-c.x,npc.z-c.z)<c.radius+.35),`${id}: ${npc.name} is reachable outside buildings`);
    for(const e of s.game.combat.enemies){
      assert.ok(e.pos.y>-100,`${id} camp not in void`);
      assert.ok(!s.game.zone.props().near(e.pos.x,e.pos.z,.35).some(c=>e.pos.y<=c.top && Math.hypot(e.pos.x-c.x,e.pos.z-c.z)<c.radius+.35),`${id} enemy outside props/buildings`);
    }
    assert.ok(QUESTS.some(q=>q.id===`hunt_${id}`&&q.repeat));
  }
});
t('abandon and track use validated quest ids',()=>{
  const s=session();assert.equal(s.story.trackQuest('garbage'),false);atNpc(s,'guide_earth_plains');s.story.acceptQuest('hunt_earth_plains');
  assert.ok(s.story.trackQuest('hunt_earth_plains'));assert.equal(s.story.waypoint().questId,'hunt_earth_plains');
  assert.ok(s.story.abandonQuest('hunt_earth_plains'));assert.equal(s.story.tracker().length,0);
});

t('guide shops validate distance, funds, inventory and outfit ownership',()=>{
  const s=session();assert.ok(s.story.buy('capsule')); // error: not beside guide
  atNpc(s,'guide_earth_plains');const before=s.slot.zeni;
  assert.equal(s.story.buy('capsule'),null);assert.equal(s.slot.zeni,before-75);assert.equal(s.story.journal().items.capsule,1);
  assert.equal(s.story.buy('capsule'),'Not enough zeni. Complete patrols and story quests to earn more.');
  s.game.player.health-=30;assert.equal(s.story.useItem('capsule'),true);assert.equal(s.story.journal().items.capsule,0);
  assert.equal(s.story.useItem('capsule'),false);
  s.game.addZeni(5000);assert.equal(s.story.buy('CraneGi'),null);assert.ok(s.slot.outfits.includes('CraneGi'));
  assert.equal(s.game.equipOutfit('CraneGi'),true);assert.equal(s.slot.appearance.outfit,'CraneGi');assert.equal(s.game.equipOutfit('AngelRobe'),false);
});

t('v2 loadouts migrate and equipped techniques survive saving and travel',()=>{
  const s=session();s.slot.moves.push('Kamehameha');assert.ok(s.game.combat.setTechnique('Kamehameha'));
  const migrated=migrate({version:2,slots:[structuredClone(s.game.toSave())],lastSlot:0});
  const restored=createGame(0,migrated.slots[0]);assert.equal(restored.combat.snapshot().technique,'Kamehameha');
  delete migrated.slots[0].loadout;
  const old=migrate(migrated);assert.equal(old.slots[0].loadout.technique,'EnergyWave');
  old.slots[0].loadout.technique='Hakai';assert.equal(createGame(0,old.slots[0]).combat.snapshot().technique,'EnergyWave');
});
t('story bosses spawn as enemies and real combat advances their defeat objective',()=>{
  const s=session();s.slot.quests.m01_arrival={status:'done',step:2,completions:1};
  atNpc(s,'piccolo_plains');assert.ok(s.story.acceptQuest('m02_raditz'));s.tick();
  const boss=s.game.combat.enemies.find(e=>e.key==='raditz');assert.ok(boss?.boss);
  Object.assign(s.game.player.pos,{x:boss.pos.x,y:boss.pos.y,z:boss.pos.z-1.7});
  s.game.player.lockTarget=boss.id;
  assert.notEqual(s.story.interact(),'confront');assert.equal(s.slot.quests.m02_raditz.step,0);
  for(let i=0;i<1200&&boss.health>0;i++)s.tick({melee:true});
  assert.equal(boss.health,0);assert.equal(s.slot.quests.m02_raditz.step,1);
});
console.log(`${checks} RPG checks passed`);
