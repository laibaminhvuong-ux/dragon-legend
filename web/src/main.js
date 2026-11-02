// Boot: builds the shared `app` object, the scenes and the loop.
//
// `app` is what every system and screen gets:
//   app.events  app.settings  app.input  app.save  app.scenes  app.loop  app.ui  app.gfx (renderer)
//   app.game    current play session (game/game.js) or null outside play
//   app.paused  app.setPaused(bool)  app.startGame(slotIndex)  app.quitToMenu()  app.saveNow()
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
import { buildZone } from "./world/testzone.js";
import { createCharacterModel } from "./character/index.js";
import { createUI } from "./ui/index.js";
import "./ui/screens.js";
import { registerDevFallbacks } from "./ui/dev.js";
import { defaultLook } from "./game/look.js";
import { VERSION } from "./version.js";

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
app.quitToMenu = () => { app.saveNow(); app.scenes.go("menu"); };

// ---- menu scene -------------------------------------------------------------------------------
app.scenes.register("menu", {
  enter() {
    app.input.pointerLockWanted = false;
    document.exitPointerLock?.();
    app.ui.hideAll();
    app.ui.show("slotSelect");
  },
  exit() { app.ui.hide("slotSelect"); },
  render() { app.gfx.render(); },
});

// ---- play scene -------------------------------------------------------------------------------
let play = null; // { zoneView, model, cam, prev, saveTimer }
app.scenes.register("play", {
  enter({ slotIndex }) {
    const slot = app.save.loadSlot(slotIndex);
    if (!slot) return app.scenes.go("menu");
    app.game = createGame(slotIndex, slot, events);
    app.paused = false;
    const shadows = app.gfx.quality.shadows;
    const zoneView = buildZone(app.gfx.scene, app.game.zone, { castShadow: shadows });
    const model = createCharacterModel({ race: slot.race, ...slot.appearance }, { castShadow: shadows });
    app.gfx.scene.add(model.object3d);
    const cam = createFollowCamera(app.gfx.camera, app.game.zone);
    cam.setYaw(app.game.player.yaw);
    play = { zoneView, model, cam, prev: { ...app.game.player.pos }, saveTimer: 0 };
    app.input.pointerLockWanted = true;
    app.ui.hideAll();
    app.ui.show("hud");
    if (matchMedia("(pointer: coarse)").matches) app.ui.show("touchControls");
  },
  exit() {
    app.ui.hideAll();
    play?.model.dispose();
    play?.zoneView.dispose();
    play = null;
    app.game = null;
    app.paused = false;
  },
  update(dt) {
    const { input, game } = app;
    if (input.pressed("pause")) app.setPaused(!app.paused);
    if (app.paused || !play) return;
    const it = emptyIntents();
    const mv = input.axis("move"), yaw = play.cam.yaw;
    it.moveX = Math.sin(yaw) * mv.y - Math.cos(yaw) * mv.x;
    it.moveZ = Math.cos(yaw) * mv.y + Math.sin(yaw) * mv.x;
    for (const a of ["jump", "dash", "flight", "melee", "kiBlast", "transform", "lockOn", "interact"]) it[a] = input.pressed(a);
    for (const a of ["ascend", "descend", "charge", "block", "beam"]) it[a] = input.down(a);
    play.prev = { ...game.player.pos };
    game.update(dt, it);
    if ((play.saveTimer += dt) >= AUTOSAVE_SECONDS) { play.saveTimer = 0; app.saveNow(); }
  },
  render(frameDt, alpha) {
    if (!play) return app.gfx.render();
    const p = app.game.player;
    const pos = { x: play.prev.x + (p.pos.x - play.prev.x) * alpha, y: play.prev.y + (p.pos.y - play.prev.y) * alpha, z: play.prev.z + (p.pos.z - play.prev.z) * alpha };
    if (!app.paused) play.cam.addLook(app.input.takeLook(frameDt));
    else app.input.takeLook(frameDt);
    play.model.object3d.position.set(pos.x, pos.y, pos.z);
    play.model.object3d.rotation.y = p.yaw;
    play.model.update(app.paused ? 0 : frameDt, { speed: Math.hypot(p.vel.x, p.vel.z), onGround: p.onGround, flying: p.flying, charging: p.charging, dashing: p.dashing, blocking: p.blocking });
    play.cam.update(pos, frameDt);
    app.gfx.followSun(pos);
    app.gfx.render();
  },
});

// pointer lock lost while playing (Esc in the browser) = pause
let hadLock = false;
document.addEventListener("pointerlockchange", () => {
  const locked = document.pointerLockElement === canvas;
  if (hadLock && !locked && app.scenes.name === "play" && !app.paused) app.setPaused(true);
  hadLock = locked;
});
addEventListener("visibilitychange", () => document.hidden && app.saveNow());
addEventListener("beforeunload", () => app.saveNow());

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

// test hook for tools/check_smoke.cjs (and the dev console)
globalThis.__dragonlegend = app;
