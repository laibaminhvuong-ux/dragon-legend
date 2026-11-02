// Combat presentation consumes authoritative entities; it never awards damage or rewards.
import * as THREE from 'three';
import { createCharacterModel } from '../character/index.js';
export function createCombatView(gfx, combat, events) {
  const root=new THREE.Group();root.name='combat';gfx.scene.add(root);
  const models=new Map(), balls=new Map(), effects=[];
  const sphere=new THREE.SphereGeometry(.17,10,8), energy=new THREE.MeshBasicMaterial({color:0x78dfff});
  const barGeo=new THREE.PlaneGeometry(1.35,.12),barBack=new THREE.MeshBasicMaterial({color:0x281b22,depthTest:false}),barFill=new THREE.MeshBasicMaterial({color:0xf06d51,depthTest:false});
  function text(value,color='#ffffff') {
    const canvas=document.createElement('canvas');canvas.width=512;canvas.height=80;
    const ctx=canvas.getContext('2d');ctx.font='bold 30px system-ui';ctx.textAlign='center';ctx.textBaseline='middle';
    ctx.strokeStyle='#101525';ctx.lineWidth=6;ctx.strokeText(value,256,40);ctx.fillStyle=color;ctx.fillText(value,256,40);
    const tex=new THREE.CanvasTexture(canvas);tex.colorSpace=THREE.SRGBColorSpace;
    const m=new THREE.SpriteMaterial({map:tex,depthWrite:false});const s=new THREE.Sprite(m);s.scale.set(2.8,.44,1);
    s.userData.noAO=true;return s;
  }
  function disposeSprite(s){s.material.map?.dispose();s.material.dispose();s.removeFromParent();}
  const offDamage=events.on('damage',d=>{
    const sprite=text(`${d.blocked?'GUARD ':''}${d.amount}`,d.id==='player'?'#ff8279':'#ffe294');
    sprite.position.set(d.pos.x,d.pos.y,d.pos.z);root.add(sprite);effects.push({sprite,life:1});
    while(effects.length>24)removeEffect(effects.shift());
  });
  const offBeam=events.on('beam',b=>{
    const from=new THREE.Vector3(b.from.x,b.from.y,b.from.z),to=new THREE.Vector3(b.to.x,b.to.y,b.to.z),dir=to.clone().sub(from),length=dir.length();
    const mesh=new THREE.Mesh(new THREE.CylinderGeometry(.18,.35,length,10),new THREE.MeshBasicMaterial({color:b.color,transparent:true,opacity:.8,depthWrite:false}));
    mesh.position.copy(from).lerp(to,.5);mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0,1,0),dir.normalize());mesh.userData.noAO=true;root.add(mesh);effects.push({mesh,life:.3});
  });
  function removeEffect(e){if(e.sprite)disposeSprite(e.sprite);else {e.mesh.removeFromParent();e.mesh.geometry.dispose();e.mesh.material.dispose();}}
  return {
    update(dt){
      const seen=new Set();
      for(const e of combat.enemies){
        seen.add(e.id);let view=models.get(e.id);
        if(!view){
          const model=createCharacterModel(e.look,{castShadow:gfx.quality.shadows,lod:true});model.object3d.scale.multiplyScalar(e.scale || 1);root.add(model.object3d);
          const tag=text(`${e.name} · Lv. ${e.level}`,e.boss?'#ffd17c':'#f3d9d9');root.add(tag);
          const health=new THREE.Group(),back=new THREE.Mesh(barGeo,barBack),fill=new THREE.Mesh(barGeo,barFill);fill.position.z=.002;health.add(back,fill);root.add(health);
          view={model,tag,health,fill};models.set(e.id,view);
        }
        const alive=e.health>0;view.model.object3d.visible=alive;view.tag.visible=alive;view.health.visible=alive;
        if(!alive)continue;
        view.model.object3d.position.set(e.pos.x,e.pos.y,e.pos.z);view.model.object3d.rotation.y=e.yaw;
        view.model.update(dt,{speed:Math.hypot(e.vel.x,e.vel.z),onGround:e.onGround,attackSerial:e.attackSerial,attackKind:e.attackKind});
        const height=2.2*(e.scale || 1);
        view.tag.position.set(e.pos.x,e.pos.y+height+.3,e.pos.z);view.health.position.set(e.pos.x,e.pos.y+height,e.pos.z);view.health.quaternion.copy(gfx.camera.quaternion);
        const fraction=Math.max(0,e.health/e.maxHealth);view.fill.scale.x=fraction;view.fill.position.x=-(1-fraction)*.675;
        view.tag.material.color.setHex(e.windup>0?0xff6655:0xffffff);
      }
      for(const [id,v]of models)if(!seen.has(id)){v.model.dispose();disposeSprite(v.tag);v.health.removeFromParent();models.delete(id);}
      const shots=new Set();for(const b of combat.projectiles){
        shots.add(b.id);let mesh=balls.get(b.id);if(!mesh){mesh=new THREE.Mesh(sphere,energy);mesh.userData.noAO=true;root.add(mesh);balls.set(b.id,mesh);}mesh.position.set(b.pos.x,b.pos.y,b.pos.z);
      }
      for(const [id,m]of balls)if(!shots.has(id)){m.removeFromParent();balls.delete(id);}
      for(let i=effects.length-1;i>=0;i--){const e=effects[i];e.life-=dt;if(e.life<=0){removeEffect(e);effects.splice(i,1);}else if(e.sprite)e.sprite.position.y+=dt*.9;else e.mesh.material.opacity=e.life/.3*.8;}
    },
    dispose(){offDamage();offBeam();for(const v of models.values()){v.model.dispose();disposeSprite(v.tag);}effects.forEach(removeEffect);sphere.dispose();energy.dispose();barGeo.dispose();barBack.dispose();barFill.dispose();root.removeFromParent();models.clear();balls.clear();},
  };
}
