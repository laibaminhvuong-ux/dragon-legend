// Copied from Cage Career 3D (web/fighter3d.js) so Dragon Legend's fighters use the same model. Keep in sync by hand.
// Procedural 3D fighters: a jointed low-poly body built from primitives, a pose library,
// and an animator that blends between poses so every move flows into the next.
import * as THREE from "three";
import { createPromotionBelt } from "./belt3d.js";
import { ABS, BIND_POSE, BODY_TYPES, FACES, buildBody, buildGloveGeo, buildHeadGeo } from "./body3d.js";
import { TATTOO_DESIGNS, TATTOO_REGIONS, addTattoos } from "./tattoo3d.js";
import { KIT_NAMES, addCylinderUV, kitTexture } from "./kit3d.js";

export const LOOK_OPTIONS = {
  skin: ["#f2d2b6", "#e3b48e", "#c98e64", "#a96c45", "#7c4b2c", "#4f301d"],
  hair: ["Bald", "Buzz", "Short", "Mohawk", "Man bun", "Long", "Afro", "Braids", "Dreadlocks",
    "Ponytail", "Top bun", "Fade", "Undercut", "Spiky", "Curly", "Pompadour", "Bob", "Double braids", "Box braids"],
  hairColor: ["#15120f", "#3b2416", "#6e4524", "#c9a25a", "#9c3a1a", "#9b9b9b",
    "#ece6d6", "#e2c46a", "#c2561e", "#2d4fd6", "#e0559a", "#7c3aed", "#1f9d55", "#f4f4f4"],
  beard: ["None", "Stubble", "Goatee", "Full"],
  shorts: ["#c8102e", "#1d4ed8", "#151515", "#f2f2f2", "#15803d", "#e8a91c", "#7c3aed", "#f97316",
    "#0f2a5c", "#0d9488", "#ec4899", "#9ca3af", "#7f1d1d", "#38bdf8", "#84cc16"],
  design: KIT_NAMES,
  body: BODY_TYPES.map((b) => b.name),
  abs: ABS.map((a) => a.name),
  ...Object.fromEntries(TATTOO_REGIONS.map((r) => [r.key, TATTOO_DESIGNS])),
  face: FACES.map((f) => f.name),
  headband: ["None", "Red", "Black", "White", "Blue", "Gold", "Bandana"],
  wraps: ["None", "White tape", "Black tape", "Ankle sleeves"],
  knees: ["None", "Black sleeves", "White sleeves"],
};
const HEADBAND_COLORS = [null, "#c8102e", "#151515", "#f2f2f2", "#1d4ed8", "#e8a91c", "#7f1d1d"];
export { TATTOO_REGIONS };
/**
 * How each promotion looks: its logo (shape, colors, wordmark) and its official gloves. Keyed by
 * the promotion's short name as fights carry it ("GFC", "PFL", "Iron Cage", ...).
 */
export const ORG_STYLES = {
  GFC: { shape: "octagon", bg: "#c8102e", ring: "#e8a91c", text: "#ffffff", font: "italic 900", gloves: { body: "#141414", panel: "#141414" } },
  "Contender Series": { label: "CONTENDER", shape: "circle", bg: "#101012", ring: "#e8a91c", text: "#e8a91c", font: "900", gloves: { body: "#141414", panel: "#2a2a2a" } },
  CWE: { label: "CAGE WARRIORS", shape: "shield", bg: "#0f2557", ring: "#c0c6d0", text: "#ffffff", font: "900", gloves: { body: "#121212", panel: "#e9e9e9" } },
  PFL: { shape: "hexagon", bg: "#0b0b0b", ring: "#d4a017", text: "#d4a017", font: "900", gloves: { body: "#0d0d0d", panel: "#c99a12", metal: 0.35 } },
  "Valor FC": { label: "VALOR", shape: "star", bg: "#14532d", ring: "#e5e7eb", text: "#ffffff", font: "italic 900", gloves: { body: "#123d25", panel: "#0d0d0d" } },
  DFC: { label: "DRAGON FC", shape: "flame", bg: "#7f0d0d", ring: "#f2b705", text: "#f2b705", font: "900", gloves: { body: "#7a0c0c", panel: "#d9a406", metal: 0.3 } },
  "Iron Cage": { label: "IRON CAGE", shape: "circle", bg: "#3f4248", ring: "#8b8f97", text: "#e6e6e6", font: "800", gloves: { body: "#3a2a1f", panel: "#2b1f17" } },
};
export function orgStyle(org) {
  return ORG_STYLES[org] || ORG_STYLES.GFC;
}

export const SHORTS_NAMES = ["Red", "Blue", "Black", "White", "Green", "Gold", "Purple", "Orange", "Navy", "Teal", "Pink", "Silver", "Maroon", "Sky blue", "Lime"];
// Appended keys only, so every look saved before a feature still decodes to the same fighter.
const KEYS = ["skin", "hair", "hairColor", "beard", "shorts", "body", "abs", ...TATTOO_REGIONS.map((r) => r.key), "face", "headband", "wraps", "knees", "design"];
// looks saved before body type and abs existed are athletic and toned
const LOOK_DEFAULTS = { body: 1, abs: 1 };

export function parseLook(str) {
  const parts = String(str || "").split(",").map(Number);
  const look = {};
  KEYS.forEach((k, i) => {
    const n = LOOK_OPTIONS[k].length;
    look[k] = Number.isInteger(parts[i]) ? ((parts[i] % n) + n) % n : LOOK_DEFAULTS[k] ?? 0;
  });
  return look;
}
export function lookString(look) {
  return KEYS.map((k) => look[k]).join(",");
}

/** NPCs have no stored look, so it is derived from their name (the same fighter always looks the same). */
export function lookFromName(name) {
  let h = 2166136261;
  for (const c of String(name)) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  const r = () => {
    h = Math.imul(h ^ (h >>> 15), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    h ^= h >>> 16;
    return (h >>> 0) / 4294967296;
  };
  const pick = (k) => Math.floor(r() * LOOK_OPTIONS[k].length);
  return { skin: pick("skin"), hair: pick("hair"), hairColor: Math.floor(r() * 5), beard: pick("beard"), shorts: pick("shorts"), body: pick("body"), abs: pick("abs"),
    ...Object.fromEntries(TATTOO_REGIONS.map((t) => [t.key, r() < 0.3 ? 1 + Math.floor(r() * (TATTOO_DESIGNS.length - 1)) : 0])),
    face: 1 + Math.floor(r() * (FACES.length - 1)),
    design: r() < 0.45 ? 0 : 1 + Math.floor(r() * (KIT_NAMES.length - 1)),
    headband: r() < 0.12 ? 1 + Math.floor(r() * 6) : 0, wraps: r() < 0.35 ? 1 + Math.floor(r() * 3) : 0, knees: r() < 0.15 ? 1 + Math.floor(r() * 2) : 0 };
}

export function randomLook() {
  return lookFromName(Math.random().toString(36));
}

// ------------------------------------------------------------------ poses
// A pose is a set of joint rotations (radians, XYZ order) plus a hip offset.
// Fighters face +z; their left is +x. Arms and legs hang along -y, so a negative
// shoulder x swings an arm forward, a negative elbow x bends the forearm up, and a
// positive knee x bends the shin back.

const JOINTS = ["hips", "spine", "chest", "neck", "shL", "elL", "shR", "elR", "hipL", "knL", "hipR", "knR"];

function pose(base, o = {}) {
  const p = { hipsPos: [0, 0, 0] };
  for (const j of JOINTS) p[j] = [0, 0, 0];
  for (const src of [base, o]) {
    if (!src) continue;
    for (const k in src) p[k] = src[k].slice();
  }
  return p;
}

/** Swap left and right (a left hook becomes a right hook). */
export function mirror(p) {
  const m = {};
  for (const k in p) {
    const v = p[k];
    const key = k.endsWith("L") ? k.slice(0, -1) + "R" : k.endsWith("R") ? k.slice(0, -1) + "L" : k;
    m[key] = k === "hipsPos" ? [-v[0], v[1], v[2]] : [v[0], -v[1], -v[2]];
  }
  return m;
}

const STANCE = pose(null, {
  hipsPos: [0, -0.07, 0],
  hips: [0, -0.45, 0],
  spine: [0.08, 0.15, 0],
  chest: [0.06, 0.18, 0],
  neck: [0.12, 0.1, 0],
  shL: [-0.85, 0, 0.18], elL: [-1.75, 0, 0],
  shR: [-0.45, 0, -0.2], elR: [-2.3, 0, 0],
  hipL: [-0.32, 0.45, 0.1], knL: [0.42, 0, 0],
  hipR: [0.22, 0.35, -0.12], knR: [0.36, 0, 0],
});

export const POSES = {
  stance: STANCE,
  relaxed: pose(null, {
    hipsPos: [0, -0.01, 0], neck: [0.05, 0, 0], chest: [0.02, 0, 0],
    shL: [0.05, 0, 0.14], elL: [-0.35, 0, 0], shR: [0.05, 0, -0.14], elR: [-0.35, 0, 0],
    hipL: [0, 0, 0.06], knL: [0.04, 0, 0], hipR: [0, 0, -0.06], knR: [0.04, 0, 0],
  }),
  // sitting on a chair or sofa, hands resting on the thighs
  sit: pose(null, {
    hipsPos: [0, -0.5, -0.05], spine: [-0.05, 0, 0], neck: [0.05, 0, 0],
    shL: [-0.35, 0, 0.12], elL: [-0.9, 0, 0], shR: [-0.35, 0, -0.12], elR: [-0.9, 0, 0],
    hipL: [-1.5, 0, 0.12], knL: [1.5, 0, 0], hipR: [-1.5, 0, -0.12], knR: [1.5, 0, 0],
  }),
  // in the air: knees tucked, arms up for balance
  jump: pose(null, {
    hipsPos: [0, -0.05, 0], spine: [0.1, 0, 0], neck: [-0.1, 0, 0],
    shL: [-0.9, 0, 0.5], elL: [-0.9, 0, 0], shR: [-0.9, 0, -0.5], elR: [-0.9, 0, 0],
    hipL: [-1.0, 0, 0.12], knL: [1.4, 0, 0], hipR: [-0.8, 0, -0.12], knR: [1.2, 0, 0],
  }),
  // lying on your back (in bed, on a lounger), head toward -z, hands on the belly
  lie: pose(null, {
    hipsPos: [0, -0.84, 0],
    hips: [-1.5, 0, 0], neck: [0.3, 0, 0],
    shL: [-0.25, 0, 0.22], elL: [-1.1, 0, 0], shR: [-0.25, 0, -0.22], elR: [-1.1, 0, 0],
    hipL: [0, 0, 0.06], knL: [0.08, 0, 0], hipR: [0, 0, -0.06], knR: [0.08, 0, 0],
  }),
  // swimming: face down, head toward +z, arms stroking (animated in idlePose)
  swim: pose(null, {
    hipsPos: [0, -0.85, 0],
    hips: [1.45, 0, 0], neck: [-0.75, 0, 0],
    shL: [-2.6, 0, 0.2], shR: [-1.0, 0, -0.2],
    hipL: [0.05, 0, 0.05], hipR: [-0.05, 0, -0.05],
  }),
  // treading water: upright, arms sculling, legs cycling (animated in idlePose)
  tread: pose(null, {
    hipsPos: [0, -0.05, 0], neck: [-0.05, 0, 0],
    shL: [-0.3, 0, 0.9], elL: [-0.6, 0, 0], shR: [-0.3, 0, -0.9], elR: [-0.6, 0, 0],
    hipL: [-0.5, 0, 0.1], knL: [0.9, 0, 0], hipR: [-0.2, 0, -0.1], knR: [0.5, 0, 0],
  }),
  // under the shower: hands in the hair (animated in idlePose)
  shower: pose(null, {
    hipsPos: [0, -0.01, 0], neck: [-0.35, 0, 0], chest: [-0.05, 0, 0],
    shL: [-2.4, 0, 0.55], elL: [-1.9, 0, 0], shR: [-2.4, 0, -0.55], elR: [-1.9, 0, 0],
    hipL: [0, 0, 0.08], hipR: [0, 0, -0.08],
  }),
  // behind the wheel: sitting, thighs forward, hands at ten and two
  drive: pose(null, {
    hipsPos: [0, -0.5, -0.05], spine: [-0.12, 0, 0], neck: [0.05, 0, 0],
    shL: [-0.95, 0, 0.22], elL: [-0.75, 0, 0], shR: [-0.95, 0, -0.22], elR: [-0.75, 0, 0],
    hipL: [-1.4, 0, 0.1], knL: [0.5, 0, 0], hipR: [-1.4, 0, -0.1], knR: [0.5, 0, 0],
  }),
  dejected: pose(null, {
    hipsPos: [0, -0.02, 0], spine: [0.15, 0, 0], neck: [0.55, 0, 0],
    shL: [0.1, 0, 0.08], elL: [-0.25, 0, 0], shR: [-0.6, 0, -0.1], elR: [-2.1, 0, 0],
    hipL: [0, 0, 0.05], knL: [0.05, 0, 0], hipR: [0, 0, -0.05], knR: [0.05, 0, 0],
  }),
  victory: pose(null, {
    hipsPos: [0, 0, 0], chest: [-0.15, 0, 0], neck: [-0.35, 0, 0],
    shL: [-2.75, 0, 0.45], elL: [-0.25, 0, 0], shR: [-2.75, 0, -0.45], elR: [-0.25, 0, 0],
    hipL: [0, 0, 0.12], hipR: [0, 0, -0.12],
  }),
  // kneeling in the opponent's guard, leaning over them
  top: pose(null, {
    hipsPos: [0, -0.46, 0],
    spine: [0.55, 0, 0], chest: [0.3, 0, 0], neck: [-0.35, 0, 0],
    shL: [-1.2, 0, 0.35], elL: [-0.7, 0, 0], shR: [-1.2, 0, -0.35], elR: [-0.7, 0, 0],
    hipL: [-0.1, 0, 0.3], knL: [1.75, 0, 0], hipR: [-0.1, 0, -0.3], knR: [1.75, 0, 0],
  }),
  // flat on the back with the legs wrapped up in guard
  bottom: pose(null, {
    hipsPos: [0, -0.8, 0],
    hips: [-1.42, 0, 0], spine: [-0.05, 0, 0], neck: [0.55, 0, 0],
    shL: [-1.5, 0, 0.3], elL: [-0.9, 0, 0], shR: [-1.5, 0, -0.3], elR: [-0.9, 0, 0],
    hipL: [-1.15, 0, 0.5], knL: [1.45, 0, 0], hipR: [-1.15, 0, -0.5], knR: [1.45, 0, 0],
  }),
  // knocked down / out
  down: pose(null, {
    hipsPos: [0, -0.84, 0],
    hips: [-1.52, 0.1, 0], neck: [0.1, 0.5, 0],
    shL: [-0.4, 0, 1.25], elL: [-0.4, 0, 0], shR: [-0.3, 0, -1.1], elR: [-0.9, 0, 0],
    hipL: [-0.15, 0, 0.18], knL: [0.25, 0, 0], hipR: [-0.45, 0, -0.1], knR: [0.9, 0, 0],
  }),
  // sitting up, dazed (between a knockdown and getting up)
  sitting: pose(null, {
    hipsPos: [0, -0.78, 0],
    hips: [-0.35, 0, 0], spine: [0.25, 0, 0], neck: [0.3, 0, 0],
    shL: [0.6, 0, 0.35], elL: [-0.2, 0, 0], shR: [0.6, 0, -0.35], elR: [-0.2, 0, 0],
    hipL: [-1.0, 0, 0.2], knL: [1.6, 0, 0], hipR: [-1.0, 0, -0.2], knR: [1.6, 0, 0],
  }),
  ref: pose(null, {
    hipsPos: [0, -0.02, 0], neck: [0.05, 0, 0],
    shL: [-0.15, 0, 0.12], elL: [-1.3, 0, 0], shR: [-0.15, 0, -0.12], elR: [-1.3, 0, 0],
    hipL: [0, 0, 0.08], knL: [0.08, 0, 0], hipR: [0, 0, -0.08], knR: [0.08, 0, 0],
  }),
};

// referee holding the winner's hand up
POSES.refRaise = pose(POSES.ref, { shR: [-2.75, 0, -0.45], elR: [-0.2, 0, 0], neck: [-0.1, 0, 0] });

const S = STANCE;
// Attacks. Each is a list of [pose, seconds to hold the key, blend speed].
const JAB_EXT = pose(S, { shL: [-1.6, 0.05, 0.02], elL: [-0.05, 0, 0], chest: [0.08, -0.12, 0], spine: [0.12, 0.05, 0] });
const CROSS_EXT = pose(S, { shR: [-1.62, -0.1, 0.05], elR: [-0.05, 0, 0], chest: [0.12, 0.55, 0], spine: [0.15, 0.35, 0], hipR: [0.3, 0.6, -0.1], hipsPos: [0, -0.09, 0.06] });
const HOOK_L = pose(S, { shL: [-0.25, 0, 1.45], elL: [-1.55, 0, 0], chest: [0.1, -0.45, -0.05], spine: [0.1, -0.2, 0] });
const HOOK_L_LOAD = pose(S, { chest: [0.1, 0.35, 0], shL: [-0.5, 0, 0.9], elL: [-1.6, 0, 0] });
const UPPER_R_LOAD = pose(S, { hipsPos: [0, -0.14, 0], shR: [0.25, 0, -0.15], elR: [-1.5, 0, 0], chest: [0.25, 0.3, 0] });
const UPPER_R = pose(S, { hipsPos: [0, -0.04, 0.04], shR: [-1.15, 0, -0.05], elR: [-1.85, 0, 0], chest: [-0.12, 0.45, 0] });
const OVERHAND_LOAD = pose(S, { shR: [-1.6, 0, -0.9], elR: [-1.2, 0, 0], chest: [0, -0.2, 0.15] });
const OVERHAND = pose(S, { shR: [-2.05, 0.2, -0.25], elR: [-0.35, 0, 0], chest: [0.4, 0.6, -0.1], spine: [0.25, 0.3, 0], hipsPos: [0, -0.12, 0.1] });
const KICK_LOAD = pose(S, { hips: [0, 0.2, 0], hipR: [-0.4, 0.3, -0.5], knR: [1.4, 0, 0], shR: [0.4, 0, -0.5], elR: [-0.6, 0, 0] });
const BODY_KICK = pose(S, {
  hipsPos: [0, -0.04, 0], hips: [0, 0.75, -0.15], spine: [0, 0, 0.25], chest: [0.05, -0.3, 0.12],
  hipL: [0, 0.4, 0.06], knL: [0.12, 0, 0], hipR: [-0.2, 0.85, -1.35], knR: [0.15, 0, 0],
  shR: [0.6, 0, -0.55], elR: [-0.4, 0, 0], shL: [-0.9, 0, 0.3], elL: [-2.0, 0, 0],
});
const HEAD_KICK = pose(BODY_KICK, { hips: [0, 0.75, -0.35], spine: [0, 0, 0.45], hipR: [-0.2, 0.85, -1.95], knR: [0.05, 0, 0] });
const LEG_KICK = pose(S, {
  hipsPos: [0, -0.1, 0], hips: [0, 0.55, 0], chest: [0.1, -0.25, 0.05],
  hipR: [-0.3, 0.9, -0.75], knR: [0.25, 0, 0], shR: [0.5, 0, -0.4], elR: [-0.6, 0, 0],
});
const KNEE = pose(S, {
  hipsPos: [0, 0, 0.12], hips: [0, -0.1, 0], spine: [-0.15, 0, 0], neck: [0.3, 0, 0],
  shL: [-1.55, 0, -0.15], elL: [-1.15, 0, 0], shR: [-1.55, 0, 0.15], elR: [-1.15, 0, 0],
  hipR: [-1.75, 0, 0], knR: [1.9, 0, 0], hipL: [0, 0, 0.06], knL: [0.08, 0, 0],
});
const FLYING_KNEE = pose(KNEE, { hipsPos: [0, 0.38, 0.25], hipL: [0.5, 0, 0.1], knL: [1.4, 0, 0], shL: [-0.4, 0, 0.6], elL: [-1.2, 0, 0] });
const SLIP = pose(S, { hipsPos: [0, -0.15, 0], spine: [0.2, 0, -0.35], chest: [0.15, 0, -0.2], neck: [0.15, 0, -0.2] });
const SHOOT = pose(null, {
  hipsPos: [0, -0.42, 0.25], hips: [0.25, 0, 0], spine: [0.75, 0, 0], chest: [0.25, 0, 0], neck: [-0.7, 0, 0],
  shL: [-1.35, 0, 0.25], elL: [-0.55, 0, 0], shR: [-1.35, 0, -0.25], elR: [-0.55, 0, 0],
  hipL: [-1.15, 0, 0.12], knL: [1.65, 0, 0], hipR: [0.35, 0, -0.1], knR: [1.6, 0, 0],
});
const SPRAWL = pose(null, {
  hipsPos: [0, -0.55, -0.15], hips: [0.95, 0, 0], spine: [0.2, 0, 0], neck: [-0.6, 0, 0],
  shL: [-1.7, 0, 0.3], elL: [-0.4, 0, 0], shR: [-1.7, 0, -0.3], elR: [-0.4, 0, 0],
  hipL: [0.35, 0, 0.3], knL: [0.25, 0, 0], hipR: [0.35, 0, -0.3], knR: [0.25, 0, 0],
});
const CLINCH = pose(S, { shL: [-1.7, 0, -0.2], elL: [-1.3, 0, 0], shR: [-1.7, 0, 0.2], elR: [-1.3, 0, 0], spine: [0.35, 0, 0], neck: [0.25, 0, 0], hipsPos: [0, -0.1, 0.1] });
const TOUCH = pose(S, { shL: [-1.45, 0, 0.0], elL: [-0.15, 0, 0], shR: [-1.45, 0, 0.0], elR: [-0.15, 0, 0], chest: [0.1, 0, 0] });
const T = POSES.top, B = POSES.bottom;
const TAP_A = (base) => pose(base, { shL: [-0.6, 0, 1.0], elL: [-0.3, 0, 0] });
const TAP_B = (base) => pose(base, { shL: [-0.2, 0, 1.25], elL: [-0.1, 0, 0] });
const BLOCK_TOP = pose(B, { shL: [-1.2, 0, -0.2], elL: [-2.1, 0, 0], shR: [-1.2, 0, 0.2], elR: [-2.1, 0, 0], neck: [0.3, 0, 0] });

function hand(p, flip) {
  return flip ? mirror(p) : p;
}

/** A copy of a pose with some joints nudged by the given amounts (instead of replaced). */
function nudge(base, d) {
  const p = pose(base);
  for (const k in d) for (let i = 0; i < 3; i++) p[k][i] += d[k][i];
  return p;
}

// ---------------------------------------------------------------- highlight-reel strikes
// Spins turn the hips all the way round (y goes down by 2π); the animator unwinds the
// angle afterwards so the fighter never spins back the other way.
const FULL = -0.45 - Math.PI * 2;
const GUARD_UP = { shL: [-0.85, 0, 0.18], elL: [-1.75, 0, 0], shR: [-0.45, 0, -0.2], elR: [-2.3, 0, 0] };
const turn = (y, o = {}) => pose(S, { spine: [0.1, 0, 0], chest: [0.05, 0, 0], ...GUARD_UP, hips: [0, y, 0], ...o });
const LAND = pose(S, { hips: [0, FULL, 0] });

const SPIN_BACK_KICK = (head) => [
  [turn(-1.7, { neck: [0.1, 1.2, 0], hipsPos: [0, -0.06, 0] }), 0.08, 24],
  [turn(-2.7, { spine: [0.35, 0, 0], neck: [0, 1.1, 0], hipR: [-1.3, 0, 0], knR: [2.0, 0, 0], hipL: [-0.1, 0, 0], knL: [0.3, 0, 0] }), 0.08, 26],
  [turn(-Math.PI, {
    spine: [head ? 0.85 : 0.55, 0, 0], chest: [0.2, 0, 0], neck: [head ? -0.9 : -0.5, 0, 0],
    hipR: [head ? 1.85 : 1.4, 0, 0], knR: [0.04, 0, 0], hipL: [-0.15, 0, 0], knL: [0.25, 0, 0],
  }), 0.22, 30, head ? "head" : "body"],
  [turn(-4.4, { hipR: [-0.9, 0, 0], knR: [1.8, 0, 0] }), 0.1, 18],
  [turn(-5.6), 0.07, 18],
  [LAND, 0.08, 16],
];
const SPIN_HEEL_KICK = [
  [turn(-1.7, { neck: [0.1, 1.2, 0] }), 0.08, 24],
  [turn(-3.1, { hips: [0, -3.1, 0.25], hipR: [0.1, 0, -1.0], knR: [0.7, 0, 0], neck: [0, 1.0, 0] }), 0.08, 24],
  [turn(-4.5, { hips: [0, -4.5, 0.5], spine: [0, 0, 0.2], hipR: [-0.1, 0, -1.85], knR: [0.04, 0, 0], hipL: [0, 0, 0.1], knL: [0.25, 0, 0] }), 0.14, 28, "hook"],
  [turn(-5.5, { hipR: [0.1, 0, -0.6], knR: [0.6, 0, 0] }), 0.09, 18],
  [LAND, 0.1, 16],
];
const SPIN_FIST_FRAMES = (jump) => {
  const up = jump ? { hipsPos: [0, 0.3, 0.1], hipL: [-1.0, 0, 0], knL: [1.6, 0, 0], hipR: [-0.6, 0, 0], knR: [1.4, 0, 0] } : {};
  return [
    [turn(-1.8, { neck: [0.1, 1.2, 0], hipsPos: [0, jump ? -0.18 : -0.05, 0] }), 0.08, 24],
    [turn(-3.2, { ...up, neck: [0, 1.0, 0], shR: [-0.6, 0, -0.9], elR: [-1.2, 0, 0] }), 0.07, 26],
    [turn(-4.6, { ...up, shR: [-0.1, 0, -1.55], elR: [-0.1, 0, 0], chest: [0, -0.2, 0] }), 0.16, 30, "hook"],
    [turn(-5.7), 0.08, 18],
    [LAND, 0.08, 16],
  ];
};
const SPIN_ELBOW = [
  [turn(-1.8, { neck: [0.1, 1.2, 0] }), 0.08, 24],
  [turn(-3.3, { neck: [0, 1.0, 0], shR: [-0.2, 0, -1.2], elR: [-2.4, 0, 0] }), 0.07, 26],
  [turn(-4.3, { shR: [-0.15, 0.4, -1.5], elR: [-2.55, 0, 0], chest: [0.1, -0.25, 0] }), 0.16, 30, "hook"],
  [turn(-5.6), 0.08, 18],
  [LAND, 0.08, 16],
];
const TORNADO = [
  [turn(-1.6, { hipsPos: [0, -0.15, 0], knL: [0.7, 0, 0], knR: [0.7, 0, 0] }), 0.08, 22],
  [turn(-3.0, { hipsPos: [0, 0.3, 0.1], hipL: [-1.3, 0, 0.1], knL: [1.9, 0, 0], hipR: [-0.3, 0, 0], knR: [1.0, 0, 0] }), 0.08, 24],
  [turn(-4.5, { hipsPos: [0, 0.42, 0.15], hipL: [-1.0, 0, 0.1], knL: [1.9, 0, 0], hipR: [-1.2, 0, -0.9], knR: [0.5, 0, 0] }), 0.08, 24],
  [turn(-5.9, { hipsPos: [0, 0.38, 0.2], spine: [-0.15, 0, 0.2], hipL: [-0.6, 0, 0.1], knL: [1.8, 0, 0], hipR: [-2.1, 0, -0.55], knR: [0.04, 0, 0] }), 0.14, 28, "hook"],
  [turn(-6.5, { hipsPos: [0, 0.05, 0], hipR: [-0.6, 0, 0], knR: [0.8, 0, 0] }), 0.1, 18],
  [LAND, 0.08, 16],
];
// cartwheel: turn side-on, roll over the hands toward the opponent and chop the leg down
const wheel = (r, o = {}) => pose(null, { hips: [0, -1.57, r], ...o });
const CARTWHEEL = [
  [pose(S, { hips: [0, -1.4, 0], hipsPos: [0, -0.12, 0], shL: [-2.9, 0, 0.2], shR: [-2.9, 0, -0.2], elL: [-0.1, 0, 0], elR: [-0.1, 0, 0] }), 0.1, 18],
  [wheel(-1.5, { hipsPos: [0, -0.05, 0], shL: [0, 0, 2.9], shR: [0, 0, -2.9], hipL: [0, 0, 0.6], hipR: [0, 0, -0.9] }), 0.1, 22],
  [wheel(-3.1, { hipsPos: [0, 0.05, 0], shL: [0, 0, 2.95], shR: [0, 0, -2.95], hipL: [0, 0, 1.0], hipR: [0, 0, -1.0] }), 0.1, 22],
  [wheel(-4.3, { hipsPos: [0, 0.05, 0], shL: [0, 0, 2.2], shR: [0, 0, -2.6], hipL: [0, 0, 1.25], knL: [0.04, 0, 0], hipR: [0, 0, -0.5] }), 0.16, 28, "head"],
  [wheel(-5.6, { hipsPos: [0, -0.15, 0], hipL: [0, 0, 0.5], knL: [0.6, 0, 0], shL: [-1, 0, 0.6], shR: [-1, 0, -0.6] }), 0.1, 18],
  [pose(S, { hips: [0, -0.45, -Math.PI * 2] }), 0.1, 16],
];
// rolling thunder: a forward flip that brings the heel down on the head
const flip = (x, o = {}) => pose(null, { hips: [x, -0.2, 0], ...o });
const ROLLING_THUNDER = [
  [pose(S, { hipsPos: [0, -0.2, 0], spine: [0.4, 0, 0], knL: [0.8, 0, 0], knR: [0.8, 0, 0] }), 0.1, 18],
  [flip(1.5, { hipsPos: [0, -0.3, 0.1], shL: [-2.8, 0, 0.3], shR: [-2.8, 0, -0.3], hipL: [0.3, 0, 0], hipR: [0.3, 0, 0] }), 0.1, 22],
  [flip(3.0, { hipsPos: [0, -0.2, 0.2], shL: [-2.9, 0, 0.3], shR: [-2.9, 0, -0.3], hipL: [-0.3, 0, 0.2], hipR: [0.1, 0, -0.2] }), 0.1, 22],
  [flip(4.3, { hipsPos: [0, -0.05, 0.3], hipR: [-0.5, 0, -0.1], knR: [0.04, 0, 0], hipL: [-1.4, 0, 0.1], knL: [1.6, 0, 0], shL: [-1.2, 0, 0.8], shR: [-1.2, 0, -0.8] }), 0.16, 28, "head"],
  [flip(5.6, { hipsPos: [0, -0.2, 0.2], hipL: [-0.4, 0, 0], knL: [0.8, 0, 0], hipR: [-0.6, 0, 0], knR: [0.9, 0, 0] }), 0.1, 18],
  [pose(S, { hips: [Math.PI * 2, -0.45, 0] }), 0.1, 16],
];
const SUPERMAN = [
  [pose(S, { hipsPos: [0, -0.1, 0], hipR: [-1.2, 0.2, 0], knR: [1.5, 0, 0], shR: [0.2, 0, -0.3], elR: [-1.4, 0, 0] }), 0.12, 20],
  [pose(CROSS_EXT, {
    hipsPos: [0, 0.22, 0.2], spine: [0.35, 0.35, 0], chest: [0.15, 0.5, 0],
    hipR: [0.8, 0.3, -0.1], knR: [0.7, 0, 0], hipL: [-0.4, 0, 0.1], knL: [0.9, 0, 0],
  }), 0.2, 26, "head"],
];
const FRONT_KICK = (face) => [
  [pose(S, { hips: [0, -0.1, 0], spine: [-0.05, 0, 0], chest: [0, 0, 0], hipR: [-1.7, 0, 0], knR: [2.0, 0, 0] }), 0.1, 22],
  [pose(S, {
    hips: [face ? -0.3 : -0.12, -0.05, 0], spine: [face ? -0.15 : 0, 0, 0], chest: [0, 0, 0],
    hipR: [face ? -2.25 : -1.55, 0, 0], knR: [0.03, 0, 0], hipL: [0.15, 0, 0.05], knL: [0.15, 0, 0],
  }), 0.2, 28, face ? "head" : "body"],
];
const TEEP = [
  [pose(S, { hipL: [-1.6, 0, 0], knL: [1.9, 0, 0], hipsPos: [0, -0.05, 0] }), 0.1, 22],
  [pose(S, { hips: [-0.12, -0.35, 0], hipL: [-1.55, 0, 0], knL: [0.03, 0, 0], hipR: [0.2, 0.35, -0.1], knR: [0.1, 0, 0] }), 0.2, 28, "body"],
];
const OBLIQUE = [
  [pose(S, { hipL: [-0.9, 0, 0.1], knL: [1.3, 0, 0] }), 0.09, 22],
  [pose(S, { hips: [-0.1, -0.2, 0], hipL: [-0.75, -0.6, 0.1], knL: [0.04, 0, 0], spine: [0, 0, 0] }), 0.18, 28, "leg"],
];
const AXE = [
  [pose(S, { hips: [-0.3, -0.2, 0], spine: [-0.15, 0, 0], hipR: [-2.85, 0, -0.35], knR: [0.1, 0, 0], hipL: [0.15, 0, 0], knL: [0.1, 0, 0] }), 0.2, 14],
  [pose(S, { hips: [0.15, -0.2, 0], spine: [0.35, 0, 0], hipR: [-1.1, 0, 0], knR: [0.04, 0, 0] }), 0.18, 26, "head"],
];
const HOOK_KICK = [
  [pose(S, { hips: [0, -0.9, -0.35], hipL: [-1.3, 0, 0.5], knL: [1.7, 0, 0], spine: [0, 0, -0.2] }), 0.1, 22],
  [pose(S, { hips: [0, -1.1, -0.45], hipL: [-1.0, 0, 1.75], knL: [0.04, 0, 0], spine: [0, 0, -0.25] }), 0.08, 26],
  [pose(S, { hips: [0, -0.8, -0.45], hipL: [-1.5, 0, 1.55], knL: [1.3, 0, 0], spine: [0, 0, -0.25] }), 0.16, 26, "hook"],
];
const QUESTION_MARK = [
  [pose(S, { hips: [0, 0.35, 0], hipR: [-0.5, 0.6, -0.45], knR: [1.3, 0, 0] }), 0.12, 20],
  [pose(BODY_KICK, { hips: [0, 0.95, -0.55], hipR: [-0.55, 0.85, -2.1], knR: [1.1, 0, 0] }), 0.08, 22],
  [pose(HEAD_KICK, { hips: [0, 0.9, -0.55], hipR: [-0.45, 0.85, -2.25], knR: [0.04, 0, 0] }), 0.22, 30, "hook"],
];
const SWITCH = pose(mirror(S), { hipsPos: [0, -0.04, 0] });
const SWITCH_KICK = (jump) => [
  [jump ? pose(SWITCH, { hipsPos: [0, -0.2, 0], knL: [0.9, 0, 0], knR: [0.9, 0, 0] }) : SWITCH, 0.1, 22],
  [jump ? pose(mirror(HEAD_KICK), { hipsPos: [0, 0.35, 0.1], hipR: [-1.2, 0, 0], knR: [1.8, 0, 0] }) : mirror(BODY_KICK), 0.24, 24, jump ? "hook" : "body"],
];
const SHOWTIME = [
  [pose(S, { hipsPos: [0, 0.2, 0.1], hipL: [-1.4, 0, 0], knL: [1.6, 0, 0], shL: [-0.6, 0, 0.5], elL: [-1, 0, 0] }), 0.14, 18],
  [pose(HEAD_KICK, { hipsPos: [0, 0.5, 0.2], hipL: [0.5, 0, 0.1], knL: [1.2, 0, 0] }), 0.24, 26, "hook"],
];

/**
 * Builds the keyframes for a named technique: { frames, fwd, lungeFor }. Each frame is
 * [pose, seconds, blend speed, hit] where hit names the target ("head", "hook", "body", "leg", "ground")
 * on the frames that land. For ground strikes, base is the pose of the position they are thrown from.
 */
export function attack(move, n = 1, ground = false, base = null) {
  const m = String(move || "").toLowerCase();
  if (ground) return groundStrikes(m, n, base || POSES.top);
  const jab = [JAB_EXT, 0.14, 26, "head"], cross = [CROSS_EXT, 0.18, 26, "head"], hook = [HOOK_L, 0.18, 24, "hook"];
  const reset = [S, 0.06, 26];
  if (m.includes("spinning back kick")) return { frames: SPIN_BACK_KICK(!m.includes("body")), fwd: 0.25 };
  if (m.includes("spinning heel kick")) return { frames: SPIN_HEEL_KICK, fwd: 0.15 };
  if (m.includes("spinning back elbow")) return { frames: SPIN_ELBOW, fwd: 0.3 };
  if (m.includes("spinning back fist") || m.includes("spinning")) return { frames: SPIN_FIST_FRAMES(m.includes("jumping")), fwd: m.includes("jumping") ? 0.45 : 0.2 };
  if (m.includes("tornado")) return { frames: TORNADO, fwd: 0.3, lungeFor: 0.5 };
  if (m.includes("cartwheel")) return { frames: CARTWHEEL, fwd: 0.55, lungeFor: 0.7 };
  if (m.includes("rolling thunder")) return { frames: ROLLING_THUNDER, fwd: 0.6, lungeFor: 0.7 };
  if (m.includes("superman")) return { frames: SUPERMAN, fwd: 0.6, lungeFor: 0.4 };
  if (m.includes("front kick to the face")) return { frames: FRONT_KICK(true), fwd: 0.1 };
  if (m.includes("front kick")) return { frames: FRONT_KICK(false), fwd: 0.1 };
  if (m.includes("teep")) return { frames: TEEP, fwd: 0.05 };
  if (m.includes("oblique")) return { frames: OBLIQUE, fwd: 0.05 };
  if (m.includes("axe kick")) return { frames: AXE, fwd: 0.1 };
  if (m.includes("hook kick")) return { frames: HOOK_KICK, fwd: 0.1 };
  if (m.includes("question mark")) return { frames: QUESTION_MARK, fwd: 0.1 };
  if (m.includes("showtime")) return { frames: SHOWTIME, fwd: 0.5, lungeFor: 0.45 };
  if (m.includes("jumping switch kick")) return { frames: SWITCH_KICK(true), fwd: 0.35, lungeFor: 0.4 };
  if (m.includes("switch kick")) return { frames: SWITCH_KICK(false), fwd: 0.1 };
  if (m.includes("head kick")) return { frames: [[KICK_LOAD, 0.12, 16], [HEAD_KICK, 0.3, 20, "hook"]], fwd: 0.1 };
  if (m.includes("body kick")) return { frames: [[KICK_LOAD, 0.12, 16], [BODY_KICK, 0.3, 20, "body"]], fwd: 0.1 };
  if (m.includes("leg kick") || m.includes("calf kick")) return { frames: [[KICK_LOAD, 0.1, 16], [LEG_KICK, 0.26, 20, "leg"]] };
  if (m.includes("flying knee")) return { frames: [[pose(S, { hipsPos: [0, -0.2, 0] }), 0.15, 16], [FLYING_KNEE, 0.35, 16, "head"]], fwd: 0.55 };
  if (m.includes("knee")) return { frames: [[CLINCH, 0.2, 14], [KNEE, 0.24, 20, "body"]], fwd: 0.35 };
  if (m.includes("uppercut")) return { frames: [[UPPER_R_LOAD, 0.14, 18], [UPPER_R, 0.22, 24, "head"]], fwd: 0.15 };
  if (m.includes("overhand") || m.includes("right hand")) return { frames: [[OVERHAND_LOAD, 0.16, 16], [OVERHAND, 0.24, 24, "head"]], fwd: 0.3 };
  if (m.includes("1-2")) return { frames: [jab, reset, cross, reset, [HOOK_L_LOAD, 0.08, 20], hook], fwd: 0.2 };
  if (m.includes("hook")) return { frames: [[HOOK_L_LOAD, 0.12, 18], hook], fwd: 0.15 };
  if (m.includes("straight left")) return { frames: [[mirror(CROSS_EXT), 0.2, 24, "head"]], fwd: 0.25 };
  if (m.includes("jab") && !m.includes("cross") && n < 2) return { frames: [[JAB_EXT, 0.16, 28, "head"]], fwd: 0.15 };
  const frames = [jab, reset, cross];
  for (let i = 2; i < Math.min(n, 5); i++) frames.push(reset, i % 2 ? hook : cross);
  return { frames, fwd: 0.25 };
}

/** Punches and elbows from whatever position the striker is in. */
function groundStrikes(m, n, base) {
  const isSide = base === POSES.sideTop, isBack = base === POSES.backTop;
  let load, hit;
  if (isBack) {
    load = nudge(base, { chest: [0, -0.3, 0] });
    Object.assign(load, pose(load, { shR: [-1.0, 0, -1.3], elR: [-1.5, 0, 0] }));
    hit = nudge(base, { chest: [0.1, 0.35, 0] });
    Object.assign(hit, pose(hit, { shR: [-1.6, 0, -0.15], elR: [-0.3, 0, 0] }));
  } else if (isSide || m.includes("elbow")) {
    load = pose(nudge(base, { spine: [-0.25, 0, 0] }), { shR: [-2.9, 0, -0.5], elR: [-2.6, 0, 0] });
    hit = pose(nudge(base, { spine: [0.25, 0, 0], chest: [0.15, 0.3, 0] }), { shR: [-1.3, 0, -0.3], elR: [-2.6, 0, 0] });
    return { frames: [[load, 0.2, 14], [hit, 0.16, 26, "ground"]] };
  } else {
    load = pose(nudge(base, { spine: [-0.35, 0, 0] }), { shR: [-2.6, 0, -0.3], elR: [-1.6, 0, 0] });
    hit = pose(nudge(base, { spine: [0.3, 0, 0], chest: [0.15, 0.25, 0] }), { shR: [-1.05, 0, -0.1], elR: [-0.1, 0, 0] });
  }
  const frames = [];
  for (let i = 0; i < Math.min(Math.max(n, 1), 4); i++) {
    const f = i % 2 === 1;
    frames.push([hand(load, f), 0.13, 18], [hand(hit, f), 0.12, 28, "ground"]);
  }
  return { frames };
}

/** What a hit looks like on the receiving end, as a pose offset that fades out. */
export function hitOffset(kind, strength = 1) {
  const s = strength;
  switch (kind) {
    case "body": return { chest: [0.45 * s, 0, 0], spine: [0.25 * s, 0, 0], neck: [0.2 * s, 0, 0], hipsPos: [0, -0.05 * s, -0.08 * s] };
    case "leg": return { knL: [0.6 * s, 0, 0], hipL: [0.2 * s, 0, 0], hipsPos: [0, -0.07 * s, 0] };
    case "ground": return { neck: [0, 0.7 * s, 0], chest: [0, 0.2 * s, 0] };
    case "hook": return { neck: [-0.15 * s, 0.75 * s, 0.25 * s], chest: [-0.1 * s, 0.25 * s, 0], hipsPos: [0, 0, -0.05 * s] };
    default: return { neck: [-0.6 * s, 0.15 * s, 0], chest: [-0.28 * s, 0, 0], spine: [-0.12 * s, 0, 0], hipsPos: [0, 0, -0.1 * s] };
  }
}

// ---------------------------------------------------------------- ground positions
// Each position has a pose for the fighter on top and the one underneath; the arena
// places the two bodies (see GROUND in arena3d.js).
Object.assign(POSES, {
  halfTop: pose(T, {
    hipsPos: [0, -0.5, 0.05], spine: [0.85, 0.2, 0], chest: [0.25, 0, 0], neck: [-0.4, 0, 0],
    shL: [-1.4, 0, 0.5], elL: [-0.9, 0, 0], shR: [-1.0, 0, -0.6], elR: [-1.3, 0, 0],
    hipL: [-0.3, 0, 0.35], knL: [1.8, 0, 0], hipR: [0.1, 0, -0.25], knR: [1.5, 0, 0],
  }),
  halfBottom: pose(B, {
    hips: [-1.42, 0.35, 0.15], shL: [-1.7, 0, 0.4], elL: [-1.6, 0, 0], shR: [-1.2, 0, -0.2], elR: [-2.0, 0, 0],
    hipL: [-0.9, 0, 0.35], knL: [1.7, 0, 0], hipR: [-0.5, 0, -0.2], knR: [1.5, 0, 0],
  }),
  mountTop: pose(null, {
    hipsPos: [0, -0.52, 0], spine: [0.15, 0, 0], chest: [0.05, 0, 0], neck: [0.15, 0, 0],
    shL: [-0.9, 0, 0.35], elL: [-1.2, 0, 0], shR: [-0.9, 0, -0.35], elR: [-1.2, 0, 0],
    hipL: [-0.4, 0, 0.62], knL: [1.7, 0, 0], hipR: [-0.4, 0, -0.62], knR: [1.7, 0, 0],
  }),
  mountBottom: pose(null, {
    hipsPos: [0, -0.83, 0], hips: [-1.52, 0, 0], neck: [0.45, 0, 0],
    shL: [-1.8, 0, 0.25], elL: [-1.9, 0, 0], shR: [-1.8, 0, -0.25], elR: [-1.9, 0, 0],
    hipL: [-0.7, 0, 0.25], knL: [1.4, 0, 0], hipR: [-0.7, 0, -0.25], knR: [1.4, 0, 0],
  }),
  sideTop: pose(null, {
    hipsPos: [0, -0.5, 0], spine: [1.15, 0, 0], chest: [0.3, 0, 0], neck: [-0.6, 0, 0],
    shL: [-1.0, 0, -0.5], elL: [-1.0, 0, 0], shR: [-1.2, 0, 0.4], elR: [-1.4, 0, 0],
    hipL: [-0.1, 0, 0.35], knL: [1.75, 0, 0], hipR: [0.25, 0, -0.25], knR: [1.5, 0, 0],
  }),
  sideBottom: pose(null, {
    hipsPos: [0, -0.83, 0], hips: [-1.5, 0.2, 0], neck: [0.4, 0.4, 0],
    shL: [-1.9, 0, -0.2], elL: [-2.2, 0, 0], shR: [-1.6, 0, -0.3], elR: [-1.8, 0, 0],
    hipL: [-0.9, 0, 0.2], knL: [1.6, 0, 0], hipR: [-0.5, 0, -0.2], knR: [1.2, 0, 0],
  }),
  backTop: pose(null, {
    hipsPos: [0, -0.75, 0], hips: [-0.55, 0, 0], spine: [0.4, 0, 0], chest: [0.2, 0, 0], neck: [0.1, 0, 0],
    shL: [-1.5, 0, -0.35], elL: [-1.7, 0, 0], shR: [-1.5, 0, 0.35], elR: [-1.7, 0, 0],
    hipL: [-1.0, 0, 0.6], knL: [1.2, 0, 0], hipR: [-1.0, 0, -0.6], knR: [1.2, 0, 0],
  }),
  backBottom: pose(null, {
    hipsPos: [0, -0.78, 0], hips: [-0.3, 0, 0], spine: [0.15, 0, 0], neck: [0.1, 0, 0],
    shL: [-1.9, 0, -0.3], elL: [-1.9, 0, 0], shR: [-1.9, 0, 0.3], elR: [-1.9, 0, 0],
    hipL: [-1.2, 0, 0.15], knL: [1.0, 0, 0], hipR: [-1.2, 0, -0.15], knR: [1.0, 0, 0],
  }),
  headlockTop: pose(null, {
    hipsPos: [0, -0.32, 0], hips: [0.3, 0, 0], spine: [0.55, 0, 0], chest: [0.2, 0, 0], neck: [-0.5, 0, 0],
    shL: [-1.0, 0, -0.45], elL: [-1.7, 0, 0], shR: [-1.0, 0, 0.45], elR: [-1.7, 0, 0],
    hipL: [-1.3, 0, 0.25], knL: [1.75, 0, 0], hipR: [0.4, 0, -0.2], knR: [1.65, 0, 0],
  }),
  headlockBottom: pose(null, {
    hipsPos: [0, -0.5, 0], hips: [0.2, 0, 0], spine: [1.05, 0, 0], chest: [0.25, 0, 0], neck: [-0.2, 0, 0],
    shL: [-1.1, 0, 0.2], elL: [-1.2, 0, 0], shR: [-1.1, 0, -0.2], elR: [-1.2, 0, 0],
    hipL: [-0.25, 0, 0.15], knL: [1.75, 0, 0], hipR: [-0.25, 0, -0.15], knR: [1.75, 0, 0],
  }),
  legsTop: pose(null, {
    hipsPos: [0, -0.78, 0], hips: [-0.45, 0, 0], spine: [0.2, 0, 0], neck: [0.2, 0, 0],
    shL: [0.5, 0, 0.4], elL: [-0.3, 0, 0], shR: [0.5, 0, -0.4], elR: [-0.3, 0, 0],
    hipL: [-0.9, 0, 0.4], knL: [1.7, 0, 0], hipR: [-1.15, 0, -0.05], knR: [0.05, 0, 0],
  }),
  legsBottom: pose(null, {
    hipsPos: [0, -0.8, 0], hips: [-1.35, 0.3, 0], neck: [0.5, 0, 0],
    shL: [-1.2, 0, -0.4], elL: [-2.0, 0, 0], shR: [-1.2, 0, 0.4], elR: [-2.0, 0, 0],
    hipL: [-1.3, 0, 0.6], knL: [1.2, 0, 0], hipR: [-0.9, 0, -0.2], knR: [1.5, 0, 0],
  }),
  // top fighter fallen back for an armbar, legs across the chest
  armbarTop: pose(null, {
    hipsPos: [0, -0.82, 0], hips: [-1.45, 0, 0], neck: [0.5, 0, 0],
    shL: [-1.3, 0, -0.3], elL: [-1.3, 0, 0], shR: [-1.3, 0, 0.3], elR: [-1.3, 0, 0],
    hipL: [-0.75, 0, 0.25], knL: [0.35, 0, 0], hipR: [-0.75, 0, -0.25], knR: [0.35, 0, 0],
  }),
});
POSES.armbarBottom = pose(POSES.mountBottom, { shL: [-1.6, 0, 0.5], elL: [-0.05, 0, 0], shR: [-1.6, 0, -0.4], elR: [-1.2, 0, 0], hipL: [-0.2, 0, 0.2], knL: [0.4, 0, 0] });

/** Base poses for each ground position: [top, bottom]. */
export const GROUND_POSES = {
  guard: ["top", "bottom"], half: ["halfTop", "halfBottom"], side: ["sideTop", "sideBottom"], mount: ["mountTop", "mountBottom"],
  back: ["backTop", "backBottom"], headlock: ["headlockTop", "headlockBottom"], legs: ["legsTop", "legsBottom"], armbar: ["armbarTop", "armbarBottom"],
};

// ---------------------------------------------------------------- submissions
// Each hold has the attacker's grip and squeeze and the defender's reaction; the two
// "hold" poses stay as the bases until the next event, so a tap happens inside the hold.
function holdPair(name, att, attSq, def, defSq) {
  POSES[name + "Att"] = att;
  POSES[name + "Def"] = def;
  return {
    att: [[att, 0.3, 8], [attSq, 0.35, 6], [att, 0.25, 8], [attSq, 0.45, 6]],
    def: [[def, 0.3, 9], [defSq, 0.3, 9], [def, 0.3, 9], [defSq, 0.35, 9]],
    attHold: name + "Att", defHold: name + "Def",
  };
}
const P_ = (name, o) => pose(POSES[name], o);
const SUBS = {
  rnc: (() => {
    const att = P_("backTop", { shR: [-1.5, 0, 0.75], elR: [-2.2, 0, 0], shL: [-1.7, 0, -0.45], elL: [-2.4, 0, 0], neck: [0.3, -0.4, 0] });
    const def = P_("backBottom", { shL: [-2.4, 0, -0.6], elL: [-1.6, 0, 0], shR: [-2.4, 0, 0.6], elR: [-1.6, 0, 0], neck: [-0.4, 0, 0] });
    return { layout: "back", ...holdPair("rnc", att, nudge(att, { hips: [-0.2, 0, 0], spine: [-0.2, 0, 0] }), def, nudge(def, { neck: [-0.2, 0, 0], hipL: [0.5, 0, 0], knL: [-0.6, 0, 0] })) };
  })(),
  armTriangle: (() => {
    const att = P_("sideTop", { spine: [1.35, 0, 0], neck: [0.4, 0, 0], shL: [-1.3, 0, -0.7], elL: [-2.1, 0, 0], shR: [-1.3, 0, 0.7], elR: [-2.1, 0, 0] });
    const def = P_("sideBottom", { shL: [-2.9, 0, -0.6], elL: [-0.4, 0, 0], shR: [-1.5, 0, -0.3], elR: [-1.2, 0, 0], neck: [0.3, 0.6, 0] });
    return { layout: "side", ...holdPair("armTri", att, nudge(att, { hipsPos: [0, -0.05, 0], hipL: [-0.4, 0, 0], hipR: [-0.3, 0, 0] }), def, nudge(def, { hipL: [0.4, 0, 0], neck: [-0.2, 0, 0] })) };
  })(),
  kimuraTop: (() => {
    const att = P_("sideTop", { spine: [0.8, 0, 0], shL: [-1.0, 0, -0.2], elL: [-1.6, 0, 0], shR: [-1.0, 0, 0.4], elR: [-1.6, 0, 0] });
    const def = P_("sideBottom", { shL: [-0.6, 0, 1.3], elL: [-1.8, 0, 0] });
    return { layout: "side", ...holdPair("kimT", att, nudge(att, { chest: [0, 0.4, 0], spine: [-0.2, 0, 0] }), def, pose(def, { shL: [0.3, 0, 1.4], hips: [-1.5, -0.3, 0] })) };
  })(),
  americana: (() => {
    const att = P_("sideTop", { spine: [1.1, 0, 0], shL: [-1.4, 0, -0.2], elL: [-0.6, 0, 0], shR: [-1.4, 0, 0.3], elR: [-0.8, 0, 0] });
    const def = P_("sideBottom", { shL: [-0.2, 0, 1.5], elL: [-1.6, 0, 0] });
    return { layout: "side", ...holdPair("amer", att, nudge(att, { spine: [0.15, 0, 0], chest: [0, 0.25, 0] }), def, pose(def, { shL: [0, 0, 1.75] })) };
  })(),
  darce: (() => {
    const att = P_("headlockTop", { hips: [0.3, 0.5, 0], spine: [1.0, 0, 0], shL: [-1.2, 0, -0.6], elL: [-2.0, 0, 0], shR: [-1.2, 0, 0.6], elR: [-2.0, 0, 0] });
    const def = P_("headlockBottom", { shL: [-2.6, 0, -0.4], elL: [-0.8, 0, 0], neck: [0.2, 0.4, 0] });
    return { layout: "headlock", ...holdPair("darce", att, nudge(att, { chest: [-0.2, 0.4, 0], hipsPos: [0, -0.1, 0] }), def, nudge(def, { spine: [0.2, 0, 0] })) };
  })(),
  guillotineTop: (() => {
    const att = P_("headlockTop", { hipsPos: [0, -0.15, 0], spine: [0.5, 0, 0], shL: [-1.0, 0, -0.6], elL: [-2.1, 0, 0], shR: [-1.0, 0, 0.6], elR: [-2.1, 0, 0] });
    const def = P_("headlockBottom", { spine: [0.8, 0, 0], neck: [-0.2, 0, 0], shL: [-1.6, 0, -0.4], elL: [-1.6, 0, 0], shR: [-1.6, 0, 0.4], elR: [-1.6, 0, 0] });
    return { layout: "headlock", ...holdPair("guilT", att, nudge(att, { hips: [-0.35, 0, 0], spine: [-0.3, 0, 0], hipsPos: [0, 0.08, 0] }), def, nudge(def, { spine: [-0.2, 0, 0], hipsPos: [0, 0.08, 0] })) };
  })(),
  armbarTop: (() => {
    const att = POSES.armbarTop;
    const def = POSES.armbarBottom;
    return { layout: "armbar", ...holdPair("abT", att, nudge(att, { hips: [-0.15, 0, 0], hipsPos: [0, 0.05, 0], neck: [0.2, 0, 0] }), def, nudge(def, { hips: [0, 0.2, 0], knR: [0.5, 0, 0] })) };
  })(),
  triangle: (() => {
    const att = P_("bottom", { hips: [-1.35, 0, 0], hipL: [-1.85, 0, 0.35], knL: [1.75, 0, 0], hipR: [-1.6, 0, -0.3], knR: [1.3, 0, 0], shL: [-1.9, 0, -0.1], elL: [-1.2, 0, 0], shR: [-1.9, 0, 0.1], elR: [-1.2, 0, 0] });
    const def = P_("top", { hipsPos: [0, -0.42, 0], spine: [0.95, 0, 0], chest: [0.3, 0, 0], neck: [0.5, 0, 0], shL: [-0.6, 0, 0.3], elL: [-1.2, 0, 0], shR: [-1.3, 0, -0.4], elR: [-0.2, 0, 0] });
    return { layout: "guard", ...holdPair("tri", att, nudge(att, { hipL: [-0.2, 0, 0], knL: [0.15, 0, 0], hips: [0.15, 0, 0] }), def, nudge(def, { spine: [-0.25, 0, 0], neck: [-0.2, 0, 0] })) };
  })(),
  armbarBottom: (() => {
    const att = P_("bottom", { hips: [-1.4, 0.6, 0], hipL: [-2.2, 0, 0.35], knL: [0.6, 0, 0], hipR: [-1.3, 0, -0.5], knR: [1.6, 0, 0], shL: [-1.6, 0, 0.2], elL: [-0.8, 0, 0], shR: [-1.6, 0, -0.2], elR: [-0.8, 0, 0] });
    const def = P_("top", { spine: [0.5, 0, 0], neck: [0.3, 0, 0], shR: [-1.4, 0, 0], elR: [0, 0, 0] });
    return { layout: "guard", ...holdPair("abB", att, nudge(att, { hips: [-0.15, 0, 0], hipsPos: [0, 0.08, 0] }), def, nudge(def, { spine: [0.4, 0, 0] })) };
  })(),
  guillotineBottom: (() => {
    const att = P_("bottom", { hips: [-1.2, 0, 0], spine: [0.3, 0, 0], neck: [0.4, 0, 0], shL: [-1.4, 0, -0.6], elL: [-2.1, 0, 0], shR: [-1.4, 0, 0.6], elR: [-2.1, 0, 0], hipL: [-1.2, 0, 0.5], knL: [1.5, 0, 0], hipR: [-1.2, 0, -0.5], knR: [1.5, 0, 0] });
    const def = P_("top", { hipsPos: [0, -0.48, 0], spine: [1.1, 0, 0], chest: [0.35, 0, 0], neck: [0.5, 0, 0], shL: [-1.2, 0, 0.1], elL: [-1.6, 0, 0], shR: [-1.2, 0, -0.1], elR: [-1.6, 0, 0] });
    return { layout: "guard", ...holdPair("guilB", att, nudge(att, { hips: [-0.25, 0, 0], spine: [-0.4, 0, 0] }), def, nudge(def, { spine: [0.15, 0, 0] })) };
  })(),
  kimuraBottom: (() => {
    const att = P_("bottom", { hips: [-0.8, 0.5, 0], spine: [0.3, 0, 0], shL: [-1.1, 0, -0.3], elL: [-1.7, 0, 0], shR: [-1.3, 0, 0.4], elR: [-1.6, 0, 0] });
    const def = P_("top", { spine: [0.8, 0, 0], hips: [0, 0, 0.2], shR: [0.6, 0, -0.9], elR: [-1.6, 0, 0] });
    return { layout: "guard", ...holdPair("kimB", att, nudge(att, { hips: [-0.4, 0.3, 0] }), def, pose(def, { shR: [0.9, 0, -1.1] })) };
  })(),
  omoplata: (() => {
    const att = P_("bottom", { hips: [-0.6, 1.0, 0], hipL: [-1.5, 0, 0.8], knL: [1.7, 0, 0], hipR: [-1.0, 0, -0.2], knR: [1.6, 0, 0], shL: [-1.0, 0, -0.4], elL: [-0.6, 0, 0], shR: [-1.0, 0, 0.3], elR: [-0.6, 0, 0] });
    const def = P_("top", { hipsPos: [0, -0.55, 0], spine: [1.45, 0, 0], chest: [0.2, 0, 0], neck: [0.1, 0, 0], shR: [0.9, 0, -0.5], elR: [-1.2, 0, 0], shL: [-1.4, 0, 0.4], elL: [-0.2, 0, 0] });
    return { layout: "guard", ...holdPair("omo", att, nudge(att, { spine: [0.5, 0, 0] }), def, pose(def, { shR: [1.3, 0, -0.6] })) };
  })(),
  heelHook: (() => {
    const att = POSES.legsBottom;
    const def = P_("legsTop", { hips: [-0.7, 0, 0], shL: [-0.3, 0, 0.9], elL: [-0.4, 0, 0] });
    return { layout: "legs", ...holdPair("hh", att, nudge(att, { hips: [0, -0.6, 0] }), def, nudge(def, { hips: [-0.3, 0, 0], shR: [-1.8, 0, 0] })) };
  })(),
};

/** The animation for a submission attempt: { layout, att, def, attHold, defHold }. */
export function submission(name, fromBottom) {
  const m = String(name || "").toLowerCase();
  if (m.includes("rear-naked")) return SUBS.rnc;
  if (m.includes("arm-triangle")) return SUBS.armTriangle;
  if (m.includes("d'arce") || m.includes("darce")) return SUBS.darce;
  if (m.includes("americana")) return SUBS.americana;
  if (m.includes("heel hook")) return SUBS.heelHook;
  if (m.includes("omoplata")) return SUBS.omoplata;
  if (m.includes("triangle")) return SUBS.triangle;
  if (m.includes("armbar")) return fromBottom ? SUBS.armbarBottom : SUBS.armbarTop;
  if (m.includes("guillotine")) return fromBottom ? SUBS.guillotineBottom : SUBS.guillotineTop;
  if (m.includes("kimura")) return fromBottom ? SUBS.kimuraBottom : SUBS.kimuraTop;
  return fromBottom ? SUBS.triangle : SUBS.rnc;
}

// ---------------------------------------------------------------- takedowns
// { att, def, mat (seconds until they hit the canvas), fwd, dFwd, big }
const FALL_BACK = pose(null, { hipsPos: [0, -0.45, -0.1], hips: [-0.9, 0, 0], neck: [0.5, 0, 0], shL: [-1.6, 0, 0.7], elL: [-0.4, 0, 0], shR: [-1.6, 0, -0.7], elR: [-0.4, 0, 0], hipL: [-0.9, 0, 0.1], knL: [0.6, 0, 0], hipR: [-0.7, 0, -0.1], knR: [0.5, 0, 0] });
const LEGS_GRABBED = pose(S, {
  hips: [0, 0, 0], hipsPos: [0, 0.03, 0], spine: [-0.3, 0, 0], chest: [-0.2, 0, 0], neck: [0.35, 0, 0],
  shL: [-1.4, 0, 0.7], elL: [-0.5, 0, 0], shR: [-1.4, 0, -0.7], elR: [-0.5, 0, 0],
  hipL: [0, 0, 0.04], knL: [0.05, 0, 0], hipR: [0, 0, -0.04], knR: [0.05, 0, 0],
});
const DRIVE = pose(SHOOT, {
  hipsPos: [0, -0.3, 0.2], spine: [0.85, 0, 0], neck: [-0.6, 0, 0],
  shL: [-0.9, 0, -0.35], elL: [-1.2, 0, 0], shR: [-0.9, 0, 0.35], elR: [-1.2, 0, 0],
  hipL: [-1.0, 0, 0.1], knL: [1.3, 0, 0], hipR: [0.7, 0, -0.1], knR: [0.4, 0, 0],
});
const BODY_LOCK = pose(CLINCH, { hips: [0, 0, 0], shL: [-1.25, 0, -0.65], elL: [-1.5, 0, 0], shR: [-1.25, 0, 0.65], elR: [-1.5, 0, 0], spine: [0.25, 0, 0], neck: [0.1, 0.6, 0] });
const LEAN_BACK = pose(CLINCH, { hips: [0, 0, 0], spine: [-0.15, 0, 0], neck: [0.3, -0.5, 0], shL: [-1.5, 0, 0.5], elL: [-1.3, 0, 0], shR: [-1.5, 0, -0.5], elR: [-1.3, 0, 0] });
const LIFTED = (y, z, x, o = {}) => pose(null, {
  hipsPos: [0, y, z], hips: [x, 0, 0], neck: [0.3, 0, 0], shL: [-1.2, 0, 0.6], elL: [-0.6, 0, 0], shR: [-1.2, 0, -0.6], elR: [-0.6, 0, 0],
  hipL: [-0.5, 0, 0.15], knL: [0.9, 0, 0], hipR: [-0.2, 0, -0.15], knR: [0.5, 0, 0], ...o,
});
const TD = {
  "double-leg": {
    att: [[pose(S, { hipsPos: [0, -0.22, 0] }), 0.1, 18], [SHOOT, 0.3, 14], [DRIVE, 0.4, 10]],
    def: [[S, 0.32, 9], [LEGS_GRABBED, 0.3, 12], [FALL_BACK, 0.3, 9]], mat: 0.85, fwd: 0.6, dFwd: 0.1,
  },
  "reactive takedown": {
    att: [[SHOOT, 0.25, 18], [DRIVE, 0.35, 12]],
    def: [[pose(S, { hips: [0, 0.4, 0], hipR: [-0.6, 0.6, -0.6], knR: [1.0, 0, 0] }), 0.22, 14], [LEGS_GRABBED, 0.25, 12], [FALL_BACK, 0.3, 9]], mat: 0.7, fwd: 0.65, dFwd: 0.05,
  },
  "single-leg": {
    att: [[SHOOT, 0.3, 14], [pose(S, { hips: [0, 0.3, 0], hipsPos: [0, -0.2, 0], spine: [0.55, 0, 0], neck: [-0.3, 0, 0], shL: [-0.9, 0, -0.5], elL: [-1.4, 0, 0], shR: [-0.9, 0, 0.2], elR: [-1.4, 0, 0] }), 0.7, 9]],
    def: [[S, 0.28, 9],
      [pose(S, { hips: [0, 0, 0], hipL: [-1.1, 0, 0.1], knL: [0.35, 0, 0], hipR: [0.05, 0, -0.05], knR: [0.2, 0, 0], hipsPos: [0, 0.06, 0], spine: [-0.15, 0, 0], shL: [-0.4, 0, 1.2], shR: [-0.4, 0, -1.2] }), 0.18, 14],
      [pose(S, { hips: [0, 0, 0], hipL: [-1.1, 0, 0.1], knL: [0.35, 0, 0], hipR: [0.05, 0, -0.05], knR: [0.55, 0, 0], hipsPos: [0, -0.04, 0], spine: [-0.1, 0, 0], shL: [-0.6, 0, 1.0], shR: [-0.6, 0, -1.0] }), 0.16, 14],
      [pose(S, { hips: [0, 0, 0], hipL: [-1.1, 0, 0.1], knL: [0.35, 0, 0], hipR: [0.05, 0, -0.05], knR: [0.2, 0, 0], hipsPos: [0, 0.08, 0], spine: [-0.2, 0, 0], shL: [-0.4, 0, 1.3], shR: [-0.4, 0, -1.3] }), 0.16, 14],
      [FALL_BACK, 0.3, 9]], mat: 1.1, fwd: 0.55, dFwd: 0.1,
  },
  "body lock": {
    att: [[CLINCH, 0.25, 12], [BODY_LOCK, 0.4, 10], [pose(BODY_LOCK, { hipR: [-0.5, 0.3, 0.45], knR: [0.1, 0, 0], spine: [0.5, 0, 0] }), 0.3, 12]],
    def: [[CLINCH, 0.3, 12], [LEAN_BACK, 0.35, 10], [FALL_BACK, 0.3, 9]], mat: 0.95, fwd: 0.35, dFwd: 0.3,
  },
  trip: {
    att: [[CLINCH, 0.3, 12], [pose(BODY_LOCK, { hipR: [-0.6, 0.4, 0.5], knR: [0.1, 0, 0], spine: [0.4, 0.3, 0] }), 0.35, 12]],
    def: [[CLINCH, 0.3, 12], [pose(LEAN_BACK, { hipL: [-0.6, 0, 0.3], knL: [0.1, 0, 0] }), 0.25, 12], [FALL_BACK, 0.3, 9]], mat: 0.8, fwd: 0.35, dFwd: 0.3,
  },
  "ankle pick": {
    att: [[pose(S, { hipsPos: [0, -0.3, 0], spine: [0.7, 0, 0], neck: [-0.5, 0, 0], shL: [-0.7, 0, 0.1], elL: [-0.2, 0, 0], shR: [-1.5, 0, -0.2], elR: [-0.6, 0, 0], knL: [1.0, 0, 0], knR: [0.9, 0, 0] }), 0.35, 14],
      [pose(S, { hipsPos: [0, -0.25, 0], spine: [0.35, 0, 0], shL: [0.3, 0, 0.2], elL: [-0.3, 0, 0], shR: [-1.6, 0, -0.1], elR: [-0.1, 0, 0] }), 0.3, 12]],
    def: [[S, 0.3, 9], [pose(S, { hips: [0, 0, 0], hipL: [-0.9, 0, 0], knL: [0.1, 0, 0], spine: [-0.4, 0, 0], neck: [0.3, 0, 0], shL: [-1.2, 0, 0.8], shR: [-1.2, 0, -0.8] }), 0.22, 14], [FALL_BACK, 0.3, 9]], mat: 0.8, fwd: 0.45, dFwd: 0.15,
  },
  suplex: {
    att: [[CLINCH, 0.25, 12], [pose(BODY_LOCK, { hipsPos: [0, -0.18, 0], knL: [0.8, 0, 0], knR: [0.8, 0, 0] }), 0.25, 12],
      [pose(BODY_LOCK, { hipsPos: [0, -0.05, 0], hips: [-0.5, 0, 0], spine: [-0.35, 0, 0], neck: [-0.4, 0, 0], shL: [-2.3, 0, -0.4], shR: [-2.3, 0, 0.4] }), 0.25, 12],
      [pose(BODY_LOCK, { hipsPos: [0, -0.4, -0.1], hips: [-1.2, 0, 0], spine: [-0.4, 0, 0], neck: [-0.5, 0, 0], shL: [-2.8, 0, -0.3], shR: [-2.8, 0, 0.3] }), 0.25, 12]],
    def: [[CLINCH, 0.28, 12], [LIFTED(0.12, 0.1, 0.1), 0.22, 12], [LIFTED(0.55, 0.45, 0.9), 0.22, 12], [LIFTED(0.2, 0.95, 2.2, { neck: [0.6, 0, 0] }), 0.22, 12]],
    mat: 0.95, fwd: 0.35, dFwd: 0.35, big: true,
  },
  slam: {
    att: [[pose(SHOOT, { hipsPos: [0, -0.3, 0.1] }), 0.25, 14],
      [pose(S, { hips: [0, 0, 0], hipsPos: [0, 0, 0], spine: [-0.1, 0, 0], neck: [-0.2, 0, 0], shL: [-2.4, 0, 0.3], elL: [-1.0, 0, 0], shR: [-2.4, 0, -0.3], elR: [-1.0, 0, 0], hipL: [0, 0, 0.1], knL: [0.1, 0, 0], hipR: [0, 0, -0.1], knR: [0.1, 0, 0] }), 0.4, 8],
      [pose(S, { hips: [0, 0, 0], hipsPos: [0, -0.35, 0.1], spine: [0.95, 0, 0], shL: [-1.4, 0, 0.2], elL: [-0.4, 0, 0], shR: [-1.4, 0, -0.2], elR: [-0.4, 0, 0], knL: [1.1, 0, 0], knR: [1.1, 0, 0] }), 0.25, 18]],
    def: [[LEGS_GRABBED, 0.25, 12], [LIFTED(0.6, 0.35, -1.35, { hipL: [-0.7, 0, 0.2], knL: [1.2, 0, 0], hipR: [-0.3, 0, -0.2], knR: [0.6, 0, 0], shL: [-2.0, 0, 0.8], shR: [-2.0, 0, -0.8] }), 0.4, 7],
      [LIFTED(-0.6, 0.35, -1.5), 0.25, 22]],
    mat: 0.85, fwd: 0.55, dFwd: 0.15, big: true,
  },
  "judo throw": {
    att: [[pose(CLINCH, { hips: [0, -1.6, 0], neck: [0, 1.0, 0] }), 0.2, 14],
      [pose(S, { hips: [0, -2.9, 0], hipsPos: [0, -0.18, 0], spine: [0.35, 0, 0], neck: [0, 0.9, 0], shL: [-1.4, 0, 0.3], elL: [-0.8, 0, 0], shR: [-1.0, 0, -0.5], elR: [-1.4, 0, 0], knL: [0.6, 0, 0], knR: [0.6, 0, 0] }), 0.25, 14],
      [pose(S, { hips: [0, -3.0, 0], hipsPos: [0, -0.25, 0], spine: [1.1, 0, 0], chest: [0.3, 0, 0], shL: [-0.6, 0, 0.6], shR: [-0.8, 0, -0.6], knL: [0.7, 0, 0], knR: [0.4, 0, 0] }), 0.3, 12]],
    def: [[CLINCH, 0.3, 12], [LIFTED(0.35, 0.35, 0.4, { hips: [0.4, 0, 1.2] }), 0.25, 12], [LIFTED(0.1, 0.7, 0.2, { hips: [0.2, 0, 2.6] }), 0.22, 12]],
    mat: 0.85, fwd: 0.3, dFwd: 0.35, big: true,
  },
};
TD["shoot"] = TD["double-leg"];

/** The animation for a takedown, by technique (older fights only have the log text). */
export function takedown(tech, text = "") {
  const t = String(tech || "").toLowerCase();
  if (TD[t]) return TD[t];
  const s = String(text).toLowerCase();
  for (const k of Object.keys(TD)) if (s.includes(k.split(" ")[0])) return TD[k];
  if (s.includes("slams")) return TD.slam;
  return TD["double-leg"];
}

/** Small adjustments while the fighters jockey for position on the mat. */
export function groundShift(baseName) {
  const b = POSES[baseName] || POSES.top;
  return [[nudge(b, { spine: [0.15, 0.2, 0], shL: [-0.25, 0, 0.2], shR: [0.2, 0, -0.1], hipL: [0.1, 0, 0.1] }), 0.45, 6]];
}

export const SEQUENCES = {
  slip: [[SLIP, 0.25, 22]],
  shoot: [[pose(S, { hipsPos: [0, -0.22, 0] }), 0.1, 18], [SHOOT, 0.45, 12]],
  sprawl: [[SPRAWL, 0.55, 14]],
  touch: [[TOUCH, 0.5, 8]],
  // waving off a glove touch and shaking the head
  refuse: [[pose(S, { shR: [-1.1, 0, -0.5], elR: [-0.4, 0, 0], neck: [0.05, 0.35, 0], chest: [0, -0.15, 0] }), 0.3, 12],
    [pose(S, { shR: [-1.0, 0, 0.3], elR: [-0.3, 0, 0], neck: [0.05, -0.35, 0], chest: [0, 0.15, 0] }), 0.25, 12],
    [pose(S, { neck: [0.1, 0.3, 0] }), 0.25, 10], [pose(S, { neck: [0.1, -0.3, 0] }), 0.25, 10]],
  block: [[BLOCK_TOP, 0.4, 14]],
  getUp: [[POSES.sitting, 0.5, 6], [pose(S, { hipsPos: [0, -0.35, 0], spine: [0.6, 0, 0], knL: [1.2, 0, 0], knR: [1.2, 0, 0] }), 0.4, 6]],
  rocked: [[pose(S, { hipsPos: [0, -0.16, -0.05], knL: [0.85, 0, 0], knR: [0.75, 0, 0], spine: [0.1, 0, 0.25], neck: [0.25, 0.3, 0.3], shL: [-0.3, 0, 0.5], shR: [-0.3, 0, -0.5] }), 0.55, 7],
    [pose(S, { hipsPos: [0, -0.12, 0], spine: [0.1, 0, -0.2], neck: [0.3, -0.2, -0.2] }), 0.45, 6]],
  celebrate: [[POSES.victory, 0.35, 8], [pose(POSES.victory, { hipsPos: [0, 0.18, 0], knL: [0.6, 0, 0], knR: [0.6, 0, 0] }), 0.22, 10], [POSES.victory, 0.35, 8],
    [pose(POSES.victory, { hipsPos: [0, 0.18, 0], knL: [0.6, 0, 0], knR: [0.6, 0, 0] }), 0.22, 10]],

  waveOff: [[pose(POSES.ref, { shL: [-1.55, 0, 1.0], elL: [-0.1, 0, 0], shR: [-1.55, 0, -1.0], elR: [-0.1, 0, 0] }), 0.3, 10],
    [pose(POSES.ref, { shL: [-1.55, 0, 0.1], elL: [-0.1, 0, 0], shR: [-1.55, 0, -0.1], elR: [-0.1, 0, 0] }), 0.3, 10],
    [pose(POSES.ref, { shL: [-1.55, 0, 1.0], elL: [-0.1, 0, 0], shR: [-1.55, 0, -1.0], elR: [-0.1, 0, 0] }), 0.4, 10]],
  tap: (baseName) => {
    const base = POSES[baseName] || POSES.bottom;
    return [[TAP_A(base), 0.16, 22], [TAP_B(base), 0.16, 22], [TAP_A(base), 0.16, 22], [TAP_B(base), 0.16, 22], [TAP_A(base), 0.16, 22], [TAP_B(base), 0.2, 22]];
  },
};

// ------------------------------------------------------------------ model

const shared = {};
function geo(key, make) {
  return shared[key] || (shared[key] = make());
}

let envMap = null;
/** The stage hands over a soft studio reflection map once the renderer exists. */
export function setFighterEnv(tex) {
  envMap = tex;
}

function mat(color, opts = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.62, metalness: 0.02, envMap, envMapIntensity: 0.35, ...opts });
}

/** A private copy of a shared geometry with a white vertex color per vertex (bruises are painted on top). */
function withColors(g) {
  const c = g.clone();
  c.setAttribute("color", new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count * 3).fill(1), 3));
  return c;
}

// Bruises: [x, y, z, radius, how hurt before it shows, color]. Face spots are in the head's space,
// body spots in the body's (bind pose) space, scaled by the fighter's width where it matters.
const PURPLE = [0.48, 0.24, 0.36], RED = [0.86, 0.38, 0.36], DARK = [0.36, 0.2, 0.32];
const FACE_BRUISES = [
  [0.02, 0.07, 0.09, 0.032, 0.22, RED], // forehead
  [-0.034, 0.022, 0.09, 0.028, 0.28, DARK], // black eye
  [0, 0.005, 0.11, 0.018, 0.33, RED], // nose
  [-0.052, -0.005, 0.08, 0.032, 0.4, PURPLE], // cheekbone
  [0.034, 0.022, 0.09, 0.028, 0.55, DARK], // the other eye
  [0.045, -0.055, 0.07, 0.034, 0.6, PURPLE], // jaw
  [0.052, -0.005, 0.08, 0.032, 0.7, PURPLE], // other cheek
  [0, -0.045, 0.1, 0.02, 0.5, RED], // split lip
];
const BODY_BRUISES = (w, cy) => [
  [0.12 * w, cy + 0.06, 0.06, 0.08, 0.15, RED, "body"], // ribs, left side
  [-0.11 * w, cy - 0.06, 0.07, 0.07, 0.35, PURPLE, "body"], // liver
  [-0.12 * w, cy + 0.06, 0.06, 0.08, 0.5, RED, "body"], // ribs, right side
  [0.14 * w, 0.68, 0.02, 0.09, 0.12, RED, "leg"], // outside of the lead thigh
  [0.1 * w, 0.42, -0.02, 0.07, 0.4, PURPLE, "leg"], // lead calf
  [0.12 * w, 0.72, 0.05, 0.07, 0.6, PURPLE, "leg"], // deep thigh bruise
  [-0.14 * w, 0.68, 0.02, 0.08, 0.55, RED, "leg"], // the other thigh
];

function paint(geo, spots, amount, base) {
  const P = geo.attributes.position.array, C = geo.attributes.color;
  const col = C.array;
  const start = [1, 1, 1];
  for (let v = 0, n = P.length / 3; v < n; v++) {
    const x = P[v * 3], y = P[v * 3 + 1], z = P[v * 3 + 2];
    if (base) base(x, y, z, start);
    let r = start[0], g = start[1], b = start[2];
    for (const [sx, sy, sz, rad, from, tint, region] of spots) {
      const a = amount(region);
      if (a <= from) continue;
      const d2 = ((x - sx) ** 2 + (y - sy) ** 2 + (z - sz) ** 2) / (rad * rad);
      if (d2 >= 1) continue;
      const k = Math.min(0.85, ((a - from) / (1 - from)) * 2.2) * (1 - d2) * (1 - d2);
      r += (tint[0] - r) * k;
      g += (tint[1] - g) * k;
      b += (tint[2] - b) * k;
    }
    col[v * 3] = r;
    col[v * 3 + 1] = g;
    col[v * 3 + 2] = b;
  }
  C.needsUpdate = true;
}

// Surface detail drawn by the shader, so it needs no textures or UVs: a 3D noise in the model's
// own (bind-pose) space, so it sticks to the skin as it moves. kinds: skin (pores and a blotchy
// tone), cloth (a fine weave), hair (strands), leather (grain). Every kind also darkens the
// baked creases ("occl" attribute) and fades its fine bumps out with distance so it never shimmers.
const NOISE_GLSL = `
varying vec3 vDetailPos;
varying float vOccl;
float dHash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float dNoise(vec3 x) {
  vec3 i = floor(x), f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(dHash(i), dHash(i + vec3(1, 0, 0)), f.x), mix(dHash(i + vec3(0, 1, 0)), dHash(i + vec3(1, 1, 0)), f.x), f.y),
             mix(mix(dHash(i + vec3(0, 0, 1)), dHash(i + vec3(1, 0, 1)), f.x), mix(dHash(i + vec3(0, 1, 1)), dHash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
vec3 dPerturb(vec3 surf_pos, vec3 surf_norm, vec2 dHdxy, float faceDir) {
  vec3 sx = dFdx(surf_pos), sy = dFdy(surf_pos);
  vec3 r1 = cross(sy, surf_norm), r2 = cross(surf_norm, sx);
  float det = dot(sx, r1) * faceDir;
  vec3 grad = sign(det) * (dHdxy.x * r1 + dHdxy.y * r2);
  return normalize(abs(det) * surf_norm - grad);
}`;
const DETAIL = {
  skin: { freq: 460, bump: 0.00011, tone: 0.11, toneFreq: 24, occl: [0.58, 0.46, 0.44], stretch: [1, 1, 1] },
  cloth: { freq: 900, bump: 0.00011, tone: 0.06, toneFreq: 60, occl: [0.45, 0.45, 0.48], stretch: [1, 1, 1] },
  hair: { freq: 520, bump: 0.00022, tone: 0.3, toneFreq: 260, occl: [0.5, 0.5, 0.5], stretch: [1, 0.12, 1] },
  leather: { freq: 420, bump: 0.0002, tone: 0.08, toneFreq: 40, occl: [0.45, 0.45, 0.45], stretch: [1, 1, 1] },
};
function addDetail(m, kind) {
  const D = DETAIL[kind];
  m.customProgramCacheKey = () => "detail-" + kind;
  m.onBeforeCompile = (sh) => {
    sh.vertexShader = sh.vertexShader
      .replace("#include <common>", "#include <common>\nattribute float occl;\nvarying vec3 vDetailPos;\nvarying float vOccl;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvDetailPos = position;\nvOccl = occl;");
    const st = `vec3(${D.stretch.map((v) => v.toFixed(3)).join(",")})`;
    sh.fragmentShader = sh.fragmentShader
      .replace("#include <common>", "#include <common>" + NOISE_GLSL)
      .replace("#include <map_fragment>", `#include <map_fragment>
        {
          vec3 q = vDetailPos * ${st};
          float tone = dNoise(q * ${D.toneFreq.toFixed(1)}) * 0.6 + dNoise(q * ${(D.toneFreq * 2.7).toFixed(1)}) * 0.4;
          diffuseColor.rgb *= 1.0 - ${D.tone.toFixed(3)} * 0.5 + ${D.tone.toFixed(3)} * tone;
          diffuseColor.rgb *= mix(vec3(1.0), vec3(${D.occl.join(",")}), clamp(vOccl, 0.0, 1.0));
        }`)
      .replace("#include <normal_fragment_maps>", `#include <normal_fragment_maps>
        {
          vec3 q = vDetailPos * ${st} * ${D.freq.toFixed(1)};
          float h = dNoise(q) * 0.65 + dNoise(q * 2.3) * 0.35;
          float fade = clamp(2.0 - length(fwidth(q)) * 1.6, 0.0, 1.0);
          vec2 dh = vec2(dFdx(h), dFdy(h)) * ${D.bump.toFixed(6)} * fade;
          normal = dPerturb(-vViewPosition, normal, dh, faceDirection);
        }`)
      .replace("#include <aomap_fragment>", `#include <aomap_fragment>
        reflectedLight.indirectDiffuse *= 1.0 - clamp(vOccl, 0.0, 1.0) * 0.6;
        reflectedLight.indirectSpecular *= 1.0 - clamp(vOccl, 0.0, 1.0) * 0.7;`);
  };
  return m;
}

/**
 * Light scattering under the skin: direct light wraps a little past the shadow line and comes
 * out warmer (red light travels furthest through flesh), so skin reads soft instead of plastic.
 */
const SSS_PARS = (() => {
  const src = THREE.ShaderChunk.lights_physical_pars_fragment;
  const from = "float dotNL = saturate( dot( geometryNormal, directLight.direction ) );\n\n\tvec3 irradiance = dotNL * directLight.color;";
  if (!src.includes(from)) return null;
  return src.replace(from, `float dotNLraw = dot( geometryNormal, directLight.direction );
	float dotNL = saturate( dotNLraw );
	// wrap lighting per color channel: red reaches furthest into the shadow side
	vec3 wrapK = vec3( 0.42, 0.2, 0.14 );
	vec3 wrapped = saturate( ( vec3( dotNLraw ) + wrapK ) / ( 1.0 + wrapK ) );
	vec3 irradiance = mix( vec3( dotNL ), wrapped, 0.85 ) * directLight.color;`);
})();

/** Skin: pores and tone variation, a soft reddish sheen at grazing angles, a thin clearcoat for sweat. */
function skinMat(color) {
  return addSSS(addDetail(new THREE.MeshPhysicalMaterial({
    color, roughness: 0.58, metalness: 0, envMap, envMapIntensity: 0.3, specularIntensity: 0.7,
    sheen: 0.55, sheenRoughness: 0.55, sheenColor: new THREE.Color("#ff8f74"), clearcoat: 0.1, clearcoatRoughness: 0.5,
  }), "skin"));
}

/** Adds the scattering to a material that already has its own onBeforeCompile. */
function addSSS(m) {
  if (!SSS_PARS) return m;
  const prev = m.onBeforeCompile;
  m.onBeforeCompile = (sh, r) => {
    if (prev) prev(sh, r);
    sh.fragmentShader = sh.fragmentShader.replace("#include <lights_physical_pars_fragment>", SSS_PARS);
  };
  const key = m.customProgramCacheKey;
  m.customProgramCacheKey = () => (key ? key.call(m) : "") + "-sss";
  return m;
}

// ------------------------------------------------------------------ shell hair
// Hair as a stack of thin shells over the scalp: each shell keeps only the cross-sections of
// individual strands at that height, so together they read as thousands of tufted hairs with
// soft, see-through edges (instead of a solid helmet). Strands taper and lower shells are darker,
// as light gets lost deep in the hair.
const furMats = new Map();
function furMat(color, layer, layers, density, clump, scalp) {
  // layer 0 is the scalp: solid under the hair, ragged at the hairline
  const key = [color, layer, layers, density, clump, scalp].join("|");
  if (furMats.has(key)) return furMats.get(key);
  const m = new THREE.MeshStandardMaterial({ color, roughness: 0.55, metalness: 0, envMap, envMapIntensity: 0.4, side: THREE.DoubleSide });
  const t = layer / layers;
  m.customProgramCacheKey = () => "fur";
  m.onBeforeCompile = (sh) => {
    sh.uniforms.furT = { value: t };
    sh.uniforms.furDensity = { value: density };
    sh.uniforms.furClump = { value: clump };
    sh.uniforms.furBase = { value: layer === 0 ? 1 : 0 };
    sh.uniforms.furScalp = { value: scalp ? 1 : 0 };
    sh.vertexShader = sh.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec2 vFurUv;")
      .replace("#include <begin_vertex>", "#include <begin_vertex>\nvFurUv = uv;");
    sh.fragmentShader = sh.fragmentShader
      .replace("#include <common>", `#include <common>
        varying vec2 vFurUv;
        uniform float furT, furDensity, furClump, furBase, furScalp;
        float furHash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }`)
      .replace("#include <map_fragment>", `#include <map_fragment>
        {
          // strands on a jittered grid; uv.x wraps around the head, so stretch it to keep them round
          vec2 g = vFurUv * vec2(furDensity * 2.0, furDensity);
          vec2 cell = floor(g);
          vec2 jitter = vec2(furHash(cell), furHash(cell + 17.0)) - 0.5;
          float len = 0.35 + 0.65 * furHash(cell + 3.0);
          // clumps: neighbouring strands share a little length, so the hair looks tufted
          len *= mix(1.0, 0.6 + 0.8 * furHash(floor(g / 4.0)), furClump);
          // the hairline: strands thin out and shorten over the last stretch of the cap (uv.y -> 0),
          // with a ragged, noisy edge instead of a straight line
          float ex = vFurUv.x * 40.0, ex2 = vFurUv.x * 13.0;
          float edgeNoise = mix(furHash(vec2(floor(ex), 0.0)), furHash(vec2(floor(ex) + 1.0, 0.0)), smoothstep(0.0, 1.0, fract(ex))) * 0.07
            + mix(furHash(vec2(floor(ex2), 5.0)), furHash(vec2(floor(ex2) + 1.0, 5.0)), smoothstep(0.0, 1.0, fract(ex2))) * 0.08;
          // a natural hairline on scalp caps: higher over the forehead, down at the temples and nape
          // (u = 0.25 is the front of the head, 0.75 the back)
          float front = max(0.0, cos((vFurUv.x - 0.25) * 6.2832));
          float back = max(0.0, cos((vFurUv.x - 0.75) * 6.2832));
          float lift = furScalp * (0.13 * pow(front, 1.5) - 0.04 * back);
          float hairline = smoothstep(0.0, 0.3, vFurUv.y - edgeNoise - lift);
          if (furBase > 0.5) {
            if (hairline < 0.12) discard;
            diffuseColor.rgb *= 0.45;
          } else {
            len *= hairline;
            float r = length(fract(g) - 0.5 - jitter * 0.4);
            if (furT > len || r > 0.5 * (1.0 - furT / max(len, 0.01))) discard;
            diffuseColor.rgb *= mix(0.3, 1.12, furT) * (0.85 + 0.3 * furHash(cell + 9.0));
          }
        }`);
  };
  furMats.set(key, m);
  return m;
}

/** Grows shell hair out of a hair mesh: layers shells, each pushed out along the normals. */
function growFur(base, color, { layers = 10, length = 0.012, density = 70, clump = 0.5, scalp = false } = {}) {
  const g = base.geometry;
  for (let i = 1; i <= layers; i++) {
    const shell = new THREE.Mesh(g, furMat(color, i, layers, density, clump, scalp));
    // push out along the normals by scaling around the cap's own center (cheap and close enough on a dome)
    const k = 1 + (length * i) / layers / 0.105;
    shell.scale.setScalar(k);
    shell.castShadow = false;
    shell.receiveShadow = false;
    shell.renderOrder = i;
    shell.userData.furShell = i; // distance LOD thins these out (character/cage_model.js)
    base.add(shell);
  }
  // the scalp under the hair: dark, with the same ragged hairline as the strands
  base.material = furMat(color, 0, layers, density, clump, scalp);
  base.userData.furBase = true; // a transformation's own hair hides this (and its shells with it)
}

const SOLE = new THREE.Vector3();

/** A hanging lock of hair, from 0 down to -len: knotted and twisted, not a smooth tube. */
function ropeGeo(r0, r1, len, lump) {
  const segs = Math.max(8, Math.round(len / 0.006));
  const g = new THREE.CylinderGeometry(r0, r1, len, 8, segs);
  g.translate(0, -len / 2, 0);
  const P = g.attributes.position;
  for (let i = 0; i < P.count; i++) {
    const x = P.getX(i), y = P.getY(i), z = P.getZ(i);
    const a = Math.atan2(z, x);
    const k = 1 + lump * Math.sin(-y * 330 + a * 2) + lump * 0.6 * Math.sin(-y * 120 + 1.3);
    // a gentle sway so a row of locks doesn't look combed
    P.setXYZ(i, x * k + Math.sin(-y * 18) * 0.004, y, z * k + Math.sin(-y * 13 + 1) * 0.003);
  }
  g.computeVertexNormals();
  return g;
}

const irisCache = {};
/** An iris: fibres radiating from a dark pupil, a darker ring around the edge. */
export function irisTexture(color) {
  if (irisCache[color]) return irisCache[color];
  const c = document.createElement("canvas");
  c.width = c.height = 128;
  const g = c.getContext("2d");
  const base = new THREE.Color(color);
  g.fillStyle = color;
  g.fillRect(0, 0, 128, 128);
  for (let i = 0; i < 260; i++) {
    const a = Math.random() * Math.PI * 2, r0 = 14 + Math.random() * 10, r1 = 40 + Math.random() * 22;
    const k = 0.6 + Math.random() * 0.9;
    g.strokeStyle = `rgba(${Math.min(255, base.r * 255 * k + 20) | 0},${Math.min(255, base.g * 255 * k + 14) | 0},${Math.min(255, base.b * 255 * k + 8) | 0},0.5)`;
    g.lineWidth = 1 + Math.random() * 1.5;
    g.beginPath();
    g.moveTo(64 + Math.cos(a) * r0, 64 + Math.sin(a) * r0);
    g.lineTo(64 + Math.cos(a + 0.05) * r1, 64 + Math.sin(a + 0.05) * r1);
    g.stroke();
  }
  const ring = g.createRadialGradient(64, 64, 40, 64, 64, 64);
  ring.addColorStop(0, "rgba(0,0,0,0)");
  ring.addColorStop(0.75, "rgba(0,0,0,0.55)");
  ring.addColorStop(1, "rgba(0,0,0,0.9)");
  g.fillStyle = ring;
  g.fillRect(0, 0, 128, 128);
  g.fillStyle = "#050404";
  g.beginPath();
  g.arc(64, 64, 17, 0, Math.PI * 2);
  g.fill();
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return (irisCache[color] = t);
}

function mesh(g, m, parent, x = 0, y = 0, z = 0) {
  const o = new THREE.Mesh(g, m);
  o.position.set(x, y, z);
  o.castShadow = true;
  o.receiveShadow = true;
  parent.add(o);
  return o;
}

/**
 * Build a fighter. opts: { look, weightClass (0-7), style, glove: corner color, ref: true for the referee }.
 * The returned object animates itself through update(dt).
 */
export class Fighter3D {
  constructor(opts = {}) {
    const look = typeof opts.look === "string" ? parseLook(opts.look) : opts.look || lookFromName(opts.name || "x");
    this.look = look;
    const wc = opts.weightClass ?? 3;
    const styleW = { Wrestler: 0.05, "Jiu-Jitsu": 0.01, Striker: -0.03 }[opts.style] || 0;
    // referees and people around town wear clothes instead of fight shorts and gloves
    const civ = opts.ref || opts.casual || opts.presenter;
    const width = opts.ref ? 0.98 : 0.9 + wc * 0.035 + styleW;
    const female = !!opts.female && !opts.ref;
    this.female = female;
    const height = opts.ref ? 1.0 : (0.95 + wc * 0.016) * (female ? 0.95 : 1);
    this.width = width;

    const skin = skinMat(LOOK_OPTIONS.skin[look.skin]);
    this.skinM = skin;
    this.skinBase = skin.color.clone();
    const hairM = addDetail(mat(LOOK_OPTIONS.hairColor[look.hairColor], { roughness: 0.62, envMapIntensity: 0.5 }), "hair");
    const shortsColor = opts.presenter ? opts.outfit || "#b91c38" : civ ? opts.pants || "#3c3f46" : LOOK_OPTIONS.shorts[look.shorts];
    const shortsM = addDetail(mat(shortsColor, { roughness: 0.62 }), "cloth");
    // each promotion has its own glove: the body, the knuckle panel and (for some) a fixed strap color
    const GS = { ...orgStyle(opts.org).gloves, ...(opts.eventGloves || {}) };
    this.gloveStyle = GS;
    const gloveM = addDetail(mat(GS.body, { roughness: 0.36, envMapIntensity: 0.6 }), "leather");
    const panelM = addDetail(mat(GS.panel, { roughness: 0.32, envMapIntensity: 0.7, metalness: GS.metal || 0.02 }), "leather");
    const bandM = mat(opts.glove || "#c8102e", { roughness: 0.5 });
    const shirtColor = opts.shirt || "#17181c";
    const shirtM = addDetail(mat(shirtColor, { roughness: 0.8 }), "cloth");
    const dark = mat("#120d0b", { roughness: 0.4 });

    const root = new THREE.Group();
    this.root = root;

    // the skeleton
    const bone = (parent, x, y, z) => {
      const b = new THREE.Bone();
      b.position.set(x, y, z);
      parent.add(b);
      return b;
    };
    const hips = bone(root, 0, 0.95, 0);
    this.hipsHome = 0.95;
    const spine = bone(hips, 0, 0.08, 0);
    const chest = bone(spine, 0, 0.18, 0);
    const neck = bone(chest, 0, 0.29, 0);
    const head = bone(neck, 0, 0.12, 0.01);
    const arms = {}, legs = {};
    for (const side of ["L", "R"]) {
      const sx = side === "L" ? 1 : -1;
      const sh = bone(chest, sx * (female ? 0.172 : 0.19) * width, 0.2, -0.01);
      arms["sh" + side] = sh;
      arms["el" + side] = bone(sh, 0, -0.27, 0);
      arms["hand" + side] = arms["el" + side];
      const hp = bone(hips, sx * (female ? 0.092 : 0.085) * width, -0.06, 0);
      legs["hip" + side] = hp;
      legs["kn" + side] = bone(hp, 0, -0.42, 0);
    }
    this.j = { hips, spine, chest, neck, ...arms, ...legs };

    // one smooth skin over the whole skeleton (built in a relaxed A-pose, then bound)
    const order = ["hips", "spine", "chest", "neck", "head", "shL", "elL", "shR", "elR", "hipL", "knL", "hipR", "knR"];
    const bones = { ...this.j, head };
    for (const [k, r] of Object.entries(BIND_POSE)) bones[k].rotation.set(...r);
    root.updateMatrixWorld(true);
    const kind = opts.presenter ? "presenter" : opts.ref ? "ref" : opts.casual ? "casual" : "fighter";
    const body = buildBody(bones, order, width, kind, { body: look.body, abs: look.abs, female, bikini: !!opts.bikini, step: opts.detail === "low" ? 0.022 : undefined });
    // Body geometry is cached across fighters; only the vertex-painted skin is private.
    this.sharedGeometry = new Set(Object.values(body).filter((g) => g && g.isBufferGeometry));
    // A clothing design is a print wrapped around the cloth; the geometry is shared, so only the
    // UVs (design-independent) and the map are added, and "Plain" leaves the flat colour alone.
    const design = look.design || 0;
    if (design) for (const g of [body.shorts, body.top, body.shirt, body.pants]) if (g) addCylinderUV(g);
    const printed = (m, color, on = true) => {
      const tex = on ? kitTexture(design, color) : null;
      if (!tex) return m;
      m.map = tex;
      m.color.setStyle("#ffffff");
      return m;
    };
    const skeleton = new THREE.Skeleton(order.map((n) => bones[n]));
    const skinned = (g, m) => {
      const sm = new THREE.SkinnedMesh(g, m);
      sm.castShadow = sm.receiveShadow = true;
      sm.frustumCulled = false;
      root.add(sm);
      sm.bind(skeleton);
      return sm;
    };
    skin.vertexColors = true;
    this.bodyMesh = skinned(withColors(body.skin), skin);
    if (body.shorts) {
      shortsM.side = THREE.DoubleSide;
      printed(shortsM, shortsColor, !civ);
      skinned(body.shorts, shortsM);
    }
    if (body.trim) {
      // the waistband and hem trim: darker on light shorts, lighter on dark ones
      const sc = new THREE.Color(LOOK_OPTIONS.shorts[look.shorts]);
      const lum = sc.r * 0.3 + sc.g * 0.59 + sc.b * 0.11;
      const trimM = addDetail(mat(lum > 0.35 ? sc.clone().multiplyScalar(0.35) : sc.clone().lerp(new THREE.Color("#ffffff"), 0.55), { roughness: 0.55 }), "cloth");
      trimM.side = THREE.DoubleSide;
      skinned(body.trim, trimM);
    }
    if (body.top) skinned(body.top, shortsM);
    if (body.shirt) {
      printed(shirtM, shirtColor, !opts.ref);
      skinned(body.shirt, shirtM);
    }
    if (body.pants) skinned(body.pants, shortsM);
    // tattoos are cut from the skin while the skeleton is still in the bind pose
    const wp = (b, y = 0) => b.localToWorld(new THREE.Vector3(0, y, 0));
    this.tattoos = addTattoos({
      root, skeleton, skinGeo: body.skin, look, text: opts.tattooText, envMap,
      cacheKey: [width.toFixed(3), kind, look.body, look.abs, opts.detail || ""].join("|"),
      frame: {
        width, chestY: wp(chest).y,
        axes: { tArmL: [wp(arms.shL), wp(arms.elL, -0.24)], tArmR: [wp(arms.shR), wp(arms.elR, -0.24)], tLegs: [wp(legs.hipL), wp(legs.knL, -0.4)] },
      },
    });
    for (const k of Object.keys(BIND_POSE)) bones[k].rotation.set(0, 0, 0);
    root.scale.setScalar(height);

    // the face is its own finer mesh on the head bone
    const face = new THREE.Mesh(withColors(buildHeadGeo(look.face || 0, opts.faceSeed || "", female)), skin);
    this.faceMesh = face;
    this.bruiseBase = { width, chestY: chest.getWorldPosition(new THREE.Vector3()).y };
    face.castShadow = face.receiveShadow = true;
    head.add(face);
    this.head = head;
    this.buildHead(head, skin, hairM, dark, look, opts.ref);

    for (const side of ["L", "R"]) {
      const el = arms["el" + side];
      if (!civ) {
        // open-finger MMA glove: padded knuckles, bare fingers curled under them, a wrist strap in the corner's color
        const G = buildGloveGeo(side === "L" ? -1 : 1);
        mesh(G.leather, gloveM, el);
        mesh(G.panel, panelM, el);
        mesh(geo("fingers" + side, () => withColors(G.fingers)), skin, el);
        const band = mesh(geo("band2", () => {
          const g = new THREE.CylinderGeometry(0.047, 0.047, 0.042, 24, 1);
          // rounded edges
          const P = g.attributes.position;
          for (let i = 0; i < P.count; i++) {
            const k = 1 - 0.06 * (Math.abs(P.getY(i)) / 0.021) ** 4;
            P.setX(i, P.getX(i) * k);
            P.setZ(i, P.getZ(i) * k);
          }
          g.computeVertexNormals();
          return g;
        }), bandM, el, 0, -0.212, 0);
        band.scale.z = 1.06;
      }
    }
    if (!civ) this.buildAccessories(look, width, head, legs);
    for (const side of ["L", "R"]) {
      if (!civ || opts.barefoot) continue;
      // shoes
      const shoe = new THREE.BoxGeometry(0.085, 0.06, 0.22);
      shoe.translate(0, -0.03, 0.05);
      const f = mesh(shoe, opts.ref ? dark : mat(opts.shoes || "#e8e8e8", { roughness: 0.7 }), legs["kn" + side], 0, -0.43, 0);
      f.scale.x = width;
    }

    this.cur = pose(POSES[opts.ref ? "ref" : opts.casual ? "relaxed" : "stance"]);
    this.base = opts.ref ? "ref" : opts.casual ? "relaxed" : "stance";
    this.queue = null;   // { frames, i, t }
    this.offsets = [];   // fading hit reactions
    this.time = Math.random() * 10;
    this.walk = 0;       // walking phase
    this.speed = 0;
    this.lastPos = new THREE.Vector3();
    if (!civ) this.buildBelt(width, opts.org);
    this.setDamage(0, 0, 0);
    this.applyPose(this.cur);
  }

  /** Headband or bandana, foot and ankle wraps, knee sleeves. */
  buildAccessories(look, width, head, legs) {
    const band = HEADBAND_COLORS[look.headband || 0];
    if (band) {
      const m = mat(band, { roughness: 0.7 });
      // across the forehead, dipping lower at the back
      const ring = mesh(geo("headband", () => new THREE.TorusGeometry(0.097, 0.0085, 8, 36)), m, head, 0, 0.062, -0.006);
      ring.rotation.x = Math.PI / 2 - 0.28;
      ring.scale.set(0.93, 1.07, 1.7);
      if (look.headband === 6) {
        // bandana: knot and tails at the back
        mesh(geo("knot", () => new THREE.SphereGeometry(0.016, 8, 6)), m, head, 0, 0.05, -0.105);
        for (const sx of [-1, 1]) {
          const tail = mesh(geo("tail", () => new THREE.BoxGeometry(0.018, 0.07, 0.006)), m, head, sx * 0.012, 0.015, -0.11);
          tail.rotation.z = sx * 0.3;
        }
      }
    }
    const wrap = look.wraps || 0;
    if (wrap) {
      const m = mat(wrap === 1 ? "#f1efe9" : "#141414", { roughness: 0.85 });
      for (const side of ["L", "R"]) {
        const kn = legs["kn" + side];
        const ankle = mesh(new THREE.CylinderGeometry(0.034 * width, 0.036 * width, wrap === 3 ? 0.12 : 0.07, 14), m, kn, 0, wrap === 3 ? -0.36 : -0.39, 0);
        ankle.scale.z = 1.05;
        if (wrap !== 3) {
          // a band around the arch of the foot
          const arch = mesh(geo("arch", () => new THREE.CylinderGeometry(0.042, 0.042, 0.05, 14)), m, kn, 0, -0.452, 0.05);
          arch.rotation.x = Math.PI / 2;
          arch.scale.set(0.95 * width, 1, 0.78);
        }
      }
    }
    const knees = look.knees || 0;
    if (knees) {
      const m = mat(knees === 1 ? "#141414" : "#ecebe6", { roughness: 0.75 });
      for (const side of ["L", "R"]) mesh(new THREE.CylinderGeometry(0.061 * width, 0.055 * width, 0.14, 16), m, legs["kn" + side], 0, -0.02, 0.004);
    }
  }

  /** The championship belt: worn around the waist, or carried over the shoulder on the walk out. */
  buildBelt(width, org) {
    this.belt = createPromotionBelt({ width, hips: this.j.hips, chest: this.j.chest, org, envMap });
  }

  /**
   * Visible fight damage, 0 (fresh) to 1 (a mess): cuts that open and bleed, a swelling eye,
   * bruised cheekbones, blood running down the face onto the chest, and sweat on the skin.
   */
  setDamage(d, body = this.bodyDamage || 0, leg = this.legDamage || 0) {
    d = Math.max(0, Math.min(1, d));
    const changed = Math.abs(d - (this.damage || 0)) + Math.abs(body - (this.bodyDamage || 0)) + Math.abs(leg - (this.legDamage || 0));
    if (changed < 0.01 && this.wounds) return;
    this.damage = d;
    this.bodyDamage = body;
    this.legDamage = leg;
    if (this.faceMesh) {
      paint(this.faceMesh.geometry, FACE_BRUISES, () => d, (x, y, z, out) => {
        // facial hair: skin color is multiplied by this, so darken toward the hair color
        // lips: a touch darker and redder than the skin
        const le = (x / 0.024) ** 2 + ((y + 0.041) / 0.012) ** 2;
        const lip = z > 0.085 && le < 1 ? Math.min(1, (1 - le) * 2.5) : 0;
        const k = Math.max(this.beardShade(x, y, z), this.browShade(x, y, z));
        if (!k) {
          out[0] = 1 - lip * 0.18;
          out[1] = out[2] = 1 - lip * 0.34;
          return;
        }
        const c = this.beardColor, sk = this.skinBase;
        out[0] = 1 + (Math.min(1, c.r / Math.max(0.05, sk.r)) - 1) * k;
        out[1] = 1 + (Math.min(1, c.g / Math.max(0.05, sk.g)) - 1) * k;
        out[2] = 1 + (Math.min(1, c.b / Math.max(0.05, sk.b)) - 1) * k;
      });
      const amt = { body, leg };
      paint(this.bodyMesh.geometry, BODY_BRUISES(this.bruiseBase.width, this.bruiseBase.chestY), (region) => amt[region]);
    }
    if (!this.wounds) this.buildWounds();
    const w = this.wounds;
    const show = (m, from) => {
      m.visible = d >= from;
      return m.visible;
    };
    show(w.forehead, 0.22);
    show(w.foreheadDrip, 0.32);
    if (show(w.noseBlood, 0.3)) w.noseBlood.scale.y = 0.6 + d;
    show(w.browCut, 0.42);
    if (show(w.cheekDrip, 0.48)) w.cheekDrip.scale.y = 0.5 + d * 0.9;
    show(w.mouth, 0.55);
    show(w.browCut2, 0.72);
    if (show(w.swell, 0.35)) w.swell.scale.set(0.9 + d * 0.4, 0.55 + (d - 0.35) * 0.9, 0.45 + d * 0.3);
    for (const [i, c] of w.chest.entries()) if (show(c, 0.55 + i * 0.1)) c.scale.y = 0.6 + d;
    // skin flushes and gets slick with sweat and blood
    if (this.skinM) {
      this.skinM.color.copy(this.skinBase).lerp(new THREE.Color("#b5534a"), d * 0.1);
      this.skinM.roughness = 0.55 - d * 0.12;
    }
  }

  buildWounds() {
    // a little self-glow keeps blood reading as red under the arena lights
    const blood = mat("#b3120f", { roughness: 0.22, metalness: 0.05, emissive: "#4a0000" });
    const fresh = mat("#d4201a", { roughness: 0.18, metalness: 0.05, emissive: "#5a0000" });
    const H = this.head, C = this.j.chest;
    const piece = (parent, w, h, d, x, y, z, m = blood, rz = 0) => {
      // a thin drip, rounded and tapering toward the bottom
      const g = new THREE.CylinderGeometry(w / 2, w / 5, h, 6, 1);
      g.scale(1, 1, d / w);
      g.translate(0, -h / 2, 0); // hangs down from its top, so scaling makes it drip longer
      const o = new THREE.Mesh(g, m);
      o.position.set(x, y, z);
      o.rotation.z = rz;
      o.visible = false;
      parent.add(o);
      return o;
    };
    this.wounds = {
      forehead: piece(H, 0.034, 0.006, 0.006, 0.015, 0.082, 0.088, fresh, 0.25),
      foreheadDrip: piece(H, 0.006, 0.05, 0.005, 0.022, 0.08, 0.091),
      browCut: piece(H, 0.026, 0.007, 0.006, 0.036, 0.06, 0.09, fresh, -0.3),
      cheekDrip: piece(H, 0.007, 0.07, 0.005, 0.045, 0.055, 0.084),
      browCut2: piece(H, 0.024, 0.006, 0.006, -0.034, 0.06, 0.09, fresh, 0.3),
      noseBlood: piece(H, 0.007, 0.022, 0.004, 0.004, -0.019, 0.108),
      mouth: piece(H, 0.006, 0.03, 0.004, 0.012, -0.048, 0.1),
      swell: (() => {
        // a puffy, discoloured upper lid closing over the eye
        const m = new THREE.Mesh(withColors(new THREE.SphereGeometry(0.016, 14, 10)), this.skinM);
        const c = m.geometry.attributes.color.array;
        for (let i = 0; i < c.length; i += 3) [c[i], c[i + 1], c[i + 2]] = [0.72, 0.48, 0.6];
        m.position.set(-0.034, 0.036, 0.088);
        m.visible = false;
        H.add(m);
        return m;
      })(),
      chest: [piece(C, 0.006, 0.12, 0.003, 0.02, 0.27, 0.118), piece(C, 0.005, 0.09, 0.003, -0.03, 0.26, 0.115), piece(C, 0.006, 0.15, 0.003, 0.06, 0.22, 0.104)],
    };
  }

  /** Out of the cage while injured: a head bandage and a strip of tape over the nose. */
  setInjured(on) {
    if (on && !this.bandage) {
      const white = mat("#f4f1ea", { roughness: 0.9 });
      const g = new THREE.Group();
      const band = new THREE.Mesh(new THREE.TorusGeometry(0.098, 0.016, 6, 24), white);
      band.rotation.x = Math.PI / 2 - 0.15;
      band.position.y = 0.06;
      band.scale.set(0.95, 1.05, 1);
      g.add(band);
      const tape = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.012, 0.01), white);
      tape.position.set(0, 0.01, 0.105);
      g.add(tape);
      this.head.add(g);
      this.bandage = g;
    }
    if (this.bandage) this.bandage.visible = !!on;
    this.injured = !!on;
  }

  /** null, "waist" or "shoulder". */
  setBelt(mode) {
    if (!this.belt) return;
    this.belt.waist.visible = mode === "waist";
    this.belt.sash.visible = this.belt.sash.userData.plate.visible = mode === "shoulder";
  }

  /** Shows or hides the painted eyebrows (repaints the face). */
  setBrows(on) {
    if (!this.faceMesh || this.hideBrows === !on) return;
    this.hideBrows = !on;
    const d = this.damage || 0;
    this.damage = -1; // force the repaint
    this.setDamage(d, this.bodyDamage || 0, this.legDamage || 0);
  }

  buildHead(head, skin, hairM, dark, look, ref) {
    // painted facial hair (brows, and beards below) takes the hair color; the referee is grey
    this.beardType = "None";
    this.beardColor = new THREE.Color(ref ? "#8d8d8d" : LOOK_OPTIONS.hairColor[look.hairColor]);
    const white = mat("#e6dcd2", { roughness: 0.25 });
    const iris = new THREE.MeshStandardMaterial({ map: irisTexture(["#4a2c18", "#2e1b10", "#4f6e3c", "#3d6488"][(look.skin + look.hair) % 4]), roughness: 0.3 });
    this.irisM = iris; // transformations recolour the eyes (character/cage_model.js)
    const pupil = mat("#050505", { roughness: 0.1 });
    void pupil;
    const cornea = new THREE.MeshPhysicalMaterial({ color: "#ffffff", transparent: true, opacity: 0.05, roughness: 0.03, clearcoat: 1, envMap, envMapIntensity: 0.5, depthWrite: false });
    const lashM = mat("#0b0806", { roughness: 0.8 });
    const browM = mat(LOOK_OPTIONS.hairColor[look.hairColor], { roughness: 0.9 });
    const lipM = mat(new THREE.Color(LOOK_OPTIONS.skin[look.skin]).multiplyScalar(0.72).getStyle(), { roughness: 0.45 });
    for (const sx of [-1, 1]) {
      const Fx = FACES[look.face || 0];
      mesh(geo("eyeWhite", () => new THREE.SphereGeometry(0.0118, 20, 14)), white, head, sx * 0.034, 0.029, 0.083).scale.y = Fx.eyeH || 1;
      const ir = mesh(geo("irisDisc2", () => new THREE.CircleGeometry(0.0066, 28)), iris, head, sx * 0.034, 0.029, 0.0951);
      ir.scale.y = Math.min(1, Fx.eyeH || 1);
      // a clear, wet cornea over the iris catches the highlights
      mesh(geo("cornea", () => new THREE.SphereGeometry(0.0072, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.5)), cornea, head, sx * 0.034, 0.029, 0.0905).rotation.x = Math.PI / 2;
      // upper lid: its edge crosses the top of the iris (lower on heavier, monolid eyes), lashes along the edge
      const F = FACES[look.face || 0];
      const lidCover = Math.PI * 0.42;
      const lid = mesh(geo("lid", () => withColors(new THREE.SphereGeometry(0.0128, 18, 8, 0, Math.PI * 2, 0, lidCover))), skin, head, sx * 0.034, 0.0295, 0.083);
      lid.rotation.x = -0.12 + (1 - (F.lid ?? 1)) * 0.3;
      lid.scale.y = Fx.eyeH || 1;
      const lash = mesh(geo("lash", () => new THREE.TorusGeometry(0.0128 * Math.sin(lidCover), 0.00075, 4, 20, Math.PI)), lashM, lid, 0, 0.0128 * Math.cos(lidCover), 0);
      lash.rotation.x = Math.PI / 2;
      lash.scale.set(1.03, 1.03, 1);
      // lower lid holds the bottom of the eye
      mesh(geo("lowLid", () => withColors(new THREE.SphereGeometry(0.0124, 18, 6, 0, Math.PI * 2, Math.PI * 0.655, Math.PI * 0.345))), skin, head, sx * 0.034, 0.029, 0.0832).scale.y = Fx.eyeH || 1;
      const brow = mesh(geo("brow2", () => {
        // a tapered brow: thick near the nose, thin at the tail
        const g = new THREE.CapsuleGeometry(0.004, 0.034, 3, 8);
        const P = g.attributes.position;
        for (let i = 0; i < P.count; i++) P.setX(i, P.getX(i) * (1.15 - 0.45 * ((P.getY(i) + 0.021) / 0.042)));
        g.computeVertexNormals();
        return g;
      }), browM, head, sx * 0.035, 0.0555, (F.browZ || 0) + Math.max(0.0935, 0.0735 + 0.0217 * (F.brow ?? 1) * (this.female ? 0.55 : 1)));
      brow.rotation.set(-0.25, -sx * 0.35, -sx * (Math.PI / 2 - 0.12));
      brow.scale.set(1, 1, 0.5);
      brow.visible = false; // brows are painted into the skin (see browShade); the mesh stays for the hit swelling
    }
    // lips are part of the face mesh; their color is painted in (see the face paint in setDamage)
    void lipM;
    if (ref) {
      // short, neat grey hair for the referee
      const cap = mesh(new THREE.SphereGeometry(0.104, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.45), mat("#8d8d8d", { roughness: 0.9 }), head, 0, 0.03, -0.004);
      cap.scale.set(0.95, 1.12, 1.05);
      return;
    }
    const capGeo = (cover) => new THREE.SphereGeometry(0.105, 18, 12, 0, Math.PI * 2, 0, Math.PI * cover);
    let h = LOOK_OPTIONS.hair[look.hair];
    // women opponents rarely shave their heads: a bald look becomes a ponytail
    if (this.female && h === "Bald" && !ref) h = "Ponytail";
    const shaved = () => {
      // short shaved sides, the scalp showing through
      const sides = mesh(capGeo(0.46), mat(LOOK_OPTIONS.hairColor[look.hairColor], { transparent: true, opacity: 0.42, roughness: 1 }), head, 0, 0.03, -0.006);
      sides.scale.set(0.95, 1.12, 1.05);
      sides.rotation.x = -0.25;
    };
    const hairColor = LOOK_OPTIONS.hairColor[look.hairColor];
    const fullCap = (cover = 0.5) => {
      const cap = mesh(capGeo(cover + 0.1), hairM, head, 0, 0.03, -0.006);
      cap.scale.set(0.97, 1.17, 1.08);
      cap.rotation.x = -0.2;
      growFur(cap, hairColor, { layers: 14, length: 0.011, density: 95, scalp: true });
      return cap;
    };
    const strandGeo = (r, len) => geo("strand" + r + len, () => ropeGeo(r, r * 0.8, len, 0.12));
    if (h === "Ponytail") {
      fullCap(0.5);
      mesh(geo("tie", () => new THREE.SphereGeometry(0.02, 8, 6)), hairM, head, 0, 0.05, -0.105);
      const tail = new THREE.Group();
      tail.position.set(0, 0.05, -0.11);
      tail.rotation.x = 0.35;
      head.add(tail);
      mesh(geo("ponytail", () => {
        const g = new THREE.CylinderGeometry(0.024, 0.008, 0.24, 10, 1);
        g.translate(0, -0.12, 0);
        return g;
      }), hairM, tail);
    }
    if (h === "Top bun") {
      fullCap(0.5);
      mesh(geo("topbun", () => new THREE.SphereGeometry(0.046, 12, 10)), hairM, head, 0, 0.135, -0.045);
    }
    if (h === "Fade") {
      shaved();
      const top = mesh(capGeo(0.3), hairM, head, 0, 0.04, -0.006);
      top.scale.set(0.98, 1.25, 1.08);
      top.rotation.x = -0.2;
    }
    if (h === "Undercut") {
      shaved();
      // long on top, swept back
      const top = mesh(geo("undercutTop", () => new THREE.SphereGeometry(0.07, 14, 10)), hairM, head, 0, 0.1, -0.02);
      top.scale.set(1.15, 0.6, 1.5);
      top.rotation.x = 0.15;
    }
    if (h === "Spiky") {
      fullCap(0.45);
      const spike = geo("spike", () => new THREE.ConeGeometry(0.022, 0.085, 5));
      mesh(spike, hairM, head, 0, 0.14, 0.0);
      for (let i = 0; i < 16; i++) {
        const a = (i / 16) * Math.PI * 2, rr = i % 2 ? 0.045 : 0.07;
        const sp = mesh(spike, hairM, head, Math.sin(a) * rr, 0.125 - rr * 0.35, Math.cos(a) * rr - 0.01);
        sp.rotation.set(Math.cos(a) * 0.6 - 0.2, 0, -Math.sin(a) * 0.6);
      }
    }
    if (h === "Curly") {
      fullCap(0.5);
      const curl = geo("curl", () => new THREE.SphereGeometry(0.024, 8, 6));
      for (let i = 0; i < 26; i++) {
        const a = (i / 26) * Math.PI * 2 * 2.3, lat = 0.25 + (i / 26) * 0.9;
        mesh(curl, hairM, head, Math.sin(a) * 0.09 * Math.sin(lat + 0.6), 0.04 + Math.cos(lat) * 0.085, Math.cos(a) * 0.095 * Math.sin(lat + 0.6) - 0.01);
      }
    }
    if (h === "Pompadour") {
      shaved();
      const pomp = mesh(geo("pomp", () => new THREE.SphereGeometry(0.07, 14, 10)), hairM, head, 0, 0.115, 0.01);
      pomp.scale.set(0.95, 0.65, 1.35);
      pomp.rotation.x = -0.3;
    }
    if (h === "Bob") {
      fullCap(0.5);
      const bob = mesh(geo("bob", () => new THREE.CylinderGeometry(0.104, 0.112, 0.13, 20, 1, true, Math.PI * 0.32, Math.PI * 1.36)), hairM, head, 0, -0.01, -0.006);
      bob.material = hairM;
      bob.scale.set(1, 1, 1.08);
    }
    if (h === "Double braids") {
      fullCap(0.5);
      const bead = geo("braidbead", () => new THREE.SphereGeometry(0.017, 8, 6));
      for (const sx of [-1, 1]) {
        for (let k = 0; k < 9; k++) mesh(bead, hairM, head, sx * (0.07 - k * 0.002), 0.0 - k * 0.028, -0.085 - k * 0.006);
      }
    }
    if (h === "Box braids") {
      fullCap(0.5);
      for (let i = 0; i < 26; i++) {
        const a = 1.0 + (i / 25) * (Math.PI * 2 - 2.0);
        const g = new THREE.Group();
        g.position.set(Math.sin(a) * 0.094, 0.06, Math.cos(a) * 0.1 - 0.006);
        g.rotation.y = a;
        head.add(g);
        const strand = mesh(strandGeo(0.0075, 0.3), hairM, g);
        strand.rotation.x = -0.15;
      }
    }
    if (h === "Buzz" || h === "Short" || h === "Man bun" || h === "Long") {
      const cap = mesh(capGeo(h === "Buzz" ? 0.55 : 0.6), hairM, head, 0, 0.03, -0.006);
      cap.scale.set(h === "Buzz" ? 0.94 : 0.97, h === "Buzz" ? 1.12 : 1.17, h === "Buzz" ? 1.05 : 1.08);
      cap.rotation.x = -0.2;
      growFur(cap, hairColor, h === "Buzz" ? { layers: 5, length: 0.004, density: 110, clump: 0.1, scalp: true } : { layers: 14, length: 0.012, density: 95, scalp: true });
    }
    if (h === "Short") {
      // a short fringe: a strip of longer hair over the front of the cap
      const fringe = mesh(geo("fringe2", () => new THREE.SphereGeometry(0.105, 18, 6, -0.9, 1.8, Math.PI * 0.18, Math.PI * 0.3)), hairM, head, 0, 0.03, -0.006);
      fringe.scale.set(0.98, 1.18, 1.09);
      fringe.rotation.x = -0.25;
      growFur(fringe, hairColor, { layers: 14, length: 0.02, density: 95, clump: 0.7 });
    }
    if (h === "Mohawk") {
      const strip = mesh(new THREE.BoxGeometry(0.04, 0.07, 0.2), hairM, head, 0, 0.1, -0.015);
      strip.rotation.x = -0.2;
      const sides = mesh(capGeo(0.4), mat(LOOK_OPTIONS.hairColor[look.hairColor], { transparent: true, opacity: 0.4, roughness: 1 }), head, 0, 0.03, -0.006);
      sides.scale.set(0.95, 1.12, 1.05);
    }
    if (h === "Man bun") mesh(new THREE.SphereGeometry(0.04, 10, 8), hairM, head, 0, 0.1, -0.1);
    if (h === "Long") {
      const back = mesh(new THREE.CylinderGeometry(0.085, 0.06, 0.2, 12, 1, false, Math.PI * 0.5, Math.PI), hairM, head, 0, -0.04, -0.03);
      back.rotation.x = 0.1;
    }
    if (h === "Afro") {
      // a full rounded afro sitting on top and back, hairline just above the brows
      const fro = mesh(new THREE.SphereGeometry(0.115, 20, 16), hairM, head, 0, 0.09, -0.035);
      fro.scale.set(1.12, 0.95, 1.0);
      // tightly coiled: dense, short-tufted, strongly clumped
      growFur(fro, hairColor, { layers: 18, length: 0.03, density: 120, clump: 0.9 });
    }
    if (h === "Braids") {
      // cornrows: tight rows running from the hairline to the nape
      // scalp shows between the rows
      const cap = mesh(capGeo(0.5), mat(LOOK_OPTIONS.hairColor[look.hairColor], { transparent: true, opacity: 0.35, roughness: 1 }), head, 0, 0.03, -0.006);
      cap.scale.set(0.94, 1.13, 1.04);
      cap.rotation.x = -0.3;
      const rowGeo = (r) => new THREE.TorusGeometry(r, 0.0125, 6, 28, Math.PI * 1.05);
      for (const x of [-0.066, -0.044, -0.022, 0, 0.022, 0.044, 0.066]) {
        const g = new THREE.Group();
        g.position.set(x, 0.02, 0);
        g.scale.set(1, 1.12, 1.02);
        g.rotation.x = -0.45;
        head.add(g);
        const row = mesh(rowGeo(0.1 * Math.sqrt(Math.max(0.2, 1 - (x / 0.095) ** 2)) + 0.004), hairM, g);
        row.rotation.y = -Math.PI / 2;
      }
    }
    if (h === "Dreadlocks") {
      // shoulder-length locs all around the sides and back, a few shorter ones falling over the forehead
      const cap = mesh(capGeo(0.5), hairM, head, 0, 0.03, -0.006);
      cap.scale.set(0.99, 1.2, 1.1);
      cap.rotation.x = -0.25;
      growFur(cap, hairColor, { layers: 5, length: 0.006, density: 40, clump: 0.8 });
      const locGeo = (len) => geo("loc2" + len, () => ropeGeo(0.0085, 0.007, len, 0.1));
      const tipGeo = geo("loctip2", () => new THREE.SphereGeometry(0.0078, 6, 5));
      const loc = (angle, y, ring, len, tilt) => {
        const g = new THREE.Group();
        g.position.set(Math.sin(angle) * ring * 0.95, y, Math.cos(angle) * ring * 1.05 - 0.006);
        g.rotation.y = angle;
        head.add(g);
        const strand = mesh(locGeo(len), hairM, g);
        strand.rotation.x = -tilt;
        mesh(tipGeo, hairM, strand, 0, -len, 0);
      };
      // lower ring: sides and back only, longest at the back
      for (let i = 0; i < 32; i++) {
        const a = 1.25 + (i / 31) * (Math.PI * 2 - 2.5);
        const back = Math.abs(Math.cos(a)) * (Math.cos(a) < 0 ? 1 : 0);
        loc(a, 0.06, 0.098, back > 0.5 ? 0.24 : 0.2, 0.22);
      }
      // upper ring adds volume on top
      for (let i = 0; i < 22; i++) {
        const a = 1.0 + (i / 21) * (Math.PI * 2 - 2.0);
        loc(a, 0.105, 0.08, 0.2, 0.42);
      }
      // a few shorter locs swept over the forehead
      // a few short locs falling to the sides of the forehead, clear of the eyes
      for (const a of [-0.8, -0.6, -0.4, 0.4, 0.6, 0.8]) loc(a, 0.118, 0.07, 0.075, 0.6);
    }
    // facial hair is painted into the skin (see beardShade)
    this.beardType = this.female ? "None" : LOOK_OPTIONS.beard[look.beard];
    this.beardColor = new THREE.Color(LOOK_OPTIONS.hairColor[look.hairColor]);
  }

  /** Eyebrows: an arched band of hair over each eye, thick near the nose and thinning at the tail. */
  browShade(x, y, z) {
    if (this.hideBrows) return 0; // Super Saiyan 3 has no eyebrows
    if (z < 0.07 || y < 0.04 || y > 0.075) return 0;
    const ax = Math.abs(x);
    if (ax < 0.012 || ax > 0.058) return 0;
    const t = (ax - 0.012) / 0.046; // 0 at the inner end, 1 at the tail
    const cy = 0.055 + 0.005 * Math.sin(t * Math.PI) - 0.003 * t + (this.browLift || 0);
    const half = (0.0055 - 0.003 * t) * (this.female ? 0.75 : 1);
    const d = Math.abs(y - cy) / half;
    if (d >= 1) return 0;
    const fade = Math.min(1, t * 6) * Math.min(1, (1 - t) * 5);
    return (1 - d * d) * fade * 0.95;
  }

  /** How much facial hair covers a point of the face (head space), 0..1. */
  beardShade(x, y, z) {
    const t = this.beardType;
    if (!t || t === "None" || z < -0.01) return 0;
    const fade = (v, a, b) => Math.max(0, Math.min(1, (v - a) / (b - a)));
    // soft-edged zones so the hair blends into the skin
    const le = (x / 0.026) ** 2 + ((y + 0.041) / 0.013) ** 2;
    const lips = z > 0.08 ? Math.max(0, Math.min(1, (1 - le) * 3)) : 0;
    const me = (x / 0.034) ** 2 + ((y + 0.024) / 0.009) ** 2;
    const moustache = z > 0.085 ? Math.max(0, Math.min(1, (1 - me) * 2)) : 0;
    const ce = (x / 0.032) ** 2 + ((y + 0.078) / 0.03) ** 2;
    const chin = Math.max(0, Math.min(1, (1 - ce) * 2.5));
    const jaw = fade(-y, 0.008, 0.04) * fade(z, -0.01, 0.03) * (1 - lips);
    if (lips > 0.9) return 0;
    if (t === "Goatee") return Math.max(moustache, chin) * 0.85;
    if (t === "Stubble") return Math.max(moustache * 0.6, jaw * 0.5);
    return Math.max(moustache, jaw) * 0.9;
  }

  setBase(name) {
    this.base = name;
  }

  /** Play keyframes, then settle back into the base pose. */
  play(frames, after) {
    if (!frames || !frames.length) return;
    this.queue = { frames, i: 0, t: 0 };
    if (after) this.base = after;
  }

  get busy() {
    return !!this.queue;
  }

  hit(kind, strength = 1) {
    this.offsets.push({ o: hitOffset(kind, strength), t: 0, dur: 0.38 + 0.2 * strength });
  }

  stopActions() {
    this.queue = null;
  }

  /** Jump straight to the base pose (used when restoring a fight mid-way). */
  snap() {
    this.queue = null;
    this.offsets = [];
    this.cur = pose(POSES[this.base]);
    this.applyPose(this.cur);
  }

  /** World position of a hand or the head, for hit sparks and camera framing. */
  worldPoint(part) {
    const v = new THREE.Vector3();
    const node = part === "head" ? this.head : this.j[part] || this.j.chest;
    if (part === "handL" || part === "handR") v.set(0, -0.27, 0);
    node.localToWorld(v);
    return v;
  }

  update(dt) {
    this.time += dt;
    let target;
    let rate = 9;
    if (this.queue) {
      const q = this.queue;
      q.t += dt;
      while (q.i < q.frames.length && q.t > q.frames[q.i][1]) {
        q.t -= q.frames[q.i][1];
        q.i++;
      }
      if (q.i >= q.frames.length) {
        this.queue = null;
      } else {
        target = pose(q.frames[q.i][0]);
        rate = q.frames[q.i][2];
      }
    }
    if (!target) target = this.idlePose();

    // a finished spin or flip leaves the hips a whole turn away from where they are headed:
    // drop the extra turn instead of unwinding it
    for (let i = 0; i < 3; i++) {
      const d = target.hips[i] - this.cur.hips[i];
      if (Math.abs(d) > Math.PI) this.cur.hips[i] += Math.PI * 2 * Math.round(d / (Math.PI * 2));
    }

    // fading hit reactions add on top
    this.offsets = this.offsets.filter((h) => (h.t += dt) < h.dur);
    for (const h of this.offsets) {
      const k = Math.sin(Math.min(1, h.t / h.dur) * Math.PI) * (h.t < 0.08 ? 1.4 : 1);
      for (const key in h.o) for (let i = 0; i < 3; i++) target[key][i] += h.o[key][i] * k;
    }

    // footwork when the whole fighter is sliding around
    const pos = this.root.position;
    const moved = this.lastPos.distanceTo(pos);
    this.lastPos.copy(pos);
    const sp = dt > 0 ? moved / dt : 0;
    this.speed += (sp - this.speed) * Math.min(1, dt * 8);
    // no footsteps in the air (flying, jumping): the owner sets `airborne`
    const gaitOk = (this.base === "stance" || this.base === "relaxed" || this.base === "ref" || this.base === "dejected") && !this.queue && !this.airborne;
    this.gait = (this.gait || 0) + ((gaitOk && this.speed > 0.15 ? 1 : 0) - (this.gait || 0)) * Math.min(1, dt * 6);
    if (this.gait > 0.01 && gaitOk) {
      if (this.base === "stance") {
        // fight footwork: short shuffling steps, guard up
        this.walk += moved * 14;
        const a = Math.min(1, this.speed / 1.2) * 0.22 * this.gait;
        target.hipL[0] += Math.sin(this.walk) * a;
        target.knL[0] += Math.max(0, Math.cos(this.walk)) * a * 1.3;
        target.hipR[0] -= Math.sin(this.walk) * a;
        target.knR[0] += Math.max(0, -Math.cos(this.walk)) * a * 1.3;
      } else {
        this.addGait(target, moved);
        rate = Math.max(rate, 22); // follow the stride closely instead of smoothing it away
      }
    }

    const k = 1 - Math.exp(-dt * rate);
    for (const key in target) for (let i = 0; i < 3; i++) this.cur[key][i] += (target[key][i] - this.cur[key][i]) * k;
    this.applyPose(this.cur);
  }

  /**
   * Walking and running. One stride (two steps) covers more ground the faster you go, so the feet
   * keep pace with the ground; legs swing from the hip with the knee folding on the swing forward,
   * arms swing against the legs (bent more when running), the body leans in, the shoulders and
   * hips twist against each other and the body bobs once per step.
   */
  addGait(target, moved) {
    const v = this.speed, g = this.gait;
    const run = Math.max(0, Math.min(1, (v - 2.4) / 2.6)); // 0 = walking, 1 = running
    const stride = 1.35 + run * 1.2;
    this.walk += (moved / stride) * Math.PI * 2;
    const ph = this.walk, sn = Math.sin(ph), cs = Math.cos(ph);
    const lerp = (a, b) => a + (b - a) * run;
    const hipA = lerp(0.38, 0.62) * g, kneeA = lerp(0.75, 1.55) * g;
    // hips: negative x swings the leg forward; the left leg leads when sin > 0
    target.hipL[0] += -hipA * sn + lerp(0, -0.12) * g;
    target.hipR[0] += hipA * sn + lerp(0, -0.12) * g;
    // knee folds while the leg swings forward (and a little on landing)
    const swingL = Math.max(0, cs), swingR = Math.max(0, -cs);
    target.knL[0] += kneeA * swingL ** 1.4 + 0.12 * g * Math.max(0, -cs);
    target.knR[0] += kneeA * swingR ** 1.4 + 0.12 * g * Math.max(0, cs);
    // arms against the legs; elbows bend more as you run
    const armA = lerp(0.32, 0.75) * g;
    target.shL[0] += armA * sn;
    target.shR[0] -= armA * sn;
    target.elL[0] += lerp(-0.1, -1.2) * g - Math.max(0, -sn) * 0.25 * g;
    target.elR[0] += lerp(-0.1, -1.2) * g - Math.max(0, sn) * 0.25 * g;
    target.shL[2] += lerp(0, 0.08) * g;
    target.shR[2] -= lerp(0, 0.08) * g;
    // the body: lean into it, shoulders twist against the hips, a bob on every step
    target.spine[0] += lerp(0.04, 0.2) * g;
    target.neck[0] -= lerp(0.02, 0.12) * g;
    target.chest[1] += lerp(0.1, 0.16) * sn * g;
    target.hips[1] -= lerp(0.08, 0.1) * sn * g;
    target.hipsPos[1] += (lerp(-0.012, -0.05) - Math.cos(ph * 2) * lerp(0.014, 0.03)) * g;
    if (this.injured) {
      // favouring one leg: a limp on the right step
      target.hips[2] += Math.max(0, sn) * 0.12 * g;
      target.spine[0] += 0.1 * g;
      target.knR[0] *= 0.6;
    }
  }

  idlePose() {
    const p = pose(POSES[this.base] || STANCE);
    const t = this.time;
    if (this.base === "swim") {
      // front crawl: the arms wheel half a turn apart, the legs flutter
      const a = t * 3.2;
      p.shL[0] = -1.6 - Math.cos(a) * 1.4;
      p.shR[0] = -1.6 + Math.cos(a) * 1.4;
      p.elL[0] = -0.3 - Math.max(0, Math.sin(a)) * 0.9;
      p.elR[0] = -0.3 - Math.max(0, -Math.sin(a)) * 0.9;
      p.hipL[0] += Math.sin(t * 9) * 0.22;
      p.hipR[0] -= Math.sin(t * 9) * 0.22;
      p.hips[2] = Math.sin(a) * 0.18;
      p.neck[1] = Math.sin(a) * 0.4;
    } else if (this.base === "tread") {
      p.shL[2] += Math.sin(t * 3) * 0.3;
      p.shR[2] -= Math.sin(t * 3) * 0.3;
      p.hipL[0] += Math.sin(t * 4) * 0.35;
      p.hipR[0] -= Math.sin(t * 4) * 0.35;
      p.knL[0] += Math.cos(t * 4) * 0.3;
      p.knR[0] -= Math.cos(t * 4) * 0.3;
      p.hipsPos[1] += Math.sin(t * 2) * 0.03;
    } else if (this.base === "shower") {
      p.elL[0] += Math.sin(t * 7) * 0.25;
      p.elR[0] += Math.sin(t * 7 + 1.5) * 0.25;
      p.shL[1] = Math.sin(t * 3.5) * 0.25;
      p.shR[1] = -Math.sin(t * 3.5) * 0.25;
      p.neck[1] = Math.sin(t * 1.3) * 0.3;
    } else if (this.base === "lie" || this.base === "sit") {
      p.chest[0] += Math.sin(t * 1.6) * 0.02;
    }
    if (this.base === "stance") {
      const b = Math.sin(t * 5.2);
      p.hipsPos[1] += b * 0.018;
      p.knL[0] += b * 0.05;
      p.knR[0] += b * 0.05;
      p.shL[0] += Math.sin(t * 2.6) * 0.06;
      p.shR[0] += Math.sin(t * 2.6 + 1.3) * 0.05;
      p.chest[1] += Math.sin(t * 1.3) * 0.06;
      p.neck[1] += Math.sin(t * 0.9) * 0.05;
    } else if (/top$|bottom$|Att$|Def$/i.test(this.base)) {
      const b = Math.sin(t * 2.2);
      p.spine[0] += b * 0.04;
      p.shL[0] += Math.sin(t * 1.7) * 0.08;
      p.shR[0] += Math.sin(t * 1.9 + 1) * 0.08;
      p.hipL[2] += Math.sin(t * 1.3) * 0.05;
    } else if (this.base === "victory") {
      p.shL[2] += Math.sin(t * 4) * 0.12;
      p.shR[2] -= Math.sin(t * 4) * 0.12;
    } else if (this.base === "relaxed" || this.base === "ref" || this.base === "dejected") {
      p.chest[0] += Math.sin(t * 1.6) * 0.02;   // breathing
      p.hipsPos[1] += Math.sin(t * 1.6) * 0.004;
    } else if (this.base === "down") {
      p.neck[1] += Math.sin(t * 0.7) * 0.08;
    }
    return p;
  }

  applyPose(p) {
    const j = this.j;
    j.hips.position.set(p.hipsPos[0], this.hipsHome + p.hipsPos[1], p.hipsPos[2]);
    for (const name of JOINTS) j[name].rotation.set(p[name][0], p[name][1], p[name][2]);
    // standing: bent knees must not push the feet through the canvas, so lift the body until the
    // lowest heel or toe rests on it (jumps and ground positions are left alone)
    if (j.hips.position.y > 0.55 && this.root.parent) {
      this.root.updateMatrixWorld(true);
      let low = Infinity;
      for (const kn of [j.knL, j.knR]) for (const z of [-0.035, 0.13]) {
        low = Math.min(low, this.root.worldToLocal(kn.localToWorld(SOLE.set(0, -0.487, z))).y);
      }
      if (low < 0) j.hips.position.y -= low;
    }
  }

  dispose() {
    const keep = new Set([...Object.values(shared), ...(this.sharedGeometry || []), ...(this.tattoos || []).map((o) => o.geometry)]);
    const keepMaterials = new Set(furMats.values());
    const geometries = new Set(), materials = new Set(), skeletons = new Set();
    this.root.traverse((o) => {
      if (!o.isMesh) return;
      if (!keep.has(o.geometry)) geometries.add(o.geometry);
      for (const m of Array.isArray(o.material) ? o.material : [o.material]) if (m && !keepMaterials.has(m)) materials.add(m);
      if (o.isSkinnedMesh && o.skeleton) skeletons.add(o.skeleton);
    });
    // Materials and skeletons are shared within this fighter, so release each once.
    // Cached geometry, shell-hair materials, iris/tattoo textures and the environment map remain reusable.
    for (const g of geometries) g.dispose();
    for (const m of materials) m.dispose();
    for (const s of skeletons) s.dispose();
    this.root.removeFromParent();
  }
}
