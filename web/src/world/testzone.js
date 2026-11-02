// Draws a zone from game/zones.js: ground following heightAt(), sky, fog and scattered props.
// PLACEHOLDER dressing; Freebuff's lane owns zone dressing. Keep buildZone()'s signature.
import * as THREE from "three";

/** Mulberry32: deterministic random so props land in the same spots every time. */
function rng(seed) {
  return () => { seed |= 0; seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

/** Adds the zone to the scene. Returns { object3d, dispose() }. */
export function buildZone(scene, zone, { castShadow = true } = {}) {
  const group = new THREE.Group();
  const disposables = [];
  const track = (x) => { disposables.push(x); return x; };

  scene.background = new THREE.Color(zone.sky);
  scene.fog = new THREE.Fog(zone.sky, 80, zone.size * 0.75);

  const seg = 160;
  const geo = track(new THREE.PlaneGeometry(zone.size, zone.size, seg, seg));
  geo.rotateX(-Math.PI / 2);
  const p = geo.attributes.position;
  const colors = new Float32Array(p.count * 3);
  const base = new THREE.Color(zone.ground), c = new THREE.Color();
  for (let i = 0; i < p.count; i++) {
    const h = zone.heightAt(p.getX(i), p.getZ(i));
    p.setY(i, h);
    c.copy(base).offsetHSL(0, 0, h * 0.02 + (Math.sin(p.getX(i) * 0.7) * Math.cos(p.getZ(i) * 0.6)) * 0.015);
    colors.set([c.r, c.g, c.b], i * 3);
  }
  geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  const ground = new THREE.Mesh(geo, track(new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1 })));
  ground.receiveShadow = true;
  group.add(ground);

  // rocks and trees (instanced: cheap on phones)
  const rand = rng(7);
  const rockGeo = track(new THREE.DodecahedronGeometry(1, 0));
  const rocks = new THREE.InstancedMesh(rockGeo, track(new THREE.MeshStandardMaterial({ color: 0x8a7f72, roughness: 0.95, flatShading: true })), 120);
  const trunkGeo = track(new THREE.CylinderGeometry(0.25, 0.35, 3, 6));
  const crownGeo = track(new THREE.ConeGeometry(1.8, 4, 7));
  const trunks = new THREE.InstancedMesh(trunkGeo, track(new THREE.MeshStandardMaterial({ color: 0x6b4a2f })), 90);
  const crowns = new THREE.InstancedMesh(crownGeo, track(new THREE.MeshStandardMaterial({ color: 0x3f7d3a, flatShading: true })), 90);
  const m = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), v = new THREE.Vector3();
  const place = () => {
    for (;;) {
      const x = (rand() - 0.5) * zone.size * 0.95, z = (rand() - 0.5) * zone.size * 0.95;
      if (Math.hypot(x - zone.spawn.x, z - zone.spawn.z) > 12) return [x, z];
    }
  };
  for (let i = 0; i < rocks.count; i++) {
    const [x, z] = place();
    const k = 0.5 + rand() * 2.5;
    q.setFromEuler(new THREE.Euler(rand() * 3, rand() * 3, rand() * 3));
    m.compose(v.set(x, zone.heightAt(x, z) + k * 0.3, z), q, s.set(k, k * (0.6 + rand() * 0.6), k));
    rocks.setMatrixAt(i, m);
  }
  for (let i = 0; i < trunks.count; i++) {
    const [x, z] = place();
    const k = 0.8 + rand() * 0.7, y = zone.heightAt(x, z);
    q.identity();
    m.compose(v.set(x, y + 1.5 * k, z), q, s.set(k, k, k));
    trunks.setMatrixAt(i, m);
    m.compose(v.set(x, y + 4.5 * k, z), q, s.set(k, k, k));
    crowns.setMatrixAt(i, m);
  }
  for (const im of [rocks, trunks, crowns]) { im.castShadow = castShadow; im.receiveShadow = true; group.add(im); }

  scene.add(group);
  return {
    object3d: group,
    dispose() {
      scene.remove(group);
      disposables.forEach((d) => d.dispose());
      scene.fog = null;
    },
  };
}
