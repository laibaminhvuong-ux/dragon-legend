// Original procedural Great Ape: heavy fur torso, long arms, muzzle, fangs and a curved tail.
import * as THREE from 'three';
export function createGreatApe({golden=false,castShadow=true}={}){
  const root=new THREE.Group();root.name=golden?'golden-great-ape':'great-ape';
  const geo=new THREE.SphereGeometry(1,12,10),box=new THREE.BoxGeometry(1,1,1),fangGeo=new THREE.ConeGeometry(.018,.09,6);
  const fur=new THREE.MeshStandardMaterial({color:golden?0xd6a72c:0x5b3520,roughness:.95});
  const skin=new THREE.MeshStandardMaterial({color:golden?0x9c7138:0x8c6246,roughness:.9});
  const dark=new THREE.MeshStandardMaterial({color:0x1b1514,roughness:.9}),ivory=new THREE.MeshStandardMaterial({color:0xffefd0});
  const eyes=new THREE.MeshStandardMaterial({color:0xf02020,emissive:0xb40000,emissiveIntensity:.7});
  const add=(parent,name,geometry,material,position,scale)=>{const mesh=new THREE.Mesh(geometry,material);mesh.name=name;mesh.position.set(...position);mesh.scale.set(...scale);mesh.castShadow=castShadow;mesh.receiveShadow=castShadow;parent.add(mesh);return mesh;};
  const ball=(p,n,m,pos,scale)=>add(p,n,geo,m,pos,scale);
  const hips=new THREE.Group();hips.position.y=.78;root.add(hips);
  ball(hips,'fur-pelvis',fur,[0,.1,0],[.38,.32,.25]);
  ball(hips,'fur-chest',fur,[0,.52,-.025],[.49,.49,.31]);
  ball(hips,'chest-skin',skin,[0,.43,.265],[.29,.29,.075]);
  const head=new THREE.Group();head.position.set(0,.98,.06);hips.add(head);
  ball(head,'fur-head',fur,[0,0,0],[.27,.29,.23]);
  ball(head,'face',skin,[0,-.055,.17],[.21,.2,.12]);
  ball(head,'muzzle',skin,[0,-.14,.265],[.17,.09,.11]);
  ball(head,'nose',dark,[0,-.07,.325],[.09,.045,.035]);
  add(head,'mouth',box,dark,[0,-.17,.35],[.22,.035,.018]);
  for(const sign of [-1,1]){
    ball(head,'ear',skin,[sign*.275,.005,0],[.07,.095,.045]);
    ball(head,'red-eye',eyes,[sign*.095,.035,.211],[.06,.028,.018]);
    const brow=ball(head,'heavy-brow',fur,[sign*.10,.076,.20],[.11,.04,.035]);brow.rotation.z=sign*.18;
    const fang=add(head,'fang',fangGeo,ivory,[sign*.08,-.17,.36],[1,1,1]);fang.rotation.z=Math.PI;
  }
  const arms=[],legs=[];
  for(const sign of [-1,1]){
    const arm=new THREE.Group();arm.position.set(sign*.44,.69,0);hips.add(arm);
    ball(arm,'fur-upper-arm',fur,[sign*.03,-.18,0],[.19,.3,.19]);
    ball(arm,'fur-forearm',fur,[sign*.06,-.51,.02],[.16,.27,.15]);
    ball(arm,'ape-hand',skin,[sign*.07,-.77,.055],[.15,.16,.12]);
    for(let i=0;i<3;i++)ball(arm,'finger',skin,[sign*.07+(i-1)*.07,-.86,.08],[.036,.1,.047]);
    arms.push(arm);
    const leg=new THREE.Group();leg.position.set(sign*.21,0,0);hips.add(leg);
    ball(leg,'fur-thigh',fur,[0,-.2,0],[.19,.28,.18]);
    ball(leg,'fur-shin',fur,[0,-.49,.02],[.14,.25,.14]);
    ball(leg,'ape-foot',skin,[0,-.70,.12],[.17,.08,.23]);legs.push(leg);
  }
  const curve=new THREE.CatmullRomCurve3([new THREE.Vector3(0,.85,-.2),new THREE.Vector3(.2,.65,-.65),new THREE.Vector3(.5,.85,-.9),new THREE.Vector3(.45,1.25,-.8)]);
  const tailGeo=new THREE.TubeGeometry(curve,16,.065,8,false);add(root,'ape-tail',tailGeo,fur,[0,0,0],[1,1,1]);
  let time=0,lastAttack=0,attackUntil=0,disposed=false;
  return {object3d:root,update(dt,anim={}){
    time+=dt;if(anim.attackSerial && anim.attackSerial!==lastAttack){lastAttack=anim.attackSerial;attackUntil=time+.3;}
    const stride=Math.min(1,(anim.speed || 0)/8),swing=Math.sin(time*9)*stride*.5;
    arms[0].rotation.x=-swing;arms[1].rotation.x=swing;legs[0].rotation.x=swing;legs[1].rotation.x=-swing;
    if(attackUntil>time)arms[(lastAttack || 0)%2].rotation.x=-1.3*Math.sin((attackUntil-time)/.3*Math.PI);
    if(anim.blocking)arms.forEach(a=>a.rotation.x=-1.2);
    hips.rotation.x=anim.dashing?.25:0;hips.position.y=.78+Math.abs(Math.sin(time*9))*.025*stride;
  },dispose(){if(disposed)return;disposed=true;root.removeFromParent();[geo,box,fangGeo,tailGeo].forEach(g=>g.dispose());[fur,skin,dark,ivory,eyes].forEach(m=>m.dispose());}};
}
