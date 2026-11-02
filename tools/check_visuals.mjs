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
  const model=createCharacterModel(defaultLook(race),{castShadow:false});const scene=new THREE.Scene();scene.add(model.object3d);
  for(const point of Object.values(model.attach))assert.ok(point instanceof THREE.Object3D && point.parent);
  const baseline=model.object3d.scale.clone();
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
  model.dispose();model.dispose();assert.equal(scene.children.length,0);
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
