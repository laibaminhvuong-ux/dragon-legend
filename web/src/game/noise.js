// Seeded 2D gradient noise + fractal helpers. Pure and deterministic, so gameplay (ground height,
// prop placement) and rendering (terrain mesh, textures) always agree. Output of noise2 is about -1..1.

/** Mulberry32 random: returns () => [0, 1). */
export function rng(seed) {
  let s = seed | 0;
  return () => {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Makes a gradient-noise function. With `period` set, noise repeats every `period` units (tileable textures). */
export function makeNoise2(seed = 1, period = 0) {
  const r = rng(seed);
  const perm = new Uint8Array(512);
  const p = Array.from({ length: 256 }, (_, i) => i);
  for (let i = 255; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [p[i], p[j]] = [p[j], p[i]]; }
  for (let i = 0; i < 512; i++) perm[i] = p[i & 255];
  const gx = new Float32Array(256), gy = new Float32Array(256);
  for (let i = 0; i < 256; i++) { const a = r() * Math.PI * 2; gx[i] = Math.cos(a); gy[i] = Math.sin(a); }
  const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
  const wrap = period > 0 ? (v) => ((v % period) + period) % period : (v) => v;

  return function noise2(x, y) {
    const xf = Math.floor(x), yf = Math.floor(y);
    const tx = x - xf, ty = y - yf;
    const x0 = wrap(xf) & 255, y0 = wrap(yf) & 255, x1 = wrap(xf + 1) & 255, y1 = wrap(yf + 1) & 255;
    const h00 = perm[perm[x0] + y0], h10 = perm[perm[x1] + y0], h01 = perm[perm[x0] + y1], h11 = perm[perm[x1] + y1];
    const d00 = gx[h00] * tx + gy[h00] * ty;
    const d10 = gx[h10] * (tx - 1) + gy[h10] * ty;
    const d01 = gx[h01] * tx + gy[h01] * (ty - 1);
    const d11 = gx[h11] * (tx - 1) + gy[h11] * (ty - 1);
    const u = fade(tx), v = fade(ty);
    return 1.414 * ((d00 + (d10 - d00) * u) + ((d01 + (d11 - d01) * u) - (d00 + (d10 - d00) * u)) * v);
  };
}

/** Fractal sum of `octaves` layers (each double frequency, `gain` amplitude). About -1..1. */
export function fbm(noise, x, y, octaves = 5, lacunarity = 2, gain = 0.5) {
  let sum = 0, amp = 1, norm = 0, f = 1;
  for (let i = 0; i < octaves; i++) {
    sum += noise(x * f, y * f) * amp;
    norm += amp;
    amp *= gain;
    f *= lacunarity;
  }
  return sum / norm;
}

/** Ridged fractal (sharp mountain crests). About 0..1. */
export function ridged(noise, x, y, octaves = 5) {
  let sum = 0, amp = 0.5, f = 1, prev = 1;
  for (let i = 0; i < octaves; i++) {
    let n = 1 - Math.abs(noise(x * f, y * f));
    n *= n;
    sum += n * amp * prev;
    prev = n;
    amp *= 0.5;
    f *= 2;
  }
  return sum;
}

export const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
export const lerp = (a, b, t) => a + (b - a) * t;
