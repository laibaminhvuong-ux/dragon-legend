import assert from 'node:assert/strict';
import { FORMS } from '../web/src/data/forms.js';
import { RACES } from '../web/src/data/races.js';
import { MAX_LEVEL } from '../web/src/data/stats.js';
import { QUESTS, NPCS, CHARACTERS } from '../web/src/data/story.js';
import { createGame,emptyIntents } from '../web/src/game/game.js';
import { createStory } from '../web/src/game/story.js';
import { newSlot,migrate,SCHEMA_VERSION } from '../web/src/game/schema.js';
import { defaultLook } from '../web/src/game/look.js';
import { chooseFormPath,formAvailable,instinctBenefits } from '../web/src/game/forms.js';
import { gainFormMastery,masteryProgress } from '../web/src/game/mastery.js';
import { derive,xpForLevels,xpToNext } from '../web/src/game/progression.js';
let checks=0;const test=(name,fn)=>{fn();checks++;console.log('ok',name);};
const fresh=(race='Saiyan',level=250)=>{const s=newSlot(defaultLook(race));s.level=level;return s;};
test('cap is 2000, XP budgets respect caps and shared Saiyan paths match',()=>{
  assert.equal(MAX_LEVEL,2000);assert.equal(xpToNext(2000),0);assert.ok(xpToNext(1999)>0);
  assert.equal(xpForLevels(1999,10),xpToNext(1999));
  assert.deepEqual(RACES.Saiyan.forms,RACES.HalfSaiyan.forms);
  for(const id of ['Oozaru','GoldenOozaru','SSJ4','FalseSSJ','SSJGrade2','SSJGrade3','SSJFullPower','SSJRage','LegendarySSJ','Kaioken','Kaioken10'])assert.ok(RACES.Saiyan.forms.includes(id));
});
test('SSJ grade switching shares mastery and auto-evolves to Full Power',()=>{
  const s=fresh();s.forms=['SSJ'];
  assert.deepEqual(gainFormMastery(s,'SSJ',250),['SSJGrade2']);
  assert.deepEqual(gainFormMastery(s,'SSJGrade2',250),['SSJGrade3']);
  assert.deepEqual(gainFormMastery(s,'SSJGrade3',500),['SSJFullPower']);
  assert.equal(masteryProgress(s,'SSJFullPower').points,1000);
  assert.equal(s.quests.Form_SSJFullPower.status,'done');assert.ok(s.level<FORMS.SSJ2.unlockLevel);
  assert.ok(QUESTS.find(q=>q.id==='Form_SSJ2').after.includes('Form_SSJFullPower'));
});
test('Great Ape mastery evolves Golden Great Ape then SSJ4 for both races',()=>{
  for(const race of ['Saiyan','HalfSaiyan']){
    const s=fresh(race,100);s.forms=['Oozaru'];assert.deepEqual(gainFormMastery(s,'Oozaru',1000),['GoldenOozaru']);
    assert.deepEqual(gainFormMastery(s,'GoldenOozaru',2000),['SSJ4']);assert.ok(s.forms.includes('SSJ4'));
  }
});
test('Rage requires SSJ2 mastery and the Goku Black story milestone',()=>{
  const s=fresh('HalfSaiyan',700);s.forms=['SSJ2'];assert.deepEqual(gainFormMastery(s,'SSJ2',1200),[]);
  s.quests.m31_zamasu={status:'done'};assert.deepEqual(gainFormMastery(s,'SSJ2',1),['SSJRage']);
});
test('idle, unowned and paused training cannot create mastery',()=>{
  const s=fresh();s.forms=['SSJ'];assert.deepEqual(gainFormMastery(s,'SSJ2',10000),[]);
  const g=createGame(0,s);g.selectForm('SSJ');for(let i=0;i<60;i++)g.update(1/60,emptyIntents());
  assert.equal(s.formMastery.SSJ,undefined);
  g.update(1/60,{...emptyIntents(),charge:true});assert.ok(s.formMastery.SSJ>0);
  g.player.health=0;const previous=s.formMastery.SSJ;g.addFormMastery(100);assert.equal(s.formMastery.SSJ,previous);
});
test('max-level path selection is exclusive and persists',()=>{
  const s=fresh('Saiyan',1999);assert.ok(chooseFormPath(s,'instinct'));s.level=2000;assert.equal(chooseFormPath(s,'instinct'),null);
  assert.ok(chooseFormPath(s,'ego'));assert.equal(formAvailable(s,'UIOmen'),true);assert.equal(formAvailable(s,'UltraEgo'),false);
  const copy=migrate({version:4,slots:[structuredClone(s)],lastSlot:0});assert.equal(copy.slots[0].loadout.formPath,'instinct');
});
test('learnable UI Sign is much weaker than every full UI transformation',()=>{
  const slot=fresh('Saiyan',2000),base=derive(slot),tech=instinctBenefits({form:'',uiTechniqueUntil:5},1);
  assert.equal(tech.kind,'technique');assert.equal(tech.chance,.1);assert.equal(derive(slot).strength,base.strength);
  for(const form of ['UIOmen','UIPerfected','UITrue']){
    const full=instinctBenefits({form},1);assert.ok(full.chance>=tech.chance*3);assert.ok(full.cooldown<tech.cooldown);
    assert.ok(derive(slot,form).strength>=base.strength*5);
  }
  assert.equal(instinctBenefits({form:'',uiTechniqueUntil:5},6).chance,0);
});
test('manga training follows Tournament -> Moro -> Granolah and has valid references',()=>{
  const index=id=>QUESTS.findIndex(q=>q.id===id);
  assert.ok(index('m32_tournament')<index('m35_moro_escape'));assert.ok(index('m37_moro_final')<index('m38_granolah'));assert.ok(index('m40_gas')<index('m34_super_hero'));
  const q=id=>QUESTS.find(q=>q.id===id);
  assert.ok(q('Form_UIOmen').after.includes('m32_tournament'));
  assert.ok(q('t_ui_moro_mastery').after.includes('m37_moro_final'));
  assert.ok(q('Form_UITrue').after.includes('t_ui_moro_mastery'));
  for(const quest of QUESTS){assert.ok(NPCS.some(n=>n.id===quest.giver),`${quest.id} giver`);for(const pre of quest.after || [])assert.ok(q(pre),`${quest.id} prerequisite ${pre}`);}
  for(const npc of NPCS)assert.ok(CHARACTERS[npc.who]);
});
test('legacy saves scale levels once, preserve XP fraction, stats and old unlocks',()=>{
  const old=fresh('HalfSaiyan',50);old.xp=Math.floor(xpToNext(50)*.5);old.forms=['HSSJ','HSSJ2'];old.quests.Form_HSSJ={status:'done'};delete old.loadout.formPath;delete old.formMastery;
  const migrated=migrate({version:3,slots:[old],lastSlot:0});assert.equal(migrated.version,SCHEMA_VERSION);assert.equal(old.level,500);
  assert.ok(Math.abs(old.xp/xpToNext(500)-.5)<.001);assert.equal(old.statPoints,1350);
  assert.ok(old.forms.includes('HSSJ')&&old.forms.includes('SSJ')&&old.forms.includes('SSJ2'));assert.equal(old.quests.Form_SSJ.status,'done');
  migrate(migrated);assert.equal(old.level,500);assert.equal(old.statPoints,1350);
});
test('direct selection, appearance and accessory commands reject invalid choices',()=>{
  const s=fresh(),g=createGame(0,s);assert.ok(g.selectForm('UITrue'));s.forms.push('SSJ');assert.equal(g.selectForm('SSJ'),null);
  assert.equal(g.customizeAppearance({hair:'Swept',skin:1}),null);assert.equal(s.appearance.hair,'Swept');assert.ok(g.customizeAppearance({hair:'missing'}));
  assert.ok(g.equipAccessory('Scouter'));s.quests.m02_raditz={status:'done'};assert.equal(g.equipAccessory('Scouter'),null);assert.equal(s.appearance.accessory,'Scouter');
});
test('Ki stat investment increases endurance without raising technique costs',()=>{
  const base=fresh('Saiyan',2000),invested=fresh('Saiyan',2000);invested.stats.Ki=100;
  const a=derive(base),b=derive(invested);assert.equal(a.kiCostScale,b.kiCostScale);assert.ok(b.maxKi>a.maxKi);
});
test('completed old story quests open the newly added manga destinations',()=>{
  const s=fresh('Saiyan',1500);s.quests.m33_broly={status:'done',completions:1};
  const copy=migrate({version:4,slots:[s],lastSlot:0});assert.ok(copy.slots[0].story.unlocked.includes('new_namek'));
  s.quests.m37_moro_final={status:'done',completions:1};createStory(createGame(0,s));assert.ok(s.story.unlocked.includes('planet_cereal'));
});
test('all three endgame quest paths unlock and activate for both Saiyan races',()=>{
  for(const race of ['Saiyan','HalfSaiyan'])for(const path of ['beast','instinct','ego']){
    const slot=fresh(race,2000);chooseFormPath(slot,path);
    for(const q of QUESTS.filter(q=>q.main))slot.quests[q.id]={status:'done',completions:1};
    slot.forms=['SSJ','SSJFullPower','SSJ2','SSJ3','SSJGod','SSJBlue'];slot.quests.Form_SSJBlue={status:'done'};
    let game,story;
    const enter=zone=>{slot.zone=zone;slot.position=null;game=createGame(0,slot);story=createStory(game);};
    for(const q of QUESTS.filter(q=>q.path===path)){
      const giver=NPCS.find(n=>n.id===q.giver);enter(giver.zone);
      const npc=story.npcs().find(n=>n.id===giver.id);assert.ok(npc,`${race}/${q.id} visible giver`);
      Object.assign(game.player.pos,{x:npc.x+1,y:npc.y,z:npc.z});assert.ok(story.acceptQuest(q.id),`${race}/${q.id} accepted`);
      for(const step of q.steps){
        assert.equal(step.type,'train');enter(step.zone);
        for(let i=0;i<Math.ceil(step.seconds*4)+1&&slot.quests[q.id].status==='active';i++)story.update(.25,{charge:step.mode==='charge'});
      }
      assert.equal(slot.quests[q.id].status,'done',`${race}/${q.id} completed`);
      for(const id of q.rewards.forms || [])assert.equal(game.selectForm(id),null,`${id} usable`);
    }
    const expected={beast:['Beast'],instinct:['UIOmen','UIPerfected','UITrue'],ego:['UltraEgo']}[path];
    for(const id of expected)assert.ok(slot.forms.includes(id),`${race}/${path}/${id} unlocked`);
    if(path==='instinct')assert.equal(slot.story.items.instinctMastery,1);
  }
});
console.log(`${checks} form and progression checks passed`);
