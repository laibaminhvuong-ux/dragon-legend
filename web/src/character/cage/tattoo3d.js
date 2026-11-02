// Copied from Cage Career 3D (web/tattoo3d.js) so Dragon Legend's fighters use the same model. Keep in sync by hand.
// Tattoos: each area of the body (chest, back, arms, legs) gets a thin layer cut from the skin mesh,
// mapped flat (chest, back) or wrapped round (arms, legs), and painted with a design drawn on a canvas.
// The layer is skinned to the same skeleton, so ink stretches and moves with the muscle under it.
import * as THREE from "three";

export const TATTOO_DESIGNS = ["None", "Tribal", "Script", "Roses", "Dragon", "Skull", "Wings", "Stars"];
export const TATTOO_REGIONS = [
  { key: "tChest", name: "Chest" },
  { key: "tBack", name: "Back" },
  { key: "tArmL", name: "Left arm" },
  { key: "tArmR", name: "Right arm" },
  { key: "tLegs", name: "Leg" },
];

const INK = "rgba(22, 28, 44, 0.88)";

// ---------------------------------------------------------------- designs, drawn into a 512x512 tile
// wrap = true for arms and legs: x runs around the limb, y down it.

function tribal(g, wrap) {
  g.fillStyle = INK;
  const band = (y0, h) => {
    for (let i = 0; i < (wrap ? 6 : 4); i++) {
      const x0 = (i / (wrap ? 6 : 4)) * 512 + (wrap ? 0 : 40);
      g.beginPath();
      g.moveTo(x0, y0 + h * 0.5);
      g.bezierCurveTo(x0 + 40, y0 - h * 0.2, x0 + 70, y0 + h * 0.2, x0 + 120, y0);
      g.bezierCurveTo(x0 + 90, y0 + h * 0.45, x0 + 60, y0 + h * 0.7, x0 + 110, y0 + h);
      g.bezierCurveTo(x0 + 50, y0 + h * 0.8, x0 + 20, y0 + h * 0.75, x0, y0 + h * 0.5);
      g.fill();
    }
  };
  if (wrap) {
    band(60, 120);
    g.fillRect(0, 196, 512, 14);
    band(250, 90);
  } else {
    band(140, 230);
  }
}

function script(g, wrap, text) {
  g.fillStyle = INK;
  g.textAlign = "center";
  g.textBaseline = "middle";
  const t = String(text || "Warrior");
  if (wrap) {
    g.save();
    g.translate(256, 256);
    g.rotate(-Math.PI / 2);
    g.font = "italic bold 92px Georgia, serif";
    g.fillText(t, 0, 0, 470);
    g.restore();
  } else {
    g.font = "italic bold 96px Georgia, serif";
    g.fillText(t, 256, 230, 470);
    g.lineWidth = 6;
    g.strokeStyle = INK;
    g.beginPath();
    g.moveTo(90, 300);
    g.quadraticCurveTo(256, 340, 422, 300);
    g.stroke();
  }
}

function rose(g, x, y, r) {
  g.fillStyle = "rgba(170, 20, 40, 0.85)";
  g.beginPath();
  g.arc(x, y, r, 0, Math.PI * 2);
  g.fill();
  g.strokeStyle = INK;
  g.lineWidth = r * 0.12;
  g.beginPath();
  for (let a = 0; a < Math.PI * 6; a += 0.2) {
    const rr = (a / (Math.PI * 6)) * r * 0.9;
    g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr);
  }
  g.stroke();
  g.fillStyle = "rgba(30, 110, 50, 0.85)";
  for (const s of [-1, 1]) {
    g.beginPath();
    g.ellipse(x + s * r * 1.2, y + r * 0.6, r * 0.6, r * 0.25, s * 0.6, 0, Math.PI * 2);
    g.fill();
  }
}

function roses(g, wrap) {
  if (wrap) {
    rose(g, 130, 120, 55);
    rose(g, 360, 210, 65);
    rose(g, 200, 340, 50);
  } else {
    rose(g, 256, 230, 85);
    rose(g, 140, 300, 50);
    rose(g, 372, 300, 50);
  }
}

function dragon(g, wrap) {
  g.fillStyle = INK;
  const pts = [];
  for (let t = 0; t <= 1; t += 0.02) {
    const x = wrap ? 256 + Math.sin(t * Math.PI * 3) * 170 : 60 + t * 390;
    const y = wrap ? 30 + t * 430 : 256 + Math.sin(t * Math.PI * 2.5) * 110;
    pts.push([x, y, 34 * (1 - t * 0.7)]);
  }
  for (const [x, y, r] of pts) {
    g.beginPath();
    g.arc(x, y, r, 0, Math.PI * 2);
    g.fill();
  }
  g.fillStyle = "rgba(200, 40, 30, 0.8)";
  for (let i = 0; i < pts.length; i += 3) {
    const [x, y, r] = pts[i];
    g.beginPath();
    g.moveTo(x, y - r);
    g.lineTo(x + r * 0.6, y - r * 1.8);
    g.lineTo(x - r * 0.4, y - r * 0.9);
    g.fill();
  }
  // head with horns
  const [hx, hy] = pts[0];
  g.fillStyle = INK;
  g.beginPath();
  g.moveTo(hx - 70, hy);
  g.lineTo(hx + 30, hy - 40);
  g.lineTo(hx + 50, hy + 30);
  g.closePath();
  g.fill();
}

function skull(g, wrap) {
  const x = 256, y = wrap ? 230 : 240, r = wrap ? 120 : 130;
  g.fillStyle = INK;
  g.beginPath();
  g.arc(x, y, r, Math.PI, 0);
  g.lineTo(x + r * 0.75, y + r * 0.6);
  g.lineTo(x - r * 0.75, y + r * 0.6);
  g.closePath();
  g.fill();
  g.fillRect(x - r * 0.5, y + r * 0.55, r, r * 0.4);
  g.globalCompositeOperation = "destination-out";
  for (const s of [-1, 1]) {
    g.beginPath();
    g.ellipse(x + s * r * 0.38, y + r * 0.05, r * 0.25, r * 0.3, 0, 0, Math.PI * 2);
    g.fill();
  }
  g.beginPath();
  g.moveTo(x, y + r * 0.3);
  g.lineTo(x - r * 0.1, y + r * 0.5);
  g.lineTo(x + r * 0.1, y + r * 0.5);
  g.fill();
  for (let i = -2; i <= 2; i++) g.fillRect(x + i * r * 0.18 - 4, y + r * 0.65, 8, r * 0.28);
  g.globalCompositeOperation = "source-over";
}

function wings(g, wrap) {
  g.fillStyle = INK;
  const wing = (s) => {
    for (let i = 0; i < 7; i++) {
      g.beginPath();
      const len = 200 - i * 18, y = 150 + i * 30;
      g.ellipse(256 + s * (40 + len / 2), y, len / 2, 16, s * (0.25 - i * 0.06), 0, Math.PI * 2);
      g.fill();
    }
  };
  if (wrap) {
    g.save();
    g.scale(0.9, 1.3);
    wing(1);
    g.restore();
  } else {
    wing(-1);
    wing(1);
    g.beginPath();
    g.arc(256, 160, 26, 0, Math.PI * 2);
    g.fill();
  }
}

function star(g, x, y, r) {
  g.beginPath();
  for (let i = 0; i < 10; i++) {
    const a = (i / 10) * Math.PI * 2 - Math.PI / 2, rr = i % 2 ? r * 0.42 : r;
    g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr);
  }
  g.closePath();
  g.fill();
}

function stars(g, wrap) {
  g.fillStyle = INK;
  if (wrap) [[130, 100, 50], [360, 180, 40], [230, 300, 55], [400, 400, 35], [90, 420, 30]].forEach(([x, y, r]) => star(g, x, y, r));
  else {
    star(g, 150, 230, 70);
    star(g, 362, 230, 70);
  }
}

const DRAW = { Tribal: tribal, Script: script, Roses: roses, Dragon: dragon, Skull: skull, Wings: wings, Stars: stars };
const textures = new Map();

function designTexture(design, wrap, text) {
  const key = design + wrap + (design === "Script" ? text : "");
  if (textures.has(key)) return textures.get(key);
  const c = document.createElement("canvas");
  c.width = c.height = 512;
  const g = c.getContext("2d");
  DRAW[design](g, wrap, text);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  textures.set(key, t);
  return t;
}

// ---------------------------------------------------------------- the layers

const layerCache = new Map();

/**
 * A layer of the skin for one area, with texture coordinates for a design.
 * skinGeo: the body's skin geometry (bind pose). frame: bind-pose landmarks { chestY, width, axes: { armL: [from, to], ... } }.
 */
function layer(skinGeo, region, frame, cacheKey) {
  const key = cacheKey + region;
  if (layerCache.has(key)) return layerCache.get(key);
  const P = skinGeo.attributes.position, N = skinGeo.attributes.normal;
  const SI = skinGeo.attributes.skinIndex, SW = skinGeo.attributes.skinWeight;
  const idx = skinGeo.index.array;
  const n = P.count;
  const uv = new Float32Array(n * 2), inside = new Uint8Array(n);
  const p = new THREE.Vector3(), nm = new THREE.Vector3();
  // the dominant bone of each vertex (skeleton order: hips, spine, chest, neck, head, shL, elL, shR, elR, hipL, knL, hipR, knR)
  const bone = (v) => {
    let best = 0, bw = -1;
    for (let k = 0; k < 4; k++) if (SW.getComponent(v, k) > bw) {
      bw = SW.getComponent(v, k);
      best = SI.getComponent(v, k);
    }
    return best;
  };
  const wrapAxis = { tArmL: [5, 6], tArmR: [7, 8], tLegs: [9, 10] }[region];
  const [from, to] = wrapAxis ? frame.axes[region] : [];
  const axis = wrapAxis ? to.clone().sub(from) : null;
  const len = axis ? axis.length() : 1;
  if (axis) axis.normalize();
  const e1 = axis ? new THREE.Vector3().crossVectors(axis, new THREE.Vector3(0, 0, 1)).normalize() : null;
  const e2 = axis ? new THREE.Vector3().crossVectors(axis, e1) : null;
  const w = frame.width, cy = frame.chestY;
  for (let v = 0; v < n; v++) {
    p.fromBufferAttribute(P, v);
    nm.fromBufferAttribute(N, v);
    const b = bone(v);
    if (region === "tChest" || region === "tBack") {
      const front = region === "tChest";
      if (b > 2 || (front ? nm.z < 0.25 : nm.z > -0.25)) continue;
      const u = ((front ? p.x : -p.x) + 0.2 * w) / (0.4 * w), vv = (cy + 0.32 - p.y) / 0.44;
      if (u < 0 || u > 1 || vv < 0 || vv > 1) continue;
      uv[v * 2] = u;
      uv[v * 2 + 1] = 1 - vv;
      inside[v] = 1;
    } else {
      if (b !== wrapAxis[0] && b !== wrapAxis[1]) continue;
      const d = p.clone().sub(from);
      const t = d.dot(axis) / len;
      if (t < 0.08 || t > 0.98) continue;
      const a = Math.atan2(d.dot(e2), d.dot(e1));
      uv[v * 2] = a / (Math.PI * 2) + 0.5;
      uv[v * 2 + 1] = 1 - t;
      inside[v] = 1;
    }
  }
  // keep whole triangles inside the area, skipping the wrap-around seam
  const tri = [];
  for (let i = 0; i < idx.length; i += 3) {
    const a = idx[i], b = idx[i + 1], c = idx[i + 2];
    if (!inside[a] || !inside[b] || !inside[c]) continue;
    const us = [uv[a * 2], uv[b * 2], uv[c * 2]];
    if (Math.max(...us) - Math.min(...us) > 0.5) continue;
    tri.push(a, b, c);
  }
  const g = new THREE.BufferGeometry();
  const pos = new Float32Array(n * 3);
  for (let v = 0; v < n; v++) {
    // sit a hair above the skin
    pos[v * 3] = P.getX(v) + N.getX(v) * 0.0012;
    pos[v * 3 + 1] = P.getY(v) + N.getY(v) * 0.0012;
    pos[v * 3 + 2] = P.getZ(v) + N.getZ(v) * 0.0012;
  }
  g.setAttribute("position", new THREE.BufferAttribute(pos, 3));
  g.setAttribute("normal", N);
  g.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  g.setAttribute("skinIndex", SI);
  g.setAttribute("skinWeight", SW);
  g.setIndex(tri);
  layerCache.set(key, g);
  return g;
}

/** Adds the fighter's tattoos as skinned layers. look holds a design index per area. */
export function addTattoos({ root, skeleton, skinGeo, frame, look, text, cacheKey, envMap }) {
  const meshes = [];
  for (const r of TATTOO_REGIONS) {
    const design = TATTOO_DESIGNS[look[r.key] || 0];
    if (!design || design === "None") continue;
    const geo = layer(skinGeo, r.key, frame, cacheKey);
    if (!geo.index.count) continue;
    const wrap = r.key !== "tChest" && r.key !== "tBack";
    const m = new THREE.SkinnedMesh(geo, new THREE.MeshStandardMaterial({
      map: designTexture(design, wrap, text), transparent: true, depthWrite: false, roughness: 0.5, envMap, envMapIntensity: 0.3,
      polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2,
    }));
    m.frustumCulled = false;
    m.receiveShadow = true;
    root.add(m);
    m.bind(skeleton);
    meshes.push(m);
  }
  return meshes;
}
