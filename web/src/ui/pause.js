// Pause screen: fighter summary and stat points, settings, rebinds, save codes.
// Reads state, writes through app.settings / app.game.spendStatPoint / app.save. Never mutates game
// state directly, and the game keeps running paused (main.js skips its update).
import { h, btn } from "./dom.js";
import { STR, formatDuration, formatKey } from "./strings.js";
import { DEFAULT_BINDINGS, ACTIONS } from "../core/input.js";
import { saveCodePanel } from "./saveCode.js";

const TABS = ["game", "settings", "controls", "codes"];

/** settings.bindings stores overrides only, so drop anything that matches the default. */
function overridesFrom(bindings) {
  const out = {};
  for (const [id, codes] of Object.entries(bindings)) {
    const def = DEFAULT_BINDINGS[id] || [];
    if (codes.join(",") !== def.join(",")) out[id] = codes;
  }
  return out;
}

export function pause(app) {
  let root = null;
  let body = null;
  let tabHost = null;
  let tab = "game";
  let offStats = null;
  let capturing = null;
  let captureHandler = null;
  let message = "";

  function stopCapture() {
    if (captureHandler) window.removeEventListener("keydown", captureHandler, true);
    captureHandler = null;
    capturing = null;
  }

  function startCapture(actionId) {
    stopCapture();
    capturing = actionId;
    message = "";
    render();

    captureHandler = (e) => {
      e.preventDefault();
      e.stopPropagation();
      stopCapture();
      if (e.code === "Escape") return render();
      const all = app.input.bindings();
      const next = {};
      for (const [id, codes] of Object.entries(all)) next[id] = codes.filter((c) => c !== e.code);
      next[actionId] = [e.code];
      app.settings.set("bindings", overridesFrom(next));
      message = STR.pause.controlsSaved;
      render();
    };
    window.addEventListener("keydown", captureHandler, true);
  }

  function statSpend(name) {
    const error = app.game?.spendStatPoint(name, 1);
    message = error || "";
    render();
  }

  // ---- tabs ---------------------------------------------------------------------------------

  function gameTab() {
    const wrap = h("div", "pause-tab");
    const game = app.game;
    if (!game) return wrap.append(h("p", "note", STR.hud.offline)), wrap;
    const s = game.hud();
    const save = game.toSave?.() || {};
    const stats = save.stats || {};

    const info = h("div", "pause-info");
    const row = (label, value) => {
      const r = h("div", "info-row");
      r.append(h("span", "info-label", label), h("span", "info-value", value));
      return r;
    };
    info.append(
      row(STR.pause.race, s.raceName),
      row(STR.pause.level, String(s.level)),
      row(STR.pause.power, String(s.powerLevel)),
      row(STR.pause.zeni, String(s.zeni)),
      row(STR.pause.playTime, formatDuration(save.playTime || 0)),
    );
    wrap.append(info);

    wrap.append(h("p", "points-note", STR.pause.points(s.statPoints)));
    if (s.statPoints > 0) {
      for (const name of Object.keys(STR.pause.statNames)) {
        const r = h("div", "stat-row");
        const add = btn("+", () => statSpend(name), "primary small");
        r.append(
          h("span", "name", STR.pause.statNames[name]),
          h("span", "val", String(stats[name] ?? 0)),
          add,
        );
        wrap.append(r);
      }
      wrap.append(h("p", "note", STR.pause.statHint));
    }
    return wrap;
  }

  function setRow(label, control) {
    const r = h("div", "set-row");
    r.append(h("span", "set-label", label), control);
    return r;
  }

  function slider(key, label, { min = 0, max = 1, step = 0.05, percent = true } = {}) {
    const input = h("input");
    input.type = "range";
    input.min = String(min);
    input.max = String(max);
    input.step = String(step);
    input.value = String(app.settings.get(key));
    const out = h("span", "set-value", percent ? `${Math.round(Number(input.value) * 100)}%` : Number(input.value).toFixed(2));
    input.addEventListener("input", () => {
      const v = app.settings.set(key, Number(input.value));
      out.textContent = percent ? `${Math.round(v * 100)}%` : v.toFixed(2);
    });
    const r = setRow(label, input);
    r.append(out);
    return r;
  }

  function checkbox(key, label) {
    const input = h("input");
    input.type = "checkbox";
    input.checked = Boolean(app.settings.get(key));
    input.addEventListener("change", () => app.settings.set(key, input.checked));
    return setRow(label, input);
  }

  function settingsTab() {
    const wrap = h("div", "pause-tab");

    const select = h("select");
    for (const q of ["low", "medium", "high"]) {
      const opt = h("option", "", STR.pause.qualityOptions[q]);
      opt.value = q;
      select.append(opt);
    }
    select.value = app.settings.get("quality");
    select.addEventListener("change", () => app.settings.set("quality", select.value));
    const qualityRow = setRow(STR.pause.quality, select);
    qualityRow.append(h("span", "set-value", ""));

    wrap.append(
      qualityRow,
      h("p", "note", STR.pause.qualityHint),
      slider("masterVolume", STR.pause.master),
      slider("musicVolume", STR.pause.music),
      slider("sfxVolume", STR.pause.sfx),
      slider("voiceVolume", "Voices"),
      slider("mouseSensitivity", STR.pause.sensitivity, { min: 0.1, max: 3, step: 0.05, percent: false }),
      checkbox("invertY", STR.pause.invertY),
      checkbox("showFps", STR.pause.showFps),
    );

    const reset = h("div", "pause-actions");
    reset.append(btn(STR.pause.resetSettings, () => { app.settings.reset(); message = STR.pause.settingsSaved; render(); }, "ghost small"));
    wrap.append(reset);
    return wrap;
  }

  function controlsTab() {
    const wrap = h("div", "pause-tab");
    wrap.append(h("p", "note", STR.pause.controlsHint));
    const bindings = app.input.bindings();

    for (const action of ACTIONS) {
      const r = h("div", "key-row");
      const codes = h("div", "key-codes");
      for (const code of bindings[action.id] || []) codes.append(h("kbd", "key", formatKey(code)));
      const label = capturing === action.id ? STR.pause.pressKey : STR.pause.change;
      const change = btn(label, () => startCapture(action.id), "ghost small");
      change.disabled = capturing === action.id;
      r.append(h("span", "key-name", action.label), codes, change);
      wrap.append(r);
    }

    const reset = h("div", "pause-actions");
    reset.append(btn(STR.pause.resetControls, () => {
      app.settings.set("bindings", {});
      message = STR.pause.controlsSaved;
      render();
    }, "ghost small"));
    wrap.append(reset);
    return wrap;
  }

  function codesTab() {
    const wrap = h("div", "pause-tab");
    wrap.append(saveCodePanel(app, { onImported: () => render() }));
    if (!app.save.persistent) wrap.append(h("p", "menu-warn", STR.menu.privateWindow));
    return wrap;
  }

  const BUILDERS = { game: gameTab, settings: settingsTab, controls: controlsTab, codes: codesTab };

  function render() {
    if (!root) return;
    root.replaceChildren();

    const panel = h("div", "pause");
    const head = h("div", "pause-head");
    head.append(h("h1", null, STR.pause.title));

    tabHost = h("div", "pause-tabs");
    for (const name of TABS) {
      const b = h("button", "tab" + (tab === name ? " on" : ""), STR.pause.tabs[name]);
      b.type = "button";
      b.addEventListener("click", () => {
        stopCapture();
        tab = name;
        message = "";
        render();
      });
      tabHost.append(b);
    }
    head.append(tabHost);

    body = h("div", "pause-body");
    body.append(BUILDERS[tab]());
    if (message) body.append(h("p", "message", message));

    const foot = h("div", "pause-foot");
    foot.append(
      btn(STR.pause.resume, () => app.setPaused(false), "primary"),
      btn(STR.pause.saveAndQuit, () => app.quitToMenu(), "ghost"),
    );

    panel.append(head, body, foot);
    root.append(panel);
  }

  return {
    mount(el) {
      root = el;
      tab = "game";
      message = "";
      render();
      offStats = app.events.on("stats", () => { if (tab === "game") render(); });
    },
    unmount() {
      stopCapture();
      if (offStats) offStats();
      offStats = null;
      root = null;
      body = null;
      tabHost = null;
    },
  };
}
