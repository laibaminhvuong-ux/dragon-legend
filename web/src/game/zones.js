// Zone layouts as pure data + functions, so gameplay (ground height, props to collide with) works
// without rendering and world/ draws exactly the same ground. Units: metres, Y up.
//
// A zone exposes:
//   id, name, size (play area, square, centred on 0,0), spawn {x, z}
//   heightAt(x, z)        ground height; valid outside the play area too (the far mountains)
//   normalAt(x, z)        ground normal {x, y, z}
//   water                 { x, z, radius, level } or null
//   surfaceAt(x, z)       "water" | "sand" | "rock" | "dirt" | "grass" | "snow"
//   dirtAt(x, z)          0..1 bare-earth amount (the terrain shader uses the same value)
//   props()               memoised { trees, rocks, bushes, stones, near(x, z, r) } (see placeProps)
import { makeNoise2, fbm, ridged, rng, smoothstep, lerp } from "./noise.js";

function makeTrainingPlains() {
  const nHills = makeNoise2(11), nDetail = makeNoise2(12), nWarp = makeNoise2(13), nRidge = makeNoise2(14);
  const nDirt = makeNoise2(15), nForest = makeNoise2(16), nShore = makeNoise2(17);
  const size = 640;
  const water = { x: -135, z: 125, radius: 58, level: 0.35 };
  // rock mesas (flat-topped buttes with layered cliffs): x, z, radius, height
  const mesas = [
    { x: 150, z: -70, r: 36, h: 32 }, { x: 225, z: 150, r: 52, h: 46 }, { x: -60, z: -215, r: 30, h: 26 },
    { x: -235, z: -95, r: 44, h: 40 }, { x: 70, z: 235, r: 24, h: 21 }, { x: 255, z: -225, r: 42, h: 58 },
    { x: -25, z: -120, r: 15, h: 15 }, { x: 95, z: 95, r: 11, h: 12 },
  ];

  function mesaHeight(m, x, z) {
    const dx = x - m.x, dz = z - m.z;
    const d = Math.hypot(dx, dz);
    if (d > m.r * 1.6) return 0;
    // jagged outline: broad lobes + gullies and buttresses
    const dw = d + fbm(nWarp, x / 28, z / 28, 3) * m.r * 0.24 + fbm(nDetail, x / 7, z / 7, 3) * m.r * 0.06;
    const s = smoothstep(m.r, m.r * 0.82, dw);
    // ledges: layered strata instead of a smooth wall
    const t = s * 6;
    const steps = (Math.floor(t) + smoothstep(0.25, 0.75, t - Math.floor(t))) / 6;
    const skirt = smoothstep(m.r * 1.55, m.r, dw) * 0.16; // talus slope at the foot
    const top = s > 0.999 ? fbm(nDetail, x / 18, z / 18, 2) * 1.1 : 0;
    return m.h * Math.max(steps, skirt * (1 - s) + steps) + top;
  }

  function heightAt(x, z) {
    let h = fbm(nHills, x / 230, z / 230, 5) * 17 + fbm(nDetail, x / 42, z / 42, 3) * 1.8;
    // flat training ground around spawn
    h *= smoothstep(28, 95, Math.hypot(x, z));
    // lake: level the rim, then dig an irregular shallow basin
    const dl = Math.hypot(x - water.x, z - water.z);
    if (dl < water.radius * 2.2) {
      h = lerp(h, 1.6, smoothstep(water.radius * 2.2, water.radius * 1.15, dl));
      const dw = dl + fbm(nShore, x / 24, z / 24, 3) * water.radius * 0.22;
      h -= 2.9 * smoothstep(water.radius * 1.05, water.radius * 0.3, dw);
    }
    for (const m of mesas) h += mesaHeight(m, x, z);
    // mountain ring at the edge of the play area, rising into the far ranges
    const e = Math.max(Math.abs(x), Math.abs(z)) / (size / 2);
    if (e > 0.78) {
      // domain-warped ridges: broad ranges with separate peaks and valleys between them
      const wx = x + fbm(nWarp, x / 420, z / 420, 3) * 140, wz = z + fbm(nWarp, x / 420 + 7.3, z / 420 + 3.1, 3) * 140;
      const r1 = ridged(nRidge, wx / 560, wz / 560, 4);
      const foothills = smoothstep(0.78, 1.1, e) * (12 + r1 * 80 + fbm(nDetail, x / 60, z / 60, 3) * 6);
      const ranges = smoothstep(1.0, 3.4, e) * (45 + r1 * r1 * 330 + fbm(nHills, x / 300, z / 300, 4) * 40);
      h += foothills + ranges;
    }
    return h;
  }

  function normalAt(x, z) {
    const e = 0.6;
    const nx = heightAt(x - e, z) - heightAt(x + e, z);
    const nz = heightAt(x, z - e) - heightAt(x, z + e);
    const ny = 2 * e;
    const l = Math.hypot(nx, ny, nz);
    return { x: nx / l, y: ny / l, z: nz / l };
  }

  const dirtAt = (x, z) => smoothstep(0.04, 0.32, fbm(nDirt, x / 55, z / 55, 4));

  function surfaceAt(x, z) {
    const h = heightAt(x, z);
    if (h < water.level - 0.02 && Math.hypot(x - water.x, z - water.z) < water.radius * 1.4) return "water";
    if (h < water.level + 0.7 && Math.hypot(x - water.x, z - water.z) < water.radius * 1.5) return "sand";
    const n = normalAt(x, z);
    if (h > 135 + fbm(nDetail, x / 40, z / 40, 2) * 20 && n.y > 0.6) return "snow";
    if (n.y < 0.78) return "rock";
    return dirtAt(x, z) > 0.55 ? "dirt" : "grass";
  }

  const forestAt = (x, z) => fbm(nForest, x / 95, z / 95, 3);

  let propsCache = null;
  const zone = {
    id: "test",
    name: "Training Plains",
    size,
    spawn: { x: 0, z: 0 },
    water,
    mesas,
    heightAt,
    normalAt,
    surfaceAt,
    dirtAt,
    forestAt,
    props() { return (propsCache ||= placeProps(zone)); },
  };
  return zone;
}

/**
 * Deterministic prop placement (same every run, same for game and renderer).
 * trees  [{ x, y, z, scale, rot, variant }]          collide: trunk radius 0.35 * scale
 * rocks  [{ x, y, z, scale, rx, ry, rz, variant }]    collide when scale >= 0.6: radius 0.8 * scale, top y + 1.1 * scale
 * bushes [{ x, y, z, scale, rot }]                    no collision
 * stones [{ x, y, z, scale, rx, ry, rz, variant }]    pebbles, no collision
 * near(x, z, r) -> colliders within r: [{ x, z, radius, top }]
 */
function placeProps(zone) {
  const r = rng(4242);
  const half = zone.size / 2 - 12;
  const trees = [], rocks = [], bushes = [], stones = [];
  const pick = () => ({ x: (r() * 2 - 1) * half, z: (r() * 2 - 1) * half });
  const awayFromSpawn = (p, d) => Math.hypot(p.x - zone.spawn.x, p.z - zone.spawn.z) > d;

  for (let tries = 0; trees.length < 340 && tries < 20000; tries++) {
    const p = pick();
    if (!awayFromSpawn(p, 22)) continue;
    const f = zone.forestAt(p.x, p.z);
    if (f < -0.02 && r() > 0.06) continue; // groves, with the odd lone tree
    if (zone.surfaceAt(p.x, p.z) !== "grass") continue;
    if (zone.normalAt(p.x, p.z).y < 0.9) continue;
    if (trees.some((t) => (t.x - p.x) ** 2 + (t.z - p.z) ** 2 < 36)) continue;
    const scale = 0.8 + r() * 0.65;
    trees.push({ x: p.x, y: zone.heightAt(p.x, p.z), z: p.z, scale, rot: r() * Math.PI * 2, variant: Math.floor(r() * 4) });
  }
  for (let tries = 0; rocks.length < 230 && tries < 20000; tries++) {
    const p = pick();
    if (!awayFromSpawn(p, 16)) continue;
    const s = zone.surfaceAt(p.x, p.z);
    if (s === "water" || s === "snow") continue;
    const nearMesa = zone.mesas.some((m) => Math.abs(Math.hypot(p.x - m.x, p.z - m.z) - m.r * 1.15) < m.r * 0.35);
    if (!nearMesa && s !== "rock" && r() > 0.35) continue; // boulders gather under cliffs
    const scale = (nearMesa ? 0.7 : 0.35) + Math.pow(r(), 2) * (nearMesa ? 3.2 : 1.8);
    rocks.push({ x: p.x, y: zone.heightAt(p.x, p.z) - scale * 0.25, z: p.z, scale, rx: r() * 6.3, ry: r() * 6.3, rz: r() * 0.4, variant: Math.floor(r() * 5) });
  }
  for (let tries = 0; bushes.length < 520 && tries < 20000; tries++) {
    const t = trees[Math.floor(r() * trees.length)];
    const p = r() < 0.7 && t ? { x: t.x + (r() * 2 - 1) * 9, z: t.z + (r() * 2 - 1) * 9 } : pick();
    if (Math.abs(p.x) > half || Math.abs(p.z) > half || !awayFromSpawn(p, 14)) continue;
    if (zone.surfaceAt(p.x, p.z) !== "grass") continue;
    bushes.push({ x: p.x, y: zone.heightAt(p.x, p.z), z: p.z, scale: 0.6 + r() * 0.9, rot: r() * 6.3 });
  }
  for (let tries = 0; stones.length < 1400 && tries < 30000; tries++) {
    const p = pick();
    const s = zone.surfaceAt(p.x, p.z);
    if (s === "water" || s === "snow" || (s === "grass" && r() > 0.3)) continue;
    stones.push({ x: p.x, y: zone.heightAt(p.x, p.z) - 0.03, z: p.z, scale: 0.08 + r() * 0.25, rx: r() * 6.3, ry: r() * 6.3, rz: r() * 6.3, variant: Math.floor(r() * 5) });
  }

  // collision grid
  const CELL = 16, grid = new Map();
  const add = (c) => {
    const k = Math.floor(c.x / CELL) + "," + Math.floor(c.z / CELL);
    if (!grid.has(k)) grid.set(k, []);
    grid.get(k).push(c);
  };
  for (const t of trees) add({ x: t.x, z: t.z, radius: 0.35 * t.scale, top: t.y + 14 * t.scale });
  for (const k of rocks) if (k.scale >= 0.6) add({ x: k.x, z: k.z, radius: 0.8 * k.scale, top: k.y + 1.1 * k.scale });

  function near(x, z, rad) {
    const out = [];
    const c0x = Math.floor((x - rad - 4) / CELL), c1x = Math.floor((x + rad + 4) / CELL);
    const c0z = Math.floor((z - rad - 4) / CELL), c1z = Math.floor((z + rad + 4) / CELL);
    for (let cx = c0x; cx <= c1x; cx++) for (let cz = c0z; cz <= c1z; cz++) {
      const list = grid.get(cx + "," + cz);
      if (list) for (const c of list) if (Math.hypot(c.x - x, c.z - z) < rad + c.radius) out.push(c);
    }
    return out;
  }
  return { trees, rocks, bushes, stones, near };
}

export const ZONES = { test: makeTrainingPlains() };

export function getZone(id) {
  return ZONES[id] || ZONES.test;
}
