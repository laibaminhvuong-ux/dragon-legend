// Draws the story in the world: NPCs (with name tags and quest markers), Dragon Balls and other
// pickups, travel pads to other worlds, and a beam of light over the current objective.
// createStoryView(gfx, story) -> { update(dt, playerPos), refresh(), dispose() }
import * as THREE from "three";
import { createCharacterModel } from "../character/index.js";

const disposables = [];
const own = (x) => { disposables.push(x); return x; };

/** A text sprite (name tags, pad labels, objective text). */
function label(text, { color = "#ffffff", size = 34, bg = "rgba(0,0,0,0.45)", worldHeight = 0.42 } = {}) {
  const pad = 14;
  const c = document.createElement("canvas");
  const g = c.getContext("2d");
  g.font = `600 ${size}px system-ui, sans-serif`;
  const w = Math.ceil(g.measureText(text).width) + pad * 2, h = size + pad;
  c.width = w; c.height = h;
  g.font = `600 ${size}px system-ui, sans-serif`;
  if (bg) { g.fillStyle = bg; roundRect(g, 0, 0, w, h, h / 2.6); g.fill(); }
  g.fillStyle = color;
  g.textBaseline = "middle";
  g.fillText(text, pad, h / 2 + 1);
  const tex = own(new THREE.CanvasTexture(c));
  tex.colorSpace = THREE.SRGBColorSpace;
  const sprite = new THREE.Sprite(own(new THREE.SpriteMaterial({ map: tex, depthWrite: false, transparent: true, fog: false })));
  sprite.scale.set((worldHeight * w) / h, worldHeight, 1);
  sprite.renderOrder = 10;
  sprite.userData.noAO = true;
  return sprite;
}
function roundRect(g, x, y, w, h, r) {
  g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
}

const MARKERS = { "!": { text: "!", color: "#ffd23a" }, side: { text: "!", color: "#f2f2f2" }, "?": { text: "?", color: "#ffd23a" }, "⚔": { text: "⚔", color: "#ff5a4a" } };

function dragonBallTexture(stars, color = "#d8202a") {
  const c = document.createElement("canvas");
  c.width = 256; c.height = 128;
  const g = c.getContext("2d");
  const grad = g.createLinearGradient(0, 0, 0, 128);
  grad.addColorStop(0, "#ffd36a"); grad.addColorStop(1, "#f08a12");
  g.fillStyle = grad; g.fillRect(0, 0, 256, 128);
  // stars on the front of the ball (u around 0.5)
  g.fillStyle = color;
  const pts = [[128, 64], [112, 50], [144, 50], [112, 78], [144, 78], [128, 40], [128, 88]].slice(0, stars);
  for (const [x, y] of pts) star(g, x, y, stars === 1 ? 14 : 9);
  const t = own(new THREE.CanvasTexture(c));
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
function star(g, x, y, r) {
  g.beginPath();
  for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r; g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
  g.closePath(); g.fill();
}

export function createStoryView(gfx, story) {
  const { scene, quality } = gfx;
  disposables.length = 0;
  const root = new THREE.Group();
  scene.add(root);

  // ------------------------------------------------------------- NPCs
  const npcs = new Map(); // id -> { model, tag, marker, data }
  function syncNpcs() {
    const list = story.npcs();
    const seen = new Set();
    for (const n of list) {
      seen.add(n.id);
      let e = npcs.get(n.id);
      if (!e) {
        const model = createCharacterModel({ ...n.look }, { castShadow: quality.shadows });
        model.object3d.scale.multiplyScalar(n.scale);
        model.object3d.position.set(n.x, n.y, n.z);
        model.object3d.rotation.y = n.rot;
        if (n.boss) model.setAura?.(0xff3a3a);
        root.add(model.object3d);
        const tag = label(n.name, { color: n.boss ? "#ffb0a8" : "#ffffff" });
        tag.position.set(n.x, n.y + 2.15 * n.scale + 0.25, n.z);
        root.add(tag);
        e = { model, tag, marker: null, markerKey: "", data: n, yaw: n.rot };
        npcs.set(n.id, e);
      }
      e.data = n;
      const key = n.marker ? (n.marker === "!" && !n.main ? "side" : n.marker) : "";
      if (key !== e.markerKey) {
        if (e.marker) root.remove(e.marker);
        e.marker = key ? label(MARKERS[key].text, { color: MARKERS[key].color, size: 60, bg: null, worldHeight: 0.8 }) : null;
        if (e.marker) { e.marker.position.set(n.x, n.y + 2.15 * n.scale + 1.0, n.z); root.add(e.marker); }
        e.markerKey = key;
      }
    }
    for (const [id, e] of npcs) if (!seen.has(id)) {
      e.model.dispose(); root.remove(e.tag); if (e.marker) root.remove(e.marker);
      npcs.delete(id);
    }
  }

  // ------------------------------------------------------------- pickups
  const pickups = new Map(); // "quest:index" -> object
  const ballGeo = own(new THREE.SphereGeometry(0.32, 32, 16));
  const glowTex = own(radialGlow());
  function syncPickups() {
    const list = story.pickups();
    const seen = new Set();
    for (const p of list) {
      const key = p.questId + ":" + p.index;
      seen.add(key);
      if (pickups.has(key)) continue;
      const g = new THREE.Group();
      g.position.set(p.x, p.y, p.z);
      if (p.item === "supplies") {
        const crate = new THREE.Mesh(own(new THREE.BoxGeometry(0.9, 0.7, 0.9)), own(new THREE.MeshStandardMaterial({ color: 0x8a6a3a, roughness: 0.8 })));
        crate.position.y = -0.25; crate.castShadow = true;
        g.add(crate);
      } else {
        const big = p.item === "namek_ball";
        const ball = new THREE.Mesh(ballGeo, own(new THREE.MeshPhysicalMaterial({ map: dragonBallTexture(p.index % 7 + 1, big ? "#c81818" : "#d8202a"), roughness: 0.08, clearcoat: 1, emissive: 0xff8a20, emissiveIntensity: 0.35 })));
        ball.scale.setScalar(big ? 2.2 : 1);
        g.add(ball);
      }
      const glow = new THREE.Sprite(own(new THREE.SpriteMaterial({ map: glowTex, color: 0xffa040, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending })));
      glow.scale.setScalar(2.4);
      glow.userData.noAO = true;
      g.add(glow);
      root.add(g);
      pickups.set(key, g);
    }
    for (const [k, g] of pickups) if (!seen.has(k)) { root.remove(g); pickups.delete(k); }
  }

  // ------------------------------------------------------------- travel pads
  const padGroup = new THREE.Group();
  root.add(padGroup);
  let padKey = "";
  const padMat = own(new THREE.MeshStandardMaterial({ color: 0x9fd8ff, emissive: 0x3aa0ff, emissiveIntensity: 1.6, roughness: 0.3 }));
  const padDisc = own(new THREE.MeshBasicMaterial({ color: 0x3aa0ff, transparent: true, opacity: 0.35, depthWrite: false, blending: THREE.AdditiveBlending }));
  const ringGeo = own(new THREE.TorusGeometry(1.1, 0.07, 10, 48));
  const discGeo = own(new THREE.CircleGeometry(1.05, 40));
  const beamGeo = own(new THREE.CylinderGeometry(1.0, 1.0, 6, 32, 1, true));
  const beamMat = own(new THREE.MeshBasicMaterial({ color: 0x3aa0ff, transparent: true, opacity: 0.12, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending }));
  function syncPads() {
    const list = story.pads();
    const key = list.map((p) => p.zone).join(",");
    if (key === padKey) return;
    padKey = key;
    padGroup.clear();
    for (const p of list) {
      const g = new THREE.Group();
      g.position.set(p.x, p.y + 0.05, p.z);
      const ring = new THREE.Mesh(ringGeo, padMat); ring.rotation.x = Math.PI / 2; g.add(ring);
      const disc = new THREE.Mesh(discGeo, padDisc); disc.rotation.x = -Math.PI / 2; disc.position.y = 0.02; g.add(disc);
      const beam = new THREE.Mesh(beamGeo, beamMat); beam.position.y = 3; beam.userData.noAO = true; g.add(beam);
      const tag = label(p.name, { color: "#bfe6ff", size: 30, worldHeight: 0.36 }); tag.position.y = 2.4; g.add(tag);
      padGroup.add(g);
    }
  }

  // ------------------------------------------------------------- objective beacon
  const beacon = new THREE.Group();
  const bMat = own(new THREE.MeshBasicMaterial({ color: 0xffc83a, transparent: true, opacity: 0.22, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending, fog: false }));
  // the beam starts above head height so the person you're looking for stays visible inside it
  const bBeam = new THREE.Mesh(own(new THREE.CylinderGeometry(0.35, 0.35, 120, 24, 1, true)), bMat);
  bBeam.position.y = 63.2; bBeam.userData.noAO = true;
  beacon.add(bBeam);
  root.add(beacon);
  let beaconText = "", beaconLabel = null;

  function refresh() { syncNpcs(); syncPickups(); syncPads(); }
  refresh();

  let t = 0, since = 0;
  return {
    refresh,
    update(dt, playerPos) {
      t += dt;
      if ((since += dt) > 0.3) { since = 0; refresh(); }
      // NPCs idle, and turn to face you when you come close
      for (const e of npcs.values()) {
        const n = e.data;
        const d = Math.hypot(playerPos.x - n.x, playerPos.z - n.z);
        const want = d < 7 ? Math.atan2(playerPos.x - n.x, playerPos.z - n.z) : n.rot;
        let diff = ((want - e.yaw + Math.PI * 3) % (Math.PI * 2)) - Math.PI;
        e.yaw += diff * Math.min(1, dt * 4);
        e.model.object3d.rotation.y = e.yaw;
        e.model.update(dt, { speed: 0, onGround: true, flying: false, charging: false, dashing: false, blocking: false });
        if (e.marker) e.marker.position.y = n.y + 2.15 * n.scale + 1.0 + Math.sin(t * 3) * 0.08;
      }
      for (const g of pickups.values()) { g.children[0].rotation.y += dt * 1.5; g.position.y += Math.sin(t * 2.4) * 0.002; }
      // beacon over the current objective
      const w = story.waypoint();
      beacon.visible = !!w && Math.hypot(w.x - playerPos.x, w.z - playerPos.z) > 5;
      if (w) {
        beacon.position.set(w.x, w.y, w.z);
        if (w.text !== beaconText) {
          beaconText = w.text;
          if (beaconLabel) beacon.remove(beaconLabel);
          beaconLabel = label(w.text, { color: "#ffe08a", size: 30, worldHeight: 0.5 });
          beaconLabel.position.y = 4.2;
          beacon.add(beaconLabel);
        }
        // the label grows with distance so it stays readable
        const d = Math.hypot(w.x - playerPos.x, w.z - playerPos.z);
        if (beaconLabel) { const k = Math.max(1, d / 18); beaconLabel.scale.set(beaconLabel.scale.x / beaconLabel.scale.y * 0.5 * k, 0.5 * k, 1); beaconLabel.position.y = 4.2 + k * 1.2; }
      }
      bMat.opacity = 0.16 + Math.sin(t * 2) * 0.05;
    },
    dispose() {
      for (const e of npcs.values()) e.model.dispose();
      scene.remove(root);
      for (const d of disposables) d.dispose?.();
      disposables.length = 0;
    },
  };
}

function radialGlow() {
  const c = document.createElement("canvas");
  c.width = c.height = 64;
  const g = c.getContext("2d");
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, "rgba(255,255,255,0.9)"); grad.addColorStop(0.35, "rgba(255,200,120,0.35)"); grad.addColorStop(1, "rgba(255,160,60,0)");
  g.fillStyle = grad; g.fillRect(0, 0, 64, 64);
  return new THREE.CanvasTexture(c);
}
