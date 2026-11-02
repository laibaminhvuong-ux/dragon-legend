// Zones as pure data + functions, so gameplay (ground height, props to collide with) works
// without rendering and world/ draws exactly the same ground. Units: metres, Y up.
// Built from the recipes in data/zones.js.
//
// A zone exposes:
//   id, name, planet, saga, size (play area, square, centred on 0,0), spawn {x, z}, gravity (1 = normal)
//   heightAt(x, z)        ground height (void zones return far below killY off the edge)
//   normalAt(x, z)        ground normal {x, y, z}
//   water                 { x, z, radius, level, ocean } or null
//   killY                 falling below this respawns the player (void worlds), or null
//   surfaceAt(x, z)       "water" | "sand" | "rock" | "dirt" | "grass" | "snow" | "white" | "stone" | "void"
//   dirtAt(x, z)          0..1 bare-earth amount (the terrain shader uses the same value)
//   biome, landmarks, travelPoint, def
//   place(x, z)          story coordinates -> world coordinates (Snake Way measures x from the road)
//   props()               memoised { trees, rocks, bushes, stones, near(x, z, r) } (see placeProps)
import { makeNoise2, fbm, ridged, rng, smoothstep, lerp } from "./noise.js";
import { ZONE_DEFS } from "../data/zones.js";

const VOID = -400;

function makeZone(id, def) {
  const T = def.terrain;
  const seed = [...id].reduce((a, c) => (a * 31 + c.charCodeAt(0)) | 0, 7);
  // the original Training Plains seeds, so that world keeps its exact shape
  const s0 = id === "earth_plains" ? 11 : (seed & 0xffff) + 100;
  const nHills = makeNoise2(s0), nDetail = makeNoise2(s0 + 1), nWarp = makeNoise2(s0 + 2), nRidge = makeNoise2(s0 + 3);
  const nDirt = makeNoise2(s0 + 4), nForest = makeNoise2(s0 + 5), nShore = makeNoise2(s0 + 6);
  const size = T.size;
  const hills = T.hills === false ? null : { amp: 17, scale: 230, ...(T.hills || {}) };
  const flatSpawn = T.flatSpawn ?? 28;
  const mesas = T.mesas || [];
  const water = T.lake ? { ...T.lake, ocean: false } : T.ocean ? { x: 0, z: 0, radius: size * 4, level: T.ocean.level, ocean: true } : null;
  const ground = T.ground || "grass";

  function mesaHeight(m, x, z) {
    const d = Math.hypot(x - m.x, z - m.z);
    if (d > m.r * 1.6) return 0;
    // jagged outline: broad lobes + gullies and buttresses
    const dw = d + fbm(nWarp, x / 28, z / 28, 3) * m.r * 0.24 + fbm(nDetail, x / 7, z / 7, 3) * m.r * 0.06;
    const s = smoothstep(m.r, m.r * 0.82, dw);
    const t = s * 6;
    const steps = (Math.floor(t) + smoothstep(0.25, 0.75, t - Math.floor(t))) / 6;
    const skirt = smoothstep(m.r * 1.55, m.r, dw) * 0.16;
    const top = s > 0.999 ? fbm(nDetail, x / 18, z / 18, 2) * Math.min(1.1, m.r * 0.08) : 0;
    return m.h * Math.max(steps, skirt * (1 - s) + steps) + top;
  }

  function pathCentre(z) {
    const P = T.path;
    return Math.sin(z / P.wave) * P.amp + Math.sin(z / (P.wave * 0.37)) * P.amp * 0.18;
  }

  function rawHeight(x, z) {
    // Snake Way: a narrow winding road above the clouds
    if (T.path) {
      const P = T.path;
      if (z < P.from - 6 || z > P.to + 6) return VOID;
      const cx = pathCentre(z), slope = (pathCentre(z + 1) - pathCentre(z - 1)) / 2;
      const d = Math.abs(x - cx) / Math.sqrt(1 + slope * slope);
      if (d > P.width) return VOID;
      return 0.35 * Math.cos((d / P.width) * Math.PI * 0.5) + Math.sin(z * 0.05) * 0.4;
    }
    // King Kai's tiny planet: the cap of a small sphere
    if (T.planetoid) {
      const R = T.planetoid.radius, d = Math.hypot(x, z);
      if (d >= R) return VOID;
      return Math.sqrt(R * R - d * d) - R + fbm(nDetail, x / 9, z / 9, 2) * 0.25;
    }
    // floating platforms (Lookout, Tournament of Power)
    if (T.platform) {
      const P = T.platform, d = Math.hypot(x, z);
      const edge = P.broken ? P.radius * (0.92 + fbm(nWarp, x / 25, z / 25, 3) * 0.12) : P.radius;
      if (d > edge) return VOID;
      return P.height;
    }
    let h = hills ? fbm(nHills, x / hills.scale, z / hills.scale, 5) * hills.amp + fbm(nDetail, x / 42, z / 42, 3) * 1.8 * Math.min(1, hills.amp / 10) : 0;
    if (flatSpawn > 0) h *= smoothstep(flatSpawn, flatSpawn + 67, Math.hypot(x - T.spawn.x, z - T.spawn.z));
    // oceans with islands
    if (T.ocean) {
      let land = -14;
      for (const isl of T.islands || []) {
        const d = Math.hypot(x - isl.x, z - isl.z);
        if (d > isl.r * 1.5) continue;
        const dw = d + fbm(nShore, x / 30, z / 30, 3) * isl.r * 0.25;
        const k = smoothstep(isl.r * 1.15, isl.r * 0.55, dw);
        land = Math.max(land, lerp(-14, isl.h + Math.max(0, h * 0.5), k));
      }
      h = land;
    }
    if (T.lake) {
      const w = T.lake, dl = Math.hypot(x - w.x, z - w.z);
      if (dl < w.radius * 2.2) {
        h = lerp(h, 1.6, smoothstep(w.radius * 2.2, w.radius * 1.15, dl));
        const dw = dl + fbm(nShore, x / 24, z / 24, 3) * w.radius * 0.22;
        h -= 2.9 * smoothstep(w.radius * 1.05, w.radius * 0.3, dw);
      }
    }
    for (const m of mesas) h += mesaHeight(m, x, z);
    // mountain ring at the edge of the play area, rising into the far ranges
    if (T.edge === "mountains") {
      const e = Math.max(Math.abs(x), Math.abs(z)) / (size / 2);
      if (e > 0.78) {
        const wx = x + fbm(nWarp, x / 420, z / 420, 3) * 140, wz = z + fbm(nWarp, x / 420 + 7.3, z / 420 + 3.1, 3) * 140;
        const r1 = ridged(nRidge, wx / 560, wz / 560, 4);
        const foothills = smoothstep(0.78, 1.1, e) * (12 + r1 * 80 + fbm(nDetail, x / 60, z / 60, 3) * 6);
        const ranges = smoothstep(1.0, 3.4, e) * (45 + r1 * r1 * 330 + fbm(nHills, x / 300, z / 300, 4) * 40);
        h += foothills + ranges;
      }
    }
    return h;
  }

  // on Snake Way, things given at x = 0 sit on the road wherever it winds
  const onRoad = (p) => (T.path && p ? { ...p, x: p.x + pathCentre(p.z) } : p);
  // landmarks: level the ground under buildings, dig craters
  const landmarks = (def.landmarks || []).map((l) => onRoad({ scale: 1, rot: 0, ...l })).map((l) => ({ ...l, base: rawHeight(l.x, l.z) }));
  const shapers = landmarks.filter((l) => l.flatten || l.dig);
  const tp = onRoad(def.travelPoint);
  const spawn = onRoad(T.spawn);
  const tpBase = tp ? rawHeight(tp.x, tp.z) : 0;

  function heightAt(x, z) {
    let h = rawHeight(x, z);
    if (h <= VOID) return h;
    for (const l of shapers) {
      const d = Math.hypot(x - l.x, z - l.z);
      if (l.flatten && d < l.flatten * 1.7) h = lerp(h, l.base, smoothstep(l.flatten * 1.7, l.flatten, d));
      if (l.dig && d < l.dig.radius * 1.3) {
        const r = l.dig.radius;
        h += -l.dig.depth * smoothstep(r, 0, d) + smoothstep(r * 1.3, r, d) * smoothstep(r * 0.7, r, d) * l.dig.depth * 0.35;
      }
    }
    if (tp && !T.platform && !T.path && !T.planetoid) {
      const d = Math.hypot(x - tp.x, z - tp.z);
      if (d < 22) h = lerp(h, tpBase, smoothstep(22, 12, d));
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

  const dirtAt = ground === "dirt" ? (x, z) => 0.75 + 0.25 * smoothstep(-0.3, 0.3, fbm(nDirt, x / 55, z / 55, 4))
    : (x, z) => smoothstep(0.04, 0.32, fbm(nDirt, x / 55, z / 55, 4));
  const snowLine = def.biome.snowLine ?? 135;

  function surfaceAt(x, z) {
    const h = heightAt(x, z);
    if (h <= VOID + 1) return "void";
    if (water) {
      const nearWater = water.ocean || Math.hypot(x - water.x, z - water.z) < water.radius * 1.5;
      if (nearWater && h < water.level - 0.02) return "water";
      if (nearWater && h < water.level + 0.7) return "sand";
    }
    if (ground === "white" || ground === "stone") return ground;
    const n = normalAt(x, z);
    if (ground === "snow" || (h > snowLine + fbm(nDetail, x / 40, z / 40, 2) * 20 && n.y > 0.6)) return n.y < 0.78 ? "rock" : "snow";
    if (n.y < 0.78) return "rock";
    if (ground === "sand") return "sand";
    return dirtAt(x, z) > 0.55 ? "dirt" : "grass";
  }

  const forestAt = (x, z) => fbm(nForest, x / 95, z / 95, 3);

  let propsCache = null;
  const zone = {
    id,
    name: def.name,
    planet: def.planet,
    saga: def.saga,
    size,
    spawn: { x: spawn.x, z: spawn.z },
    gravity: T.gravity ?? 1,
    killY: T.killY ?? null,
    water,
    mesas,
    ground,
    biome: def.biome,
    landmarks,
    travelPoint: tp ? { ...tp, y: heightAt(tp.x, tp.z) } : null,
    def,
    seed: s0,
    /** Story coordinates -> world: on Snake Way, x is measured from the road's centre line. */
    place: (x, z) => (T.path ? { x: x + pathCentre(z), z } : { x, z }),
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
 * near(x, z, r) -> colliders within r: [{ x, z, radius, top }] (trees, boulders, landmarks)
 */
function placeProps(zone) {
  const B = zone.biome;
  const r = rng(zone.id === "earth_plains" ? 4242 : zone.seed * 7 + 1);
  const half = zone.size / 2 - 12;
  const trees = [], rocks = [], bushes = [], stones = [];
  const pick = () => ({ x: (r() * 2 - 1) * half, z: (r() * 2 - 1) * half });
  const clear = (p, d) => Math.hypot(p.x - zone.spawn.x, p.z - zone.spawn.z) > d
    && !(zone.travelPoint && Math.hypot(p.x - zone.travelPoint.x, p.z - zone.travelPoint.z) < 16)
    && !zone.landmarks.some((l) => Math.hypot(p.x - l.x, p.z - l.z) < (l.flatten || l.collide || 3) * 1.15 + 2);
  const treeCount = B.trees === "none" ? 0 : B.treeCount ?? 340;
  const lush = (s) => s === "grass" || (zone.ground === "sand" && s === "sand") || (zone.ground === "dirt" && s === "dirt") || (zone.ground === "stone" && s === "stone");
  const spread = treeCount < 20; // a handful of trees: no groves

  for (let tries = 0; trees.length < treeCount && tries < 20000; tries++) {
    const p = pick();
    if (!clear(p, spread ? 8 : 22)) continue;
    if (!spread && zone.forestAt(p.x, p.z) < -0.02 && r() > 0.06) continue;
    if (!lush(zone.surfaceAt(p.x, p.z))) continue;
    if (zone.normalAt(p.x, p.z).y < 0.9) continue;
    if (trees.some((t) => (t.x - p.x) ** 2 + (t.z - p.z) ** 2 < 36)) continue;
    const scale = 0.8 + r() * 0.65;
    trees.push({ x: p.x, y: zone.heightAt(p.x, p.z), z: p.z, scale, rot: r() * Math.PI * 2, variant: Math.floor(r() * 4) });
  }
  const rockCount = B.rocks ?? 230;
  for (let tries = 0; rocks.length < rockCount && tries < 20000; tries++) {
    const p = pick();
    if (!clear(p, 16)) continue;
    const s = zone.surfaceAt(p.x, p.z);
    if (s === "water" || s === "snow" && zone.ground !== "snow" || s === "void") continue;
    const nearMesa = zone.mesas.some((m) => Math.abs(Math.hypot(p.x - m.x, p.z - m.z) - m.r * 1.15) < m.r * 0.35);
    if (!nearMesa && s !== "rock" && r() > 0.35) continue;
    const scale = (nearMesa ? 0.7 : 0.35) + Math.pow(r(), 2) * (nearMesa ? 3.2 : 1.8);
    rocks.push({ x: p.x, y: zone.heightAt(p.x, p.z) - scale * 0.25, z: p.z, scale, rx: r() * 6.3, ry: r() * 6.3, rz: r() * 0.4, variant: Math.floor(r() * 5) });
  }
  const bushCount = B.bushes ?? 520;
  for (let tries = 0; bushes.length < bushCount && tries < 20000; tries++) {
    const t = trees[Math.floor(r() * trees.length)];
    const p = r() < 0.7 && t ? { x: t.x + (r() * 2 - 1) * 9, z: t.z + (r() * 2 - 1) * 9 } : pick();
    if (Math.abs(p.x) > half || Math.abs(p.z) > half || !clear(p, 14)) continue;
    if (!lush(zone.surfaceAt(p.x, p.z))) continue;
    bushes.push({ x: p.x, y: zone.heightAt(p.x, p.z), z: p.z, scale: 0.6 + r() * 0.9, rot: r() * 6.3 });
  }
  const stoneCount = B.stones ?? (zone.ground === "white" ? 0 : 1400);
  for (let tries = 0; stones.length < stoneCount && tries < 30000; tries++) {
    const p = pick();
    const s = zone.surfaceAt(p.x, p.z);
    if (s === "water" || s === "void" || s === "white" || (s === "grass" && r() > 0.3)) continue;
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
  for (const l of zone.landmarks) if (l.collide) add({ x: l.x, z: l.z, radius: l.collide * (l.scale || 1), top: zone.heightAt(l.x, l.z) + 12 * (l.scale || 1) });

  function near(x, z, rad) {
    const out = [];
    const reach = rad + 26;
    const c0x = Math.floor((x - reach) / CELL), c1x = Math.floor((x + reach) / CELL);
    const c0z = Math.floor((z - reach) / CELL), c1z = Math.floor((z + reach) / CELL);
    for (let cx = c0x; cx <= c1x; cx++) for (let cz = c0z; cz <= c1z; cz++) {
      const list = grid.get(cx + "," + cz);
      if (list) for (const c of list) if (Math.hypot(c.x - x, c.z - z) < rad + c.radius) out.push(c);
    }
    return out;
  }
  return { trees, rocks, bushes, stones, near };
}

export const ZONES = {};
for (const [id, def] of Object.entries(ZONE_DEFS)) ZONES[id] = makeZone(id, def);
// saves from before the story worlds used "test" for the Training Plains
ZONES.test = ZONES.earth_plains;

export function getZone(id) {
  return ZONES[id] || ZONES.earth_plains;
}
