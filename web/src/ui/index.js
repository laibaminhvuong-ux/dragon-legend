// Screen registry. Screens are DOM overlays above the canvas; they read game state and call app
// methods, never change game state directly.
//
//   registerScreen(name, factory)    factory(app) -> { mount(container, params), unmount(), update?(frameDt) }
//   app.ui.show(name, params)        mounts the screen (no-op if already shown)
//   app.ui.hide(name) / app.ui.isShown(name) / app.ui.has(name)
//
// Screen names the game uses (main.js shows/hides them):
//   "slotSelect"     menu scene: pick / create / delete a character, then app.startGame(index)
//   "hud"            play scene, always on
//   "pause"          when app.paused is true
//   "touchControls"  play scene on touch devices: drives input.setVirtual / setVirtualAxis / addLook
// A registered screen replaces the dev fallback of the same name (ui/dev.js).
const factories = new Map();

export function registerScreen(name, factory) {
  factories.set(name, factory);
}

export function createUI(app, root) {
  const shown = new Map(); // name -> { screen, el }
  return {
    has: (name) => factories.has(name),
    isShown: (name) => shown.has(name),
    show(name, params = {}) {
      if (shown.has(name)) return;
      const factory = factories.get(name);
      if (!factory) return;
      const el = document.createElement("div");
      el.className = "screen screen-" + name;
      root.appendChild(el);
      const screen = factory(app);
      shown.set(name, { screen, el });
      screen.mount(el, params);
    },
    hide(name) {
      const s = shown.get(name);
      if (!s) return;
      shown.delete(name);
      try { s.screen.unmount(); } finally { s.el.remove(); }
    },
    hideAll() { for (const n of [...shown.keys()]) this.hide(n); },
    /** Called once per frame by main.js. */
    update(frameDt) { for (const { screen } of shown.values()) screen.update?.(frameDt); },
  };
}
