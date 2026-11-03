// Tests real vendored Three.js scene graphs without WebGL. Browser coverage is separate.
import assert from 'node:assert/strict';
import { register } from 'node:module';
register('data:text/javascript,' + encodeURIComponent(`
  let three;
  export function initialize(data) { three = data.three; }
  export async function resolve(specifier, context, next) {
    return specifier === 'three' ? { url: three, shortCircuit: true } : next(specifier, context);
  }
`), { parentURL: import.meta.url, data: { three: new URL('../web/vendor/three/three.module.min.js', import.meta.url).href } });
const THREE = await import('../web/vendor/three/three.module.min.js');
const { createCharacterModel } = await import('../web/src/character/index.js');
const { createFollowCamera } = await import('../web/src/render/camera.js');
const { defaultLook } = await import('../web/src/game/look.js');
const { RACES, RACE_ORDER } = await import('../web/src/data/races.js');
const { KI_COLORS } = await import('../web/src/data/appearance.js');
// Texture rasterization is intentionally stubbed for this structural node check.
// Actual rendered pixels are checked by the browser smoke scripts.
globalThis.document={createElement(tag){
  assert.equal(tag,'canvas');const canvas={width:0,height:0};
  const context=new Proxy({canvas,createRadialGradient:()=>({addColorStop(){}}),createLinearGradient:()=>({addColorStop(){}}),measureText:t=>({width:String(t).length*10})},{get:(target,key)=>key in target?target[key]:()=>{}});
  canvas.getContext=()=>context;return canvas;
}};
const { FORMS }=await import('../web/src/data/forms.js');
const { FORM_LOOKS }=await import('../web/src/data/form_looks.js');
const { ACCESSORIES }=await import('../web/src/data/accessories.js');
let count=0;
for(const race of RACE_ORDER){
  const colourIndex=RACE_ORDER.indexOf(race);
  const customHex=colourIndex===0?'#12ab34':null;
  const model=createCharacterModel({...defaultLook(race),kiColor:colourIndex,kiColorHex:customHex},{castShadow:false});const scene=new THREE.Scene();scene.add(model.object3d);
  for(const point of Object.values(model.attach))assert.ok(point instanceof THREE.Object3D && point.parent);
  const baseline=model.object3d.scale.clone();
  model.update(1/60,{charging:true,onGround:true});
  const charge=model.object3d.getObjectByName('ki-charge-aura');assert.ok(charge?.visible,`${race} charges in base form`);
  assert.equal(charge.children[0].material.uniforms.uColor.value.getHex(),customHex?0x12ab34:KI_COLORS[colourIndex],'charging uses personal Ki palette or custom hex');
  const sameRoot=model.object3d,sameMaterial=charge.children[0].material;
  model.setKiColor(0xff6600);assert.equal(model.object3d,sameRoot);assert.equal(charge.children[0].material,sameMaterial);assert.equal(sameMaterial.uniforms.uColor.value.getHex(),0xff6600,'live recolour reuses model and material');
  const chargeMats=new Set();charge.traverse(o=>{if(o.isMesh){chargeMats.add(o.material);assert.equal(o.layers.mask,2);assert.equal(o.material.depthWrite,false);}});
  let chargeDisposed=0;for(const m of chargeMats)m.addEventListener('dispose',()=>chargeDisposed++);
  model.update(1/60,{});assert.equal(charge.visible,false,'release hides charging energy');
  model.update(1/60,{charging:true});assert.equal(model.object3d.getObjectByName('ki-charge-aura'),charge,'charge reuses GPU resources');
  model.update(1/60,{kaioken:2});const kaioken=model.object3d.getObjectByName('kaioken-overlay-aura');assert.ok(kaioken?.visible);
  const kaiMats=new Set();kaioken.traverse(o=>{if(o.isMesh || o.isLineSegments)kaiMats.add(o.material);});let kaiDisposed=0;
  for(const m of kaiMats)m.addEventListener('dispose',()=>kaiDisposed++);
  model.update(1/60,{});assert.equal(kaioken.visible,false);
  for(const id of RACES[race].forms){
    assert.ok(FORM_LOOKS[id],`${id} has a visual recipe`);
    model.setForm(id);
    for(const anim of [{onGround:true,speed:7},{flying:true},{charging:true},{blocking:true},{attackSerial:1,attackKind:'jab'}]){
      model.update(1/60,anim);model.object3d.updateMatrixWorld(true);
      model.object3d.traverse(o=>assert.ok(o.matrixWorld.elements.every(Number.isFinite),`${race}/${id} finite transforms`));
    }
    if(id==='Oozaru' || id==='GoldenOozaru'){
      const ape=model.object3d.getObjectByName(id==='Oozaru'?'great-ape':'golden-great-ape');
      assert.ok(ape?.getObjectByName('muzzle'));assert.ok(ape.getObjectByName('fang'));assert.ok(ape.getObjectByName('ape-tail'));
      const resources=new Set();ape.traverse(o=>{if(o.isMesh)resources.add(o.geometry)});
      let disposed=0;resources.forEach(g=>g.addEventListener('dispose',()=>disposed++));
      model.setForm('');assert.equal(disposed,resources.size,'ape resources disposed once');
    }
    if(id==='SSJ4')assert.ok(model.object3d.getObjectByName('ssj4-red-fur'));
    if(id==='SSJGrade3')assert.ok(model.object3d.scale.x>baseline.x*1.3,'Grade 3 has visibly wider bulk');
    model.setForm('');assert.deepEqual(model.object3d.scale.toArray(),baseline.toArray(),'base scale restored');count++;
  }
  if(race==='Saiyan' || race==='HalfSaiyan'){
    model.setForm('SSJBlue');const formScale=model.object3d.scale.clone();
    model.update(1/60,{kaioken:10,charging:true});assert.equal(kaioken.visible,true);assert.equal(charge.visible,true);assert.deepEqual(model.object3d.scale.toArray(),formScale.toArray(),'overlay keeps Blue form size');
    model.setForm('');model.update(1/60,{});assert.equal(kaioken.visible,false);
  }
  model.dispose();model.dispose();assert.equal(chargeDisposed,chargeMats.size,'charge materials disposed once');assert.equal(kaiDisposed,kaiMats.size,'Kaioken materials disposed once');assert.equal(scene.children.length,0);
}
for(const id of Object.keys(ACCESSORIES)){
  const model=createCharacterModel({...defaultLook('Saiyan'),accessory:id});
  if(id!=='None')assert.ok(model.object3d.getObjectByName('equipped-accessory'));
  model.dispose();count++;
}
const {createUltraInstinctAvatar}=await import('../web/src/fx/ultra_instinct_avatar.js');
const avatar=createUltraInstinctAvatar(),avatarScene=new THREE.Scene();avatarScene.add(avatar.object3d);
const avatarState={active:true,pos:{x:1,y:0,z:2},yaw:.5,remaining:6,pulse:1};
avatar.update(1/60,avatarState);avatar.object3d.updateMatrixWorld(true);
const avatarGeos=new Set(),avatarMats=new Set();let avatarMeshes=0;
avatar.object3d.traverse(o=>{
  assert.ok(o.matrixWorld.elements.every(Number.isFinite));
  if(!o.isMesh)return;avatarMeshes++;avatarGeos.add(o.geometry);avatarMats.add(o.material);
  assert.equal(o.material.transparent,true);assert.equal(o.material.depthWrite,false);assert.equal(o.castShadow,false);assert.equal(o.layers.mask,2);
});
assert.ok(avatarMeshes>10);assert.ok(avatar.object3d.getObjectByName('avatar-fist'));assert.ok(avatar.object3d.getObjectByName('avatar-strike-wave'));
let avatarFreed=0;for(const resource of [...avatarGeos,...avatarMats])resource.addEventListener('dispose',()=>avatarFreed++);
avatar.dispose();avatar.dispose();assert.equal(avatarFreed,avatarGeos.size+avatarMats.size);assert.equal(avatarScene.children.length,0);
const {createCombatView}=await import('../web/src/combat/view.js');const {createEvents}=await import('../web/src/core/events.js');
const view=createCombatView({scene:avatarScene,camera:new THREE.PerspectiveCamera(),quality:{shadows:false}}, {enemies:[],projectiles:[],avatarState:()=>avatarState},createEvents());
view.update(1/60);assert.ok(avatarScene.getObjectByName('ultra-instinct-energy-avatar'));
avatarState.active=false;view.update(1/60);assert.equal(avatarScene.getObjectByName('ultra-instinct-energy-avatar'),undefined);view.dispose();assert.equal(avatarScene.children.length,0);count++;
const terrain = { heightAt: (x, z) => Math.sin(x) * 3 + Math.cos(z) * 2 };
const camera = new THREE.PerspectiveCamera();
const follow = createFollowCamera(camera, terrain);
follow.setYaw(0);
for (let i = 0; i < 120; i++) {
  follow.addLook({ x: .02, y: i < 60 ? -1 : 1 });
  follow.update({ x: i / 10, y: 0, z: i / 15 }, 1 / 60, i > 60 ? { x: 20, y: 2, z: 20 } : null);
  assert.ok(camera.position.toArray().every(Number.isFinite));
  assert.ok(camera.position.y >= terrain.heightAt(camera.position.x, camera.position.z) + .4 - 1e-8);
}
const fixed = new THREE.PerspectiveCamera(), a = createFollowCamera(fixed, { heightAt: () => 0 });
a.setYaw(0); a.update({ x: 0, y: 0, z: 0 }, 0);
const old = fixed.position.clone(); a.update({ x: 10, y: 0, z: 0 }, 0);
assert.deepEqual(fixed.position.toArray(), old.toArray(), 'zero-dt follow is paused');
a.update({x:0,y:0,z:0},0,null,3.2);assert.ok(fixed.position.length()>old.length()*2.5,'large form frames even while menu pauses simulation');
a.update({x:0,y:0,z:0},0,null,1);assert.ok(fixed.position.distanceTo(old)<1e-8,'base framing restores');
console.log(`visual structure checks passed: ${count} forms/accessories, poses, ape geometry, bulk, restoration/disposal and camera; texture drawing stubbed (browser pixels not checked)`);

// Reticle projects the actual firing point, and never overlays modal/death/cutscene screens.
const canvasDocument=globalThis.document;
globalThis.document={createElement(){return {style:{},setAttribute(){},classList:{toggle(){}},remove(){this.removed=true;}};}};
const {createAimReticle}=await import('../web/src/ui/aimReticle.js');
const aimCamera=new THREE.PerspectiveCamera(60,16/9,.1,200);aimCamera.position.set(0,2,-6);aimCamera.lookAt(0,1,10);aimCamera.updateMatrixWorld();
let aimPoint={x:0,y:1,z:10},dot;
const reticleApp={gfx:{camera:aimCamera},game:{player:{health:100},combat:{aimState:()=>({point:aimPoint,locked:false})}}};
const reticle=createAimReticle({append(el){dot=el;}},reticleApp);
reticle.update();assert.equal(dot.hidden,false);assert.ok(Math.abs(parseFloat(dot.style.left)-50)<.001);assert.ok(Math.abs(parseFloat(dot.style.top)-50)<.001);
for(const mode of ['paused','dialogueOpen']){reticleApp[mode]=true;reticle.update();assert.equal(dot.hidden,true);reticleApp[mode]=false;}
reticleApp.cutscene={active:true};reticle.update();assert.equal(dot.hidden,true);reticleApp.cutscene.active=false;
reticleApp.game.player.health=0;reticle.update();assert.equal(dot.hidden,true);reticleApp.game.player.health=100;
for(const p of [{x:0,y:2,z:-20},{x:10000,y:0,z:10},{x:NaN,y:0,z:10}]){aimPoint=p;reticle.update();assert.equal(dot.hidden,true,'out-of-view aim is hidden');}
reticle.dispose();assert.equal(dot.removed,true);globalThis.document=canvasDocument;
console.log('aim reticle structure checks passed: projection, visibility, invalid/behind-camera targets and disposal');

const shots=[],shotScene=new THREE.Scene();
const shotView=createCombatView({scene:shotScene,camera:new THREE.PerspectiveCamera(),quality:{shadows:false}},{enemies:[],projectiles:shots,avatarState:()=>({active:false})},createEvents());
const materialFor=color=>shotScene.getObjectByName('combat').children.find(o=>o.isMesh && o.material.color.getHex()===color)?.material;
shots.push({id:1,color:0x123456,pos:{x:0,y:1,z:0}});shotView.update(1/60);const firstMat=materialFor(0x123456);assert.ok(firstMat);
let firstFreed=0,secondFreed=0;firstMat.addEventListener('dispose',()=>firstFreed++);
shots.push({id:2,color:0x987654,pos:{x:0,y:1,z:1}});shotView.update(1/60);materialFor(0x987654).addEventListener('dispose',()=>secondFreed++);assert.equal(firstFreed,0,'live custom-colour shots retain their material');
shots.shift();shotView.update(1/60);assert.equal(firstFreed,1,'unused arbitrary-colour material freed');assert.equal(secondFreed,0);
shots.length=0;shotView.update(1/60);assert.equal(secondFreed,1);shotView.dispose();assert.equal(firstFreed,1);assert.equal(secondFreed,1);
console.log('custom Ki material lifecycle checks passed');

const {createWishDragon}=await import('../web/src/character/wish_dragon.js');
for(const id of ['earth','namek','super','cereal']){
  const dragon=createWishDragon(id),scene=new THREE.Scene();scene.add(dragon.object3d);
  assert.ok(dragon.object3d.getObjectByName('coiled-dragon-body'));assert.ok(dragon.object3d.getObjectByName('dragon-head'));
  if(id==='namek')assert.ok(dragon.object3d.getObjectByName('broad-chest'));
  if(id==='super')assert.ok(dragon.object3d.getObjectByName('golden-wings'));
  if(id==='cereal')assert.ok(dragon.object3d.getObjectByName('frilled-head-fin'));
  for(let i=0;i<180;i++)dragon.update(1/60);dragon.object3d.updateMatrixWorld(true);
  const resources=new Set();dragon.object3d.traverse(o=>{assert.ok(o.matrixWorld.elements.every(Number.isFinite));if(o.isMesh){resources.add(o.geometry);resources.add(o.material);assert.equal(o.castShadow,false);}});
  let freed=0;for(const r of resources)r.addEventListener('dispose',()=>freed++);
  dragon.dispose();dragon.dispose();assert.equal(freed,resources.size);assert.equal(scene.children.length,0);
}
const {createStoryView}=await import('../web/src/world/story_view.js');
const dragonScene=new THREE.Scene(),dragonNpcs=['earth','namek','super','cereal'].map((id,i)=>({id:'test_'+id,dragon:id,name:id,x:i*20,y:0,z:0,rot:0,scale:3,marker:'?',look:{}}));
const storyFixture={npcs:()=>dragonNpcs,pickups:()=>['dragon_ball','namek_ball','super_ball','cereal_ball'].map((item,index)=>({item,index,questId:'test',x:index*5,y:1,z:0})),pads:()=>[],waypoint:()=>null};
const dragonView=createStoryView({scene:dragonScene,quality:{shadows:false}},storyFixture);
dragonView.update(1/60,{x:0,y:0,z:0});
for(const id of ['earth','namek','super','cereal'])assert.ok(dragonScene.getObjectByName('wish-dragon-'+id),'story uses actual dragon model');
dragonNpcs.length=0;dragonView.refresh();assert.equal(dragonScene.getObjectByName('wish-dragon-super'),undefined);dragonView.dispose();assert.equal(dragonScene.children.length,0);
console.log('wish dragon visual structure checks passed: all four silhouettes, summon animation, real story view, orb variants and one-time resource disposal');
