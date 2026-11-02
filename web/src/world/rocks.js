// Boulders and pebbles: noise-displaced, cut-faceted rocks with the same layered rock shader as
// the cliffs, moss on their tops and darker crevices. Instanced per variant.
import * as THREE from "three";
import { makeNoise2, fbm, rng } from "../game/noise.js";
import { patchShader } from "./terrain.js";

/** Welds duplicate vertices so normals come out smooth. */
function weld(geo) {
  const p = geo.attributes.position, map = new Map(), pos = [], idx = [];
  for (let i = 0; i < p.count; i++) {
    const k = `${p.getX(i).toFixed(4)},${p.getY(i).toFixed(4)},${p.getZ(i).toFixed(4)}`;
    let j = map.get(k);
    if (j === undefined) { j = pos.length / 3; map.set(k, j); pos.push(p.getX(i), p.getY(i), p.getZ(i)); }
    idx.push(j);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  return g;
}

function rockVariant(seed, detail = 3) {
  const r = rng(seed), n = makeNoise2(seed);
  const g = weld(new THREE.IcosahedronGeometry(1, detail));
  const p = g.attributes.position;
  // a few cutting planes give flat fractured faces
  const cuts = Array.from({ length: 5 }, () => ({ n: new THREE.Vector3(r() * 2 - 1, r() * 1.2 - 0.4, r() * 2 - 1).normalize(), d: 0.55 + r() * 0.3 }));
  const ao = [];
  const v = new THREE.Vector3();
  const stretch = new THREE.Vector3(0.9 + r() * 0.5, 0.6 + r() * 0.35, 0.8 + r() * 0.4);
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const disp = fbm(n, v.x * 1.6 + 10, v.y * 1.6 + v.z, 4) * 0.22 + fbm(n, v.z * 3 + 5, v.x * 3, 3) * 0.08;
    v.multiplyScalar(1 + disp);
    for (const c of cuts) {
      const d = v.dot(c.n);
      if (d > c.d) v.addScaledVector(c.n, -(d - c.d) * 0.9);
    }
    v.multiply(stretch);
    if (v.y < -0.25) v.y = -0.25 + (v.y + 0.25) * 0.25; // flat underside, sits on the ground
    p.setXYZ(i, v.x, v.y, v.z);
    ao.push(Math.max(0.45, Math.min(1, 0.8 + disp * 1.6)));
  }
  g.setAttribute("color", new THREE.Float32BufferAttribute(ao.flatMap((a) => [a, a, a]), 3));
  g.computeVertexNormals();
  g.computeBoundingSphere();
  return g;
}

export function createRocks(zone, scene, tex, quality) {
  const props = zone.props();
  const group = new THREE.Group();
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.9, normalMap: tex.rockNormal, normalScale: new THREE.Vector2(0.8, 0.8), envMapIntensity: 0.6 });
  const rt = zone.biome?.tints?.rock || [1, 1, 1], gt = zone.biome?.tints?.grass || [1, 1, 1];
  patchShader(mat, { tRock: { value: tex.rock }, tGrass: { value: tex.grass }, uRockTint: { value: new THREE.Vector3(...rt) }, uGrassTint: { value: new THREE.Vector3(...gt) }, uSnowy: { value: zone.ground === "snow" ? 1 : 0 } }, /* glsl */ `
    vec3 N = normalize(vWNormal);
    vec3 col = triplanarRock(vWPos, N) * 0.95 * uRockTint;
    float moss = smoothstep(0.55, 0.85, N.y + (texture2D(tGrass, vWPos.xz * 0.5).g - 0.3) * 0.5);
    col = mix(col, uSnowy > 0.5 ? vec3(0.88, 0.91, 0.96) : texture2D(tGrass, vWPos.xz * 0.6).rgb * vec3(0.8, 0.95, 0.6) * uGrassTint, moss * 0.85);
    diffuseColor.rgb *= col;
  `);
  const variants = [1, 2, 3, 4, 5].map((s) => rockVariant(s * 17 + 3, 3)); // ~1.3k triangles
  const pebbleVariants = [1, 2, 3, 4, 5].map((s) => rockVariant(s * 17 + 3, 1)); // ~80 triangles
  const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), s = new THREE.Vector3(), v = new THREE.Vector3();

  const place = (list, castShadow, geos) => geos.forEach((geo, vi) => {
    const items = list.filter((k) => k.variant === vi);
    if (!items.length) return;
    const im = new THREE.InstancedMesh(geo, mat, items.length);
    items.forEach((k, i) => {
      q.setFromEuler(e.set(k.rz, k.ry, k.rz * 0.5));
      m.compose(v.set(k.x, k.y, k.z), q, s.set(k.scale, k.scale, k.scale));
      im.setMatrixAt(i, m);
    });
    im.castShadow = castShadow && quality.shadows;
    im.receiveShadow = true;
    im.computeBoundingSphere();
    group.add(im);
  });
  place(props.rocks, true, variants);
  if (quality.grassDensity) place(props.stones, false, pebbleVariants); // pebbles only from medium up

  scene.add(group);
  return {
    dispose() { scene.remove(group); [...variants, ...pebbleVariants].forEach((g) => g.dispose()); mat.dispose(); group.traverse((o) => o.isInstancedMesh && o.dispose()); },
  };
}
