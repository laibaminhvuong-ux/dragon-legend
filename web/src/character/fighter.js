// Original low-poly fighters assembled from reusable geometry; no external assets or textures.
import * as THREE from 'three';
import { resolveLook } from '../game/look.js';
import { CHARACTER as C, HAIR_SHAPES, FACE_SHAPES, OUTFIT_SHAPES } from '../data/character.js';

export function createCharacterModel(look, { castShadow = true } = {}) {
  const L = resolveLook(look);
  const root = new THREE.Group(); root.name = 'fighter';
  const body = new THREE.Group(); root.add(body);
  body.scale.set(L.build.width, L.build.height, L.build.depth);
  const geometries = new Set(), materials = new Set(), cache = new Map();
  const mat = color => {
    const m = new THREE.MeshStandardMaterial({ color, roughness: .85, flatShading: true });
    materials.add(m); return m;
  };
  const skin = mat(L.skinColor), cloth = mat(L.tintColor), hair = mat(L.hairColor);
  const dark = mat(C.dark), white = mat(C.white), accent = mat(C.accent);
  const armor = mat(C.armor), gold = mat(C.gold), frost = mat(C.frost);
  const geometry = (kind, args) => {
    const key = `${kind}:${args.join(',')}`;
    if (!cache.has(key)) {
      const g = new THREE[kind](...args); cache.set(key, g); geometries.add(g);
    }
    return cache.get(key);
  };
  function mesh(parent, name, kind, args, material, pos, scale) {
    const m = new THREE.Mesh(geometry(kind, args), material);
    m.name = name; m.castShadow = castShadow; m.receiveShadow = castShadow;
    if (pos) m.position.set(...pos);
    if (scale) m.scale.set(...scale);
    parent.add(m); return m;
  }
  const ball = (p, n, m, pos, scale) => mesh(p, n, 'SphereGeometry', [1, 10, 8], m, pos, scale);
  const box = (p, n, m, pos, scale) => mesh(p, n, 'BoxGeometry', [1, 1, 1], m, pos, scale);
  const cone = (p, n, m, pos, r, h) => mesh(p, n, 'ConeGeometry', [r, h, 6], m, pos);
  const group = (p, name, pos) => { const g = new THREE.Group(); g.name = name; g.position.set(...pos); p.add(g); return g; };
  const hips = group(body, 'hips', [0, .87, 0]);
  const style = OUTFIT_SHAPES[L.outfit] || 'gi';
  const armored = ['armor', 'elite', 'frost'].includes(style);
  const robed = ['robe', 'angel'].includes(style);
  const bareArms = armored || robed || style === 'vest';
  ball(hips, 'pelvis', cloth, [0, .02, 0], [.23, .16, .15]);
  ball(hips, 'torso', style === 'vest' ? skin : cloth, [0, .32, 0], [.27, .34, .16]);
  box(hips, 'sash', style === 'vest' ? gold : accent, [0, .06, 0], [.47, .085, .32]);
  const neck = group(hips, 'neck', [0, .61, 0]);
  ball(neck, 'neckSkin', skin, [0, -.025, 0], [.075, .09, .075]);
  const head = group(neck, 'head', [0, .14, 0]);
  ball(head, 'headSkin', skin, [0, 0, 0], [.165, .18, .145]);
  ball(head, 'jaw', skin, [0, -.09, .018], [.12, .09, .12]);
  for (const side of [-1, 1]) ball(head, 'ear', skin, [side * .167, -.01, 0], [.035, .06, .027]);
  const face = FACE_SHAPES[L.face] || FACE_SHAPES.Calm;
  for (const side of [-1, 1]) {
    box(head, 'eyeWhite', white, [side * .073, .015, .134], [.064, face.eye, .014]);
    box(head, 'pupil', dark, [side * .069, .014, .144], [.019, face.eye, .008]);
    const brow = box(head, 'brow', hair, [side * .073, .048, .139], [.078, .012, .014]);
    brow.rotation.z = side * face.brow;
  }
  cone(head, 'nose', skin, [0, -.025, .15], .022, .06).rotation.x = Math.PI / 2;
  box(head, 'mouth', dark, [0, -.087, .133], [.06, .009, .009]).rotation.z = face.mouth;

  if (L.hair !== 'None') {
    ball(head, 'hairCap', hair, [0, .087, -.023], [.176, L.hair === 'Bowl' ? .13 : .11, .155]);
    for (const [x, y, z, r, h, rx, rz] of HAIR_SHAPES[L.hair] || []) {
      const spike = cone(head, 'hairSpike', hair, [x, y, z], r, h);
      spike.rotation.set(rx, 0, rz);
    }
    if (L.hair === 'Bowl') box(head, 'fringe', hair, [0, .038, .13], [.3, .06, .06]);
    if (L.hair === 'Short') ball(head, 'shortCrown', hair, [0, .12, -.04], [.15, .09, .13]);
    if (L.hair === 'Ponytail') {
      ball(head, 'hairTie', gold, [0, .02, -.18], [.055, .055, .045]);
      ball(head, 'ponytail', hair, [0, -.12, -.2], [.075, .18, .07]);
    }
  }

  function limb(name, x, y, upperLen, lowerLen, width, upperMat, lowerMat) {
    const pivot = group(hips, name, [x, y, 0]);
    ball(pivot, `${name}Upper`, upperMat, [0, -upperLen / 2, 0], [width, upperLen * .63, width]);
    const joint = group(pivot, `${name}Joint`, [0, -upperLen, 0]);
    ball(joint, `${name}Lower`, lowerMat, [0, -lowerLen / 2, 0], [width * .85, lowerLen * .61, width * .85]);
    const end = group(joint, `${name}End`, [0, -lowerLen, 0]);
    return { pivot, joint, end };
  }
  const armL = limb('armL', .3, .51, .27, .25, .083, bareArms ? skin : cloth, skin);
  const armR = limb('armR', -.3, .51, .27, .25, .083, bareArms ? skin : cloth, skin);
  const legL = limb('legL', .12, 0, .37, .38, .115, cloth, cloth);
  const legR = limb('legR', -.12, 0, .37, .38, .115, cloth, cloth);
  for (const arm of [armL, armR]) {
    ball(arm.end, 'hand', skin, [0, -.025, .015], [.063, .075, .062]);
    box(arm.joint, 'wristBand', armored ? white : accent, [0, -.19, 0], [.14, .085, .14]);
  }
  for (const leg of [legL, legR]) {
    box(leg.end, 'boot', armored ? white : dark, [0, -.06, .045], [.18, .12, .29]);
    box(leg.joint, 'bootCuff', armored ? gold : accent, [0, -.26, 0], [.18, .14, .18]);
  }

  if (armored) {
    box(hips, 'breastplate', armor, [0, .36, .025], [.5, .38, .33]);
    box(hips, 'armorPanel', style === 'frost' ? frost : gold, [0, .27, .2], [.32, .16, .025]);
    for (const side of [-1, 1]) {
      box(hips, 'shoulderGuard', armor, [side * .31, .56, 0], [.21, .09, .34]);
      if (style === 'elite') box(hips, 'hipGuard', gold, [side * .25, -.03, 0], [.13, .25, .3]);
    }
  } else if (robed) {
    mesh(hips, 'robeSkirt', 'CylinderGeometry', [.23, .35, .52, 10], cloth, [0, -.16, 0]);
    box(hips, 'cape', white, [0, .2, -.22], [.62, .8, .035]);
    ball(hips, 'collar', white, [0, .57, -.02], [.32, .1, .19]);
    if (style === 'angel') box(hips, 'robeEmblem', gold, [0, .33, .17], [.12, .27, .02]);
  } else if (style === 'jacket' || style === 'vest') {
    for (const side of [-1, 1]) box(hips, 'jacketPanel', cloth, [side * .16, .36, .15], [.16, .39, .06]);
    box(hips, 'jacketTrim', gold, [0, .36, .18], [.025, .4, .025]);
  } else if (style !== 'suit') {
    for (const side of [-1, 1]) {
      const lapel = box(hips, 'giLapel', style === 'weighted' ? white : accent, [side * .075, .47, .16], [.055, .26, .03]);
      lapel.rotation.z = side * -.45;
    }
    ball(hips, 'giBadge', white, [.16, .4, .16], [.045, .045, .015]);
  }

  let tail = null;
  if (L.race.tail) {
    tail = group(hips, 'tail', [0, -.015, -.14]);
    const points = L.race.id === 'FrostDemon'
      ? [[0, 0, 0], [0, -.22, -.3], [.15, -.32, -.65], [.28, -.1, -.85]]
      : [[0, 0, 0], [.2, -.05, -.2], [.36, .1, -.24], [.32, .3, -.2]];
    mesh(tail, 'tailMesh', 'TubeGeometry', [new THREE.CatmullRomCurve3(points.map(p => new THREE.Vector3(...p))), 10, L.race.id === 'FrostDemon' ? .065 : .035, 6, false], L.race.id === 'FrostDemon' ? skin : mat(C.tailBrown));
  }
  if (L.race.id === 'Namekian') {
    const patch = mat(C.namekPatch);
    for (const side of [-1, 1]) {
      const antenna = cone(head, 'antenna', skin, [side * .085, .22, .06], .022, .17);
      antenna.rotation.z = side * -.35;
      ball(head, 'pointedEar', skin, [side * .21, 0, -.01], [.075, .035, .03]);
    }
    for (const arm of [armL, armR]) box(arm.pivot, 'armPatch', patch, [0, -.15, .078], [.09, .13, .015]);
  } else if (L.race.id === 'FrostDemon') {
    ball(head, 'crownPlate', frost, [0, .09, -.015], [.15, .105, .14]);
    for (const side of [-1, 1]) {
      const horn = cone(head, 'horn', dark, [side * .22, .09, -.01], .045, .21);
      horn.rotation.z = side * -1.1;
    }
  } else if (L.race.id === 'Majin') {
    const curl = cone(head, 'headTentacle', skin, [0, .23, -.04], .065, .25);
    curl.rotation.x = -.5;
    for (const side of [-1, 1]) for (let i = 0; i < 3; i++) ball(head, 'vent', dark, [side * .147, -.025 + i * .04, .07], [.009, .009, .009]);
  }

  const attach = { head, chest: group(hips, 'chest', [0, .35, .2]), back: group(hips, 'back', [0, .35, -.24]), waist: hips,
    handL: armL.end, handR: armR.end, footL: legL.end, footR: legR.end };
  let phase = 0, aura = null, disposed = false;
  function setAura(hex) {
    if (hex == null) {
      if (aura) { aura.removeFromParent(); aura.geometry.dispose(); aura.material.dispose(); aura = null; }
      return;
    }
    if (!aura) {
      aura = new THREE.Mesh(new THREE.SphereGeometry(1, 12, 10), new THREE.MeshBasicMaterial({ transparent: true, opacity: .16, depthWrite: false, blending: THREE.AdditiveBlending, wireframe: true }));
      aura.name = 'aura'; aura.position.y = .95; aura.scale.set(.65, 1.12, .65); body.add(aura);
    }
    aura.material.color.setHex(hex);
  }
  return {
    object3d: root, attach,
    update(dt, anim = {}) {
      if (disposed || dt <= 0) return;
      const speed = Math.max(0, anim.speed || 0);
      const stride = anim.onGround && !anim.charging ? Math.min(1, speed / 8) : 0;
      phase += dt * (4 + speed * 1.1);
      const swing = Math.sin(phase) * .85 * stride;
      legL.pivot.rotation.x = swing; legR.pivot.rotation.x = -swing;
      legL.joint.rotation.x = Math.max(0, -Math.sin(phase)) * stride;
      legR.joint.rotation.x = Math.max(0, Math.sin(phase)) * stride;
      armL.pivot.rotation.set(-swing * .7, 0, -.08);
      armR.pivot.rotation.set(swing * .7, 0, .08);
      armL.joint.rotation.x = armR.joint.rotation.x = -.15 - stride * .3;
      hips.position.y = .87 + Math.abs(Math.sin(phase)) * .025 * stride;
      hips.rotation.x = anim.dashing ? .55 : anim.flying ? .16 : 0;
      if (!anim.onGround) {
        legL.pivot.rotation.x = -.3; legR.pivot.rotation.x = .12;
        legL.joint.rotation.x = .6; legR.joint.rotation.x = .2;
      }
      if (anim.flying || anim.dashing) armL.pivot.rotation.x = armR.pivot.rotation.x = .35;
      if (anim.charging || anim.blocking) {
        armL.pivot.rotation.x = armR.pivot.rotation.x = -.8;
        armL.joint.rotation.x = armR.joint.rotation.x = -1.2;
        armL.pivot.rotation.z = anim.charging ? -.35 : -.1;
        armR.pivot.rotation.z = -armL.pivot.rotation.z;
      }
      if (tail) tail.rotation.y = Math.sin(phase * .4) * .12;
      if (aura) aura.material.opacity = .16 + Math.sin(phase * 3) * .035;
    },
    setHairColor(hex) { hair.color.setHex(hex ?? L.hairColor); },
    setAura,
    dispose() {
      if (disposed) return;
      disposed = true; setAura(null);
      geometries.forEach(g => g.dispose()); materials.forEach(m => m.dispose()); root.removeFromParent();
    },
  };
}
