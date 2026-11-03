import { createGreatApe } from "./great_ape.js";
// Fighters built on Cage Career 3D's model (character/cage/: sculpted skinned body, detailed head and
// eyes, shell hair, skin shading, walk/run animation), dressed for Dragon Ball: gi, armour, capes,
// anime spiky hair, and race features (Saiyan tail, Namekian antennae, Frost Demon dome and tail,
// Majin antenna). Implements the contract in character/index.js.
import * as THREE from "three";
import { Fighter3D, LOOK_OPTIONS, attack } from "./cage/fighter3d.js";
import { resolveLook } from "../game/look.js";
import { KI_CHARGE_LOOK } from "../data/appearance.js";
import { KAIOKEN } from "../data/kaioken.js";
import { irisTexture } from "./cage/fighter3d.js";
import { FORM_LOOKS } from "../data/form_looks.js";
import { createAura } from "../fx/aura.js";

// --------------------------------------------------------------------------------- mapping
const BUILD = { // weight class (girth), body type, abs, height scale
  Slim: { wc: 1, body: 0, abs: 2, h: 1.0 }, Average: { wc: 3, body: 1, abs: 2, h: 1.0 }, Muscular: { wc: 6, body: 2, abs: 3, h: 1.03 },
  Tall: { wc: 4, body: 1, abs: 2, h: 1.1 }, Short: { wc: 2, body: 1, abs: 1, h: 0.86 },
};
const FACE = { Calm: 0, Fierce: 4, Smirk: 5, Determined: 0, Cold: 4 };
// our hair -> Cage base hair (spiky anime styles get a short base under the big spikes)
const HAIR = { None: "Bald", Short: "Short", Bowl: "Bob", Ponytail: "Ponytail", Spiky: "Buzz", Wild: "Buzz", Swept: "Buzz", LongSpiky: "Buzz" };
const SPIKES = { Spiky: "goku", Wild: "wild", Swept: "flame", LongSpiky: "mane" };

/** The Cage palette index nearest to a colour (for skin and hair). */
function nearest(list, hex) {
  const c = new THREE.Color(hex);
  let best = 0, bd = Infinity;
  list.forEach((s, i) => { const o = new THREE.Color(s); const d = (o.r - c.r) ** 2 + (o.g - c.g) ** 2 + (o.b - c.b) ** 2; if (d < bd) { bd = d; best = i; } });
  return best;
}
const hexStr = (n) => "#" + n.toString(16).padStart(6, "0");
const shade = (hex, k) => new THREE.Color(hex).multiplyScalar(k).getHex();

/** What each outfit is made of: top, trousers, boots, plus extra armour pieces. */
function outfitParts(outfit, tint) {
  switch (outfit) {
    case "SaiyanArmor": case "EliteArmor": return { top: 0x1c2a5c, pants: 0x1c2a5c, shoes: 0xf2f2f2, armor: { plate: 0xf4f2ea, trim: outfit === "EliteArmor" ? 0xd8b04a : tint, pads: true } };
    case "FrostArmor": return { top: 0x2a1c3c, pants: 0x2a1c3c, shoes: 0xe8e8e8, armor: { plate: 0xf0eef6, trim: tint, pads: true } };
    case "SaiyanSuit": return { top: shade(tint, 0.55), pants: shade(tint, 0.55), shoes: 0xf2f2f2, gloves: 0xf2f2f2 };
    case "PrideTrooper": return { top: 0xb8202a, pants: 0x161616, shoes: 0x161616, gloves: 0x161616, sash: 0x161616 };
    case "NamekRobe": return { top: tint, pants: tint, shoes: 0x6a3a22, sash: 0x3a8acf, cape: 0xf4f2ea, wrist: 0x3a8acf };
    case "GiantsRobe": return { top: 0x3a2a4a, pants: 0x3a2a4a, shoes: 0x2a1a12, cape: 0x8a1a2a };
    case "AngelRobe": return { top: tint, pants: tint, shoes: 0x1a1a1a, sash: 0x1a1a1a, collar: 0xd8b04a };
    case "CapsuleCorp": return { top: tint, pants: 0x2a3a5a, shoes: 0x2a2a2a };
    case "MajinVest": return { top: 0x241a2e, pants: 0xf2f0ea, shoes: 0x1a1a1a, sash: 0x111111, wrist: 0xd8b04a };
    case "CraneGi": return { top: tint, pants: shade(tint, 0.75), shoes: 0x1a1a1a, sash: 0x1a1a1a };
    case "WeightedGi": return { top: tint, pants: tint, shoes: 0x1d3a8a, sash: 0x1d3a8a, wrist: 0x1d3a8a, undershirt: 0x1d3a8a };
    case "TurtleGi": default: return { top: tint, pants: tint, shoes: 0x1d3a8a, sash: 0x1d3a8a, wrist: 0x1d3a8a, undershirt: 0x1d3a8a };
  }
}

// --------------------------------------------------------------------------------- pieces
function std(color, o = {}) { return new THREE.MeshStandardMaterial({ color, roughness: o.rough ?? 0.6, metalness: o.metal ?? 0, side: o.side ?? THREE.FrontSide, emissive: o.emissive ?? 0 }); }

/** A tapered tube along points, for tails and antennae. */
function taper(points, r0, r1, seg = 24, sides = 10) {
  const curve = new THREE.CatmullRomCurve3(points);
  const g = new THREE.TubeGeometry(curve, seg, 1, sides, false);
  const P = g.attributes.position, N = g.attributes.normal;
  const per = sides + 1;
  for (let i = 0; i <= seg; i++) {
    const t = i / seg, r = r0 + (r1 - r0) * t, c = curve.getPointAt(t);
    for (let s = 0; s < per; s++) {
      const k = i * per + s;
      P.setXYZ(k, c.x + N.getX(k) * r, c.y + N.getY(k) * r, c.z + N.getZ(k) * r);
    }
  }
  g.computeVertexNormals();
  return g;
}

/** One spike of anime hair: a slightly curved, flattened cone from the scalp outwards. */
function spike(len, rad, dir, up = 0.0) {
  const g = new THREE.ConeGeometry(rad, len, 7, 4);
  g.translate(0, len / 2, 0);
  const P = g.attributes.position;
  for (let i = 0; i < P.count; i++) { const y = P.getY(i) / len; P.setX(i, P.getX(i) * 1.25); P.setZ(i, P.getZ(i) * 0.75 + y * y * up * len); }
  g.computeVertexNormals();
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().normalize());
  g.applyQuaternion(q);
  return g;
}

/** Big spiky hair on the head bone. Head space: centre about (0, 0.06, 0), radius about 0.105; +Z is the face. */
function spikyHair(style, mat) {
  const group = new THREE.Group();
  const add = (geo, x, y, z) => { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = true; group.add(m); };
  const V = (x, y, z) => new THREE.Vector3(x, y, z);
  // a base cap so no scalp shows between spikes
  const cap = new THREE.SphereGeometry(0.112, 24, 14, 0, Math.PI * 2, 0, Math.PI * 0.55);
  cap.scale(1.02, 1.0, 1.08); cap.translate(0, 0.05, -0.012);
  add(cap, 0, 0, 0);
  const ring = (n, yAngle, len, rad, tilt, spread = Math.PI * 2, start = 0, up = 0) => {
    for (let i = 0; i < n; i++) {
      const a = start + (i / n) * spread;
      const dir = V(Math.sin(a) * Math.cos(yAngle), Math.sin(yAngle), Math.cos(a) * Math.cos(yAngle));
      const base = dir.clone().multiplyScalar(0.085);
      const d = dir.clone(); d.y += tilt;
      add(spike(len * (0.85 + ((i * 37) % 10) / 33), rad, d, up), base.x, base.y + 0.05, base.z - 0.015);
    }
  };
  if (style === "goku") {
    ring(7, 0.25, 0.16, 0.042, 0.25, Math.PI * 1.4, Math.PI * 0.8);  // sides and back
    ring(5, 0.9, 0.15, 0.045, 0.35, Math.PI * 2, 0);                  // crown
    ring(4, 0.15, 0.09, 0.03, -0.25, Math.PI * 0.6, -Math.PI * 0.3);  // bangs over the forehead
  } else if (style === "wild") {
    ring(9, 0.2, 0.2, 0.045, 0.15, Math.PI * 1.5, Math.PI * 0.75);
    ring(6, 0.85, 0.2, 0.048, 0.3);
    ring(5, 0.1, 0.1, 0.03, -0.3, Math.PI * 0.7, -Math.PI * 0.35);
  } else if (style === "flame") { // Vegeta: a tall widow's-peak flame
    ring(9, 0.55, 0.24, 0.045, 1.6, Math.PI * 2, 0, -0.2);
    ring(6, 1.2, 0.26, 0.05, 1.8);
  } else if (style === "mane") { // Raditz: a huge mane down the back
    ring(6, 0.6, 0.14, 0.045, 0.3);
    for (let i = 0; i < 9; i++) {
      const a = Math.PI * 0.65 + (i / 8) * Math.PI * 0.7;
      const dir = V(Math.sin(a) * 0.4, -1, Math.cos(a) * 0.4 - 0.25);
      add(spike(0.55 + (i % 3) * 0.12, 0.05, dir, 0.1), Math.sin(a) * 0.07, 0.05, Math.cos(a) * 0.07 - 0.03);
    }
  }
  return group;
}

/**
 * Transformation hair (data/form_looks.js): ssj1 = tall golden spikes swept up with a few bangs,
 * ssj2 = sharper, more upright, a single lone bang, ssj3 = a mane to the waist, beast = a towering
 * swept-up crest, grade3 = swollen stiff SSJ spikes (Super Trunks), legendary = Broly's huge wild mane,
 * ego = Vegeta's tall sharp Ultra Ego flame. Vegeta-style flame hair keeps its flame shape in Super Saiyan 1/2, as in the story.
 */
function formHair(style, baseStyle, mat) {
  if (style === "same") return spikyHair(baseStyle || "goku", mat);
  if (baseStyle === "flame" && (style === "ssj1" || style === "ssj2")) {
    const g = spikyHair("flame", mat);
    g.scale.y = style === "ssj2" ? 1.12 : 1.05;
    return g;
  }
  const group = new THREE.Group();
  const add = (geo, x, y, z) => { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = true; group.add(m); };
  const V = (x, y, z) => new THREE.Vector3(x, y, z);
  const cap = new THREE.SphereGeometry(0.113, 24, 14, 0, Math.PI * 2, 0, Math.PI * 0.55);
  cap.scale(1.03, 1.0, 1.09); cap.translate(0, 0.05, -0.012);
  add(cap, 0, 0, 0);
  const ring = (n, yAngle, len, rad, tilt, spread = Math.PI * 2, start = 0, up = 0, jitter = 0.3) => {
    for (let i = 0; i < n; i++) {
      const a = start + (i / Math.max(1, n - (spread < Math.PI * 2 ? 1 : 0))) * spread;
      const dir = V(Math.sin(a) * Math.cos(yAngle), Math.sin(yAngle), Math.cos(a) * Math.cos(yAngle));
      const base = dir.clone().multiplyScalar(0.085);
      const d = dir.clone(); d.y += tilt;
      add(spike(len * (1 - jitter / 2 + jitter * (((i * 37) % 10) / 10)), rad, d, up), base.x, base.y + 0.05, base.z - 0.015);
    }
  };
  if (style === "ssj1") {
    // full, flame-like spikes swept up and back, a fringe of several bangs
    ring(8, 0.3, 0.19, 0.05, 0.75, Math.PI * 1.5, Math.PI * 0.75, -0.15); // sides and back, swept up
    ring(6, 1.0, 0.2, 0.054, 0.35, Math.PI * 2, 0, -0.25);              // crown, leaning back
    ring(4, 0.12, 0.1, 0.03, -0.4, Math.PI * 0.55, -Math.PI * 0.27);    // bangs over the forehead
  } else if (style === "ssj2") {
    // thinner, sharper and nearly vertical, standing taller; the bangs are gone except one lone strand
    ring(10, 0.45, 0.27, 0.036, 2.0, Math.PI * 1.55, Math.PI * 0.72, 0, 0.45);
    ring(8, 1.15, 0.3, 0.038, 1.6, Math.PI * 2, 0, 0, 0.45);
    add(spike(0.16, 0.019, V(0.25, -1, 0.6), 0.2), 0.03, 0.115, 0.083);
  } else if (style === "ssj3") {
    ring(6, 0.95, 0.15, 0.05, 0.45);                                   // crown
    ring(4, 0.15, 0.1, 0.03, -0.35, Math.PI * 0.5, -Math.PI * 0.25);   // bangs
    // the mane: long spikes down the back to the waist
    for (let i = 0; i < 15; i++) {
      const a = Math.PI * 0.5 + (i / 14) * Math.PI;
      const side = Math.sin(a);
      const dir = V(side * 0.42, -1, Math.cos(a) * 0.25 - 0.42);
      const len = 0.62 + (1 - Math.abs(side)) * 0.32 + ((i * 7) % 5) * 0.03;
      add(spike(len, 0.06, dir, 0.08), side * 0.075, 0.08, Math.cos(a) * 0.06 - 0.04);
    }
  } else if (style === "ssj4") {
    ring(7, 0.9, 0.15, 0.05, 0.25, Math.PI * 2, 0, -0.2);              // wild crown
    ring(5, 0.12, 0.12, 0.03, -0.45, Math.PI * 0.6, -Math.PI * 0.3);   // long bangs
    for (let i = 0; i < 11; i++) {                                      // mane to the shoulder blades
      const a = Math.PI * 0.55 + (i / 10) * Math.PI * 0.9;
      const side = Math.sin(a);
      add(spike(0.36 + ((i * 7) % 4) * 0.04, 0.055, V(side * 0.6, -0.7, Math.cos(a) * 0.3 - 0.6), 0.1), side * 0.075, 0.08, Math.cos(a) * 0.06 - 0.04);
    }
  } else if (style === "grade3") {
    // Super Trunks / Grade 3: SSJ1's shape grown stiff and swollen, thick spikes fanned out and up, almost no fringe
    ring(9, 0.35, 0.25, 0.066, 1.0, Math.PI * 1.6, Math.PI * 0.7, -0.1, 0.25);  // sides and back, flared out
    ring(7, 1.0, 0.27, 0.07, 0.6, Math.PI * 2, 0, -0.15, 0.25);                 // crown, upright
    ring(4, 0.65, 0.2, 0.06, 0.9, Math.PI * 0.7, -Math.PI * 0.35, 0.1);         // front, standing straight up
    add(spike(0.1, 0.028, V(0.2, -1, 0.7), 0.15), 0.025, 0.11, 0.085);          // one short bang
  } else if (style === "legendary") {
    // Broly: an enormous wild mane, thick spikes swept up and back, flaring out at the sides, no fringe
    ring(11, 0.4, 0.3, 0.064, 0.55, Math.PI * 1.7, Math.PI * 0.65, -0.3, 0.4);  // sides, flared out wide
    ring(8, 1.05, 0.32, 0.066, 0.7, Math.PI * 2, 0, -0.45, 0.4);                // crown, swept back
    ring(5, 0.75, 0.24, 0.058, 1.4, Math.PI * 0.8, -Math.PI * 0.4, -0.2, 0.3);  // front, standing up off the forehead
    for (let i = 0; i < 9; i++) {                                                // the long back: a thick mane to the shoulders
      const a = Math.PI * 0.6 + (i / 8) * Math.PI * 0.8, side = Math.sin(a);
      add(spike(0.3 + ((i * 7) % 4) * 0.04, 0.064, V(side * 0.7, -0.9, Math.cos(a) * 0.45 - 0.45), 0.15), side * 0.08, 0.06, Math.cos(a) * 0.07 - 0.04);
    }
  } else if (style === "ego") {
    // Vegeta's Ultra Ego: a tall, sharp flame with a deep widow's peak, standing straight up and swept slightly back
    ring(9, 0.5, 0.27, 0.058, 0.7, Math.PI * 1.7, Math.PI * 0.65, -0.2, 0.3);   // sides and back, fanning out like a flame
    ring(6, 1.2, 0.34, 0.062, 1.2, Math.PI * 2, 0, -0.15, 0.25);                // crown
    ring(4, 0.85, 0.32, 0.056, 1.8, Math.PI * 0.6, -Math.PI * 0.3, -0.1, 0.25); // front, straight up from the peak
    add(spike(0.07, 0.022, V(0, -1, 0.35), 0), 0, 0.125, 0.09);                 // widow's peak
  } else if (style === "beast") {
    ring(9, 0.55, 0.36, 0.05, 2.6, Math.PI * 1.6, Math.PI * 0.7, -0.35, 0.35); // a towering crest swept up and back
    ring(6, 1.2, 0.42, 0.055, 2.8, Math.PI * 2, 0, -0.3);
    ring(3, 0.12, 0.09, 0.026, -0.4, Math.PI * 0.45, -Math.PI * 0.22);
  }
  return group;
}

/** Adds rigid pieces to bones: armour, capes, sashes, race features. Returns materials/geometries to dispose. */
function dress(f, parts, L, look, hairMat) {
  const own = [];
  const keep = (x) => { own.push(x); return x; };
  const J = f.j, w = f.width;
  const at = (bone, geo, mat, x = 0, y = 0, z = 0) => { const m = new THREE.Mesh(keep(geo), mat); m.position.set(x, y, z); m.castShadow = m.receiveShadow = true; bone.add(m); return m; };
  // sash/belt around the waist
  if (parts.sash) {
    const m = keep(std(parts.sash, { rough: 0.7 }));
    const band = at(J.hips, new THREE.CylinderGeometry(0.155 * w, 0.16 * w, 0.06, 28), m, 0, 0.03, 0); band.scale.z = 0.78;
    at(J.hips, new THREE.BoxGeometry(0.05, 0.16, 0.012), m, 0.05, -0.05, 0.128).rotation.z = 0.15; // knot tails
    at(J.hips, new THREE.BoxGeometry(0.05, 0.14, 0.012), m, -0.03, -0.045, 0.128).rotation.z = -0.1;
  }
  // wristbands
  if (parts.wrist) {
    const m = keep(std(parts.wrist, { rough: 0.7 }));
    for (const s of ["L", "R"]) at(J["el" + s], new THREE.CylinderGeometry(0.046, 0.046, 0.07, 18), m, 0, -0.2, 0);
  }
  // gloves (bodysuits, Pride Troopers)
  if (parts.gloves) {
    const m = keep(std(parts.gloves, { rough: 0.5 }));
    for (const s of ["L", "R"]) { const g = at(J["el" + s], new THREE.SphereGeometry(0.05, 16, 12), m, 0, -0.27, 0.005); g.scale.set(0.95, 1.25, 0.8); }
  }
  // the gi's undershirt shows at the neck as a V
  if (parts.undershirt) {
    const m = keep(std(parts.undershirt, { rough: 0.75 }));
    const v = at(J.chest, new THREE.CylinderGeometry(0.0, 0.065, 0.13, 3), m, 0, 0.215, 0.108); v.rotation.set(Math.PI, 0, 0); v.scale.z = 0.25;
  }
  // Saiyan / Frieza Force battle armour: chest plate, shoulder pads
  if (parts.armor) {
    const plate = keep(std(parts.armor.plate, { rough: 0.35, metal: 0.15 })), trim = keep(std(parts.armor.trim, { rough: 0.4, metal: 0.1 }));
    const c = at(J.chest, new THREE.SphereGeometry(0.2, 28, 18, 0, Math.PI * 2, Math.PI * 0.18, Math.PI * 0.6), plate, 0, 0.13, 0.0);
    c.scale.set(1.08 * w, 1.05, 0.82);
    const belly = at(J.spine, new THREE.CylinderGeometry(0.15 * w, 0.14 * w, 0.14, 24), plate, 0, 0.07, 0.0); belly.scale.z = 0.8;
    if (parts.armor.pads) for (const s of ["L", "R"]) {
      const sx = s === "L" ? 1 : -1;
      const pad = at(J["sh" + s], new THREE.SphereGeometry(0.085, 18, 10, 0, Math.PI * 2, 0, Math.PI / 2), trim, sx * 0.03, 0.02, 0); pad.scale.set(1.3, 0.8, 1.25); pad.rotation.z = -sx * 0.45;
    }
  }
  if (parts.collar) {
    const m = keep(std(parts.collar, { rough: 0.3, metal: 0.5 }));
    const t = at(J.chest, new THREE.TorusGeometry(0.1, 0.018, 10, 28), m, 0, 0.27, 0.01); t.rotation.x = Math.PI / 2;
  }
  // capes (Namekian robe, Demon Clan)
  if (parts.cape) {
    const m = keep(std(parts.cape, { rough: 0.8, side: THREE.DoubleSide }));
    const geo = new THREE.PlaneGeometry(0.5 * w, 1.05, 4, 8);
    const P = geo.attributes.position;
    for (let i = 0; i < P.count; i++) { const y = P.getY(i), x = P.getX(i); P.setZ(i, -Math.abs(x) * 0.25 - (0.525 - y) * 0.08); }
    geo.translate(0, -0.5, 0);
    geo.computeVertexNormals();
    const cape = at(J.chest, geo, m, 0, 0.27, -0.13);
    cape.rotation.x = 0.06;
    f.cape = cape;
    // shoulder pads of a Namekian cape
    for (const s of ["L", "R"]) { const pad = at(J.chest, new THREE.SphereGeometry(0.07, 14, 8, 0, Math.PI * 2, 0, Math.PI / 2), m, (s === "L" ? 1 : -1) * 0.17 * w, 0.27, -0.01); pad.scale.set(1.4, 0.6, 1.2); }
  }
  // ----- race features
  const race = L.race.id;
  const skinHex = L.skinColor;
  if (race === "Saiyan") {
    const fur = keep(std(0x4a2e1c, { rough: 0.85 }));
    at(J.hips, taper([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, -0.12, -0.12), new THREE.Vector3(0.12, -0.28, -0.18), new THREE.Vector3(0.22, -0.32, -0.05), new THREE.Vector3(0.18, -0.22, 0.04)], 0.032, 0.022), fur, 0, -0.02, -0.13);
  }
  if (race === "Namekian") {
    const m = keep(std(shade(skinHex, 0.9), { rough: 0.55 }));
    (f.raceSkin ||= []).push([m, 0.9]);
    for (const s of [1, -1]) {
      at(f.head, taper([new THREE.Vector3(0, 0, 0), new THREE.Vector3(s * 0.02, 0.06, 0.02), new THREE.Vector3(s * 0.05, 0.12, 0.0)], 0.009, 0.006, 12, 8), m, s * 0.03, 0.135, 0.07);
      at(f.head, new THREE.SphereGeometry(0.011, 10, 8), m, s * 0.08, 0.255, 0.07);
    }
    // pink muscle patches on the arms
    const pink = keep(std(0xd88a9a, { rough: 0.5 }));
    for (const s of ["L", "R"]) { const p = at(J["sh" + s], new THREE.SphereGeometry(0.05, 14, 10), pink, (s === "L" ? 1 : -1) * 0.035, -0.12, 0); p.scale.set(0.55, 1.4, 0.95); }
  }
  if (race === "FrostDemon") {
    const dome = keep(std(0x8a3ab8, { rough: 0.15, metal: 0.1 }));
    f.domeM = dome;
    const d = at(f.head, new THREE.SphereGeometry(0.105, 24, 14, 0, Math.PI * 2, 0, Math.PI * 0.42), dome, 0, 0.075, -0.01); d.scale.set(1.04, 0.95, 1.12);
    const tail = keep(std(skinHex, { rough: 0.45 }));
    (f.raceSkin ||= []).push([tail, 1]);
    at(J.hips, taper([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, -0.3, -0.25), new THREE.Vector3(0.05, -0.75, -0.35), new THREE.Vector3(0.25, -0.9, -0.1), new THREE.Vector3(0.35, -0.92, 0.15)], 0.06, 0.02, 30), tail, 0, -0.04, -0.12);
  }
  if (race === "Majin") {
    const m = keep(std(skinHex, { rough: 0.5 }));
    (f.raceSkin ||= []).push([m, 1]);
    at(f.head, taper([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0.12, -0.04), new THREE.Vector3(0, 0.2, -0.14), new THREE.Vector3(0, 0.17, -0.24), new THREE.Vector3(0, 0.08, -0.26)], 0.035, 0.012, 24), m, 0, 0.13, 0.0);
  }
  // anime spiky hair
  const sp = SPIKES[look.hair];
  if (sp && L.race.hairStyles.includes(look.hair)) { const h = spikyHair(sp, hairMat); f.head.add(h); h.traverse((o) => o.isMesh && own.push(o.geometry)); f.spikes = h; f.spikeStyle = sp; }
  return own;
}

// ----------------------------------------------------------------------------- distance detail
// Every model is ~50 meshes (hair alone is up to 28 shells) and each is drawn in the main, shadow
// and ambient-occlusion passes, so a crowd of NPCs and enemies costs far more than the world.
// Other characters (created with lod: true) thin their hair shells and drop shadows with distance, and live on
// camera layer 1 so the lake's reflection pass skips them. The player's own model keeps full detail.
const LOD_NEAR = 14, LOD_MID = 32;
const lodModels = new Set();

function setBand(m, band) {
  if (m.band === band) return;
  m.band = band;
  for (const s of m.shells) s.visible = band === 0 || (band === 1 && s.userData.furShell % 3 === 0);
  for (const c of m.casters) c.castShadow = band < 2;
}

/** Call once per frame before rendering, with the camera. */
export function updateCharacterLod(camera) {
  const p = camera.position;
  for (const m of lodModels) {
    const e = m.root.matrixWorld.elements; // world position (enemies sit inside a parent group)
    const d = Math.hypot(e[12] - p.x, e[13] - p.y, e[14] - p.z);
    const b = m.band;
    // a metre of hysteresis so a model on a boundary doesn't flicker
    const near = LOD_NEAR + (b === 0 ? 1 : -1), mid = LOD_MID + (b <= 1 ? 1 : -1);
    setBand(m, d < near ? 0 : d < mid ? 1 : 2);
  }
}

// --------------------------------------------------------------------------------- the model
export function createCharacterModel(look, { castShadow = true, female = look.female, lod = false } = {}) {
  const L = resolveLook(look);
  const B = BUILD[look.build] || BUILD.Average;
  const parts = outfitParts(look.outfit, L.tintColor);
  const human = ["Saiyan", "HalfSaiyan", "Human"].includes(L.race.id);
  const cageLook = {
    skin: human ? nearest(LOOK_OPTIONS.skin, L.skinColor) : 1,
    hair: LOOK_OPTIONS.hair.indexOf(L.race.hairStyles.includes(look.hair) ? HAIR[look.hair] || "Bald" : "Bald"),
    hairColor: nearest(LOOK_OPTIONS.hairColor, L.hairColor),
    beard: 0, shorts: 0, body: B.body, abs: B.abs, face: FACE[look.face] ?? 0, headband: 0, wraps: 0, knees: 0, design: 0,
  };
  const f = new Fighter3D({ look: cageLook, weightClass: B.wc, casual: true, female: !!female, shirt: hexStr(parts.top), pants: hexStr(parts.pants), shoes: hexStr(parts.shoes), faceSeed: look.race + look.face });
  const root = f.root;
  root.scale.multiplyScalar(B.h);
  // alien skin tones (the Cage palette only has human ones)
  f.skinM.color.setHex(L.skinColor);
  f.skinBase.copy(f.skinM.color);
  const hairMat = std(L.hairColor, { rough: 0.5 });
  const owned = dress(f, parts, L, look, hairMat);
  owned.push(hairMat);
  root.traverse((o) => { if (o.isMesh) o.castShadow = castShadow && o.castShadow; });
  let lodEntry = null;
  if (lod) {
    lodEntry = { root, band: -1, shells: [], casters: [] };
    root.traverse((o) => {
      if (!o.isMesh) return;
      o.layers.set(1); // not reflected (see above)
      if (o.userData.furShell) lodEntry.shells.push(o);
      if (o.castShadow) lodEntry.casters.push(o);
    });
    lodModels.add(lodEntry);
  }

  // attachment points
  const point = (bone, x, y, z) => { const o = new THREE.Object3D(); o.position.set(x, y, z); bone.add(o); return o; };
  const J = f.j;
  const attach = {
    head: f.head, chest: point(J.chest, 0, 0.15, 0.12), back: point(J.chest, 0, 0.15, -0.13), waist: J.hips,
    handL: point(J.elL, 0, -0.27, 0), handR: point(J.elR, 0, -0.27, 0), footL: point(J.knL, 0, -0.45, 0.05), footR: point(J.knR, 0, -0.45, 0.05),
  };

  let aura = null, chargeAura = null, kaiokenAura = null, t = 0, attackSerial = 0;
  // transformations (setForm): what was swapped out, so it can be put back exactly
  const baseScale = root.scale.clone();
  const furBases = [];
  root.traverse((o) => o.userData.furBase && furBases.push(o));
  const skinM = f.skinM;
  const baseSkin = { color: skinM.color.getHex(), metal: skinM.metalness ?? 0, rough: skinM.roughness ?? 0.5 };
  const raceSkin = (f.raceSkin || []).map(([m, k]) => ({ m, k, hex: m.color.getHex() }));
  const baseDome = f.domeM ? f.domeM.color.getHex() : 0;
  const baseIris = f.irisM ? f.irisM.map : null;
  let formId = "", formAura = null, formHairGroup = null, formHairMat = null, ape=null, hiddenParts=[], furParts=[];
  const hexCss = (n) => "#" + n.toString(16).padStart(6, "0");
  function clearForm() {
    ape?.dispose();ape=null;
    const furGeometries=new Set(),furMaterials=new Set();
    for(const mesh of furParts){mesh.removeFromParent();furGeometries.add(mesh.geometry);furMaterials.add(mesh.material);}furParts=[];
    furGeometries.forEach(g=>g.dispose());furMaterials.forEach(m=>m.dispose());
    for(const [part,visible] of hiddenParts)part.visible=visible;hiddenParts=[];
    if (formAura) { formAura.dispose(); formAura = null; }
    if (formHairGroup) {
      formHairGroup.removeFromParent();
      formHairGroup.traverse((o) => o.isMesh && o.geometry.dispose());
      formHairMat.dispose();
      formHairGroup = formHairMat = null;
    }
    if (f.spikes) f.spikes.visible = true;
    for (const b of furBases) b.visible = true;
    skinM.color.setHex(baseSkin.color); f.skinBase.copy(skinM.color);
    if ("metalness" in skinM) { skinM.metalness = baseSkin.metal; skinM.roughness = baseSkin.rough; }
    for (const r of raceSkin) r.m.color.setHex(r.hex);
    if (f.domeM) f.domeM.color.setHex(baseDome);
    if (f.irisM && baseIris) f.irisM.map = baseIris;
    f.setBrows?.(true);
    root.scale.copy(baseScale);
  }
  const pose = { fly: 0, flyFast: 0, climb: 0, charge: 0, dash: 0, block: 0 };
  return {
    object3d: root,
    attach,
    fighter: f,
    update(dt, anim = {}) {
      if (anim.kaioken && !kaiokenAura) {
        kaiokenAura = createAura(KAIOKEN.aura);kaiokenAura.object3d.name='kaioken-overlay-aura';
        kaiokenAura.object3d.traverse(o=>{o.layers.set(1);o.castShadow=false;});root.add(kaiokenAura.object3d);
      }
      if(kaiokenAura){kaiokenAura.object3d.visible=!!anim.kaioken;if(anim.kaioken && dt>0)kaiokenAura.update(dt);}
      // Charging remains visible at full Ki, including in base form.
      if (anim.charging && !chargeAura) {
        chargeAura = createAura({color:L.kiColor,...KI_CHARGE_LOOK});
        chargeAura.object3d.name = 'ki-charge-aura';
        chargeAura.object3d.traverse(o=>{o.layers.set(1);o.castShadow=false;});
        root.add(chargeAura.object3d);
      }
      if (chargeAura) {
        chargeAura.object3d.visible = !!anim.charging;
        if (anim.charging && dt>0) chargeAura.update(dt);
      }
      if (dt <= 0) return;
      if (anim.attackSerial && anim.attackSerial !== attackSerial) {
        attackSerial = anim.attackSerial;
        f.play(attack(anim.attackKind || "jab").frames);
      }
      t += dt;
      // ease in/out of the special poses
      const ease = (k, on) => (pose[k] += ((on ? 1 : 0) - pose[k]) * Math.min(1, dt * 8));
      ease("fly", anim.flying); ease("charge", anim.charging); ease("dash", anim.dashing); ease("block", anim.blocking);
      // how fast and which way we fly: blends hover -> full-speed flight, and tilts for climbing/diving
      const flySpeed = Math.hypot(anim.speed || 0, (anim.vy || 0) * 0.6);
      pose.flyFast += (Math.min(1, Math.max(0, (flySpeed - 2) / 8)) - pose.flyFast) * Math.min(1, dt * 3);
      pose.climb += (Math.max(-1, Math.min(1, (anim.vy || 0) / 10)) - pose.climb) * Math.min(1, dt * 3);
      f.airborne = !!anim.flying || anim.onGround === false; // no walking legs in the air
      f.update(dt);
      ape?.update(dt,anim);
      const j = J;
      // flying, two poses blended by speed:
      //  hover (slow or still): upright, one knee drawn up, arms loose and a little out, a gentle bob and sway
      //  full speed: body nearly horizontal, one fist punched ahead, the other arm swept back, legs trailing
      //  straight, head up to look where it's going; climbing tilts the body up, diving tips it down
      if (pose.fly > 0.01) {
        const k = pose.fly, fast = pose.flyFast, hov = 1 - fast, climb = pose.climb;
        const bob = Math.sin(t * 2.2), sway = Math.sin(t * 1.3);
        // body
        const pitch = fast * (1.3 - 0.75 * Math.max(0, climb)) + Math.max(0, -climb) * 0.5 * hov;
        j.hips.rotation.x += (pitch - Math.max(0, climb) * 0.25 * hov) * k;
        j.hips.rotation.z += sway * 0.04 * hov * k;
        j.hips.position.y += bob * 0.035 * hov * k;
        j.chest.rotation.x -= 0.18 * fast * k;
        j.neck.rotation.x -= (0.95 * fast + 0.1 * hov) * k;
        // legs: hover = right knee up, left leg hanging; fast = both trailing straight, feet together
        j.hipR.rotation.x += (-0.75 * hov + 0.08 * fast) * k; j.knR.rotation.x += (1.25 * hov + 0.12 * fast) * k;
        j.hipL.rotation.x += (0.12 * hov + 0.16 * fast + bob * 0.04 * hov) * k; j.knL.rotation.x += (0.4 * hov + 0.08 * fast) * k;
        j.hipL.rotation.z += 0.06 * hov * k; j.hipR.rotation.z -= 0.04 * hov * k;
        // arms: hover = loose, a little out from the body, elbows soft; fast = right fist ahead, left swept back
        for (const s of ["L", "R"]) {
          const sx = s === "L" ? 1 : -1;
          const loose = hov * (1 - Math.max(0, climb)); // a raised arm isn't hanging loose
          j["sh" + s].rotation.z += sx * (0.28 + bob * 0.03) * loose * k;
          j["el" + s].rotation.x -= 0.35 * loose * k;
        }
        const up = Math.max(0, climb), arm = Math.max(fast, up); // rising also raises the leading fist, towards the sky
        j.shR.rotation.x += (-2.75 - 0.5 * up) * arm * k; j.elR.rotation.x += 0.15 * arm * k;
        j.shL.rotation.x += 0.45 * arm * k; j.shL.rotation.z += 0.12 * arm * k; j.elL.rotation.x -= 0.15 * arm * k;
      }
      // powering up: crouched, fists clenched at the sides, chest out, head back a little
      if (pose.charge > 0.01) {
        const k = pose.charge, shake = Math.sin(t * 40) * 0.01;
        j.hips.position.y -= 0.1 * k;
        for (const s of ["L", "R"]) {
          const sx = s === "L" ? 1 : -1;
          j["hip" + s].rotation.x -= 0.45 * k; j["kn" + s].rotation.x += 0.8 * k; j["hip" + s].rotation.z += sx * 0.25 * k;
          j["sh" + s].rotation.z += sx * 0.45 * k; j["sh" + s].rotation.x += 0.25 * k; j["el" + s].rotation.x -= 1.1 * k;
        }
        j.chest.rotation.x -= 0.25 * k + shake; j.neck.rotation.x -= 0.15 * k;
      }
      // dashing: hard forward lean
      if (pose.dash > 0.01) { const k = pose.dash; j.hips.rotation.x += 0.55 * k; j.shL.rotation.x += 0.6 * k; j.shR.rotation.x += 0.6 * k; }
      // blocking: forearms crossed in front of the face
      if (pose.block > 0.01) {
        const k = pose.block;
        j.shL.rotation.x -= 1.3 * k; j.elL.rotation.x -= 1.6 * k; j.shL.rotation.z -= 0.35 * k;
        j.shR.rotation.x -= 1.3 * k; j.elR.rotation.x -= 1.6 * k; j.shR.rotation.z += 0.35 * k;
      }
      if (f.cape) f.cape.rotation.x = 0.06 + Math.min(0.9, (anim.speed || 0) * 0.08) + Math.sin(t * 3) * 0.03;
      if (formAura) formAura.update(dt);
      if (aura) { aura.material.opacity = 0.22 + Math.sin(t * 14) * 0.06; aura.scale.y = 1.45 + Math.sin(t * 9) * 0.05; }
    },
    setHairColor(hex) { hairMat.color.setHex(hex ?? L.hairColor); },
    setKiColor(hex) { if(L.kiColor===hex)return;L.kiColor=hex;chargeAura?.setColor(hex); },
    /** Shows a transformation as in the story (data/form_looks.js); "" or null = base form. */
    setForm(id) {
      id = id || "";
      if (id === formId) return;
      clearForm();
      formId = id;
      const F = FORM_LOOKS[id];
      if (!F) return;
      if (F.hair) {
        formHairMat = new THREE.MeshStandardMaterial({ color: F.hair.color, roughness: 0.42, emissive: new THREE.Color(F.hair.color).multiplyScalar(F.hair.glow ?? 0.3) });
        formHairGroup = formHair(F.hair.style, f.spikeStyle, formHairMat);
        f.head.add(formHairGroup);
        if (f.spikes) f.spikes.visible = false;
        for (const b of furBases) b.visible = false;
      }
      if (F.eyes != null && f.irisM) f.irisM.map = irisTexture(hexCss(F.eyes));
      if (F.brows === false) f.setBrows?.(false);
      if (F.skin != null) {
        skinM.color.setHex(F.skin);
        for (const r of raceSkin) r.m.color.setHex(shade(F.skin, r.k));
      } else if (F.flush) {
        skinM.color.lerp(new THREE.Color(F.flush[0]), F.flush[1]);
        for (const r of raceSkin) r.m.color.lerp(new THREE.Color(F.flush[0]), F.flush[1]);
      }
      if (F.skinMetal != null && "metalness" in skinM) { skinM.metalness = F.skinMetal; skinM.roughness = 0.35; }
      f.skinBase.copy(skinM.color);
      if (F.dome != null && f.domeM) f.domeM.color.setHex(F.dome);
      if (F.scale) root.scale.copy(baseScale).multiplyScalar(F.scale);
      if (F.bulk) root.scale.set(baseScale.x*F.bulk[0],baseScale.y*F.bulk[1],baseScale.z*F.bulk[2]);
      if (F.slim) root.scale.set(baseScale.x * 0.95, baseScale.y * 1.01, baseScale.z * 0.95);
      if(id==='SSJ4'){
        const furGeometry=new THREE.SphereGeometry(1,12,8),furMaterial=new THREE.MeshStandardMaterial({color:0xa72437,roughness:.95});
        const patch=(parent,position,scale)=>{const mesh=new THREE.Mesh(furGeometry,furMaterial);mesh.name='ssj4-red-fur';mesh.position.set(...position);mesh.scale.set(...scale);mesh.castShadow=castShadow;parent.add(mesh);furParts.push(mesh);};
        for(const side of ['L','R']){
          patch(J['sh'+side],[0,-.14,0],[.085,.17,.085]);patch(J['el'+side],[0,-.09,0],[.067,.13,.075]);
          patch(J.chest,[side==='L'?.15:-.15,.08,0],[.1,.24,.15]);
        }
        patch(J.chest,[0,.08,-.11],[.23,.24,.065]);
      }
      if (id==='Oozaru'  || id==='GoldenOozaru'){
        hiddenParts=root.children.map(part=>[part,part.visible]);hiddenParts.forEach(([part])=>part.visible=false);
        ape=createGreatApe({golden:id==='GoldenOozaru',castShadow});root.add(ape.object3d);
      }
      if (F.aura) { formAura = createAura(F.aura); root.add(formAura.object3d); }
    },
    setAura(hex) {
      if (hex == null) { if (aura) { root.remove(aura); aura.geometry.dispose(); aura.material.dispose(); aura = null; } return; }
      if (!aura) {
        aura = new THREE.Mesh(new THREE.SphereGeometry(0.62, 20, 14), new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0.25 }));
        aura.position.y = 0.95; aura.scale.set(1, 1.45, 1); aura.userData.noAO = true;
        root.add(aura);
      }
      aura.material.color.setHex(hex);
    },
    dispose() {
      if (lodEntry) lodModels.delete(lodEntry);
      clearForm();
      chargeAura?.dispose(); chargeAura = null;
      kaiokenAura?.dispose(); kaiokenAura = null;
      this.setAura(null);
      for (const o of owned) o.dispose?.();
      f.dispose();
    },
  };
}
