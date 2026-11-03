import assert from 'node:assert/strict';
import { KI_COLORS, kiColor, normalizeKiHex } from '../web/src/data/appearance.js';
import { kiColourInput } from '../web/src/ui/kiColourInput.js';
import { RACE_ORDER } from '../web/src/data/races.js';
import { defaultLook, validateLook, resolveLook } from '../web/src/game/look.js';
import { newSlot, migrate, SCHEMA_VERSION } from '../web/src/game/schema.js';
import { createGame, emptyIntents } from '../web/src/game/game.js';
import { createEvents } from '../web/src/core/events.js';
import { createSaveStore } from '../web/src/core/save.js';
let n=0;
const test=(name,fn)=>{fn();n++;console.log('ok',name);};
test('every race accepts all Ki colours and rejects invalid palette indexes',()=>{
  for(const race of RACE_ORDER)for(let i=0;i<KI_COLORS.length;i++){
    const look={...defaultLook(race),kiColor:i};assert.equal(validateLook(look),null);assert.equal(resolveLook(look).kiColor,KI_COLORS[i]);
  }
  for(const value of [-1,8,1.5,'red',null,NaN])assert.match(validateLook({...defaultLook(),kiColor:value}),/Ki colour/);
});
test('v4 migration preserves progression and defaults missing/broken Ki colours only',()=>{
  const s=newSlot(defaultLook());s.level=532;s.xp=123;s.statPoints=19;s.loadout.testAllPaths=true;
  delete s.appearance.kiColor;
  const p=migrate({version:4,slots:[s],lastSlot:0});assert.equal(p.version,SCHEMA_VERSION);assert.equal(s.appearance.kiColor,0);
  assert.deepEqual([s.level,s.xp,s.statPoints,s.loadout.testAllPaths],[532,123,19,true]);
  s.appearance.kiColor=7;assert.equal(migrate(p).slots[0].appearance.kiColor,7);
  s.appearance.kiColor=99;assert.equal(migrate(p).slots[0].appearance.kiColor,0);
});
test('selected colour survives new slots, save export/import and live customization',()=>{
  const save=createSaveStore();assert.equal(save.createSlot(0,{...defaultLook(),kiColor:6}).ok,true);
  const g=createGame(0,save.loadSlot(0));assert.equal(g.customizeAppearance({kiColor:5}),null);
  assert.match(g.customizeAppearance({kiColor:99}),/Ki colour/);assert.equal(g.slot.appearance.kiColor,5);
  save.saveSlot(0,g.toSave());const code=save.exportCode();assert.equal(save.importCode(code).ok,true);assert.equal(save.loadSlot(0).appearance.kiColor,5);
});
function fresh(index=0){
  const events=createEvents(),g=createGame(0,newSlot({...defaultLook(),kiColor:index}),events);
  for(const e of g.combat.enemies)e.health=0;
  g.player.pos={x:0,y:0,z:0};g.player.yaw=0;g.player.onGround=true;
  return {g,events};
}
const tick=(g,it={})=>g.update(1/60,{...emptyIntents(),...it});
test('blast and beam carry the chosen colour; existing shots keep their launch colour',()=>{
  for(let i=0;i<KI_COLORS.length;i++){
    const {g,events}=fresh(i);tick(g,{kiBlast:true});const shot=g.combat.projectiles[0];assert.equal(shot.color,KI_COLORS[i]);
    assert.equal(g.customizeAppearance({kiColor:(i+1)%KI_COLORS.length}),null);assert.equal(shot.color,KI_COLORS[i]);
    let beam;events.on('beam',b=>beam=b);tick(g,{beam:true});tick(g);assert.equal(beam.color,kiColor(g.slot.appearance));
  }
});
test('aim marker ray matches actual unlocked and elevated locked shots',()=>{
  const {g}=fresh();g.player.yaw=.6;
  const free=g.combat.aimState();tick(g,{kiBlast:true});assert.deepEqual(g.combat.projectiles[0].dir,free.dir);assert.equal(free.locked,false);
  const e=g.combat.enemies[0];e.health=100;e.pos={x:5,y:12,z:9};g.player.lockTarget=e.id;
  const aim=g.combat.aimState();assert.equal(aim.locked,true);assert.deepEqual(aim.point,{x:5,y:13,z:9});
  const len=Math.hypot(aim.point.x-aim.origin.x,aim.point.y-aim.origin.y,aim.point.z-aim.origin.z);
  for(const axis of ['x','y','z'])assert.ok(Math.abs(aim.dir[axis]-(aim.point[axis]-aim.origin[axis])/len)<1e-10);
  e.health=0;assert.equal(g.combat.aimState().locked,false);
});
test('base form charges at full Ki and stops on release or death',()=>{
  const {g}=fresh();tick(g,{charge:true});assert.equal(g.player.charging,true);assert.equal(g.player.form,'');
  assert.equal(g.player.ki,g.player.maxKi);tick(g);assert.equal(g.player.charging,false);
  g.player.health=0;tick(g,{charge:true});assert.equal(g.player.charging,false);
});
test('hex parsing supports short/long RGB, optional hash, black, and safe validation',()=>{
  for(const [input,expected] of [['#AbC','#aabbcc'],[' 12aBCd ','#12abcd'],['#000','#000000'],['fff','#ffffff']])assert.equal(normalizeKiHex(input),expected);
  for(const value of ['red','#12','#abcd','#12345678','0xabcdef','##abcdef',123456]){assert.equal(normalizeKiHex(value),null);assert.match(validateLook({...defaultLook(),kiColorHex:value}),/hex colour/);}
  assert.equal(kiColor({kiColor:6,kiColorHex:'#000000'}),0);
});
test('custom hex survives save import and migration and colours both attacks',()=>{
  const {g,events}=fresh(6);assert.equal(g.customizeAppearance({kiColorHex:'#12ab34'}),null);
  assert.match(g.customizeAppearance({kiColorHex:'invalid'}),/hex colour/);assert.equal(g.slot.appearance.kiColorHex,'#12ab34');
  tick(g,{kiBlast:true});assert.equal(g.combat.projectiles[0].color,0x12ab34);
  let beam;events.on('beam',b=>beam=b);tick(g,{beam:true});tick(g);assert.equal(beam.color,0x12ab34);
  const save=createSaveStore();save.saveSlot(0,g.toSave());assert.equal(save.importCode(save.exportCode()).ok,true);assert.equal(kiColor(save.loadSlot(0).appearance),0x12ab34);
  const profile=migrate({version:5,slots:[g.toSave()]});assert.equal(profile.slots[0].appearance.kiColorHex,'#12ab34');
  g.slot.appearance.kiColorHex='junk';assert.equal(migrate(profile).slots[0].appearance.kiColorHex,null);assert.equal(g.slot.appearance.kiColor,6);
  assert.equal(g.customizeAppearance({kiColor:2,kiColorHex:null}),null);assert.equal(kiColor(g.slot.appearance),KI_COLORS[2]);
});
test('hex field commits complete colours via Apply or Enter and rejects partial input',()=>{
  const previous=globalThis.document,nodes=[];let value=null;
  globalThis.document={createElement(tag){const el={tag,style:{},attrs:{},events:{},children:[],setAttribute(k,v){this.attrs[k]=v;},append(...children){this.children.push(...children);},addEventListener(k,fn){this.events[k]=fn;}};nodes.push(el);return el;}};
  try{
    kiColourInput({kiColor:0},v=>{value=v;});const input=nodes.find(n=>n.tag==='input'),button=nodes.find(n=>n.tag==='button');
    input.value='#12';button.events.click();assert.equal(value,null);assert.equal(input.attrs['aria-invalid'],'true');
    input.value='aBc';input.events.input();assert.equal(value,null,'typing leaves the applied colour alone');
    input.events.keydown({key:'Enter',preventDefault(){},stopPropagation(){}});assert.equal(value,'#aabbcc');assert.equal(input.value,'#aabbcc');
    input.value='#000000';button.events.click();assert.equal(value,'#000000');
  }finally{globalThis.document=previous;}
});
console.log(`Ki and aim checks passed: ${n}`);
