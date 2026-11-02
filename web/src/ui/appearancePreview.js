import * as THREE from 'three';
import { createCharacterModel } from '../character/index.js';
export function createAppearancePreview(container,app){
  const canvas=document.createElement('canvas');canvas.style.cssText='width:100%;height:260px;display:block;background:#111c30;border-radius:12px';container.append(canvas);
  const renderer=new THREE.WebGLRenderer({canvas,antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio || 1,1.5));renderer.outputColorSpace=THREE.SRGBColorSpace;
  const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera(32,1,.1,50);
  camera.position.set(2.6,1.9,4);camera.lookAt(0,1,0);
  scene.add(new THREE.HemisphereLight(0xffffff,0x33415b,2));const key=new THREE.DirectionalLight(0xffedda,3);key.position.set(2,4,4);scene.add(key);
  let model=null,stamp='',lastWidth=0;
  return {
    update(dt){
      const look={race:app.game.slot.race,...app.game.slot.appearance},next=JSON.stringify(look);
      if(next!==stamp){model?.dispose();model=createCharacterModel(look,{castShadow:false});scene.add(model.object3d);stamp=next;}
      const width=Math.max(1,canvas.clientWidth);if(width!==lastWidth){lastWidth=width;renderer.setSize(width,260,false);camera.aspect=width/260;camera.updateProjectionMatrix();}
      model.update(dt,{onGround:true,speed:0});renderer.render(scene,camera);
    },
    dispose(){model?.dispose();renderer.dispose();renderer.forceContextLoss();canvas.remove();},
  };
}
