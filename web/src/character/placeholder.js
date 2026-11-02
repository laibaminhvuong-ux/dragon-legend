// PLACEHOLDER fighter: a simple jointed mannequin from boxes/spheres so the skeleton has something
// to move. Codex's lane replaces this with the real procedural models (hair, faces, outfits, race
// features), keeping the contract in character/index.js.
import * as THREE from "three";
import { resolveLook } from "../game/look.js";

export function createCharacterModel(look, { castShadow = true } = {}) {
  const L = resolveLook(look);
  const mats = [];
  const mat = (color) => { const m = new THREE.MeshStandardMaterial({ color, roughness: 0.7 }); mats.push(m); return m; };
  const skin = mat(L.skinColor), tint = mat(L.tintColor), hairMat = mat(L.hairColor), dark = mat(0x1e1e24);
  const geos = [];
  const box = (w, h, d, m) => { const g = new THREE.BoxGeometry(w, h, d); geos.push(g); const mesh = new THREE.Mesh(g, m); mesh.castShadow = castShadow; return mesh; };
  const ball = (r, m) => { const g = new THREE.SphereGeometry(r, 16, 12); geos.push(g); const mesh = new THREE.Mesh(g, m); mesh.castShadow = castShadow; return mesh; };

  const root = new THREE.Group();
  const body = new THREE.Group(); // scaled by build
  body.scale.set(L.build.width, L.build.height, L.build.depth);
  root.add(body);

  const hips = new THREE.Group(); hips.position.y = 0.95; body.add(hips);
  const torso = box(0.46, 0.55, 0.26, tint); torso.position.y = 0.3; hips.add(torso);
  const belt = box(0.48, 0.08, 0.28, dark); belt.position.y = 0.04; hips.add(belt);
  const neck = new THREE.Group(); neck.position.y = 0.6; hips.add(neck);
  const head = ball(0.15, skin); head.position.y = 0.16; neck.add(head);
  if (L.hair !== "None") { const h = ball(0.165, hairMat); h.scale.set(1, 0.75, 1); h.position.set(0, 0.22, -0.02); neck.add(h); }
  const eyes = box(0.16, 0.03, 0.02, dark); eyes.position.set(0, 0.17, 0.145); neck.add(eyes);
  if (L.race.tail) { const t = box(0.05, 0.05, 0.45, L.race.id === "Saiyan" ? hairMat : skin); t.position.set(0, -0.05, -0.3); t.rotation.x = 0.5; hips.add(t); }

  function limb(x, y, len, w, upperMat, lowerMat, parent) {
    const pivot = new THREE.Group(); pivot.position.set(x, y, 0); parent.add(pivot);
    const upper = box(w, len, w, upperMat); upper.position.y = -len / 2; pivot.add(upper);
    const knee = new THREE.Group(); knee.position.y = -len; pivot.add(knee);
    const lower = box(w * 0.9, len, w * 0.9, lowerMat); lower.position.y = -len / 2; knee.add(lower);
    const end = new THREE.Group(); end.position.y = -len; knee.add(end);
    return { pivot, knee, end };
  }
  const armL = limb(0.3, 0.52, 0.3, 0.11, tint, skin, hips);
  const armR = limb(-0.3, 0.52, 0.3, 0.11, tint, skin, hips);
  const legL = limb(0.12, 0, 0.46, 0.15, tint, tint, hips);
  const legR = limb(-0.12, 0, 0.46, 0.15, tint, tint, hips);

  const attach = {
    head: neck, chest: new THREE.Object3D(), back: new THREE.Object3D(), waist: hips,
    handL: armL.end, handR: armR.end, footL: legL.end, footR: legR.end,
  };
  attach.chest.position.set(0, 0.35, 0.14); hips.add(attach.chest);
  attach.back.position.set(0, 0.35, -0.14); hips.add(attach.back);

  let phase = 0, aura = null;
  return {
    object3d: root,
    attach,
    update(dt, anim) {
      const s = anim.onGround ? Math.min(1, anim.speed / 8) : 0;
      phase += dt * (4 + anim.speed * 1.1);
      const swing = Math.sin(phase) * 0.9 * s;
      legL.pivot.rotation.x = swing; legR.pivot.rotation.x = -swing;
      legL.knee.rotation.x = Math.max(0, -Math.sin(phase)) * s; legR.knee.rotation.x = Math.max(0, Math.sin(phase)) * s;
      armL.pivot.rotation.x = -swing * 0.8; armR.pivot.rotation.x = swing * 0.8;
      armL.knee.rotation.x = armR.knee.rotation.x = -0.4 * s - 0.1;
      if (!anim.onGround && !anim.flying) { legL.pivot.rotation.x = -0.5; legL.knee.rotation.x = 0.9; legR.pivot.rotation.x = 0.2; }
      hips.position.y = 0.95 + Math.abs(Math.sin(phase)) * 0.04 * s;
      if (aura) aura.material.opacity = 0.25 + Math.sin(phase * 3) * 0.08;
    },
    setHairColor(hex) { hairMat.color.setHex(hex ?? L.hairColor); },
    setAura(hex) {
      if (hex == null) { if (aura) { root.remove(aura); aura.geometry.dispose(); aura.material.dispose(); aura = null; } return; }
      if (!aura) {
        aura = new THREE.Mesh(new THREE.SphereGeometry(0.8, 16, 12), new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
        aura.scale.set(0.9, 1.4, 0.9); aura.position.y = 1; root.add(aura);
      }
      aura.material.color.setHex(hex);
    },
    dispose() {
      this.setAura(null);
      geos.forEach((g) => g.dispose());
      mats.forEach((m) => m.dispose());
      root.removeFromParent();
    },
  };
}
