import { renameText } from "../data/names.js";
// HUD: health, ki, XP, level, power level, zeni, zone, form, stat-point badge, toasts and FPS.
// Polls app.game.hud() once per frame but only touches the DOM when a value actually changes.
import { h } from "./dom.js";
import { STR } from "./strings.js";
import { createAimReticle } from "./aimReticle.js";

const LOW_FRACTION = 0.3;
const TOAST_MS = 3400;
const MAX_TOASTS = 4;

export function hud(app) {
  let els = null;
  let last = {};
  let offNotify = null;
  let offStats = null;
  let fpsTimer = 0;
  let toastCount = 0;
  let reticle = null;

  const put = (key, value, apply) => {
    if (last[key] === value) return;
    last[key] = value;
    apply(value);
  };

  function bar(cls) {
    const wrap = h("div", "hud-bar " + cls);
    const fill = h("i");
    const label = h("span");
    wrap.append(fill, label);
    return { wrap, fill, label };
  }

  function toast(text) {
    if (!els || !text) return;
    const t = h("div", "toast", text);
    els.toasts.append(t);
    toastCount++;
    while (toastCount > MAX_TOASTS && els.toasts.firstChild) {
      els.toasts.firstChild.remove();
      toastCount--;
    }
    setTimeout(() => {
      t.classList.add("out");
      setTimeout(() => {
        if (t.isConnected) { t.remove(); toastCount--; }
      }, 420);
    }, TOAST_MS);
  }

  return {
    mount(el) {
      const root = h("div", "hud");

      const left = h("div", "hud-left");
      const name = h("div", "hud-name");
      const race = h("span", "race");
      const level = h("span", "lv");
      const zone = h("span", "zone");
      const form = h("span", "hud-form");
      name.append(race, level, form, zone);

      const hp = bar("hp");
      const ki = bar("ki");
      const xp = bar("xp");

      const meta = h("div", "hud-meta");
      const power = h("span");
      const zeni = h("span");
      meta.append(power, zeni);

      const points = h("button", "hud-points");
      points.type = "button";
      points.hidden = true;
      points.addEventListener("click", () => app.setPaused(true));

      left.append(name, hp.wrap, ki.wrap, xp.wrap, meta, points);

      const fps = h("div", "hud-fps");
      fps.hidden = true;
      const toasts = h("div", "hud-toasts");
      toasts.setAttribute("aria-live", "polite");

      root.append(left, fps, toasts);
      el.append(root);
      reticle = createAimReticle(root,app);
      els = { root, race, level, zone, form, hp, ki, xp, power, zeni, points, fps, toasts };

      put("showFps", app.settings.get("showFps"), (v) => { fps.hidden = !v; });
      offNotify = app.events.on("notify", ({ text }) => toast(renameText(text)));
      offStats = app.events.on("stats", () => { last = {}; });
    },

    update(frameDt) {
      reticle?.update();
      if (!els) return;
      const game = app.game;
      if (!game) return;
      const s = game.hud();

      put("race", s.raceName, (v) => { els.race.textContent = v; });
      put("level", s.level, (v) => { els.level.textContent = STR.hud.level(v); });
      put("zone", s.zoneName || "", (v) => { els.zone.textContent = v; });
      put("form", s.formName !== "Base" ? s.formName || s.form : "", (v) => {
        els.form.textContent = v;
        els.form.hidden = !v;
      });

      const hpPct = s.maxHealth > 0 ? Math.max(0, Math.min(1, s.health / s.maxHealth)) : 0;
      put("hpPct", Math.round(hpPct * 1000), () => {
        els.hp.fill.style.width = `${hpPct * 100}%`;
        els.hp.wrap.classList.toggle("low", hpPct <= LOW_FRACTION);
      });
      put("hpText", `${Math.ceil(s.health)}/${s.maxHealth}`, () => {
        els.hp.label.textContent = STR.hud.health(s.health, s.maxHealth);
      });

      const kiPct = s.maxKi > 0 ? Math.max(0, Math.min(1, s.ki / s.maxKi)) : 0;
      put("kiPct", Math.round(kiPct * 1000), () => { els.ki.fill.style.width = `${kiPct * 100}%`; });
      put("kiText", `${Math.floor(s.ki)}/${s.maxKi}`, () => {
        els.ki.label.textContent = STR.hud.ki(s.ki, s.maxKi);
      });

      const xpPct = s.xpNext > 0 ? Math.max(0, Math.min(1, s.xp / s.xpNext)) : 0;
      put("xpPct", Math.round(xpPct * 1000), () => { els.xp.fill.style.width = `${xpPct * 100}%`; });
      put("xpTitle", `${Math.floor(s.xp)}/${s.xpNext}`, () => {
        els.xp.wrap.title = STR.hud.xp(s.xp, s.xpNext);
      });

      put("pl", s.powerLevel, (v) => { els.power.textContent = STR.hud.power(v); });
      put("zeni", s.zeni, (v) => { els.zeni.textContent = STR.hud.zeni(v); });

      put("points", s.statPoints > 0 ? s.statPoints : 0, (v) => {
        els.points.hidden = v === 0;
        els.points.textContent = STR.hud.statPoints(v);
      });

      const showFps = app.settings.get("showFps");
      put("showFps", showFps, (v) => { els.fps.hidden = !v; });
      if (showFps && (fpsTimer += frameDt) >= 0.25) {
        fpsTimer = 0;
        els.fps.textContent = STR.hud.fps(Math.round(app.loop.stats.fps));
      }
    },

    unmount() {
      reticle?.dispose();reticle=null;
      if (offNotify) offNotify();
      if (offStats) offStats();
      offNotify = offStats = null;
      els = null;
      last = {};
      toastCount = 0;
    },
  };
}
