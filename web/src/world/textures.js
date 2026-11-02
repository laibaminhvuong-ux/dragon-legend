// Procedural textures, generated at startup (no image files): tileable ground albedos, detail
// normal maps, bark, leaf clusters, water ripples and the zone map the terrain shader reads.
import * as THREE from "three";
import { makeNoise2, smoothstep, rng } from "../game/noise.js";

/** Tileable fractal noise sampler: f(u, v) with u, v in [0, 1) -> about -1..1. */
function tileFbm(seed, cells, octaves = 5, gain = 0.5) {
  const layers = [];
  for (let i = 0; i < octaves; i++) layers.push(makeNoise2(seed + i * 101, cells << i));
  return (u, v) => {
    let s = 0, a = 1, n = 0;
    for (let i = 0; i < octaves; i++) {
      const f = cells << i;
      s += layers[i](u * f, v * f) * a;
      n += a;
      a *= gain;
    }
    return s / n;
  };
}

function dataTexture(size, fill, { srgb = true, repeat = true } = {}) {
  const data = new Uint8Array(size * size * 4);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const o = (y * size + x) * 4;
    const c = fill(x / size, y / size, x, y);
    data[o] = c[0]; data[o + 1] = c[1]; data[o + 2] = c[2]; data[o + 3] = c[3] ?? 255;
  }
  const t = new THREE.DataTexture(data, size, size, THREE.RGBAFormat);
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.magFilter = THREE.LinearFilter;
  t.minFilter = THREE.LinearMipmapLinearFilter;
  t.generateMipmaps = true;
  t.anisotropy = 8;
  t.needsUpdate = true;
  return t;
}

const b = (v) => Math.max(0, Math.min(255, Math.round(v * 255)));
const mix = (a, c, t) => [a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t];

/** Normal map from a tileable height function h(u, v); strength scales the bumps. */
function normalTexture(size, h, strength) {
  const heights = new Float32Array(size * size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) heights[y * size + x] = h(x / size, y / size);
  const at = (x, y) => heights[((y + size) % size) * size + ((x + size) % size)];
  return dataTexture(size, (u, v, x, y) => {
    const dx = (at(x + 1, y) - at(x - 1, y)) * strength;
    const dy = (at(x, y + 1) - at(x, y - 1)) * strength;
    const l = Math.hypot(dx, dy, 1);
    return [b((-dx / l) * 0.5 + 0.5), b((-dy / l) * 0.5 + 0.5), b(1 / l * 0.5 + 0.5)];
  }, { srgb: false });
}

export function createTextures(zone, { size = 512 } = {}) {
  const n1 = tileFbm(1, 8), n2 = tileFbm(2, 32, 3), n3 = tileFbm(3, 4, 4), n4 = tileFbm(4, 64, 2);
  const r = rng(99);

  // grass seen from above: mottled greens with dry yellow streaks and dark gaps
  const grassSpots = new Float32Array(size * size);
  for (let i = 0; i < size * 40; i++) {
    const x = Math.floor(r() * size), y = Math.floor(r() * size), len = 2 + Math.floor(r() * 6), dir = r() * Math.PI;
    for (let k = 0; k < len; k++) {
      const px = (x + Math.round(Math.cos(dir) * k) + size) % size, py = (y + Math.round(Math.sin(dir) * k) + size) % size;
      grassSpots[py * size + px] = r() < 0.5 ? 1 : -1;
    }
  }
  const grass = dataTexture(size, (u, v, x, y) => {
    const m = n1(u, v) * 0.5 + 0.5, f = n2(u, v);
    let c = mix([0.16, 0.27, 0.07], [0.33, 0.42, 0.12], smoothstep(0.25, 0.75, m));
    c = mix(c, [0.45, 0.45, 0.2], smoothstep(0.3, 0.7, n3(u, v)) * 0.35);
    const s = grassSpots[y * size + x];
    const k = 0.85 + f * 0.25 + (s > 0 ? 0.18 : s < 0 ? -0.22 : 0);
    return [b(c[0] * k), b(c[1] * k), b(c[2] * k)];
  });

  // dirt: brown earth with pebbles
  const pebbles = new Float32Array(size * size);
  for (let i = 0; i < 900; i++) {
    const cx = r() * size, cy = r() * size, rad = 1 + r() * 3.5, tone = r();
    for (let y = Math.floor(cy - rad); y <= cy + rad; y++) for (let x = Math.floor(cx - rad); x <= cx + rad; x++) {
      const d = Math.hypot(x - cx, y - cy) / rad;
      if (d < 1) pebbles[((y + size) % size) * size + ((x + size) % size)] = (1 - d * d) * (0.5 + tone);
    }
  }
  const dirt = dataTexture(size, (u, v, x, y) => {
    const m = n1(u + 0.3, v) * 0.5 + 0.5, f = n2(u, v + 0.5);
    let c = mix([0.30, 0.22, 0.15], [0.46, 0.36, 0.25], m);
    const p = pebbles[y * size + x];
    if (p > 0) c = mix(c, [0.55 * (0.7 + p * 0.3), 0.5 * (0.7 + p * 0.3), 0.45 * (0.7 + p * 0.3)], Math.min(1, p * 1.5));
    const k = 0.88 + f * 0.18;
    return [b(c[0] * k), b(c[1] * k), b(c[2] * k)];
  });

  // rock: sandstone strata (bands run along v), cracks and grain
  const rock = dataTexture(size, (u, v) => {
    const warp = n3(u, v) * 0.08;
    const band = Math.sin((v + warp * 2.5) * Math.PI * 2 * 4) * 0.5 + 0.5;
    const band2 = Math.sin((v + warp * 4) * Math.PI * 2 * 11) * 0.5 + 0.5;
    let c = mix([0.44, 0.37, 0.31], [0.58, 0.49, 0.4], band * 0.6 + band2 * 0.2 + n1(u, v) * 0.2);
    c = mix(c, [0.4, 0.39, 0.37], smoothstep(0.0, 0.6, n3(u * 2, v * 2)) * 0.6);
    const crack = smoothstep(0.03, 0.0, Math.abs(n2(u * 0.5, v))) * 0.5;
    const k = (0.85 + n4(u, v) * 0.2) * (1 - crack);
    return [b(c[0] * k), b(c[1] * k), b(c[2] * k)];
  });

  const sand = dataTexture(size, (u, v) => {
    const k = 0.9 + n4(u, v) * 0.12 + n1(u, v) * 0.06;
    return [b(0.66 * k), b(0.58 * k), b(0.44 * k)];
  });

  const groundNormal = normalTexture(size, (u, v) => n2(u, v) * 0.6 + n4(u, v) * 0.4 + Math.max(0, n1(u, v)) * 0.5, 2.2);
  const rockNormal = normalTexture(size, (u, v) => {
    const warp = n3(u, v) * 0.08;
    return Math.abs(Math.sin((v + warp) * Math.PI * 2 * 9)) * 0.6 + n2(u, v) * 0.5 + n4(u, v) * 0.3;
  }, 3.5);

  // bark: vertical fissures
  const nb = tileFbm(7, 4, 4), nb2 = tileFbm(8, 16, 3);
  const barkH = (u, v) => Math.abs(nb(u * 1, v * 0.25)) * 0.8 + nb2(u, v * 0.3) * 0.3;
  const bark = dataTexture(256, (u, v) => {
    const h = barkH(u, v);
    const k = 0.7 + h * 0.6;
    return [b(0.46 * k), b(0.39 * k), b(0.31 * k)];
  });
  const barkNormal = normalTexture(256, barkH, 4);

  // water ripples (normal map for the lake)
  const nw = tileFbm(21, 8, 4), nw2 = tileFbm(22, 16, 3);
  const waterNormals = normalTexture(256, (u, v) => nw(u, v) * 0.6 + nw2(u, v) * 0.4, 3);

  // zone map: R = bare dirt, G = macro colour variation, B = near-lake (sand allowed)
  const zs = zone.size + 200;
  const zoneMap = dataTexture(256, (u, v) => {
    const x = (u - 0.5) * zs, z = (v - 0.5) * zs;
    const w = zone.water;
    const lake = w ? smoothstep(w.radius * 1.6, w.radius * 1.2, Math.hypot(x - w.x, z - w.z)) : 0;
    return [b(zone.dirtAt(x, z)), b(n3(u, v) * 0.5 + 0.5), b(lake)];
  }, { srgb: false, repeat: false });
  zoneMap.wrapS = zoneMap.wrapT = THREE.ClampToEdgeWrapping;

  const nc = tileFbm(31, 4, 6, 0.55);
  const cloudNoise = dataTexture(256, (u, v) => { const k = b(nc(u, v) * 0.5 + 0.5); return [k, k, k]; }, { srgb: false });

  return { cloudNoise, grass, dirt, rock, sand, groundNormal, rockNormal, bark, barkNormal, waterNormals, zoneMap, zoneMapSize: zs, leaves: leafTexture() };
}

/** Leaf cluster: dozens of leaves on a transparent background (alpha-tested). Canvas 2D. */
function leafTexture(size = 256) {
  const canvas = typeof OffscreenCanvas !== "undefined" ? new OffscreenCanvas(size, size) : Object.assign(document.createElement("canvas"), { width: size, height: size });
  const g = canvas.getContext("2d");
  const r = rng(5);
  for (let i = 0; i < 320; i++) {
    const a = r() * Math.PI * 2, d = Math.pow(r(), 0.6) * size * 0.42;
    const x = size / 2 + Math.cos(a) * d, y = size / 2 + Math.sin(a) * d;
    const len = size * (0.08 + r() * 0.06), w = len * 0.45;
    const light = 0.6 + r() * 0.5 - (d / size) * 0.3;
    g.save();
    g.translate(x, y);
    g.rotate(r() * Math.PI * 2);
    g.fillStyle = `rgb(${Math.round(78 * light)},${Math.round(124 * light)},${Math.round(40 * light)})`;
    g.beginPath();
    g.moveTo(0, -len / 2);
    g.quadraticCurveTo(w, 0, 0, len / 2);
    g.quadraticCurveTo(-w, 0, 0, -len / 2);
    g.fill();
    g.strokeStyle = `rgba(30,50,15,0.5)`;
    g.lineWidth = 1;
    g.beginPath(); g.moveTo(0, -len / 2); g.lineTo(0, len / 2); g.stroke();
    g.restore();
  }
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  return t;
}
