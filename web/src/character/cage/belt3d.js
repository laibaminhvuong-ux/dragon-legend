// Copied from Cage Career 3D (web/belt3d.js) so Dragon Legend's fighters use the same model. Keep in sync by hand.
// Championship hardware: a distinct silhouette, metal, enamel and strap per promotion.
import * as THREE from "three";

export const BELT_STYLES = {
  GFC: { shape: "octagon", strap: "#121217", metal: "#d5ab43", rim: "#f3d785", enamel: "#16151b", accent: "#c8102e", label: "GFC", title: "WORLD CHAMPION" },
  CWE: { shape: "shield", strap: "#13213b", metal: "#bac5d3", rim: "#edf2f8", enamel: "#173765", accent: "#579bd8", label: "CWE", title: "EUROPEAN CHAMPION" },
  PFL: { shape: "hexagon", strap: "#20201c", metal: "#c9a249", rim: "#e3d4ab", enamel: "#202c27", accent: "#37b77b", label: "PFL", title: "LEAGUE CHAMPION" },
  "Valor FC": { shape: "star", strap: "#174431", metal: "#c5cbd0", rim: "#f1e5bd", enamel: "#153c2d", accent: "#e7cf82", label: "VALOR", title: "WORLD CHAMPION" },
  DFC: { shape: "flame", strap: "#60151b", metal: "#dfad39", rim: "#ffe0a0", enamel: "#731b22", accent: "#e94c35", label: "DFC", title: "DRAGON CHAMPION" },
  "Iron Cage": { shape: "circle", strap: "#493326", metal: "#737f89", rim: "#b6bec4", enamel: "#252c32", accent: "#cf9356", label: "IRON CAGE", title: "REGIONAL CHAMPION" },
  "Contender Series": { shape: "diamond", strap: "#29252e", metal: "#ac9b74", rim: "#ded4ba", enamel: "#35303c", accent: "#c7a55e", label: "CONTENDER", title: "SERIES WINNER" },
};
const ALIASES = {
  gfc: "GFC", cwe: "CWE", pfl: "PFL", valor: "Valor FC", dfc: "DFC",
  "Global Fighting Championship": "GFC", "Cage Warriors Europe": "CWE",
  "Pro Fighters League": "PFL", "Valor Fighting Championships": "Valor FC", "Dragon Fighting Championship": "DFC",
};
export function beltStyle(org) {
  return BELT_STYLES[org] || BELT_STYLES[ALIASES[org]] || BELT_STYLES.GFC;
}
const wordmarks = new Map(); // Deliberately shared, like fighter iris textures.
function wordmark(style, side) {
  const key = style.label + (side ? ":side" : ":main");
  if (wordmarks.has(key)) return wordmarks.get(key);
  const canvas = document.createElement("canvas");
  canvas.width = 512; canvas.height = 384;
  const g = canvas.getContext("2d");
  g.clearRect(0, 0, 512, 384);
  g.textAlign = "center"; g.textBaseline = "middle";
  g.fillStyle = style.rim;
  g.font = "700 29px Arial, sans-serif";
  if (!side) g.fillText("CHAMPIONSHIP", 256, 102, 420);
  g.font = "900 " + (style.label.length > 7 ? 65 : style.label.length > 4 ? 86 : 120) + "px Arial, sans-serif";
  g.fillText(style.label, 256, 194, 445);
  if (!side) {
    g.font = "700 28px Arial, sans-serif";
    g.fillText(style.title, 256, 280, 430);
    g.fillStyle = style.accent;
    g.fillRect(142, 135, 228, 6);
    g.fillRect(174, 244, 164, 5);
  }
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 4;
  wordmarks.set(key, t);
  return t;
}
function outline(kind) {
  const s = new THREE.Shape();
  if (kind === "shield") {
    s.moveTo(-1, 0.88); s.lineTo(1, 0.88); s.lineTo(0.88, -0.15);
    s.quadraticCurveTo(0.72, -0.73, 0, -1.05);
    s.quadraticCurveTo(-0.72, -0.73, -0.88, -0.15); s.closePath();
    return s;
  }
  const n = kind === "octagon" ? 8 : kind === "hexagon" ? 6 : kind === "diamond" ? 4 : kind === "star" ? 10 : 48;
  for (let i = 0; i < n; i++) {
    const a = Math.PI / 2 + i * Math.PI * 2 / n;
    let r = kind === "star" && i % 2 ? 0.78 : 1;
    if (kind === "flame") r = 0.89 + 0.11 * Math.sin(a * 7 + 0.5);
    const x = Math.cos(a) * r, y = Math.sin(a) * r;
    if (i) s.lineTo(x, y); else s.moveTo(x, y);
  }
  s.closePath();
  return s;
}

/** Matches Fighter3D's waist/shoulder visibility contract. Geometry/materials are fighter-owned. */
export function createPromotionBelt({ width, hips, chest, org, envMap = null }) {
  const style = beltStyle(org);
  const metal = new THREE.MeshStandardMaterial({ color: style.metal, roughness: 0.3, metalness: 0.85, envMap, envMapIntensity: 0.7 });
  const rim = new THREE.MeshStandardMaterial({ color: style.rim, roughness: 0.24, metalness: 0.82, envMap, envMapIntensity: 0.7 });
  const enamel = new THREE.MeshStandardMaterial({ color: style.enamel, roughness: 0.34, metalness: 0.25, envMap });
  const accent = new THREE.MeshStandardMaterial({ color: style.accent, roughness: 0.2, metalness: 0.35, envMap });
  const leather = new THREE.MeshStandardMaterial({ color: style.strap, roughness: 0.88 });
  const add = (parent, geometry, material, x = 0, y = 0, z = 0) => {
    const m = new THREE.Mesh(geometry, material);
    m.position.set(x, y, z); m.castShadow = m.receiveShadow = true; parent.add(m); return m;
  };
  const plate = (parent, x, y, z, big) => {
    const group = new THREE.Group(); group.position.set(x, y, z); parent.add(group);
    group.name = (big ? "center-plate-" : "side-plate-") + style.label;
    const w = big ? 0.095 : 0.043, h = big ? 0.078 : 0.04;
    const g = new THREE.ExtrudeGeometry(outline(style.shape), { depth: 0.01, bevelEnabled: true, bevelSize: 0.0025, bevelThickness: 0.002, bevelSegments: 2, curveSegments: 20 });
    g.scale(w, h, 1);
    add(group, g, metal);
    const inset = g.clone(); inset.scale(0.87, 0.85, 0.5);
    add(group, inset, enamel, 0, 0, 0.01);
    const face = new THREE.MeshBasicMaterial({ map: wordmark(style, !big), transparent: true, depthWrite: false, toneMapped: false });
    const text = add(group, new THREE.PlaneGeometry(w * 1.65, h * 1.6), face, 0, 0, 0.019);
    text.castShadow = false;
    // Studs and jewels give the plates depth even when the lettering is too far away to read.
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) {
      add(group, new THREE.SphereGeometry(big ? 0.004 : 0.0025, 8, 6), rim, sx * w * 0.58, sy * h * 0.62, 0.014);
    }
    if (big) for (const sx of [-1, 1]) {
      const jewel = add(group, new THREE.OctahedronGeometry(0.007), accent, sx * w * 0.83, 0, 0.014);
      jewel.scale.y = 1.35;
    }
    return group;
  };
  const waist = new THREE.Group(); waist.name = "belt-waist-" + style.label;
  waist.position.y = 0.035; hips.add(waist);
  const strap = add(waist, new THREE.CylinderGeometry(0.172 * width, 0.172 * width, 0.083, 32, 1, true), leather);
  strap.scale.z = 0.76;
  plate(waist, 0, 0, 0.172 * width * 0.76 + 0.006, true);
  for (const sx of [-1, 1]) {
    const side = plate(waist, sx * 0.13 * width, 0, 0.09, false); side.rotation.y = sx * 0.85;
    for (const y of [-0.028, 0.028]) for (let i = 0; i < 3; i++) {
      add(waist, new THREE.SphereGeometry(0.0022, 6, 4), rim, sx * (0.06 + i * 0.018), y, 0.132 * width);
    }
  }
  const sash = new THREE.Group(); sash.name = "belt-shoulder-" + style.label;
  sash.position.set(0, 0.1, 0); sash.rotation.z = 0.55; chest.add(sash);
  const loop = new THREE.TorusGeometry(0.26, 0.024, 6, 30); loop.scale(0.66, 1, 1.6);
  add(sash, loop, leather).rotation.y = Math.PI / 2;
  const front = plate(chest, -0.02, 0.1, 0.125 * width + 0.01, true); front.rotation.z = 0.55;
  sash.userData.plate = front;
  waist.visible = sash.visible = front.visible = false;
  return { waist, sash, style, promotion: Object.keys(BELT_STYLES).find(k => BELT_STYLES[k] === style) };
}
