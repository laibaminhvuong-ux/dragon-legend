import * as THREE from 'three';
import { ACCESSORIES } from '../data/accessories.js';
export function createAccessories(model,id='None') {
  const geos=[],mats=[],root=new THREE.Group(),attached=[root];root.name='equipped-accessory';
  const spec=ACCESSORIES[id];if(!spec?.attach)return {dispose(){}};
  const parent=model.attach[spec.attach];if(!parent)return {dispose(){}};
  parent.add(root);
  const mesh=(geo,color,pos,rotation=null)=>{
    const mat=new THREE.MeshStandardMaterial({color,roughness:.6});geos.push(geo);mats.push(mat);
    const m=new THREE.Mesh(geo,mat);m.position.set(...pos);if(rotation)m.rotation.set(...rotation);root.add(m);return m;
  };
  if(id==='Scouter'){
    mesh(new THREE.BoxGeometry(.04,.08,.11),0xd4d9e2,[.16,.02,0]);
    const lens=mesh(new THREE.BoxGeometry(.16,.075,.015),0x4cf58d,[.08,.02,.15]);lens.material.transparent=true;lens.material.opacity=.7;
  }else if(id==='Halo')mesh(new THREE.TorusGeometry(.19,.016,6,24),0xffdb60,[0,.28,0],[Math.PI/2,0,0]);
  else if(id==='Cape')mesh(new THREE.BoxGeometry(.58,.78,.025),0xebe9df,[0,-.28,-.04]);
  else if(id==='Wristbands'){const bracelet=mesh(new THREE.TorusGeometry(.045,.018,6,12),0x3c6ac8,[0,.025,0],[Math.PI/2,0,0]);const other=bracelet.clone();model.attach.handL.add(other);attached.push(other);}
  return {dispose(){attached.forEach(o=>o.removeFromParent());geos.forEach(g=>g.dispose());mats.forEach(m=>m.dispose());}};
}
