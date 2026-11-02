// Copied from Cage Career 3D (web/kit3d.js) so Dragon Legend's fighters use the same model. Keep in sync by hand.
// Fight-kit and street-cloth designs. A design is painted once into a small canvas and wrapped
// around the cloth with a cylindrical UV, so the same colour can be a plain kit or a printed one:
// side panels, half-and-half, pinstripes, camo, stars, flames, tiger stripes, checker, chevrons.
import * as THREE from "three";

// Index 0 must stay "Plain": looks saved before designs existed decode to it.
export const KIT_NAMES = ["Plain", "Side stripe", "Split", "Pinstripe", "Camo", "Stars", "Flames", "Tiger", "Checker", "Chevron"];

const SIZE = 128;
const cache = new Map();

function toRgb(hex) {
  const h = String(hex || "#888888").trim().replace("#", "");
  const s = h.length === 3 ? h.split("").map((c) => c + c).join("") : h.padEnd(6, "8").slice(0, 6);
  const n = parseInt(s, 16);
  return Number.isFinite(n) ? [(n >> 16) & 255, (n >> 8) & 255, n & 255] : [136, 136, 136];
}
const rgb = ([r, g, b]) => `rgb(${Math.round(r)},${Math.round(g)},${Math.round(b)})`;

/** A shade of the given colour: k < 0 darkens toward black, k > 0 lightens toward white. */
function shade(color, k) {
  const [r, g, b] = toRgb(color);
  const f = (v) => (k < 0 ? v * (1 + k) : v + (255 - v) * k);
  return rgb([f(r), f(g), f(b)]);
}

/** The print colour: light on dark kits, dark on light ones, so a design never disappears. */
export function kitAccent(base) {
  const [r, g, b] = toRgb(base);
  const lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return lum > 0.58 ? "#141414" : "#f5f5f5";
}

function starPath(g, cx, cy, r) {
  g.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    const k = i % 2 ? r * 0.42 : r;
    const x = cx + Math.cos(a) * k, y = cy + Math.sin(a) * k;
    if (i) g.lineTo(x, y); else g.moveTo(x, y);
  }
  g.closePath();
  g.fill();
}

/** Paints one design over the whole canvas. Pure drawing: no lights, no image loads. */
export function paintKit(g, design, base) {
  const W = SIZE, H = SIZE;
  const name = KIT_NAMES[Number(design) || 0] || "Plain";
  const A = kitAccent(base);
  g.save();
  g.fillStyle = base;
  g.fillRect(0, 0, W, H);
  const seam = shade(base, -0.5);
  // copies near the wrap seam, so a shape that crosses the back is not cut in half
  const wrap = (x, draw) => { draw(x); draw(x - W); draw(x + W); };
  let seed = 20261030;
  const rnd = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 4294967296);

  if (name === "Side stripe") {
    // a wide panel down each outside seam with a thin line in front of it
    for (const x of [0.25 * W, 0.75 * W]) {
      g.fillStyle = A;
      g.fillRect(x - 5, 0, 10, H);
      g.globalAlpha = 0.55;
      g.fillRect(x - 10, 0, 2, H);
      g.fillRect(x + 8, 0, 2, H);
      g.globalAlpha = 1;
    }
  } else if (name === "Split") {
    // one leg in the print, one in the base colour; the seams sit on the outside of each leg,
    // where the wrap is clean, instead of through the crotch where the UV pinches
    g.fillStyle = A;
    g.fillRect(0, 0, W / 4, H);
    g.fillRect((3 * W) / 4, 0, W / 4, H);
    g.fillStyle = seam;
    g.fillRect(W / 4, 0, 1.5, H);
    g.fillRect((3 * W) / 4, 0, 1.5, H);
  } else if (name === "Pinstripe") {
    g.fillStyle = A;
    for (let x = 0; x < W; x += 8) g.fillRect(x, 0, 1.6, H);
  } else if (name === "Camo") {
    const blobs = (count, color, lo, hi) => {
      g.fillStyle = color;
      for (let i = 0; i < count; i++) {
        const x = rnd() * W, y = rnd() * H, rx = lo + rnd() * (hi - lo), ry = rx * (0.5 + rnd() * 0.5);
        wrap(x, (px) => { g.beginPath(); g.ellipse(px, y, rx, ry, rnd() * Math.PI, 0, Math.PI * 2); g.fill(); });
      }
    };
    blobs(12, shade(base, -0.3), 7, 17);
    blobs(10, shade(base, 0.24), 5, 12);
    blobs(7, shade(base, -0.52), 4, 9);
    // a few contrasting patches, so the pattern still reads on a light or very dark kit
    g.globalAlpha = 0.42;
    blobs(6, A, 4, 10);
    g.globalAlpha = 1;
  } else if (name === "Stars") {
    g.fillStyle = A;
    for (let i = 0; i < 8; i++) {
      const x = (i + 0.5) * (W / 8) + (rnd() - 0.5) * 5, y = 12 + rnd() * (H - 24), r = 4 + rnd() * 5;
      wrap(x, (px) => starPath(g, px, y, r));
    }
    g.fillStyle = shade(base, 0.45);
    for (let i = 0; i < 6; i++) wrap(rnd() * W, (px) => starPath(g, px, rnd() * H, 1.6 + rnd() * 1.6));
  } else if (name === "Flames") {
    // tongues licking up from the hem, with a brighter core inside each one
    for (let x = -6; x < W + 6; x += 11) {
      const h = 26 + rnd() * 34;
      g.fillStyle = A;
      g.beginPath();
      g.moveTo(x - 6, H);
      g.bezierCurveTo(x - 7, H - h * 0.5, x - 2, H - h * 0.78, x + rnd() * 3, H - h);
      g.bezierCurveTo(x + 3, H - h * 0.72, x + 7, H - h * 0.45, x + 6, H);
      g.closePath();
      g.fill();
      g.fillStyle = shade(base, 0.3);
      g.beginPath();
      g.moveTo(x - 2, H);
      g.bezierCurveTo(x - 2, H - h * 0.4, x + 1, H - h * 0.55, x + 1, H - h * 0.66);
      g.bezierCurveTo(x + 3, H - h * 0.5, x + 3, H - h * 0.35, x + 3, H);
      g.closePath();
      g.fill();
    }
  } else if (name === "Tiger") {
    g.strokeStyle = A;
    g.lineCap = "round";
    g.lineWidth = 6;
    for (let row = 0; row < 4; row++) {
      const y = H * (0.17 + row * 0.22);
      g.beginPath();
      g.moveTo(-12, y);
      for (let x = -12; x <= W + 12; x += 6) g.lineTo(x, y + Math.sin((x / W) * Math.PI * 4 + row * 1.7) * 5);
      g.stroke();
    }
    g.lineWidth = 2;
    g.globalAlpha = 0.7;
    for (let row = 0; row < 10; row++) {
      const y = H * (0.05 + row * 0.1);
      g.beginPath();
      g.moveTo(0, y);
      g.lineTo(W, y + Math.sin(row * 2.1) * 4);
      g.stroke();
    }
    g.globalAlpha = 1;
  } else if (name === "Checker") {
    const cw = W / 8, ch = H / 10;
    for (let r = 0; r < 10; r++) for (let c = 0; c < 8; c++) {
      if ((r + c) % 2) continue;
      g.fillStyle = (r + c) % 4 === 0 ? A : shade(base, -0.25);
      g.fillRect(c * cw, r * ch, cw, ch);
    }
  } else if (name === "Chevron") {
    g.strokeStyle = A;
    g.lineJoin = "miter";
    g.lineWidth = 7;
    for (let i = 0; i < 5; i++) {
      const y = H - 14 - i * 24;
      g.beginPath();
      g.moveTo(-4, y - 15);
      g.lineTo(W / 2, y);
      g.lineTo(W + 4, y - 15);
      g.stroke();
    }
    g.lineWidth = 2;
    g.globalAlpha = 0.6;
    for (let i = 0; i < 5; i++) {
      const y = H - 22 - i * 24;
      g.beginPath();
      g.moveTo(-4, y - 15);
      g.lineTo(W / 2, y);
      g.lineTo(W + 4, y - 15);
      g.stroke();
    }
    g.globalAlpha = 1;
  }
  g.restore();
}

/**
 * The map for a design at a colour, or null for a plain kit. Textures are shared per design and
 * colour: the geometry is shared across fighters, so nothing here is owned by one of them.
 */
export function kitTexture(design, base) {
  const i = Math.min(Math.max(Number(design) || 0, 0), KIT_NAMES.length - 1);
  if (i === 0 || typeof document === "undefined") return null;
  const color = String(base || "#888888");
  const key = i + "|" + color.toLowerCase();
  if (cache.has(key)) return cache.get(key);
  const c = document.createElement("canvas");
  c.width = c.height = SIZE;
  const g = c.getContext && c.getContext("2d");
  if (!g) return null;
  paintKit(g, i, color);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  cache.set(key, t);
  return t;
}

/** How many maps have been painted (the check uses it to prove the cache works). */
export function kitTextureCount() {
  return cache.size;
}

/**
 * Cylindrical UVs for a garment: u wraps around the body (0.5 at the front, 0 at the back),
 * v runs from the hem (0) to the waist (1). Shared geometry, so this is added once and never
 * depends on the fighter wearing it.
 */
export function addCylinderUV(geometry) {
  if (!geometry || !geometry.getAttribute || geometry.getAttribute("uv")) return geometry;
  const p = geometry.getAttribute("position");
  if (!p || !p.count) return geometry;
  let lo = Infinity, hi = -Infinity;
  for (let i = 0; i < p.count; i++) {
    const y = p.getY(i);
    if (y < lo) lo = y;
    if (y > hi) hi = y;
  }
  const span = Math.max(hi - lo, 1e-4);
  const uv = new Float32Array(p.count * 2);
  for (let i = 0; i < p.count; i++) {
    uv[i * 2] = 0.5 + Math.atan2(p.getX(i), p.getZ(i)) / (Math.PI * 2);
    uv[i * 2 + 1] = (p.getY(i) - lo) / span;
  }
  geometry.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  return geometry;
}
