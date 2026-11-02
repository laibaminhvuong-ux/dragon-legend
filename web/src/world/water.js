// The lake. High quality: a real reflecting water surface (three's Water: mirror reflections,
// sun glints, moving ripples). Lower: an env-mapped glossy surface with scrolling ripples.
import * as THREE from "three";
import { Water } from "../../vendor/three/addons/objects/Water.js";

export function createWater(zone, scene, tex, quality, sunDir) {
  const w = zone.water;
  if (!w) return { update() {}, dispose() {} };
  // Water.js treats the mesh's local +Z as the surface normal, so the mesh (not the geometry) is
  // rotated flat
  const geo = new THREE.CircleGeometry(w.radius * 1.6, 96);
  let mesh, update;
  if (quality.waterReflections) {
    tex.waterNormals.wrapS = tex.waterNormals.wrapT = THREE.RepeatWrapping;
    mesh = new Water(geo, {
      textureWidth: 512, textureHeight: 512, waterNormals: tex.waterNormals, sunDirection: sunDir.clone(),
      sunColor: 0xfff4e0, waterColor: 0x1a3a3c, distortionScale: 1.6, fog: true, alpha: 1,
    });
    mesh.material.uniforms.size.value = 3.5;
    update = (dt) => { mesh.material.uniforms.time.value += dt * 0.6; };
  } else {
    const n = tex.waterNormals.clone();
    n.wrapS = n.wrapT = THREE.RepeatWrapping;
    n.repeat.set(w.radius / 6, w.radius / 6);
    n.needsUpdate = true;
    mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: 0x1c3d40, roughness: 0.08, metalness: 0.1, normalMap: n, normalScale: new THREE.Vector2(0.35, 0.35), transparent: true, opacity: 0.88, envMapIntensity: 1.2 }));
    update = (dt) => { n.offset.x += dt * 0.012; n.offset.y += dt * 0.007; };
  }
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(w.x, w.level, w.z);
  mesh.receiveShadow = !quality.waterReflections;
  mesh.userData.noAO = true;
  scene.add(mesh);
  return { update, dispose() { scene.remove(mesh); geo.dispose(); mesh.material.dispose(); } };
}
