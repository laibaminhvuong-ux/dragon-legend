// Character creator: race + appearance options on the right, a live 3D preview on the left.
// The preview uses createCharacterModel() and its own small renderer so the game scene is untouched.
// Produces a look for app.save.createSlot(), then starts the game.
import * as THREE from "three";
import { createCharacterModel } from "../character/index.js";
import { RACE_ORDER, RACES, getRace } from "../data/races.js";
import { FACES, HAIR_STYLES, HAIR_COLORS, KI_COLORS, BUILDS, TINTS, findById } from "../data/appearance.js";
import { OUTFITS, starterOutfits, outfitAllowed } from "../data/outfits.js";
import { defaultLook } from "../game/look.js";
import { h, btn, hex } from "./dom.js";
import { STR } from "./strings.js";
import { kiColourInput } from './kiColourInput.js';

const IDLE_ANIM = { speed: 0, onGround: true, flying: false, charging: true, dashing: false, blocking: false };

/** Keeps every field valid for its race (used after a race change and for randomize). */
function fixLook(look) {
  const race = getRace(look.race) || getRace(RACE_ORDER[0]);
  const out = { ...look, race: race.id };
  if (!Number.isInteger(out.skin) || out.skin < 0 || out.skin >= race.skins.length) out.skin = 0;
  if (!findById(FACES, out.face)) out.face = FACES[0].id;
  if (!race.hairStyles.includes(out.hair)) out.hair = race.hairStyles[0];
  if (!Number.isInteger(out.hairColor) || out.hairColor < 0 || out.hairColor >= HAIR_COLORS.length) out.hairColor = 0;
  if (!Number.isInteger(out.kiColor) || out.kiColor < 0 || out.kiColor >= KI_COLORS.length) out.kiColor = 0;
  if (!findById(BUILDS, out.build)) out.build = "Average";
  if (!OUTFITS[out.outfit]?.starter || !outfitAllowed(out.outfit, race.id)) out.outfit = starterOutfits(race.id)[0];
  if (!Number.isInteger(out.outfitTint) || out.outfitTint < 0 || out.outfitTint >= TINTS.length) out.outfitTint = 0;
  return out;
}

const pick = (list) => list[Math.floor(Math.random() * list.length)];

export function creator(app) {
  let host = null;
  let canvas = null;
  let renderer = null;
  let scene = null;
  let camera = null;
  let pivot = null;
  let model = null;
  let observer = null;
  let raf = 0;
  let lastTime = 0;
  let slotIndex = 0;
  let look = null;
  let optionHost = null;
  let errorLine = null;

  function buildRenderer() {
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x11151f);
    scene.add(new THREE.HemisphereLight(0xcfe6ff, 0x3b3426, 1.5));

    const key = new THREE.DirectionalLight(0xfff2dd, 2.4);
    key.position.set(2.5, 4, 3);
    const rim = new THREE.DirectionalLight(0x7fb4ff, 1.2);
    rim.position.set(-3, 2.5, -2.5);
    scene.add(key, rim);

    const pedestal = new THREE.Mesh(
      new THREE.CylinderGeometry(1.35, 1.45, 0.14, 40),
      new THREE.MeshStandardMaterial({ color: 0x1c2433, roughness: 0.8, metalness: 0.1 }),
    );
    pedestal.position.y = -0.07;
    scene.add(pedestal);

    camera = new THREE.PerspectiveCamera(32, 1, 0.1, 60);
    camera.layers.enable(1);
    camera.position.set(0, 1.32, 4.4);
    camera.lookAt(0, 0.95, 0);

    pivot = new THREE.Group();
    scene.add(pivot);

    observer = new ResizeObserver(resize);
    observer.observe(canvas.parentElement);
    resize();
  }

  function resize() {
    if (!renderer) return;
    const parent = canvas.parentElement;
    const w = Math.max(1, parent.clientWidth);
    const hh = Math.max(1, parent.clientHeight);
    renderer.setSize(w, hh, false);
    camera.aspect = w / hh;
    camera.updateProjectionMatrix();
  }

  function showModel() {
    if (!pivot) return;
    if (model) {
      pivot.remove(model.object3d);
      model.dispose();
      model = null;
    }
    model = createCharacterModel(look, { castShadow: false });
    pivot.add(model.object3d);
  }

  function setLook(next) {
    look = fixLook(next);
    if (errorLine) errorLine.textContent = "";
    showModel();
    renderOptions();
  }

  function optionSection(title, ...children) {
    const sec = h("section", "opt");
    sec.append(h("h3", null, title), ...children);
    return sec;
  }

  function pillRow(items, value, onPick) {
    const row = h("div", "pill-row");
    for (const item of items) {
      const b = h("button", "pill" + (item.id === value ? " on" : ""), item.name);
      b.type = "button";
      b.addEventListener("click", () => onPick(item.id));
      row.append(b);
    }
    return row;
  }

  function swatchRow(colors, value, onPick) {
    const row = h("div", "swatch-row");
    colors.forEach((c, i) => {
      const b = h("button", "swatch" + (i === value ? " on" : ""));
      b.type = "button";
      b.style.background = hex(c);
      b.title = STR.creator.colour(i + 1);
      b.setAttribute("aria-label", `${STR.creator.colour(i + 1)}`);
      b.addEventListener("click", () => onPick(i));
      row.append(b);
    });
    return row;
  }

  function renderOptions() {
    if (!optionHost) return;
    optionHost.replaceChildren();
    const race = getRace(look.race);

    const raceGrid = h("div", "race-grid");
    for (const id of RACE_ORDER) {
      const r = RACES[id];
      const b = h("button", "race-card" + (look.race === id ? " on" : ""));
      b.type = "button";
      b.append(h("strong", null, r.name), h("span", null, r.description));
      b.addEventListener("click", () => setLook({ ...look, race: id }));
      raceGrid.append(b);
    }
    optionHost.append(optionSection(STR.creator.race, raceGrid));

    optionHost.append(optionSection(STR.creator.body, pillRow(BUILDS, look.build, (id) => setLook({ ...look, build: id }))));
    optionHost.append(optionSection(STR.creator.skin, swatchRow(race.skins, look.skin, (i) => setLook({ ...look, skin: i }))));

    optionHost.append(optionSection(STR.creator.face, pillRow(FACES, look.face, (id) => setLook({ ...look, face: id }))));

    optionHost.append(optionSection(
      STR.creator.hair,
      pillRow(
        race.hairStyles.map((id) => findById(HAIR_STYLES, id) || { id, name: id }),
        look.hair,
        (id) => setLook({ ...look, hair: id }),
      ),
    ));

    optionHost.append(optionSection(
      STR.creator.hairColor,
      swatchRow(HAIR_COLORS, look.hairColor, (i) => setLook({ ...look, hairColor: i })),
    ));
    optionHost.append(optionSection('Ki colour', swatchRow(KI_COLORS, look.kiColorHex? -1:look.kiColor, (i) => setLook({ ...look, kiColor: i, kiColorHex:null }))));
    optionHost.append(kiColourInput(look,(value,phase)=>{look={...look,kiColorHex:value};model?.setKiColor(Number.parseInt(value.slice(1),16));if(!phase?.preview)renderOptions();}));

    optionHost.append(optionSection(
      STR.creator.outfit,
      pillRow(
        starterOutfits(race.id).map((id) => ({ id, name: OUTFITS[id].name })),
        look.outfit,
        (id) => setLook({ ...look, outfit: id }),
      ),
    ));
    optionHost.append(optionSection(
      STR.creator.outfitColor,
      swatchRow(TINTS, look.outfitTint, (i) => setLook({ ...look, outfitTint: i })),
    ));
  }

  function create() {
    const result = app.save.createSlot(slotIndex, look);
    if (!result.ok) {
      if (errorLine) errorLine.textContent = result.error;
      return;
    }
    app.ui.hide("creator");
    app.startGame(slotIndex);
  }

  function randomize() {
    const race = getRace(look.race);
    setLook({
      ...look,
      skin: Math.floor(Math.random() * race.skins.length),
      face: pick(FACES).id,
      hair: pick(race.hairStyles),
      hairColor: Math.floor(Math.random() * HAIR_COLORS.length),
      build: pick(BUILDS).id,
      outfit: pick(starterOutfits(race.id)),
      outfitTint: Math.floor(Math.random() * TINTS.length),
    });
  }

  return {
    mount(el, params = {}) {
      host = el;
      slotIndex = Number.isInteger(params.slotIndex) ? params.slotIndex : 0;
      look = fixLook(defaultLook(RACE_ORDER[0]));

      const layout = h("div", "creator");

      const preview = h("div", "creator-preview");
      canvas = h("canvas", "creator-canvas");
      preview.append(canvas);

      const side = h("div", "creator-side");
      const head = h("div", "creator-head");
      const titles = h("div", "creator-titles");
      titles.append(h("h1", null, STR.creator.title), h("div", "sub", STR.creator.slot(slotIndex + 1)));
      head.append(titles, btn(STR.creator.randomize, randomize, "ghost small"));

      optionHost = h("div", "creator-opts");
      optionHost.setAttribute("aria-label", STR.creator.title);

      const foot = h("div", "creator-foot");
      errorLine = h("p", "err");
      foot.append(errorLine);
      foot.append(btn(STR.common.back, () => app.ui.hide("creator"), "ghost"), btn(STR.creator.create, create, "primary"));

      side.append(head, optionHost, foot);
      layout.append(preview, side);
      el.append(layout);

      buildRenderer();
      showModel();
      renderOptions();

      lastTime = performance.now();
      const tick = (now) => {
        raf = requestAnimationFrame(tick);
        // rAF timestamps can be older than performance.now(), so never step backwards
        const dt = Math.max(0, Math.min(0.1, (now - lastTime) / 1000));
        lastTime = now;
        if (!renderer) return;
        pivot.rotation.y += dt * 0.45;
        model?.update(dt, IDLE_ANIM);
        renderer.render(scene, camera);
      };
      raf = requestAnimationFrame(tick);
    },

    unmount() {
      cancelAnimationFrame(raf);
      raf = 0;
      if (observer) observer.disconnect();
      observer = null;
      if (model) model.dispose();
      model = null;
      if (renderer) {
        renderer.dispose();
        renderer.forceContextLoss?.();
      }
      renderer = null;
      scene = null;
      camera = null;
      pivot = null;
      optionHost = null;
      errorLine = null;
      canvas = null;
      host = null;
    },
  };
}
