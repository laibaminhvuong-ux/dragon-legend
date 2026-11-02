// Landmarks: the buildings, ships and arenas that make each world recognisable. Built from simple
// shapes with PBR materials. buildLandmarks(zone, scene, quality) -> { update(dt), dispose() }
import * as THREE from "three";

const disposables = new Set();
function mat(color, o = {}) {
  const m = new THREE.MeshStandardMaterial({ color, roughness: o.rough ?? 0.6, metalness: o.metal ?? 0, emissive: o.emissive ?? 0, emissiveIntensity: o.glow ?? 1, flatShading: !!o.flat, side: o.side ?? THREE.FrontSide, transparent: !!o.opacity, opacity: o.opacity ?? 1 });
  disposables.add(m);
  return m;
}
function mesh(geo, material, x = 0, y = 0, z = 0, parent = null) {
  disposables.add(geo);
  const m = new THREE.Mesh(geo, material);
  m.position.set(x, y, z);
  m.castShadow = true;
  m.receiveShadow = true;
  if (parent) parent.add(m);
  return m;
}
const box = (w, h, d, m, x, y, z, p) => mesh(new THREE.BoxGeometry(w, h, d), m, x, y, z, p);
const cyl = (rt, rb, h, m, x, y, z, p, seg = 24) => mesh(new THREE.CylinderGeometry(rt, rb, h, seg), m, x, y, z, p);
const sphere = (r, m, x, y, z, p, ws = 28, hs = 18, thetaLen = Math.PI) => mesh(new THREE.SphereGeometry(r, ws, hs, 0, Math.PI * 2, 0, thetaLen), m, x, y, z, p);
const dome = (r, m, x, y, z, p) => sphere(r, m, x, y, z, p, 32, 16, Math.PI / 2);
const cone = (r, h, m, x, y, z, p, seg = 24) => mesh(new THREE.ConeGeometry(r, h, seg), m, x, y, z, p);
const torus = (r, t, m, x, y, z, p) => mesh(new THREE.TorusGeometry(r, t, 12, 40), m, x, y, z, p);

/** A row of round windows around a dome or cylinder. */
function portholes(g, radius, y, count, size, m) {
  for (let i = 0; i < count; i++) {
    const a = (i / count) * Math.PI * 2;
    const w = cyl(size, size, 0.2, m, Math.cos(a) * radius, y, Math.sin(a) * radius, g, 16);
    w.rotation.z = Math.PI / 2;
    w.rotation.y = -a;
  }
}

const BUILD = {
  pod(g) { // a Saiyan attack ball, half sunk in its crater
    sphere(1.1, mat(0xdedde0, { metal: 0.8, rough: 0.3 }), 0, 0.5, 0, g);
    sphere(0.75, mat(0x7a1020, { metal: 0.3, rough: 0.1, emissive: 0x300008 }), 0.55, 0.75, 0.2, g, 20, 12, Math.PI * 0.6).rotation.z = -1.2;
  },
  crater(g) { BUILD.pod(g); },
  crashpod(g) { BUILD.pod(g); g.rotation.z = 0.5; },
  farmhouse(g) {
    box(7, 3.2, 5, mat(0xc9b28a), 0, 1.6, 0, g);
    const roof = cone(5.4, 2.4, mat(0x8a3a2a, { flat: true }), 0, 4.4, 0, g, 4); roof.rotation.y = Math.PI / 4; roof.scale.set(1, 1, 0.75);
    box(1.2, 2, 0.1, mat(0x5a3a22), 0, 1, 2.55, g);
    box(3, 2, 2.4, mat(0x9a3a2a), 6, 1, -1, g); // barn shed
    box(2.6, 1.2, 1.6, mat(0x3a4a7a, { metal: 0.4 }), -6, 0.8, 3, g); // truck body
  },
  kamehouse(g) {
    const walls = mat(0xf2a6b8), roof = mat(0xc8322a, { rough: 0.5 }), trim = mat(0xf6f0e6);
    box(7, 4, 6, walls, 0, 2, 0, g);
    box(7.3, 0.4, 6.3, trim, 0, 4.1, 0, g);
    const r = cone(5.9, 2.6, roof, 0, 5.6, 0, g, 4); r.rotation.y = Math.PI / 4; r.scale.set(1.05, 1, 0.9);
    box(1.4, 2.4, 0.15, mat(0x7a4a2a), 0, 1.2, 3.05, g);
    for (const x of [-2.2, 2.2]) box(1.2, 1.1, 0.12, mat(0xbfe6ff, { metal: 0.2, rough: 0.1 }), x, 2.5, 3.05, g);
    box(9, 0.3, 8, trim, 0, 0.15, 0, g); // porch deck
  },
  snakehead(g) { // dragon-head gate where Snake Way begins
    const green = mat(0x7da34a, { rough: 0.7 }), horn = mat(0xe6d6a0);
    box(3, 2.8, 5, green, 0, 1.4, -4.5, g);
    box(3.2, 1.2, 3, green, 0, 0.6, -1.4, g); // lower jaw
    box(3.2, 1, 3, green, 0, 2.8, -1.4, g); // upper jaw
    for (const x of [-1.3, 1.3]) { sphere(0.35, mat(0xffcc33, { emissive: 0x664400 }), x, 3.2, -3.2, g); cone(0.3, 2, horn, x, 4, -5.5, g).rotation.x = -0.6; }
  },
  kingkaihouse(g) {
    dome(4, mat(0xf3eadb), 0, 0, 0, g);
    const roof = mat(0xc83228);
    torus(4, 0.3, roof, 0, 0.1, 0, g).rotation.x = Math.PI / 2;
    sphere(0.8, roof, 0, 4, 0, g);
    box(1.4, 2.2, 0.2, mat(0x6a4a2a), 0, 1.1, 3.9, g);
  },
  car(g) {
    const red = mat(0xc8322a, { metal: 0.5, rough: 0.3 });
    box(3, 0.7, 1.6, red, 0, 0.7, 0, g);
    box(1.6, 0.6, 1.4, mat(0xddeeff, { opacity: 0.5, rough: 0.1 }), -0.2, 1.3, 0, g);
    for (const [x, z] of [[-1, -0.8], [1, -0.8], [-1, 0.8], [1, 0.8]]) { const w = cyl(0.35, 0.35, 0.25, mat(0x222222), x, 0.35, z, g, 16); w.rotation.x = Math.PI / 2; }
  },
  namekhouse(g) {
    const white = mat(0xf4f1e6, { rough: 0.45 }), win = mat(0x3a6a5a, { rough: 0.2 });
    dome(3.4, white, 0, 0.2, 0, g);
    cyl(3.5, 3.6, 0.6, white, 0, 0.3, 0, g);
    portholes(g, 3.1, 1.5, 6, 0.45, win);
    cyl(0.25, 0.25, 1.6, white, 0, 3.8, 0, g);
    sphere(0.4, white, 0, 4.6, 0, g);
  },
  gurutower(g, zone, l) { // house on top of the pillar mesa
    const top = zone.heightAt(l.x, l.z);
    const h = new THREE.Group(); h.position.y = top - g.position.y; g.add(h);
    BUILD.namekhouse(h);
    h.scale.setScalar(1.6);
  },
  friezaship(g) {
    const hull = mat(0xd8dbe2, { metal: 0.7, rough: 0.25 }), glow = mat(0xff5aa0, { emissive: 0xff2a80, glow: 1.5 });
    const s = sphere(14, hull, 0, 0, 0, g, 48, 24); s.scale.set(1, 0.42, 1); s.position.y = 6;
    torus(14, 0.6, mat(0x9aa0aa, { metal: 0.8 }), 0, 6, 0, g).rotation.x = Math.PI / 2;
    portholes(g, 13.4, 6.4, 18, 0.6, glow);
    for (let i = 0; i < 6; i++) { const a = (i / 6) * Math.PI * 2; const leg = cyl(0.5, 0.8, 5, hull, Math.cos(a) * 9, 2.5, Math.sin(a) * 9, g, 10); leg.rotation.z = Math.cos(a) * 0.3; leg.rotation.x = -Math.sin(a) * 0.3; }
  },
  capsuleship(g) {
    const hull = mat(0xeeeef0, { metal: 0.5, rough: 0.3 }), blue = mat(0x2e5ea8, { metal: 0.3 });
    sphere(3, hull, 0, 3.6, 0, g);
    torus(3, 0.25, blue, 0, 3.6, 0, g).rotation.x = Math.PI / 2;
    portholes(g, 2.9, 4.4, 8, 0.32, mat(0x8fd0ff, { emissive: 0x1a3a5a }));
    for (let i = 0; i < 4; i++) { const a = (i / 4) * Math.PI * 2 + 0.4; const leg = cyl(0.15, 0.2, 2.6, blue, Math.cos(a) * 2.6, 1.2, Math.sin(a) * 2.6, g, 8); leg.rotation.z = Math.cos(a) * 0.4; leg.rotation.x = -Math.sin(a) * 0.4; }
  },
  timemachine(g) {
    const body = mat(0xf0e6c8, { metal: 0.4, rough: 0.35 });
    const c = cyl(1.2, 1.2, 2.2, body, 0, 1.6, 0, g, 20); c.rotation.z = 0.05;
    dome(1.2, mat(0xbfe6ff, { opacity: 0.55, rough: 0.05 }), 0, 2.7, 0, g);
    for (let i = 0; i < 4; i++) { const a = (i / 4) * Math.PI * 2; const leg = cyl(0.08, 0.12, 1.4, body, Math.cos(a) * 1.1, 0.5, Math.sin(a) * 1.1, g, 6); leg.rotation.z = Math.cos(a) * 0.5; leg.rotation.x = -Math.sin(a) * 0.5; }
  },
  yardrathut(g) {
    const shell = mat(0xd9c2f0, { rough: 0.35 }), band = mat(0x8a6ad0);
    const d = sphere(3, shell, 0, 0.8, 0, g); d.scale.set(1, 0.85, 1);
    torus(2.9, 0.2, band, 0, 1.2, 0, g).rotation.x = Math.PI / 2;
    cone(0.5, 2.6, band, 0, 4.6, 0, g, 8);
  },
  capsulecorp(g) {
    const white = mat(0xf6f3ea, { rough: 0.35 }), yellow = mat(0xf2c94c, { rough: 0.45 }), glass = mat(0x8fbfdf, { rough: 0.08, metal: 0.2 });
    const main = sphere(16, white, 0, 0, 0, g, 48, 24, Math.PI / 2); main.scale.set(1, 0.72, 1);
    torus(16, 0.6, yellow, 0, 0.6, 0, g).rotation.x = Math.PI / 2;
    portholes(g, 13.6, 5.2, 16, 1.0, glass);
    // the side tower and the big ring of the lab
    cyl(5, 5, 14, white, 15, 7, -6, g, 32); dome(5, white, 15, 14, -6, g);
    torus(5.1, 0.35, yellow, 15, 9, -6, g).rotation.x = Math.PI / 2;
    portholes({ add: (m) => { m.position.x += 15; m.position.z -= 6; g.add(m); } }, 5, 11, 8, 0.6, glass);
    box(5, 3.4, 0.4, glass, 0, 1.7, 16.1, g); // entrance
  },
  dome(g) {
    const white = mat(0xf2efe6, { rough: 0.4 }), accent = mat([0x6aa6d8, 0xd88a6a, 0x8ac87a][Math.floor(Math.random() * 3)]);
    const d = sphere(6, white, 0, 0, 0, g, 36, 18, Math.PI / 2); d.scale.set(1, 0.8, 1);
    torus(6, 0.3, accent, 0, 0.4, 0, g).rotation.x = Math.PI / 2;
    portholes(g, 5.3, 2.4, 10, 0.5, mat(0x8fbfdf, { rough: 0.1 }));
  },
  labdoor(g) { // a steel door set into the mountainside
    const steel = mat(0x8a9098, { metal: 0.85, rough: 0.35 });
    box(6, 5, 1.2, steel, 0, 2.5, 0, g);
    box(5.4, 4.4, 0.3, mat(0x50565e, { metal: 0.8, rough: 0.4 }), 0, 2.3, 0.7, g);
    box(0.4, 4.4, 0.4, mat(0xb03a2a), 0, 2.3, 0.9, g);
  },
  ruin(g, zone, l) { // broken concrete buildings
    const conc = mat(0x8c8a84, { rough: 0.9, flat: true }), dark = mat(0x3a3a3c, { rough: 0.9 });
    const r = mulberry(Math.floor(l.x * 13 + l.z * 7));
    for (let i = 0; i < 4; i++) {
      const w = 4 + r() * 6, h = 4 + r() * 14, d = 4 + r() * 6;
      const b = box(w, h, d, conc, (r() - 0.5) * 14, h / 2 - 0.5, (r() - 0.5) * 14, g);
      b.rotation.y = r() * 0.4; b.rotation.z = (r() - 0.5) * 0.15;
      for (let k = 0; k < 3; k++) box(w * 0.2, 1, 0.1, dark, b.position.x + (r() - 0.5) * w * 0.6, 2 + r() * (h - 3), b.position.z + d / 2 + 0.06, g);
    }
    for (let i = 0; i < 8; i++) { const c = box(1 + r() * 2, 0.6 + r(), 1 + r() * 2, conc, (r() - 0.5) * 20, 0.3, (r() - 0.5) * 20, g); c.rotation.set(r(), r(), r()); }
  },
  husk(g) {
    const shell = mat(0x6a8a3a, { rough: 0.5, side: THREE.DoubleSide });
    const s = sphere(1.4, shell, 0, 1.2, 0, g, 20, 14, Math.PI * 0.75); s.scale.set(0.8, 1.4, 0.8); s.rotation.x = 0.5;
  },
  palace(g) { // Kami's Palace on the Lookout
    const white = mat(0xf4f1ea, { rough: 0.4 }), gold = mat(0xd8b04a, { metal: 0.6, rough: 0.3 });
    cyl(9, 10, 6, white, 0, 3, 0, g, 40);
    dome(9, white, 0, 6, 0, g);
    sphere(1, gold, 0, 15.2, 0, g);
    for (let i = 0; i < 4; i++) { const a = (i / 4) * Math.PI * 2 + Math.PI / 4; cyl(1.6, 1.6, 10, white, Math.cos(a) * 12, 5, Math.sin(a) * 12, g, 20); cone(1.8, 3, gold, Math.cos(a) * 12, 11.5, Math.sin(a) * 12, g, 20); }
    box(4, 4.4, 0.4, mat(0x7a5a3a), 0, 2.2, 10, g);
  },
  htcdoor(g) {
    const white = mat(0xf7f5ef, { rough: 0.35 });
    box(6, 6, 5, white, 0, 3, 0, g);
    box(2.6, 4.2, 0.2, mat(0xd8d2c6), 0, 2.1, 2.55, g);
    const roof = cone(4.6, 2, white, 0, 7, 0, g, 4); roof.rotation.y = Math.PI / 4;
  },
  htcroom(g) {
    const white = mat(0xfbfaf6, { rough: 0.3 });
    box(16, 6, 10, white, 0, 3, 0, g);
    for (const x of [-6, 6]) cyl(1.2, 1.2, 9, white, x, 4.5, 5.2, g, 16);
  },
  cellarena(g) { // square ring of stone tiles
    const tile = mat(0xd6d2c6, { rough: 0.85 }), seam = mat(0x8c887e, { rough: 0.9 });
    box(50, 1, 50, tile, 0, 0.5, 0, g);
    for (let i = -20; i <= 20; i += 10) { box(50, 0.05, 0.25, seam, 0, 1.02, i, g); box(0.25, 0.05, 50, seam, i, 1.02, 0, g); }
    for (const [x, z] of [[-26, -26], [26, -26], [-26, 26], [26, 26]]) { cyl(0.6, 0.6, 5, seam, x, 2.5, z, g, 12); sphere(0.7, mat(0xff4a3a, { emissive: 0x801010 }), x, 5.4, z, g); }
  },
  budokai(g) {
    const stone = mat(0xd8cdb4, { rough: 0.8 }), red = mat(0xb8322a, { rough: 0.5 });
    box(40, 1.6, 40, stone, 0, 0.8, 0, g);
    for (let i = -16; i <= 16; i += 8) { box(40, 0.05, 0.2, mat(0x9a8e76), 0, 1.62, i, g); box(0.2, 0.05, 40, mat(0x9a8e76), i, 1.62, 0, g); }
    // temple gate behind the ring
    for (const x of [-8, 8]) cyl(0.9, 0.9, 12, red, x, 6, 26, g, 16);
    box(22, 1.2, 2.4, red, 0, 12.4, 26, g);
    const roof = box(26, 1.2, 4, mat(0x3a3a3a), 0, 13.6, 26, g); roof.rotation.z = 0;
  },
  babidiship(g) {
    const hull = mat(0xc4a87a, { rough: 0.75, flat: true }), dark = mat(0x3a2a1a);
    const s = sphere(22, hull, 0, 4, 0, g, 40, 22); s.scale.set(1, 0.55, 1);
    for (let i = 0; i < 4; i++) { const a = (i / 4) * Math.PI * 2; box(4, 2.5, 0.6, dark, Math.cos(a) * 21.6, 5, Math.sin(a) * 21.6, g).rotation.y = -a + Math.PI / 2; }
    box(5, 4, 3, dark, 0, 2, -21, g); // the hatch
  },
  zsword(g) {
    const rock = mat(0x8a8274, { rough: 0.9, flat: true });
    const r = sphere(2.4, rock, 0, 0.4, 0, g, 10, 8); r.scale.set(1.2, 0.6, 1);
    box(0.3, 4.6, 0.9, mat(0xd6dce6, { metal: 0.95, rough: 0.15 }), 0, 3.4, 0, g);
    box(1.8, 0.4, 0.5, mat(0xd8b04a, { metal: 0.7 }), 0, 5.8, 0, g);
    box(0.3, 1.4, 0.3, mat(0x5a3a22), 0, 6.6, 0, g);
  },
  crystals(g) {
    const c = mat(0xf0c8ff, { rough: 0.1, emissive: 0x8a4ad0, glow: 0.6, flat: true });
    for (let i = 0; i < 7; i++) { const h = 2 + (i % 3) * 2.2; const k = cone(0.6 + (i % 2) * 0.3, h, c, Math.cos(i * 2.4) * 1.8, h / 2, Math.sin(i * 2.4) * 1.8, g, 6); k.rotation.set((i % 3 - 1) * 0.2, i, (i % 2 - 0.5) * 0.3); }
  },
  pyramid(g) { // Beerus's temple
    const stone = mat(0xc8b48c, { rough: 0.7, flat: true }), purple = mat(0x6a3a9a, { rough: 0.5 });
    for (let i = 0; i < 4; i++) box(34 - i * 7, 5, 34 - i * 7, stone, 0, 2.5 + i * 5, 0, g);
    cyl(2, 2.4, 6, purple, 0, 23, 0, g, 16);
    sphere(2.6, mat(0xffe6a0, { emissive: 0xaa7a20, glow: 1.2 }), 0, 27.5, 0, g);
  },
  stands(g) {
    const seat = mat(0x8a8a90, { rough: 0.8 });
    for (let i = 0; i < 5; i++) box(40, 1, 3, seat, 0, i * 1.2 + 0.5, i * 3, g);
  },
  bunker(g) {
    const conc = mat(0x6a6a66, { rough: 0.9 });
    const b = sphere(5, conc, 0, 0, 0, g, 24, 12, Math.PI / 2); b.scale.set(1, 0.5, 1);
    box(2, 2, 2, mat(0x3a3a3a), 0, 1, 4.4, g);
  },
  pillar(g) { // Tournament of Power stage pillar
    const stone = mat(0xbab4c8, { rough: 0.6 }), glow = mat(0x9a8aff, { emissive: 0x5a4ad0, glow: 1.4 });
    cyl(2.2, 2.6, 22, stone, 0, 11, 0, g, 12);
    torus(2.5, 0.25, glow, 0, 16, 0, g).rotation.x = Math.PI / 2;
    torus(2.5, 0.25, glow, 0, 6, 0, g).rotation.x = Math.PI / 2;
  },
  zenobox(g) { // Grand Zeno's floating viewing stand
    const gold = mat(0xd8c070, { metal: 0.7, rough: 0.3 }), white = mat(0xf2f0ff, { rough: 0.3 });
    const p = cyl(12, 9, 3, white, 0, 26, 0, g, 36);
    torus(12, 0.6, gold, 0, 27.5, 0, g).rotation.x = Math.PI / 2;
    cone(1.2, 24, white, 0, 12, 0, g, 12).rotation.x = Math.PI;
    p.castShadow = false;
  },
  hangar(g) { // Red Ribbon base buildings
    const wall = mat(0xa8a49a, { rough: 0.8 }), red = mat(0xb8322a, { rough: 0.6 });
    box(30, 10, 20, wall, 0, 5, 0, g);
    const roof = cyl(10, 10, 30, wall, 0, 10, 0, g, 24); roof.rotation.z = Math.PI / 2; roof.scale.set(1, 1, 0.5);
    box(30.2, 1.6, 0.2, red, 0, 7, 10.1, g);
    box(10, 7, 0.3, mat(0x4a4a48, { metal: 0.6 }), 0, 3.5, 10.2, g);
  },
  radartower(g) {
    const steel = mat(0x8a8a8a, { metal: 0.8, rough: 0.4 });
    cyl(0.5, 0.9, 24, steel, 0, 12, 0, g, 8);
    const dish = sphere(3, steel, 0, 25, 0, g, 24, 10, Math.PI / 3); dish.rotation.x = 2.4;
  },
};

function mulberry(seed) {
  let s = seed | 0;
  return () => { s = (s + 0x6d2b79f5) | 0; let t = Math.imul(s ^ (s >>> 15), 1 | s); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}

export function buildLandmarks(zone, scene, quality) {
  disposables.clear();
  const group = new THREE.Group();
  for (const l of zone.landmarks) {
    const make = BUILD[l.type];
    if (!make) continue;
    const g = new THREE.Group();
    const y = l.dig ? zone.heightAt(l.x, l.z) : l.flatten ? l.base : zone.heightAt(l.x, l.z);
    g.position.set(l.x, y, l.z);
    g.rotation.y = l.rot || 0;
    g.scale.setScalar(l.scale || 1);
    make(g, zone, l);
    g.traverse((o) => { if (o.isMesh) { o.castShadow = quality.shadows && o.castShadow; } });
    group.add(g);
  }
  scene.add(group);
  const owned = [...disposables];
  return {
    object3d: group,
    dispose() { scene.remove(group); owned.forEach((d) => d.dispose()); },
  };
}
