// Scene switching. A scene is { enter(params), exit(), update(dt), render(frameDt, alpha) };
// every method is optional. Scenes in use: "menu" (slot select / creator), "play".
export function createScenes(events = null) {
  const scenes = new Map();
  let current = null, currentName = "";
  return {
    register(name, scene) { scenes.set(name, scene); },
    go(name, params = {}) {
      const next = scenes.get(name);
      if (!next) throw new Error(`No scene "${name}"`);
      current?.exit?.();
      current = next;
      currentName = name;
      next.enter?.(params);
      events && events.emit("scene", { name, params });
    },
    get name() { return currentName; },
    update(dt) { current?.update?.(dt); },
    render(frameDt, alpha) { current?.render?.(frameDt, alpha); },
  };
}
