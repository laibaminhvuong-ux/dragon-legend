// Procedural trees: tapered, bending trunks and branches with bark, canopies of leaf cards with
// rounded lighting, swaying in the wind. A few variants, instanced for every tree in the zone.
// Bushes reuse the leaf material.
import * as THREE from "three";
import { rng } from "../game/noise.js";

/** Tapered tube along points (array of Vector3), radius r0 -> r1. Appends to arrays. */
function tube(out, pts, r0, r1, sides) {
  const base = out.pos.length / 3;
  const rings = pts.length;
  let len = 0;
  for (let i = 0; i < rings; i++) {
    if (i > 0) len += pts[i].distanceTo(pts[i - 1]);
    const t = i / (rings - 1);
    const dir = (i < rings - 1 ? pts[i + 1].clone().sub(pts[i]) : pts[i].clone().sub(pts[i - 1])).normalize();
    const side = Math.abs(dir.y) < 0.99 ? new THREE.Vector3(0, 1, 0).cross(dir).normalize() : new THREE.Vector3(1, 0, 0);
    const up = dir.clone().cross(side).normalize();
    const flare = i === 0 ? 1.35 : 1;
    const rad = (r0 + (r1 - r0) * t) * flare;
    for (let s = 0; s <= sides; s++) {
      const a = (s / sides) * Math.PI * 2;
      const nx = side.x * Math.cos(a) + up.x * Math.sin(a), ny = side.y * Math.cos(a) + up.y * Math.sin(a), nz = side.z * Math.cos(a) + up.z * Math.sin(a);
      out.pos.push(pts[i].x + nx * rad, pts[i].y + ny * rad, pts[i].z + nz * rad);
      out.nor.push(nx, ny, nz);
      out.uv.push(s / sides, len * 0.35);
    }
  }
  for (let i = 0; i < rings - 1; i++) for (let s = 0; s < sides; s++) {
    const a = base + i * (sides + 1) + s, b = a + sides + 1;
    out.idx.push(a, b, a + 1, a + 1, b, b + 1);
  }
}

/** Leaf cards around a centre; normals point away from the canopy centre for soft, round shading. */
function leafCluster(out, center, radius, count, cardSize, canopyCenter, r) {
  for (let k = 0; k < count; k++) {
    const p = new THREE.Vector3((r() * 2 - 1), (r() * 2 - 1) * 0.7, (r() * 2 - 1)).normalize().multiplyScalar(Math.cbrt(r()) * radius).add(center);
    const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(r() * Math.PI, r() * Math.PI, r() * Math.PI));
    const sz = cardSize * (0.75 + r() * 0.5);
    const base = out.pos.length / 3;
    const corners = [[-1, -1], [1, -1], [1, 1], [-1, 1]];
    for (const [cx, cy] of corners) {
      const v = new THREE.Vector3(cx * sz / 2, cy * sz / 2, 0).applyQuaternion(q).add(p);
      out.pos.push(v.x, v.y, v.z);
      const n = v.clone().sub(canopyCenter).normalize();
      n.y = n.y * 0.8 + 0.25;
      n.normalize();
      out.nor.push(n.x, n.y, n.z);
      out.uv.push((cx + 1) / 2, (cy + 1) / 2);
    }
    out.idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
  }
}

function toGeometry(o) {
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(o.pos, 3));
  g.setAttribute("normal", new THREE.Float32BufferAttribute(o.nor, 3));
  g.setAttribute("uv", new THREE.Float32BufferAttribute(o.uv, 2));
  g.setIndex(o.idx);
  g.computeBoundingSphere();
  return g;
}

/** One tree variant (about 9-12 m tall at scale 1). */
function treeVariant(seed, density = 1) {
  const r = rng(seed);
  const wood = { pos: [], nor: [], uv: [], idx: [] }, leaves = { pos: [], nor: [], uv: [], idx: [] };
  const H = 6.5 + r() * 2.5;
  const lean = new THREE.Vector3((r() - 0.5) * 0.8, 0, (r() - 0.5) * 0.8);
  const trunkPts = [];
  for (let i = 0; i <= 7; i++) {
    const t = i / 7;
    trunkPts.push(new THREE.Vector3(lean.x * t * t + Math.sin(t * 5 + seed) * 0.12, t * H, lean.z * t * t + Math.cos(t * 4 + seed) * 0.12));
  }
  tube(wood, trunkPts, 0.38, 0.12, 9);
  const canopy = new THREE.Vector3(lean.x, H * 0.92, lean.z);
  const ends = [new THREE.Vector3(lean.x, H + 0.6, lean.z)];
  const nb = 6 + Math.floor(r() * 3);
  for (let i = 0; i < nb; i++) {
    const t = 0.42 + r() * 0.45;
    const start = trunkPts[Math.round(t * 7)].clone();
    const a = (i / nb) * Math.PI * 2 + r() * 0.6;
    const len = H * (0.33 + r() * 0.2) * (1.1 - t * 0.5);
    const dir = new THREE.Vector3(Math.cos(a), 0.55 + r() * 0.5, Math.sin(a)).normalize();
    const pts = [];
    for (let k = 0; k <= 4; k++) {
      const u = k / 4;
      pts.push(start.clone().addScaledVector(dir, len * u).add(new THREE.Vector3(0, -Math.sin(u * Math.PI) * 0.25 + u * u * 0.6, 0)));
    }
    tube(wood, pts, 0.13 * (1.2 - t * 0.6), 0.03, 6);
    ends.push(pts[4], pts[2]);
  }
  // fewer, larger cards at low density so the canopy still looks full
  const k = Math.sqrt(1 / density);
  for (const e of ends) leafCluster(leaves, e, 1.7 + r() * 0.6, Math.round(22 * density), 2.6 * k, canopy, r);
  leafCluster(leaves, canopy, 2.8, Math.round(40 * density), 2.8 * k, canopy, r);
  return { wood: toGeometry(wood), leaves: toGeometry(leaves), height: H };
}

function bushGeometry() {
  const r = rng(77);
  const o = { pos: [], nor: [], uv: [], idx: [] };
  const c = new THREE.Vector3(0, 0.55, 0);
  leafCluster(o, c, 0.75, 16, 1.0, new THREE.Vector3(0, 0.1, 0), r);
  leafCluster(o, new THREE.Vector3(0.5, 0.4, 0.2), 0.45, 8, 0.8, new THREE.Vector3(0, 0.1, 0), r);
  return toGeometry(o);
}

function windPatch(material, uniforms, amount) {
  material.onBeforeCompile = (s) => {
    s.uniforms.uTime = uniforms.uTime;
    s.vertexShader = s.vertexShader
      .replace("#include <common>", "#include <common>\nuniform float uTime;")
      .replace("#include <begin_vertex>", /* glsl */ `#include <begin_vertex>
        #ifdef USE_INSTANCING
          vec3 ip = vec3(instanceMatrix[3][0], instanceMatrix[3][1], instanceMatrix[3][2]);
        #else
          vec3 ip = vec3(0.0);
        #endif
        float hh = max(0.0, position.y) * ${amount.toFixed(4)};
        float ph = ip.x * 0.11 + ip.z * 0.07;
        transformed.x += (sin(uTime * 1.3 + ph) * 0.6 + sin(uTime * 3.7 + ph * 3.0 + position.z) * 0.25) * hh;
        transformed.z += (cos(uTime * 1.1 + ph) * 0.4 + sin(uTime * 4.1 + ph * 2.0 + position.x) * 0.2) * hh;`);
  };
}

export function createTrees(zone, scene, tex, quality) {
  const props = zone.props();
  const uniforms = { uTime: { value: 0 } };
  const group = new THREE.Group();
  const bark = new THREE.MeshStandardMaterial({ map: tex.bark, normalMap: tex.barkNormal, normalScale: new THREE.Vector2(1.4, 1.4), roughness: 0.95, envMapIntensity: 0.5 });
  windPatch(bark, uniforms, 0.004);
  const leafMat = new THREE.MeshStandardMaterial({ map: tex.leaves, alphaTest: 0.5, side: THREE.DoubleSide, roughness: 0.7, envMapIntensity: 0.9, emissive: 0x1a2a0c, emissiveIntensity: 0.55, alphaToCoverage: quality.msaa > 0 });
  windPatch(leafMat, uniforms, 0.012);
  const leafDepth = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: tex.leaves, alphaTest: 0.5 });
  const variants = [1, 2, 3, 4].map((s) => treeVariant(s * 31, quality.leafDensity));
  const m = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), v = new THREE.Vector3(), c = new THREE.Color();
  const disposables = [bark, leafMat, leafDepth];

  variants.forEach((variant, vi) => {
    const list = props.trees.filter((t) => t.variant === vi);
    if (!list.length) return;
    const trunks = new THREE.InstancedMesh(variant.wood, bark, list.length);
    const crowns = new THREE.InstancedMesh(variant.leaves, leafMat, list.length);
    crowns.customDepthMaterial = leafDepth;
    crowns.userData.noAO = true;
    list.forEach((t, i) => {
      q.setFromAxisAngle(v.set(0, 1, 0), t.rot);
      m.compose(v.set(t.x, t.y - 0.15, t.z), q, s.set(t.scale, t.scale, t.scale));
      trunks.setMatrixAt(i, m);
      crowns.setMatrixAt(i, m);
      // each tree a slightly different green (autumn-ish tint on a few)
      const k = (Math.sin(t.x * 12.9 + t.z * 78.2) * 43758.5) % 1;
      const f = Math.abs(k);
      crowns.setColorAt(i, c.setRGB(0.85 + f * 0.25, 0.9 + f * 0.15, 0.75 + (f > 0.85 ? -0.2 : f * 0.2)));
    });
    for (const im of [trunks, crowns]) { im.castShadow = quality.shadows; im.receiveShadow = true; im.computeBoundingSphere(); group.add(im); }
    disposables.push(variant.wood, variant.leaves);
  });

  if (props.bushes.length && quality.grassDensity) {
    const bg = bushGeometry();
    const bushes = new THREE.InstancedMesh(bg, leafMat, props.bushes.length);
    bushes.customDepthMaterial = leafDepth;
    bushes.userData.noAO = true;
    props.bushes.forEach((b, i) => {
      q.setFromAxisAngle(v.set(0, 1, 0), b.rot);
      m.compose(v.set(b.x, b.y - 0.1, b.z), q, s.set(b.scale * 1.2, b.scale, b.scale * 1.2));
      bushes.setMatrixAt(i, m);
      bushes.setColorAt(i, c.setRGB(0.8 + (i % 7) * 0.04, 0.85 + (i % 5) * 0.04, 0.7));
    });
    bushes.castShadow = quality.shadows;
    bushes.receiveShadow = true;
    bushes.computeBoundingSphere();
    group.add(bushes);
    disposables.push(bg);
  }

  scene.add(group);
  return {
    update(dt) { uniforms.uTime.value += dt; },
    dispose() { scene.remove(group); disposables.forEach((d) => d.dispose()); group.traverse((o) => o.isInstancedMesh && o.dispose()); },
  };
}
