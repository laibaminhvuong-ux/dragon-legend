// Original low-poly energy projection. Shared geometry/materials; no shadows or reflection pass.
import * as THREE from 'three';
import { INSTINCT_AVATAR as A } from '../data/avatar.js';
export function createUltraInstinctAvatar(){
  const root=new THREE.Group();root.name='ultra-instinct-energy-avatar';root.scale.setScalar(A.scale);
  const sphere=new THREE.SphereGeometry(1,12,8),box=new THREE.BoxGeometry(1,1,1),spike=new THREE.ConeGeometry(.1,.3,6),ringGeo=new THREE.TorusGeometry(1,.025,5,32);
  const energy=new THREE.MeshBasicMaterial({color:A.color,transparent:true,opacity:A.opacity,depthWrite:false,blending:THREE.AdditiveBlending});
  const core=new THREE.MeshBasicMaterial({color:A.coreColor,transparent:true,opacity:.35,depthWrite:false,blending:THREE.AdditiveBlending});
  const make=(parent,name,geo,mat,pos,scale)=>{const mesh=new THREE.Mesh(geo,mat);mesh.name=name;mesh.position.set(...pos);mesh.scale.set(...scale);mesh.layers.set(1);mesh.userData.noAO=true;parent.add(mesh);return mesh;};
  make(root,'avatar-torso',sphere,energy,[0,1.12,0],[.34,.48,.2]);
  make(root,'avatar-waist',sphere,energy,[0,.78,0],[.24,.2,.17]);
  const head=new THREE.Group();head.position.set(0,1.73,0);root.add(head);
  make(head,'avatar-head',sphere,energy,[0,0,0],[.17,.2,.145]);
  for(const sign of [-1,1]){
    make(head,'avatar-eye',box,core,[sign*.07,.018,.141],[.065,.016,.012]);
    const hair=make(head,'avatar-hair',spike,core,[sign*.12,.18,-.025],[.8,1,.8]);hair.rotation.z=sign*-.5;
    make(root,'avatar-leg',sphere,energy,[sign*.14,.37,0],[.13,.38,.13]);
  }
  make(head,'avatar-hair-crown',spike,core,[0,.23,-.04],[1,1.2,1]);
  const arms=[];
  for(const sign of [-1,1]){
    const pivot=new THREE.Group();pivot.position.set(sign*.34,1.4,0);root.add(pivot);
    make(pivot,'avatar-arm',sphere,energy,[sign*.045,-.3,0],[.12,.34,.12]);
    make(pivot,'avatar-fist',sphere,core,[sign*.055,-.66,.015],[.12,.12,.11]);arms.push(pivot);
  }
  const impact=make(root,'avatar-strike-wave',ringGeo,core,[0,.025,A.range/A.scale*.55],[.05,.05,.05]);impact.rotation.x=-Math.PI/2;
  root.traverse(o=>{o.layers.set(1);o.userData.noAO=true;});
  let time=0,lastPulse=0,strikeAge=1,disposed=false;
  return {object3d:root,
    update(dt,state){
      root.visible=!!state.active;if(!state.active)return;
      time+=dt;strikeAge+=dt;
      root.position.set(state.pos.x-Math.sin(state.yaw)*.8,state.pos.y,state.pos.z-Math.cos(state.yaw)*.8);root.rotation.y=state.yaw;
      if(state.pulse!==lastPulse){lastPulse=state.pulse;strikeAge=0;}
      const punch=strikeAge<.45?Math.sin(strikeAge/.45*Math.PI):0;
      arms[0].rotation.x=lastPulse%2?-punch*1.5:-.2;arms[1].rotation.x=lastPulse%2?-.2:-punch*1.5;
      energy.opacity=A.opacity+Math.sin(time*5)*.025;
      impact.visible=strikeAge<.45;impact.scale.setScalar(.1+Math.min(1,strikeAge/.45)*1.1);
      core.opacity=Math.max(.12,.35*(Math.min(1,state.remaining/.6)));
    },
    dispose(){if(disposed)return;disposed=true;root.removeFromParent();[sphere,box,spike,ringGeo].forEach(g=>g.dispose());energy.dispose();core.dispose();},
  };
}
