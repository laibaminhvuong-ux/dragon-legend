import assert from 'node:assert/strict';
import {DRAGON_HUNTS,DRAGON_LOOKS,ORB_LOOKS} from '../web/src/data/dragon_hunts.js';
import {QUESTS,NPCS} from '../web/src/data/story.js';
import {createGame,emptyIntents} from '../web/src/game/game.js';
import {createStory} from '../web/src/game/story.js';
import {defaultLook} from '../web/src/game/look.js';
import {newSlot,migrate} from '../web/src/game/schema.js';
import {createEvents} from '../web/src/core/events.js';
import {ZONES} from '../web/src/game/zones.js';
let n=0;const test=(name,fn)=>{fn();n++;console.log('ok',name);};
function session(hunt){
 const slot=newSlot(defaultLook());slot.level=2000;for(const id of hunt.after)slot.quests[id]={status:'done'};
 const ev=createEvents(),s={slot,ev};
 s.enter=zone=>{slot.zone=zone;slot.position=null;s.game=createGame(0,slot,ev);s.story=createStory(s.game,ev);};
 s.at=(x,z,y)=>{Object.assign(s.game.player.pos,{x,z,y:y??s.game.zone.heightAt(x,z)});};
 s.enter(NPCS.find(n=>n.id===hunt.giver).zone);return s;
}
function accept(s,hunt){const npc=s.story.npcs().find(n=>n.id===hunt.giver);assert.ok(npc);s.at(npc.x,npc.z,npc.y);return s.story.acceptQuest(hunt.id);}
function collect(s,hunt,count=hunt.spots.length){const q=QUESTS.find(q=>q.id===hunt.id),step=q.steps[0];for(const spot of step.spots.slice(0,count)){s.enter(spot.zone??step.zone);s.at(spot.x,spot.z);s.story.update(1/60,emptyIntents());}}
test('three sets have independent counts, models, story gates and reachable land positions',()=>{
 assert.deepEqual(DRAGON_HUNTS.map(h=>h.spots.length),[7,7,2]);assert.equal(DRAGON_LOOKS.super.kind,'winged');assert.equal(DRAGON_LOOKS.cereal.kind,'finned');
 for(const hunt of DRAGON_HUNTS){const q=QUESTS.find(q=>q.id===hunt.id);assert.equal(q.steps.filter(s=>s.type==='talk').length,hunt.wishes);for(const id of hunt.after)assert.ok(QUESTS.some(q=>q.id===id));
  for(const p of hunt.spots){const z=ZONES[p.zone??hunt.zone];assert.ok(z);assert.ok(Number.isFinite(z.heightAt(p.x,p.z)));assert.ok(Math.abs(p.x)<z.size/2 && Math.abs(p.z)<z.size/2);}
 }
 assert.ok(ORB_LOOKS.namek_ball.scale>ORB_LOOKS.dragon_ball.scale);assert.ok(ORB_LOOKS.cereal_ball.scale<ORB_LOOKS.dragon_ball.scale);assert.equal(ORB_LOOKS.super_ball.projection,true);
});
test('story progress, level and physical giver proximity gate hunt acceptance',()=>{
 for(const hunt of DRAGON_HUNTS){const s=session(hunt);delete s.slot.quests[hunt.after[0]];assert.equal(accept(s,hunt),false);s.slot.quests[hunt.after[0]]={status:'done'};s.slot.level=hunt.level-1;assert.equal(accept(s,hunt),false);s.slot.level=2000;s.at(1000,1000);assert.equal(s.story.acceptQuest(hunt.id),false);assert.equal(accept(s,hunt),true);}
});
test('collecting a set persists across worlds and only summons after the last unique orb',()=>{
 for(const hunt of DRAGON_HUNTS){const s=session(hunt);accept(s,hunt);collect(s,hunt,hunt.spots.length-1);assert.equal(s.slot.story.flags['summon_'+hunt.dragon],undefined);
  const before=s.slot.quests[hunt.id].collected.length,p=hunt.spots[0];s.enter(p.zone??hunt.zone);s.at(p.x,p.z);s.story.update(1/60,emptyIntents());assert.equal(s.slot.quests[hunt.id].collected.length,before);
  const migrated=migrate({version:6,slots:[structuredClone(s.slot)]});assert.equal(migrated.slots[0].quests[hunt.id].collected.length,before);
  const last=hunt.spots.at(-1);s.enter(last.zone??hunt.zone);s.at(last.x,last.z);s.story.update(1/60,emptyIntents());assert.equal(s.slot.story.flags['summon_'+hunt.dragon],true);
  s.enter(hunt.zone);const dragon=s.story.npcs().find(n=>n.id==='dragon_'+hunt.dragon);assert.equal(dragon.dragon,hunt.dragon);assert.equal(dragon.marker,'?');
 }
});
test('all scripted wishes pay once, restore strength and dismiss the summoned dragon',()=>{
 for(const hunt of DRAGON_HUNTS){const s=session(hunt);accept(s,hunt);collect(s,hunt);s.enter(hunt.zone);const dragon=s.story.npcs().find(n=>n.id==='dragon_'+hunt.dragon);s.at(dragon.x,dragon.z,dragon.y);
  s.game.player.health/=2;s.game.player.ki=1;const money=s.slot.zeni,points=s.slot.statPoints;let finalSpeaker; s.ev.on('dialogue',d=>{if(d.kind==='done')finalSpeaker=d.speaker;});
  for(let i=0;i<hunt.wishes;i++)assert.equal(s.story.interact(),'talk');
  assert.equal(s.slot.quests[hunt.id].status,'done');assert.equal(s.slot.statPoints,points+hunt.statPoints);assert.equal(s.slot.zeni,money+hunt.zeni);assert.equal(s.game.player.health,s.game.player.maxHealth);assert.equal(s.game.player.ki,s.game.player.maxKi);assert.equal(finalSpeaker,dragon.name);
  assert.equal(s.story.npcs().some(n=>n.id===dragon.id),false);assert.equal(s.story.acceptQuest(hunt.id),false);s.story.interact();assert.equal(s.slot.zeni,money+hunt.zeni);
 }
});
test('abandoning a ready summon dismisses it and restarting needs the complete set again',()=>{
 const hunt=DRAGON_HUNTS[0],s=session(hunt);accept(s,hunt);collect(s,hunt);s.enter(hunt.zone);
 assert.ok(s.story.npcs().some(n=>n.id==='dragon_namek'));assert.equal(s.story.abandonQuest(hunt.id),true);assert.equal(s.story.npcs().some(n=>n.id==='dragon_namek'),false);
 assert.equal(accept(s,hunt),true);assert.equal(s.slot.quests[hunt.id].collected.length,0);assert.equal(s.story.npcs().some(n=>n.id==='dragon_namek'),false);
});
test('legacy Earth completion and the old three-ball Namek main quest remain independent',()=>{
 const earth=QUESTS.find(q=>q.id==='s_dragon_radar');assert.equal(earth.steps[0].spots.length,7);assert.equal(earth.steps[0].summonFlag,'shenron');
 const main=QUESTS.find(q=>q.id==='m11_dragon_balls');assert.equal(main.steps.find(s=>s.type==='collect').spots.length,3);assert.equal(main.steps.find(s=>s.type==='collect').summonFlag,undefined);
 const slot=newSlot(defaultLook());slot.quests[earth.id]={status:'done',completions:1};slot.story.flags.shenron=true;
 const old=migrate({version:4,slots:[slot]}).slots[0];assert.equal(old.quests[earth.id].completions,1);assert.equal(old.story.flags.shenron,true);assert.equal(old.story.flags.summon_namek,undefined);
});
console.log(`Dragon hunt checks passed: ${n}`);
