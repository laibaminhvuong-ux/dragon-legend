// Tiny event bus. app.events is the shared one.
// Event names in use: "notify" {text}, "levelup" {level, gained}, "stats" (hud snapshot),
// "settings" {key, value}, "slots" (slot list changed), "scene" {name, params}, "pause" {paused}.
export function createEvents() {
  const map = new Map();
  return {
    /** Subscribes; returns an unsubscribe function. */
    on(name, fn) {
      if (!map.has(name)) map.set(name, new Set());
      map.get(name).add(fn);
      return () => map.get(name)?.delete(fn);
    },
    off(name, fn) {
      map.get(name)?.delete(fn);
    },
    emit(name, data) {
      for (const fn of [...(map.get(name) || [])]) {
        try { fn(data); } catch (e) { console.error(`event "${name}" handler failed`, e); }
      }
    },
  };
}
