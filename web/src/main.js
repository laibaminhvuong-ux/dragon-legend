// Boot: builds the shared `app` object, the scenes and the loop.
//
// `app` is what every system and screen gets:
//   app.events  app.settings  app.input  app.save  app.scenes  app.loop  app.ui  app.gfx (renderer)
//   app.game    current play session (game/game.js) or null outside play
//   app.story   the story in the current world (game/story.js): quests, NPCs, travel. null outside play
//   app.travel(zoneId)  go to another world (saves first)
//   app.paused  app.setPaused(bool)  app.startGame(slotIndex)  app.quitToMenu()  app.saveNow()
//   app.music   soundtrack: app.music.play(worldId | mood), app.music.current
//   app.version
import { createEvents } from "./core/events.js";
import { createSettings } from "./core/settings.js";
import { createInput } from "./core/input.js";
import { createSaveStore } from "./core/save.js";
import { createScenes } from "./core/scenes.js";
import { createLoop } from "./core/loop.js";
import { createRenderer } from "./render/renderer.js";
import { createFollowCamera } from "./render/camera.js";
import { createGame, emptyIntents } from "./game/game.js";
import { getZone } from "./game/zones.js";
import { createStory } from "./game/story.js";
import { FORMS } from "./data/forms.js";
import { createCombatView } from "./combat/view.js";
import { createStoryView } from "./world/story_view.js";
import { buildZone } from "./world/testzone.js";
import { createCharacterModel, updateCharacterLod } from "./character/index.js";
import { createUI } from "./ui/index.js";
import "./ui/screens.js";
import { registerDevFallbacks } from "./ui/dev.js";
import { defaultLook } from "./game/look.js";
import { VERSION } from "./version.js";
import { createMusic } from "./audio/music.js";

const AUTOSAVE_SECONDS = 60;
const params = new URLSearchParams(location.search);
const canvas = document.getElementById("game");
const uiRoot = document.getElementById("ui");

const events = createEvents();
const settings = createSettings(events);
const app = {
  version: VERSION,
  events,
  settings,
  input: createInput(canvas, settings, events),
  save: createSaveStore(events),
  scenes: createScenes(events),
  gfx: createRenderer(canvas, settings, events),
  game: null,
  paused: false,
  loop: null,
  ui: null,
};
app.ui = createUI(app, uiRoot);
app.music = createMusic(settings, events);
registerDevFallbacks(app.ui);

app.setPaused = (p) => {
  if (!app.game || app.paused === p) return;
  app.paused = p;
  app.input.pointerLockWanted = !p;
  if (p) { document.exitPointerLock?.(); app.ui.show("pause"); app.saveNow(); } else app.ui.hide("pause");
  events.emit("pause", { paused: p });
};
app.saveNow = () => { if (app.game) app.save.saveSlot(app.game.slotIndex, app.game.toSave()); };
app.startGame = (slotIndex) => app.scenes.go("play", { slotIndex });
/** Travel to another world: save, show a short "travelling" card, rebuild the scene there. */
app.travel = (zoneId) => {
  if (!app.game) return;
  const slotIndex = app.game.slotIndex;
  const slot = app.game.toSave();
  slot.zone = zoneId;
  slot.position = null;
  app.save.saveSlot(slotIndex, slot);
  const card = document.createElement("div");
  card.id = "loading";
  card.innerHTML = `<div class="loading-orb"></div><div>${getZone(zoneId).name}</div><small>${getZone(zoneId).planet} · ${getZone(zoneId).saga}</small>`;
  document.body.appendChild(card);
  setTimeout(() => {
    app.scenes.go("play", { slotIndex });
    requestAnimationFrame(() => requestAnimationFrame(() => card.remove()));
  }, 40);
};
let pendingTravel = null;
events.on("travel", ({ zone }) => (pendingTravel = zone));
app.quitToMenu = () => { app.saveNow(); app.scenes.go("menu"); };

// ---- the world (built once, shared by the menu backdrop and play) -----------------------------
let world = null;
function ensureWorld(zone) {
  if (world && world.zone === zone) return world;
  world?.dispose();
  world = buildZone(app.gfx, zone);
  app.world = world;
  return world;
}
events.on("qualityChanged", () => {
  if (!world) return;
  const zone = world.zone;
  world.dispose();
  world = null;
  ensureWorld(zone);
});

// ---- menu scene: slow flyover behind the slot select -------------------------------------------
let menuTime = 0;
app.scenes.register("menu", {
  enter() {
    app.input.pointerLockWanted = false;
    document.exitPointerLock?.();
    app.ui.hideAll();
    ensureWorld(getZone("earth_plains"));
    app.ui.show("slotSelect");
    app.music.play("menu");
  },
  exit() { app.ui.hide("slotSelect"); },
  render(frameDt) {
    menuTime += frameDt;
    const zone = world.zone, cam = app.gfx.camera;
    const a = menuTime * 0.025 + 0.8, rad = 120;
    const x = Math.sin(a) * rad, z = Math.cos(a) * rad;
    cam.position.set(x, Math.max(zone.heightAt(x, z), zone.water?.level ?? 0) + 14, z);
    cam.lookAt(Math.sin(a + 0.9) * 60, 10, Math.cos(a + 0.9) * 60);
    const focus = { x, y: 0, z };
    world.update(frameDt, focus, cam.position);
    app.gfx.followSun(focus);
    app.gfx.render(frameDt);
  },
});

// ---- play scene -------------------------------------------------------------------------------
let play = null; // { model, cam, prev, saveTimer }
app.scenes.register("play", {
  enter({ slotIndex }) {
    const slot = app.save.loadSlot(slotIndex);
    if (!slot) return app.scenes.go("menu");
    app.game = createGame(slotIndex, slot, events);
    app.story = createStory(app.game, events);
    app.paused = false;
    const shadows = app.gfx.quality.shadows;
    ensureWorld(app.game.zone);
    const storyView = createStoryView(app.gfx, app.story, app.game.combat);
    const combatView = createCombatView(app.gfx, app.game.combat, events);
    app.music.play(app.game.zone.id);
    const model = createCharacterModel({ race: slot.race, ...slot.appearance }, { castShadow: shadows });
    app.gfx.scene.add(model.object3d);
    const cam = createFollowCamera(app.gfx.camera, app.game.zone);
    cam.setYaw(app.game.player.yaw);
    play = { model, cam, storyView, combatView, prev: { ...app.game.player.pos }, saveTimer: 0 };
    app.input.pointerLockWanted = true;
    app.ui.hideAll();
    app.ui.show("hud");
    app.ui.show("rpg");
    if (matchMedia("(pointer: coarse)").matches) app.ui.show("touchControls");
  },
  exit() {
    app.ui.hideAll();
    play?.model.dispose();
    play?.storyView.dispose();
    play?.combatView.dispose();
    app.story = null;
    play = null;
    app.game = null;
    app.paused = false;
  },
  update(dt) {
    const { input, game } = app;
    if (app.dialogueOpen) { app.dialogueInput?.(input); return; }
    if (input.pressed("pause")) app.setPaused(!app.paused);
    if (app.paused || app.dialogueOpen || !play) return;
    const it = emptyIntents();
    const mv = input.axis("move"), yaw = play.cam.yaw;
    it.moveX = Math.sin(yaw) * mv.y - Math.cos(yaw) * mv.x;
    it.moveZ = Math.cos(yaw) * mv.y + Math.sin(yaw) * mv.x;
    for (const a of ["jump", "dash", "flight", "melee", "kiBlast", "transform", "lockOn", "interact"]) it[a] = input.pressed(a);
    for (const a of ["ascend", "descend", "charge", "block", "beam"]) it[a] = input.down(a);
    it.melee = input.down("melee") || it.melee;
    play.prev = { ...game.player.pos };
    game.update(dt, it);
    app.story.update(dt, it);
    if (pendingTravel) { const z = pendingTravel; pendingTravel = null; return app.travel(z); }
    if ((play.saveTimer += dt) >= AUTOSAVE_SECONDS) { play.saveTimer = 0; app.saveNow(); }
  },
  render(frameDt, alpha) {
    if (!play) return app.gfx.render(frameDt);
    const p = app.game.player;
    const renderAlpha = app.paused || app.dialogueOpen ? 1 : alpha;
    const pos = { x: play.prev.x + (p.pos.x - play.prev.x) * renderAlpha, y: play.prev.y + (p.pos.y - play.prev.y) * renderAlpha, z: play.prev.z + (p.pos.z - play.prev.z) * renderAlpha };
    const frozen = app.paused || app.dialogueOpen;
    if (!frozen) play.cam.addLook(app.input.takeLook(frameDt));
    else app.input.takeLook(frameDt);
    const lookKey = app.game.slot.appearance.outfit;
    if (play.outfit !== lookKey) {
      if (play.outfit !== undefined) {
        play.model.dispose();
        play.model = createCharacterModel({ race: app.game.slot.race, ...app.game.slot.appearance }, { castShadow: app.gfx.quality.shadows });
        app.gfx.scene.add(play.model.object3d);play.lastForm=undefined;
      }
      play.outfit=lookKey;
    }
    play.model.object3d.visible = p.health > 0;
    play.model.object3d.position.set(pos.x, pos.y, pos.z);
    play.model.object3d.rotation.y = p.yaw;
    play.model.update(frozen ? 0 : frameDt, { speed: Math.hypot(p.vel.x, p.vel.z), onGround: p.onGround, flying: p.flying, charging: p.charging, dashing: p.dashing, blocking: p.blocking, attackSerial: p.attackSerial, attackKind: p.attackKind });
    if (play.lastForm !== p.form) {
      play.lastForm = p.form;
      play.model.setHairColor(FORMS[p.form]?.hairColor ?? null);
      play.model.setAura(FORMS[p.form]?.auraColor ?? null);
    }
    const target = app.game.combat.enemies.find(e => e.id === p.lockTarget && e.health > 0);
    play.cam.update(pos, frozen ? 0 : frameDt, target?.pos);
    play.combatView.update(frozen ? 0 : frameDt);
    world.update(frozen ? 0 : frameDt, pos, app.gfx.camera.position);
    play.storyView.update(frozen ? 0 : frameDt, pos);
    // battle music when a villain is close, the world's own theme otherwise
    if ((play.musicCheck = (play.musicCheck || 0) + frameDt) > 1) {
      play.musicCheck = 0;
      const villain = app.story.npcs().some((n) => n.boss && Math.hypot(n.x - pos.x, n.z - pos.z) < 45);
      app.music.play(villain ? "battle" : app.game.zone.id);
    }
    app.gfx.followSun(pos);
    updateCharacterLod(app.gfx.camera);
    app.gfx.render(frameDt);
  },
});

// pointer lock lost while playing (Esc in the browser) = pause
let hadLock = false;
document.addEventListener("pointerlockchange", () => {
  const locked = document.pointerLockElement === canvas;
  if (hadLock && !locked && app.scenes.name === "play" && !app.paused && !app.dialogueOpen) app.setPaused(true);
  hadLock = locked;
});
addEventListener("visibilitychange", () => document.hidden && app.saveNow());
addEventListener("beforeunload", () => app.saveNow());
// leaving the page: save and stop drawing
addEventListener("pagehide", () => {
  app.saveNow();
  app.loop?.stop();
});

app.loop = createLoop({
  beforeFrame: () => app.input.poll(),
  update(dt) {
    app.scenes.update(dt);
    app.input.endTick();
  },
  render(frameDt, alpha) {
    app.scenes.render(frameDt, alpha);
    app.ui.update(frameDt);
  },
});

// ?dev: skip the menu (creates a default Saiyan in slot 1 if it's empty)
if (params.has("dev")) {
  if (!app.save.listSlots()[0]) app.save.createSlot(0, defaultLook("Saiyan"));
  app.startGame(0);
} else app.scenes.go("menu");
app.loop.start();
requestAnimationFrame(() => requestAnimationFrame(() => document.getElementById("loading")?.remove()));

// test hook for tools/check_smoke.cjs (and the dev console)
globalThis.__dragonlegend = app;
