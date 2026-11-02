// TEMPORARY dev screens so the skeleton is playable before the real UI lands. Each is registered
// only if no real screen of that name exists (call registerDevFallbacks() after the real ones).
// Freebuff: delete entries here as your screens replace them.
import { registerScreen } from "./index.js";
import { defaultLook } from "../game/look.js";

const h = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };

const screens = {
  slotSelect: (app) => {
    let off = null;
    return {
      mount(el) {
        el.classList.add("dev-panel");
        const draw = () => {
          el.replaceChildren(h("h1", null, "Dragon Ball"), h("p", "dev-note", "Dev slot select (placeholder until the real creator lands)"));
          app.save.listSlots().forEach((s, i) => {
            const row = h("div", "dev-row");
            row.append(h("span", null, s ? `Slot ${i + 1}: ${s.raceName}, level ${s.level}` : `Slot ${i + 1}: empty`));
            const go = h("button", null, s ? "Play" : "New Saiyan");
            go.onclick = () => {
              if (!s) {
                const r = app.save.createSlot(i, defaultLook("Saiyan"));
                if (!r.ok) return app.events.emit("notify", { text: r.error });
              }
              app.startGame(i);
            };
            row.append(go);
            if (s) { const del = h("button", null, "Delete"); del.onclick = () => app.save.deleteSlot(i); row.append(del); }
            el.append(row);
          });
        };
        draw();
        off = app.events.on("slots", draw);
      },
      unmount() { off && off(); },
    };
  },

  hud: (app) => {
    let line, t = 0;
    return {
      mount(el) { line = h("div", "dev-hud"); el.append(line); },
      update(frameDt) {
        if ((t += frameDt) < 0.1 || !app.game) return;
        t = 0;
        const s = app.game.hud();
        line.textContent = `${s.raceName} · Lv ${s.level} (${s.xp}/${s.xpNext} XP) · HP ${s.health}/${s.maxHealth} · Ki ${s.ki}/${s.maxKi} · PL ${s.powerLevel} · ${s.zeni} zeni` + (app.settings.get("showFps") ? ` · ${app.loop.stats.fps} fps` : "");
      },
      unmount() {},
    };
  },

  pause: (app) => ({
    mount(el) {
      el.classList.add("dev-panel");
      const resume = h("button", null, "Resume");
      resume.onclick = () => app.setPaused(false);
      const quit = h("button", null, "Save and quit to menu");
      quit.onclick = () => app.quitToMenu();
      el.append(h("h1", null, "Paused"), resume, quit);
    },
    unmount() {},
  }),
};

export function registerDevFallbacks(ui) {
  for (const [name, f] of Object.entries(screens)) if (!ui.has(name)) registerScreen(name, f);
}
