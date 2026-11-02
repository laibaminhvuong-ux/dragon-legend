// Copied from Cage Career 3D (web/body3d.js) so Dragon Legend's fighters use the same model. Keep in sync by hand.
// Smooth, muscular bodies. Every body part is a shape (a tapered capsule or an ellipsoid) on a
// bone; the shapes are blended into one surface with a smooth union of their distance fields and
// meshed with marching cubes, then skinned to the bones so the body bends at the joints instead of
// being a stack of balls and tubes. Clothes are the same surface pushed outward and trimmed.
import * as THREE from "three";
import { edgeTable, triTable } from "./vendor/mc-tables.js";

// body types: how big the frame is, how much muscle, how much fat
export const BODY_TYPES = [
  { name: "Lean", girth: 0.93, muscle: 0.85, fat: 0.15 },
  { name: "Athletic", girth: 1.0, muscle: 1.0, fat: 0.25 },
  { name: "Muscular", girth: 1.07, muscle: 1.3, fat: 0.2 },
  { name: "Stocky", girth: 1.12, muscle: 1.05, fat: 0.65 },
];
// ab definition: how much the six-pack and obliques show through
export const ABS = [
  { name: "Soft", show: 0, belly: 1.0 },
  { name: "Toned", show: 0.45, belly: 0.55 },
  { name: "Defined", show: 0.8, belly: 0.3 },
  { name: "Shredded", show: 1.0, belly: 0.1 },
];

function smin(a, b, k) {
  const h = Math.max(k - Math.abs(a - b), 0) / k;
  return Math.min(a, b) - h * h * k * 0.25;
}

/**
 * The body as shapes on bones. bones: { hips, spine, chest, neck, head, shL, elL, shR, elR, hipL, knL, hipR, knR }.
 * w = overall width, opts: { body, abs, feet (include bare feet), hands (include bare hands), ref }.
 */
function bodyShapes(w, opts) {
  const B = BODY_TYPES[opts.body ?? 1], A = ABS[opts.abs ?? 1];
  const F = !!opts.female;
  // women: a lighter frame and less muscle mass, a narrower waist, wider hips, a chest instead of pecs
  const g = w * B.girth * (F ? 0.9 : 1), m = B.muscle * (F ? 0.82 : 1), fat = B.fat * (0.4 + A.belly) * (F ? 1.15 : 1);
  const P = [];
  // e = ellipsoid [bone, center, radii, blend], c = capsule [bone, a, b, ra, rb, blend]; tag marks parts clothes use
  const e = (bone, c, r, k = 0.05, tag) => P.push({ t: "e", bone, c: new THREE.Vector3(...c), r: new THREE.Vector3(...r), k, tag });
  const c = (bone, a, b, ra, rb, k = 0.05, tag) => P.push({ t: "c", bone, a: new THREE.Vector3(...a), b: new THREE.Vector3(...b), ra, rb, k, tag });
  // torso
  e("hips", [0, 0.0, 0], [0.155 * g * (F ? 1.16 : 1), 0.105, 0.1 * (1 + fat * 0.15)], 0.06);
  e("spine", [0, 0.09, 0.008 + fat * 0.02], [0.13 * g * (1 + fat * 0.08) * (F ? 0.9 : 1), 0.13, 0.09 * (1 + fat * 0.3)], 0.07);
  e("chest", [0, 0.12, 0], [0.16 * g * (F ? 0.95 : 1), 0.155, 0.1], 0.07);
  e("chest", [0, 0.25, -0.025], [0.105 * g * m * (F ? 0.8 : 1), 0.055, 0.055], 0.06); // traps
  if (F) for (const s of [-1, 1]) e("chest", [s * 0.058 * g, 0.13, 0.07], [0.056, 0.054, 0.05], 0.035, "breast");
  for (const s of [-1, 1]) {
    if (!F) e("chest", [s * 0.068 * g, 0.165, 0.058], [0.072 * g * m, 0.052 * m, 0.038 * m], 0.03); // pecs
    e("chest", [s * 0.12 * g, 0.07, -0.015], [0.05 * g * m, 0.12, 0.055], 0.05); // lats
    e("hips", [s * 0.058 * g * (F ? 1.12 : 1), -0.045, -0.055], [0.07 * g * (F ? 1.15 : 1), 0.078, 0.062 * (1 + fat * 0.2) * (F ? 1.15 : 1)], 0.04); // glutes
    // obliques show on lean, defined fighters
    if (A.show > 0) e("spine", [s * 0.1 * g, 0.06, 0.04], [0.035, 0.075, 0.03 * A.show], 0.02);
  }
  // the six-pack: three rows either side of the line down the middle
  if (A.show > 0) {
    const bump = 0.012 + 0.016 * A.show;
    for (const s of [-1, 1]) for (const [i, y] of [-0.01, 0.055, 0.12].entries()) {
      e("spine", [s * 0.03, y, 0.083 + fat * 0.012], [0.028, 0.026 + (i === 0 ? 0.008 : 0), bump], 0.012 + 0.012 * (1 - A.show));
    }
  }
  // collarbones, the chest-to-shoulder line every lean fighter shows
  for (const s of [-1, 1]) c("chest", [s * 0.02, 0.236, 0.062], [s * 0.15 * g, 0.252, 0.012], 0.0105, 0.0095, 0.018);
  // serratus: the finger-like ridges over the ribs below the armpit
  if (!F && A.show > 0.4) for (let i = 0; i < 3; i++) for (const s of [-1, 1]) {
    e("chest", [s * (0.126 - i * 0.004) * g, 0.085 - i * 0.034, 0.05 - i * 0.004], [0.016, 0.01, 0.004 + 0.005 * A.show], 0.028);
  }
  // the back: shoulder blades, the muscles between them and the two columns along the spine
  for (const s of [-1, 1]) {
    e("chest", [s * 0.078 * g, 0.165, -0.088], [0.048 * g, 0.06, 0.016 + 0.006 * m], 0.025); // shoulder blades
    e("chest", [s * 0.12 * g, 0.13, -0.07], [0.034 * g * m, 0.04, 0.028 * m], 0.025); // teres / infraspinatus
    e("chest", [s * 0.038, 0.12, -0.094], [0.032, 0.07, 0.012 + 0.006 * m], 0.025); // rhomboids
    c("spine", [s * 0.03, -0.07, -0.072], [s * 0.031, 0.17, -0.078], 0.026 * g * (0.8 + 0.2 * m), 0.021 * g, 0.022); // spinal erectors
  }
  // neck and head
  c("neck", [0, -0.02, 0], [0, 0.1, 0.012], 0.052 * g * (0.95 + m * 0.05), 0.047 * g, 0.04);
  e("neck", [0, -0.005, -0.03], [0.06 * g * m, 0.04, 0.035], 0.04); // back of the neck
  for (const s of [-1, 1]) c("neck", [s * 0.038, 0.1, -0.008], [s * 0.012, -0.015, 0.042], 0.012 * g, 0.014 * g, 0.018); // the cords down the sides of the neck
  if (!F) e("neck", [0, 0.045, 0.047], [0.009, 0.012, 0.008], 0.01); // Adam's apple
  for (const s of [-1, 1]) {
    const sh = s > 0 ? "shL" : "shR", el = s > 0 ? "elL" : "elR", hip = s > 0 ? "hipL" : "hipR", kn = s > 0 ? "knL" : "knR";
    // arms
    e(sh, [0, -0.02, 0], [0.07 * g * m, 0.075, 0.068 * g * m], 0.05, "arm"); // deltoid
    e(sh, [0, -0.05, 0.03], [0.034 * g * m, 0.05, 0.024 * m], 0.02, "arm"); // front delt
    e(sh, [0, -0.05, -0.03], [0.034 * g * m, 0.05, 0.024 * m], 0.02, "arm"); // rear delt
    c(sh, [0, -0.03, 0], [0, -0.26, 0], 0.052 * g, 0.043 * g, 0.04, "arm");
    e(sh, [0, -0.135, 0.022], [0.04 * g * m, 0.072, 0.04 * g * m], 0.03, "arm"); // biceps
    e(sh, [0, -0.12, -0.024], [0.04 * g * m, 0.085, 0.036 * g * m], 0.03, "arm"); // triceps
    c(el, [0, 0, 0], [0, -0.215, 0], 0.045 * g, 0.031 * g, 0.035, "forearm");
    e(el, [0, -0.06, 0.01], [0.044 * g * m, 0.072, 0.04 * g], 0.03, "forearm");
    e(el, [s * 0.014, -0.045, 0.024], [0.028 * g * m, 0.065, 0.026 * m], 0.02, "forearm"); // brachioradialis
    e(el, [0, 0.0, -0.032], [0.02, 0.022, 0.014], 0.015, "forearm"); // the point of the elbow
    if (opts.hands) e(el, [0, -0.265, 0.005], [0.034, 0.05, 0.024], 0.03, "hand");
    // legs
    c(hip, [0, -0.02, 0], [0, -0.4, 0], 0.088 * g, 0.054 * g, 0.05, "leg");
    e(hip, [s * 0.008, -0.17, 0.028], [0.068 * g * m, 0.15, 0.062 * g * m], 0.04, "leg"); // quads
    e(hip, [-s * 0.03, -0.12, 0.01], [0.04 * g, 0.12, 0.045 * g], 0.04, "leg"); // inner thigh
    e(hip, [0, -0.2, -0.03], [0.058 * g, 0.14, 0.05 * g * m], 0.04, "leg"); // hamstrings
    e(hip, [-s * 0.034, -0.335, 0.036], [0.034 * g * m, 0.055, 0.033 * m], 0.025, "leg"); // the teardrop above the inner knee
    e(hip, [s * 0.05, -0.2, 0.008], [0.036 * g * m, 0.13, 0.044 * m], 0.03, "leg"); // outer quad
    c(kn, [0, 0, 0], [0, -0.405, 0], 0.05 * g, 0.03 * g, 0.035, "shin");
    e(kn, [0, -0.005, 0.044], [0.026, 0.03, 0.016], 0.018, "shin"); // kneecap
    e(kn, [-s * 0.016, -0.115, -0.038], [0.03 * g * m, 0.08, 0.036 * g * m], 0.03, "shin"); // calf, inner head
    e(kn, [s * 0.018, -0.1, -0.034], [0.026 * g * m, 0.07, 0.032 * g * m], 0.03, "shin"); // calf, outer head
    e(kn, [s * 0.012, -0.13, 0.03], [0.016, 0.1, 0.016], 0.02, "shin"); // shin muscle
    c(kn, [0, -0.25, -0.03], [0, -0.41, -0.034], 0.015, 0.012, 0.02, "shin"); // Achilles tendon
    e(kn, [s * 0.025, -0.398, 0.002], [0.011, 0.013, 0.011], 0.01, "shin"); // ankle bones
    e(kn, [-s * 0.022, -0.392, 0.004], [0.011, 0.013, 0.011], 0.01, "shin");
    if (opts.feet) {
      // heel, arch and the ball of the foot, then five toes (the big toe on the inside)
      e(kn, [0, -0.452, -0.018], [0.03, 0.03, 0.036], 0.02, "foot");
      e(kn, [s * 0.004, -0.456, 0.05], [0.038, 0.024, 0.07], 0.025, "foot");
      e(kn, [s * 0.004, -0.469, 0.106], [0.042, 0.016, 0.03], 0.018, "foot");
      c(kn, [-s * 0.021, -0.472, 0.122], [-s * 0.023, -0.474, 0.152], 0.0115, 0.0105, 0.007, "foot");
      [[-0.001, 0.145, 0.0082], [0.013, 0.14, 0.0076], [0.025, 0.133, 0.0072], [0.035, 0.124, 0.0068]].forEach(([x, z, r]) => {
        c(kn, [s * x, -0.474, 0.12], [s * x * 1.05, -0.477, z], r, r * 0.92, 0.006, "foot");
      });
    }
  }
  return P;
}

/** Shapes placed in model space at the bind pose, ready to evaluate. */
function prepare(P, bones) {
  const tmp = new THREE.Matrix4();
  return P.map((p) => {
    const bone = bones[p.bone];
    const inv = tmp.copy(bone.matrixWorld).invert().clone();
    let center, radius;
    if (p.t === "e") {
      center = p.c.clone().applyMatrix4(bone.matrixWorld);
      radius = Math.max(p.r.x, p.r.y, p.r.z);
    } else {
      const a = p.a.clone().applyMatrix4(bone.matrixWorld), b = p.b.clone().applyMatrix4(bone.matrixWorld);
      center = a.clone().add(b).multiplyScalar(0.5);
      radius = a.distanceTo(b) / 2 + Math.max(p.ra, p.rb);
    }
    return { ...p, inv: inv.elements, center, bound: radius + p.k + 0.02 };
  });
}

const L = new THREE.Vector3();
function primDist(p, x, y, z) {
  const m = p.inv;
  // into the bone's own space
  const lx = m[0] * x + m[4] * y + m[8] * z + m[12];
  const ly = m[1] * x + m[5] * y + m[9] * z + m[13];
  const lz = m[2] * x + m[6] * y + m[10] * z + m[14];
  if (p.t === "e") {
    const qx = (lx - p.c.x) / p.r.x, qy = (ly - p.c.y) / p.r.y, qz = (lz - p.c.z) / p.r.z;
    const k0 = Math.sqrt(qx * qx + qy * qy + qz * qz);
    const k1 = Math.sqrt((qx / p.r.x) ** 2 + (qy / p.r.y) ** 2 + (qz / p.r.z) ** 2);
    return k1 > 1e-6 ? (k0 * (k0 - 1)) / k1 : -Math.min(p.r.x, p.r.y, p.r.z);
  }
  const ax = p.a.x, ay = p.a.y, az = p.a.z;
  const bx = p.b.x - ax, by = p.b.y - ay, bz = p.b.z - az;
  const px = lx - ax, py = ly - ay, pz = lz - az;
  const t = Math.max(0, Math.min(1, (px * bx + py * by + pz * bz) / (bx * bx + by * by + bz * bz)));
  const dx = px - bx * t, dy = py - by * t, dz = pz - bz * t;
  return Math.sqrt(dx * dx + dy * dy + dz * dz) - (p.ra + (p.rb - p.ra) * t);
}

function field(prims, x, y, z) {
  let d = 1e9;
  for (const p of prims) {
    const cx = x - p.center.x, cy = y - p.center.y, cz = z - p.center.z;
    if (cx * cx + cy * cy + cz * cz > p.bound * p.bound && d < 0.5) continue;
    d = smin(d, primDist(p, x, y, z), p.k);
  }
  return d;
}

/**
 * A spatial index over the shapes: the box is cut into cells and each cell keeps only the shapes
 * that can reach it, so a lookup tests a handful of shapes instead of all of them.
 * Returns the cell's shape list for a point (or null outside the box).
 */
function shapeGrid(prims, min, max, margin = 0, cell = 0.05) {
  const nx = Math.ceil((max.x - min.x) / cell), ny = Math.ceil((max.y - min.y) / cell), nz = Math.ceil((max.z - min.z) / cell);
  const cells = new Array(nx * ny * nz);
  const reach = cell * 0.87 + margin;
  for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
    const cx = min.x + (i + 0.5) * cell, cy = min.y + (j + 0.5) * cell, cz = min.z + (k + 0.5) * cell;
    cells[i + nx * (j + ny * k)] = prims.filter((p) => (cx - p.center.x) ** 2 + (cy - p.center.y) ** 2 + (cz - p.center.z) ** 2 < (p.bound + reach) ** 2);
  }
  return (x, y, z) => {
    const i = Math.floor((x - min.x) / cell), j = Math.floor((y - min.y) / cell), k = Math.floor((z - min.z) / cell);
    if (i < 0 || j < 0 || k < 0 || i >= nx || j >= ny || k >= nz) return null;
    return cells[i + nx * (j + ny * k)];
  };
}

/** The distance field of a set of shapes, sped up with a shapeGrid. */
function fastField(prims, min, max) {
  const look = shapeGrid(prims, min, max);
  return (x, y, z) => {
    const list = look(x, y, z);
    if (!list) return field(prims, x, y, z);
    if (!list.length) return 0.1;
    let d = 1e9;
    for (const p of list) d = smin(d, primDist(p, x, y, z), p.k);
    return d;
  };
}

/** Marching cubes over a box; f(x, y, z) < 0 inside. Returns an indexed BufferGeometry. */
function polygonize(f, min, max, step) {
  const nx = Math.ceil((max.x - min.x) / step) + 1, ny = Math.ceil((max.y - min.y) / step) + 1, nz = Math.ceil((max.z - min.z) / step) + 1;
  const vals = new Float32Array(nx * ny * nz);
  const idx = (i, j, k) => i + nx * (j + ny * k);
  // sample in blocks: a block whose centre is far from the surface is all inside or all outside,
  // so only blocks near the surface get every point evaluated (much faster for fine grids)
  const BS = 4, reach = step * BS * 0.87 * 1.6 + 0.004;
  for (let bk = 0; bk < nz; bk += BS) for (let bj = 0; bj < ny; bj += BS) for (let bi = 0; bi < nx; bi += BS) {
    const ei = Math.min(nx, bi + BS + 1), ej = Math.min(ny, bj + BS + 1), ek = Math.min(nz, bk + BS + 1);
    const c = f(min.x + (bi + BS / 2) * step, min.y + (bj + BS / 2) * step, min.z + (bk + BS / 2) * step);
    const far = Math.abs(c) > reach;
    for (let k = bk; k < ek; k++) for (let j = bj; j < ej; j++) for (let i = bi; i < ei; i++) {
      vals[idx(i, j, k)] = far ? c : f(min.x + i * step, min.y + j * step, min.z + k * step);
    }
  }
  const pos = [], index = [], edgeVert = new Map();
  // corner offsets (Bourke order) and edges as [corner, corner]
  const C = [[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0], [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]];
  const E = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
  const cv = new Float32Array(8), ev = new Int32Array(12);
  for (let k = 0; k < nz - 1; k++) for (let j = 0; j < ny - 1; j++) for (let i = 0; i < nx - 1; i++) {
    let cube = 0;
    for (let c = 0; c < 8; c++) {
      cv[c] = vals[idx(i + C[c][0], j + C[c][1], k + C[c][2])];
      if (cv[c] < 0) cube |= 1 << c;
    }
    const edges = edgeTable[cube];
    if (!edges) continue;
    for (let e = 0; e < 12; e++) {
      if (!(edges & (1 << e))) continue;
      const [a, b] = E[e];
      const ia = idx(i + C[a][0], j + C[a][1], k + C[a][2]), ib = idx(i + C[b][0], j + C[b][1], k + C[b][2]);
      const key = ia < ib ? ia * 4 + (ib - ia === 1 ? 0 : ib - ia === nx ? 1 : 2) : ib * 4 + (ia - ib === 1 ? 0 : ia - ib === nx ? 1 : 2);
      let v = edgeVert.get(key);
      if (v === undefined) {
        const t = cv[a] / (cv[a] - cv[b]);
        v = pos.length / 3;
        pos.push(
          min.x + (i + C[a][0] + (C[b][0] - C[a][0]) * t) * step,
          min.y + (j + C[a][1] + (C[b][1] - C[a][1]) * t) * step,
          min.z + (k + C[a][2] + (C[b][2] - C[a][2]) * t) * step,
        );
        edgeVert.set(key, v);
      }
      ev[e] = v;
    }
    const base = cube << 4;
    for (let t = 0; triTable[base + t] !== -1; t += 3) {
      // inside is negative here, so flip the winding to face outward
      index.push(ev[triTable[base + t]], ev[triTable[base + t + 2]], ev[triTable[base + t + 1]]);
    }
  }
  // smooth normals straight from the shape's gradient (no faceting from the grid)
  const nrm = new Float32Array(pos.length), h = step * 0.5;
  for (let v = 0; v < pos.length; v += 3) {
    const x = pos[v], y = pos[v + 1], z = pos[v + 2];
    let nx = f(x + h, y, z) - f(x - h, y, z), ny = f(x, y + h, z) - f(x, y - h, z), nz = f(x, y, z + h) - f(x, y, z - h);
    const l = Math.hypot(nx, ny, nz) || 1;
    nrm[v] = nx / l;
    nrm[v + 1] = ny / l;
    nrm[v + 2] = nz / l;
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute("normal", new THREE.BufferAttribute(nrm, 3));
  g.setIndex(index);
  return g;
}

/**
 * Baked contact shading ("occl" attribute, 0 = open, 1 = deep crease): how much of the surface's
 * own shape crowds each point, sampled a little way out along the normal. It darkens the lines
 * between muscles, under the pecs, around the eyes and nose, and in folds of cloth.
 */
function bakeOcclusion(geo, f, radii = [0.008, 0.02, 0.04], spots = []) {
  const P = geo.attributes.position.array, N = geo.attributes.normal.array;
  const out = new Float32Array(P.length / 3);
  for (let v = 0; v < out.length; v++) {
    const x = P[v * 3], y = P[v * 3 + 1], z = P[v * 3 + 2], nx = N[v * 3], ny = N[v * 3 + 1], nz = N[v * 3 + 2];
    let o = 0;
    for (const r of radii) o += Math.max(0, 1 - Math.max(0, f(x + nx * r, y + ny * r, z + nz * r)) / r);
    o = Math.min(1, (o / radii.length) * 1.7);
    for (const [sx, sy, sz, rad, amt] of spots) {
      const d2 = ((x - sx) ** 2 + (y - sy) ** 2 + (z - sz) ** 2) / (rad * rad);
      if (d2 < 1) o = Math.max(o, amt * (1 - d2) * (1 - d2));
    }
    out[v] = o;
  }
  geo.setAttribute("occl", new THREE.BufferAttribute(out, 1));
}

/** Bone weights per vertex: each shape pulls its vertices toward its bone, nearer shapes pull harder. */
function skin(geo, prims, boneIndex, near = null) {
  const n = geo.attributes.position.count;
  const P = geo.attributes.position.array;
  const si = new Uint16Array(n * 4), sw = new Float32Array(n * 4);
  const acc = new Map();
  for (let v = 0; v < n; v++) {
    const x = P[v * 3], y = P[v * 3 + 1], z = P[v * 3 + 2];
    acc.clear();
    for (const p of (near && near(x, y, z)) || prims) {
      const cx = x - p.center.x, cy = y - p.center.y, cz = z - p.center.z;
      if (cx * cx + cy * cy + cz * cz > (p.bound + 0.05) ** 2) continue;
      const d = Math.max(0, primDist(p, x, y, z));
      const wgt = Math.exp(-d / 0.014);
      const b = boneIndex[p.bone];
      acc.set(b, (acc.get(b) || 0) + wgt);
    }
    const top = [...acc.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4);
    const sum = top.reduce((s, t) => s + t[1], 0) || 1;
    top.forEach(([b, wgt], i) => {
      si[v * 4 + i] = b;
      sw[v * 4 + i] = wgt / sum;
    });
    if (!top.length) sw[v * 4] = 1;
  }
  geo.setAttribute("skinIndex", new THREE.Uint16BufferAttribute(si, 4));
  geo.setAttribute("skinWeight", new THREE.Float32BufferAttribute(sw, 4));
}

/** Joins geometries with the same attributes into one. */
function mergeGeos(list) {
  const out = new THREE.BufferGeometry();
  for (const name of Object.keys(list[0].attributes)) {
    const a0 = list[0].attributes[name];
    const arr = new a0.array.constructor(list.reduce((n, g) => n + g.attributes[name].array.length, 0));
    let o = 0;
    for (const g of list) {
      arr.set(g.attributes[name].array, o);
      o += g.attributes[name].array.length;
    }
    out.setAttribute(name, new THREE.BufferAttribute(arr, a0.itemSize));
  }
  const idx = [];
  let base = 0;
  for (const g of list) {
    for (const i of g.index.array) idx.push(i + base);
    base += g.attributes.position.count;
  }
  out.setIndex(idx);
  return out;
}

const cache = new Map();

/**
 * Builds the skin (and clothes) for a skeleton in its bind pose.
 * bones: name -> Bone (matrixWorld up to date, in the fighter's own space), order: bone names in skeleton order.
 * kind: "fighter" (shorts), "casual" (shirt + trousers), "ref" (shirt + trousers).
 * Returns { skin, shorts?, shirt?, pants? } geometries (shared between fighters with the same build).
 */
export function buildBody(bones, order, w, kind, opts = {}) {
  const key = [w.toFixed(3), kind, opts.body ?? 1, opts.abs ?? 1, opts.step || 0, opts.female ? "F" : "M", opts.bikini ? "bikini" : "sport"].join("|");
  if (cache.has(key)) return cache.get(key);
  const presenter = kind === "presenter";
  const civ = kind !== "fighter" && !presenter;
  const shapes = prepare(bodyShapes(w, { ...opts, feet: !civ, hands: civ || presenter }), bones);
  const boneIndex = Object.fromEntries(order.map((n, i) => [n, i]));
  const step = opts.step || (civ ? 0.016 : 0.0105);
  const min = new THREE.Vector3(-0.62, -0.06, -0.3), max = new THREE.Vector3(0.62, 1.82, 0.3);
  const out = {};
  const skinField = fastField(shapes, min, max);
  const near = shapeGrid(shapes, min, max, 0.05);
  out.skin = polygonize(skinField, min, max, step);
  skin(out.skin, shapes, boneIndex, near);
  // the navel is a dimple in the shading
  const navel = bones.spine.localToWorld(new THREE.Vector3(0, -0.005, 0.09));
  bakeOcclusion(out.skin, skinField, undefined, civ ? [] : [[navel.x, navel.y, navel.z, 0.014, 0.9]]);
  const hipY = bones.hipL.getWorldPosition(L).y, kneeY = bones.knL.getWorldPosition(L).y;
  const sub = (filter) => shapes.filter(filter);
  const clothes = (parts, off, lo, hi) => {
    const pf = fastField(parts, min, max);
    const g = polygonize((x, y, z) => Math.max(pf(x, y, z) - off, lo - y, y - hi), min, max, step);
    skin(g, shapes, boneIndex, near);
    bakeOcclusion(g, (x, y, z) => pf(x, y, z) - off, [0.01, 0.025]);
    return g;
  };
  const torsoBones = new Set(["hips", "spine", "chest"]);
  if (presenter && opts.bikini) {
    // Adult presenter swimwear: opaque briefs and two fitted cups, independently skinned.
    const hips = sub((p) => p.bone === "hips" || p.tag === "leg");
    const briefField = fastField(hips, min, max);
    // A high-cut V along each leg, rather than a horizontal shorts/skirt hem.
    out.shorts = polygonize((x, y, z) => Math.max(briefField(x, y, z) - 0.009, hipY - 0.055 + Math.abs(x) * 0.62 - y, y - hipY - 0.11), min, max, step);
    skin(out.shorts, shapes, boneIndex, near);
    bakeOcclusion(out.shorts, (x, y, z) => briefField(x, y, z) - 0.009, [0.01, 0.025]);
    const chestY = bones.chest.getWorldPosition(L).y;
    out.top = clothes(sub((p) => p.tag === "breast"), 0.012, chestY + 0.065, chestY + 0.205);
  } else if (!civ) {
    // loose fight shorts: from the waist to mid-thigh
    const shortsParts = sub((p) => p.bone === "hips" || p.bone === "spine" || p.tag === "leg");
    const hem = kneeY + (hipY - kneeY) * 0.42;
    out.shorts = clothes(shortsParts, 0.016, hem, hipY + 0.14);
    // a stitched waistband and a trim along the hem, a shade apart from the shorts
    out.trim = mergeGeos([clothes(shortsParts, 0.021, hipY + 0.105, hipY + 0.145), clothes(shortsParts, 0.019, hem - 0.003, hem + 0.022)]);
    if (opts.female) {
      // a sports bra over the chest
      const chestY = bones.chest.getWorldPosition(L).y;
      out.top = clothes(sub((p) => p.bone === "chest" && p.r && p.c.y < 0.2), 0.008, chestY + 0.05, chestY + 0.215);
    }
  } else {
    out.shirt = clothes(sub((p) => torsoBones.has(p.bone) || p.tag === "arm" || (p.bone === "neck" && p.t === "c")), 0.012, hipY + 0.02, 2);
    out.pants = clothes(sub((p) => p.bone === "hips" || p.bone === "spine" || p.tag === "leg" || p.tag === "shin"), 0.013, 0.1, hipY + 0.12);
  }
  cache.set(key, out);
  return out;
}

/** Puts a skeleton into the pose the body is built in (arms out a little so they don't merge with the torso). */
export const BIND_POSE = { shL: [0, 0, 0.55], shR: [0, 0, -0.55], hipL: [0, 0, 0.07], hipR: [0, 0, -0.07] };

/** The head, in the head bone's own space: skull, cheekbones, brow, nose, lips, chin and ears, with eye sockets. */
// Face shapes by ancestry: adjustments to the classic head. Bridge = how high the nose bridge
// stands, tip/wing = nose width, cheek = cheekbone width and size, socket = eye depth, lid = how
// much the upper lid covers (1 = open, lower = heavier), eyeH = eye opening height, lips = fullness,
// noseL = nose length, chinZ = chin projection, faceW/faceL/jawW = proportions.
export const FACES = [
  { name: "Classic" },
  { name: "East Asian", bridgeZ: -0.014, bridgeTop: -0.02, tipW: 1.08, wingX: 1.12, cheekX: 1.1, cheekR: 1.12, faceW: 1.07, faceL: 0.96,
    browZ: -0.008, brow: 0.7, socket: 0.4, lid: 0.55, eyeH: 0.8, jawW: 1.04, lips: 1.05, noseL: 0.9 },
  { name: "South Asian", bridgeZ: -0.002, tipW: 1.28, wingX: 1.2, lips: 1.3, socket: 1.15, eyeH: 1.12, faceL: 1.02, brow: 1.15, jawW: 0.97, noseL: 1.08 },
  { name: "African", bridgeZ: -0.012, bridgeTop: -0.01, tipW: 1.75, wingX: 1.75, tipR: 1.2, lips: 1.95, lipZ: 0.006, jawW: 1.1, cheekR: 1.12, cheekX: 1.06,
    socket: 0.9, faceW: 1.03, chinZ: 0.004, noseL: 0.92 },
  { name: "European", bridgeZ: 0.012, bridgeTop: 0.008, tipW: 0.78, wingX: 0.8, tipR: 0.95, lips: 0.7, socket: 1.7, brow: 1.4, browZ: 0.007,
    faceL: 1.09, faceW: 0.93, jawW: 0.95, chinZ: 0.008, noseL: 1.12, eyeH: 1.05 },
  { name: "Latino", bridgeZ: 0.0, tipW: 1.3, wingX: 1.25, cheekX: 1.1, cheekR: 1.15, lips: 1.35, jawW: 1.06, faceW: 1.03, socket: 1.05 },
  { name: "Middle Eastern", bridgeZ: 0.014, bridgeTop: 0.006, hump: true, tipW: 1.1, tipR: 1.1, brow: 1.5, browZ: 0.008, socket: 1.6, faceL: 1.06,
    noseL: 1.25, jawW: 1.02, lips: 1.1, eyeH: 0.95 },
];

/** A small personal variation so two fighters of the same ancestry don't share a face. */
function jitter(seed) {
  if (!seed) return () => 1;
  let h = 2166136261;
  for (const ch of String(seed)) h = Math.imul(h ^ ch.charCodeAt(0), 16777619);
  return (amount = 0.14) => {
    h = Math.imul(h ^ (h >>> 15), 2246822507);
    h ^= h >>> 13;
    return 1 + (((h >>> 0) / 4294967296) - 0.5) * 2 * amount;
  };
}

/** The head, in the head bone's own space: skull, cheekbones, brow, nose, lips, chin and ears, with eye sockets. */
function headShapes(F = FACES[0], seed = "", female = false) {
  const add = [], sub = [];
  const J = jitter(seed);
  // women: a softer jaw and brow, a slightly smaller nose and fuller lips, on top of the face shape
  const soft = female ? { jawW: 0.86, brow: 0.55, tipW: 0.88, lips: 1.25, faceL: 0.96, chinZ: -0.004, cheekR: 1.06 } : {};
  const v = (k, d = 1) => {
    const base = F[k] === undefined ? d : F[k];
    if (soft[k] === undefined) return base;
    return k === "chinZ" ? base + soft[k] : base * soft[k];
  };
  const e = (list, c, r, k) => list.push({ t: "e", c: new THREE.Vector3(...c), r: new THREE.Vector3(...r), k, inv: new THREE.Matrix4().elements,
    center: new THREE.Vector3(...c), bound: Math.max(...r) + k + 0.01 });
  const c = (list, a, b, ra, rb, k) => {
    const A = new THREE.Vector3(...a), B = new THREE.Vector3(...b);
    list.push({ t: "c", a: A, b: B, ra, rb, k, inv: new THREE.Matrix4().elements, center: A.clone().add(B).multiplyScalar(0.5), bound: A.distanceTo(B) / 2 + Math.max(ra, rb) + k + 0.01 });
  };
  const fw = v("faceW") * J(0.06), fl = v("faceL") * J(0.05), jw = v("jawW") * J(0.1), lips = v("lips") * J(0.18);
  const bz = v("bridgeZ", 0) + (J(1) - 1) * 0.004, bt = v("bridgeTop", 0), nl = v("noseL") * J(0.12), tw = v("tipW") * J(0.15);
  const cx = v("cheekX") * J(0.06), cr = v("cheekR") * J(0.12), chin = v("chinZ", 0) + (J(1) - 1) * 0.006, brow = v("brow") * J(0.15);
  e(add, [0, 0.025, -0.005], [0.09 * J(0.04), 0.105 * J(0.04), 0.1], 0.03); // cranium
  e(add, [0, -0.005, 0.03], [0.074 * fw, 0.085 * fl, 0.075], 0.03); // face
  e(add, [0, -0.05 * fl, 0.03], [0.068 * jw, 0.05, 0.07], 0.025); // jaw
  e(add, [0, -0.083 * fl, 0.068 + chin], [0.024 * jw, 0.019, 0.022], 0.02); // chin
  for (const s of [-1, 1]) e(add, [s * 0.035 * jw, -0.072 * fl, 0.05], [0.022, 0.016, 0.03], 0.025); // jawline toward the chin
  e(add, [0, 0.052, 0.076 + v("browZ", 0)], [0.07, 0.017 * brow, 0.025 * brow], 0.015); // brow ridge
  const tipY = -0.004 - 0.012 * (nl - 1);
  c(add, [0, 0.04 + bt, 0.093 + bz], [0, tipY, 0.107 + bz * 0.5 + 0.006 * (nl - 1)], 0.009 * J(0.15), 0.011 * tw, 0.01); // nose bridge
  if (F.hump) e(add, [0, 0.018, 0.103 + bz], [0.01, 0.012, 0.009], 0.008);
  e(add, [0, tipY - 0.004, 0.105 + bz * 0.4 + 0.006 * (nl - 1)], [0.0138 * tw, 0.0125 * v("tipR"), 0.013 * v("tipR")], 0.009); // nose tip
  e(add, [0, -0.035, 0.094 + v("lipZ", 0)], [0.024 * J(0.08), 0.008 * lips, 0.012 * (0.85 + lips * 0.15)], 0.006); // upper lip
  e(add, [0, -0.047, 0.092 + v("lipZ", 0)], [0.021 * J(0.08), 0.009 * lips, 0.012 * (0.85 + lips * 0.15)], 0.006); // lower lip
  for (const s of [-1, 1]) {
    // cheekbones: a ridge under the outer eye, not a ball
    e(add, [s * 0.052 * cx, 0.008, 0.07 + v("cheekZ", 0)], [0.024 * cr, 0.011 * cr, 0.016], 0.03);
    e(add, [s * 0.012 * v("wingX") * J(0.1), tipY - 0.008, 0.099 + bz * 0.3], [0.009 * v("wingX"), 0.008, 0.009], 0.006); // nostril wings
    e(add, [s * 0.091, 0.01, -0.008], [0.012, 0.03 * J(0.12), 0.022], 0.008); // ears
    e(sub, [s * 0.034, 0.03, 0.095], [0.021, 0.015 * (0.7 + 0.3 * v("eyeH")), 0.014 * v("socket")], 0.01); // eye sockets
    e(add, [s * 0.06 * jw, -0.056 * fl, -0.004], [0.012, 0.02, 0.024], 0.02); // angle of the jaw
    e(sub, [s * 0.0075 * v("wingX"), tipY - 0.0125, 0.101 + bz * 0.3], [0.0042 * v("wingX"), 0.0028, 0.0055], 0.003); // nostrils
    e(sub, [s * 0.097, 0.008, -0.003], [0.005, 0.015, 0.011], 0.004); // the bowl of the ear
    e(add, [s * 0.098, 0.012, -0.016], [0.006, 0.024, 0.005], 0.004); // the rim of the ear
  }
  // the line where the lips meet, the groove above the upper lip and the dent above the chin
  e(sub, [0, -0.0415, 0.108 + v("lipZ", 0)], [0.018 * J(0.08), 0.0006, 0.006], 0.002);
  e(add, [0, -0.008, 0.06], [0.05 * fw, 0.035, 0.04], 0.03); // fills the midface so cheeks and nose blend smoothly
  e(sub, [0, -0.063 * fl, 0.09 + chin], [0.012, 0.003, 0.006], 0.006);
  return { add, sub };
}

const headGeos = new Map();
/** The head mesh for a face shape and a personal seed (shared between fighters with the same pair). */
export function buildHeadGeo(face = 0, seed = "", female = false) {
  const key = face + "|" + seed + "|" + female;
  if (headGeos.has(key)) return headGeos.get(key);
  const { add, sub } = headShapes(FACES[face] || FACES[0], seed, female);
  const lo = new THREE.Vector3(-0.12, -0.12, -0.13), hi = new THREE.Vector3(0.12, 0.15, 0.14);
  const near = shapeGrid(add, lo, hi, 0, 0.02);
  const f = (x, y, z) => {
    let d = 1e9;
    const list = near(x, y, z) || add;
    if (!list.length) d = 0.05;
    for (const p of list) d = smin(d, primDist(p, x, y, z), p.k);
    for (const p of sub) {
      const s = -primDist(p, x, y, z), k = p.k;
      const h = Math.max(k - Math.abs(d - s), 0) / k;
      d = Math.max(d, s) + h * h * k * 0.25;
    }
    return d;
  };
  const g = polygonize(f, lo, hi, 0.0036);
  bakeOcclusion(g, f, [0.0025, 0.005]);
  headGeos.set(key, g);
  return g;
}

const gloveGeos = new Map();
/**
 * An open-finger MMA glove in the forearm bone's space (thumb on the side given by thumbSign):
 * padded knuckles and back of the hand, a palm strap and a thumb loop in leather, and the bare
 * fingers curled into the palm below the padding.
 */
export function buildGloveGeo(thumbSign = 1) {
  if (gloveGeos.has(thumbSign)) return gloveGeos.get(thumbSign);
  const prim = (list, t, a, b, ra, rb, k) => list.push(t === "e"
    ? { t, c: new THREE.Vector3(...a), r: new THREE.Vector3(...b), k: ra, inv: new THREE.Matrix4().elements, center: new THREE.Vector3(...a), bound: 9 }
    : { t, a: new THREE.Vector3(...a), b: new THREE.Vector3(...b), ra, rb, k, inv: new THREE.Matrix4().elements, center: new THREE.Vector3(...a), bound: 9 });
  // a fist: the back of the hand and the knuckles face out (-z, -y), the fingers curl into the palm (+z)
  const leather = [], fingers = [];
  prim(leather, "e", [0, -0.274, -0.012], [0.043, 0.05, 0.03], 0.014); // padding over the back of the hand
  prim(leather, "c", [-0.031, -0.318, -0.006], [0.031, -0.318, -0.006], 0.021, 0.021, 0.016); // the knuckle roll
  prim(leather, "e", [0, -0.262, 0.022], [0.036, 0.032, 0.012], 0.01); // palm strap
  prim(leather, "c", [0, -0.228, 0], [0, -0.242, 0], 0.043, 0.043, 0.01); // cuff under the wrist strap
  prim(leather, "c", [thumbSign * 0.039, -0.25, 0.004], [thumbSign * 0.032, -0.288, 0.028], 0.0125, 0.011, 0.008); // thumb loop
  for (const x of [-0.026, -0.0087, 0.0087, 0.026]) {
    const k = x === -0.026 * thumbSign ? 0.85 : 1; // the little finger is smaller
    prim(fingers, "c", [x, -0.332, 0.008], [x * 1.02, -0.322, 0.032 * k], 0.0098 * k, 0.0094 * k, 0.004);
    prim(fingers, "c", [x * 1.02, -0.322, 0.032 * k], [x, -0.302, 0.036 * k], 0.0094 * k, 0.0086 * k, 0.004);
  }
  prim(fingers, "c", [thumbSign * 0.032, -0.288, 0.028], [thumbSign * 0.012, -0.306, 0.045], 0.0102, 0.0094, 0.004); // the thumb, folded over the fingers
  const sdf = (list) => (x, y, z) => {
    let d = 1e9;
    for (const p of list) d = smin(d, primDist(p, x, y, z), p.k);
    return d;
  };
  const min = new THREE.Vector3(-0.075, -0.36, -0.06), max = new THREE.Vector3(0.075, -0.2, 0.075);
  const out = {};
  const all = sdf([...leather, ...fingers]), shell = sdf(leather);
  // the knuckle panel: a skin of the glove's own shape over the front of the knuckles
  const fields = { leather: shell, panel: (x, y, z) => Math.max(shell(x, y, z) - 0.0024, y + 0.296, z - 0.022), fingers: sdf(fingers) };
  for (const name of ["leather", "panel", "fingers"]) {
    out[name] = polygonize(fields[name], min, max, 0.0032);
    bakeOcclusion(out[name], all, [0.003, 0.008]);
  }
  gloveGeos.set(thumbSign, out);
  return out;
}
