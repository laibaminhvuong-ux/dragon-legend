// Fighters built on Cage Career 3D's model (character/cage/: sculpted skinned body, detailed head and
// eyes, shell hair, skin shading, walk/run animation), dressed for Dragon Ball: gi, armour, capes,
// anime spiky hair, and race features (Saiyan tail, Namekian antennae, Frost Demon dome and tail,
// Majin antenna). Implements the contract in character/index.js.
import * as THREE from "three";
import { Fighter3D, LOOK_OPTIONS } from "./cage/fighter3d.js";
import { resolveLook } from "../game/look.js";

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
    const d = at(f.head, new THREE.SphereGeometry(0.105, 24, 14, 0, Math.PI * 2, 0, Math.PI * 0.42), dome, 0, 0.075, -0.01); d.scale.set(1.04, 0.95, 1.12);
    const tail = keep(std(skinHex, { rough: 0.45 }));
    at(J.hips, taper([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, -0.3, -0.25), new THREE.Vector3(0.05, -0.75, -0.35), new THREE.Vector3(0.25, -0.9, -0.1), new THREE.Vector3(0.35, -0.92, 0.15)], 0.06, 0.02, 30), tail, 0, -0.04, -0.12);
  }
  if (race === "Majin") {
    const m = keep(std(skinHex, { rough: 0.5 }));
    at(f.head, taper([new THREE.Vector3(0, 0, 0), new THREE.Vector3(0, 0.12, -0.04), new THREE.Vector3(0, 0.2, -0.14), new THREE.Vector3(0, 0.17, -0.24), new THREE.Vector3(0, 0.08, -0.26)], 0.035, 0.012, 24), m, 0, 0.13, 0.0);
  }
  // anime spiky hair
  const sp = SPIKES[look.hair];
  if (sp && L.race.hairStyles.includes(look.hair)) { const h = spikyHair(sp, hairMat); f.head.add(h); h.traverse((o) => o.isMesh && own.push(o.geometry)); }
  return own;
}

// --------------------------------------------------------------------------------- the model
export function createCharacterModel(look, { castShadow = true, female = look.female } = {}) {
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

  // attachment points
  const point = (bone, x, y, z) => { const o = new THREE.Object3D(); o.position.set(x, y, z); bone.add(o); return o; };
  const J = f.j;
  const attach = {
    head: f.head, chest: point(J.chest, 0, 0.15, 0.12), back: point(J.chest, 0, 0.15, -0.13), waist: J.hips,
    handL: point(J.elL, 0, -0.27, 0), handR: point(J.elR, 0, -0.27, 0), footL: point(J.knL, 0, -0.45, 0.05), footR: point(J.knR, 0, -0.45, 0.05),
  };

  let aura = null, t = 0;
  const pose = { fly: 0, charge: 0, dash: 0, block: 0 };
  return {
    object3d: root,
    attach,
    fighter: f,
    update(dt, anim = {}) {
      t += dt;
      // ease in/out of the special poses
      const ease = (k, on) => (pose[k] += ((on ? 1 : 0) - pose[k]) * Math.min(1, dt * 8));
      ease("fly", anim.flying); ease("charge", anim.charging); ease("dash", anim.dashing); ease("block", anim.blocking);
      f.update(dt);
      const j = J;
      // flying: legs trail, one knee bent, arms relaxed back; leaning into the direction of travel
      if (pose.fly > 0.01) {
        const k = pose.fly, lean = Math.min(1, (anim.speed || 0) / 12);
        j.hipL.rotation.x += (0.15 + 0.2 * lean) * k; j.knL.rotation.x += 0.25 * k;
        j.hipR.rotation.x += (0.35 + 0.2 * lean) * k; j.knR.rotation.x += 0.9 * k;
        j.shL.rotation.x += 0.3 * k * lean; j.shR.rotation.x += 0.3 * k * lean;
        j.hips.rotation.x += lean * 0.9 * k;
        j.neck.rotation.x -= lean * 0.6 * k;
        j.hips.position.y += Math.sin(t * 2) * 0.02 * k;
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
      if (aura) { aura.material.opacity = 0.22 + Math.sin(t * 14) * 0.06; aura.scale.y = 1.45 + Math.sin(t * 9) * 0.05; }
    },
    setHairColor(hex) { hairMat.color.setHex(hex ?? L.hairColor); },
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
      this.setAura(null);
      for (const o of owned) o.dispose?.();
      f.dispose();
    },
  };
}
