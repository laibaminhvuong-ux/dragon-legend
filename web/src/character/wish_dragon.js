// Original low-poly wish dragons. All four variants share resources within one summon.
import * as THREE from 'three';
import {DRAGON_LOOKS} from '../data/dragon_hunts.js';
export function createWishDragon(id){
  const look=DRAGON_LOOKS[id];if(!look)throw new Error(`Unknown wish dragon: ${id}`);
  const root=new THREE.Group();root.name='wish-dragon-'+id;const body=new THREE.Group();root.add(body);
  const geos=new Set(),mats=new Set();let time=0,disposed=false;
  const ownG=g=>(geos.add(g),g),material=(color,extra={})=>{const m=new THREE.MeshStandardMaterial({color,roughness:.58,...extra});mats.add(m);return m;};
  const skin=material(look.body,id==='super'?{metalness:.35,emissive:0x815600,emissiveIntensity:.35}:{}),belly=material(look.belly),horn=material(look.horns),eye=material(look.eyes,{emissive:look.eyes,emissiveIntensity:.6});
  const sphere=ownG(new THREE.SphereGeometry(1,12,8)),cone=ownG(new THREE.ConeGeometry(1,1,8));
  const part=(name,parent,geo,mat,pos,scale)=>{const m=new THREE.Mesh(geo,mat);m.name=name;m.position.set(...pos);m.scale.set(...scale);parent.add(m);return m;};
  const points=[new THREE.Vector3(0,.25,-1),new THREE.Vector3(-2,.5,-1.8),new THREE.Vector3(-2.5,1.1,1),new THREE.Vector3(1,1.5,2),new THREE.Vector3(2.4,2.5,-.4),new THREE.Vector3(.5,3.5,-1),new THREE.Vector3(0,5.2,-.3),new THREE.Vector3(0,6.8,0)];
  const curve=new THREE.CatmullRomCurve3(points);
  part('coiled-dragon-body',body,ownG(new THREE.TubeGeometry(curve,64,.43,10,false)),skin,[0,0,0],[1,1,1]);
  for(let i=0;i<13;i++){const p=curve.getPoint(.15+i*.058);part('belly-scale',body,sphere,belly,[p.x,p.y,p.z+.32],[.31,.23,.15]);}
  const head=new THREE.Group();head.name='dragon-head';head.position.set(0,6.9,.1);body.add(head);
  part('skull',head,sphere,skin,[0,0,0],[.67,.52,.7]);
  part('muzzle',head,sphere,skin,[0,-.1,.7],[.51,.25,.52]);
  part('jaw',head,sphere,belly,[0,-.37,.65],[.48,.13,.55]);
  for(const side of [-1,1]){
    part('dragon-eye',head,sphere,eye,[side*.47,.1,.48],[.15,.1,.08]);
    const h=part('horn',head,cone,horn,[side*.5,.68,-.18],[.16,.95,.16]);h.rotation.z=-side*.3;
    part('nostril',head,sphere,horn,[side*.24,.05,1.04],[.07,.045,.05]);
    const tusk=part('fang',head,cone,horn,[side*.3,-.31,.95],[.065,.3,.065]);tusk.rotation.z=Math.PI;
    const whisker=part('whisker',head,ownG(new THREE.CylinderGeometry(.02,.015,1.5,5)),horn,[side*.85,-.1,.8],[1,1,1]);whisker.rotation.z=side*1.1;
    const arm=part('arm',body,sphere,skin,[side*.85,5,.05],[.8,.24,.26]);arm.rotation.z=-side*.45;
    part('claw-hand',body,sphere,skin,[side*1.45,4.65,.35],[.3,.2,.32]);
    for(let i=0;i<3;i++)part('claw',body,cone,horn,[side*(1.3+i*.13),4.45,.52],[.045,.28,.045]).rotation.x=Math.PI*.8;
  }
  if(look.kind==='muscular'){
    part('broad-chest',body,sphere,skin,[0,5,.05],[1.25,1.15,.65]);
    part('chest-plates',body,sphere,belly,[0,5,.6],[.85,.85,.13]);
    for(const side of [-1,1])part('muscular-shoulder',body,sphere,skin,[side*1.25,5.5,0],[.55,.65,.55]);
  }
  function fin(parent,side,size,mat,name){
    const shape=new THREE.Shape();shape.moveTo(0,0);shape.lineTo(side*size*.6,size*.85);shape.lineTo(side*size*1.2,size*.25);shape.lineTo(side*size,size*-.4);shape.lineTo(0,-size*.2);
    const mesh=part(name,parent,ownG(new THREE.ShapeGeometry(shape)),mat,[side*.5,.1,-.2],[1,1,1]);return mesh;
  }
  if(look.kind==='finned'){
    const fins=material(0xedd4b9,{side:THREE.DoubleSide});for(const side of [-1,1])fin(head,side,1.6,fins,'frilled-head-fin');
  }
  if(look.kind==='winged'){
    const wingMat=material(0xffd864,{side:THREE.DoubleSide,metalness:.4,emissive:0x7a4400,emissiveIntensity:.3});
    const wings=new THREE.Group();wings.name='golden-wings';wings.position.set(0,5.1,-.8);body.add(wings);
    for(const side of [-1,1])fin(wings,side,4,wingMat,'golden-wing');
  }
  const ring=part('summoning-ring',root,ownG(new THREE.TorusGeometry(1,.025,6,48)),material(id==='super'?0xffdb67:0x81ffbb,{emissive:id==='super'?0xffb52b:0x40b878,emissiveIntensity:1}),[0,.05,0],[1,1,1]);ring.rotation.x=Math.PI/2;
  body.scale.setScalar(.25);
  return {object3d:root,update(dt){if(disposed)return;time+=Math.max(0,dt);const rise=1-Math.exp(-time*2.5);body.scale.setScalar(.25*rise);body.position.y=Math.sin(time*1.5)*.04;head.rotation.y=Math.sin(time*.6)*.06;ring.rotation.z=time*.25;},
    dispose(){if(disposed)return;disposed=true;root.removeFromParent();geos.forEach(g=>g.dispose());mats.forEach(m=>m.dispose());}};
}
