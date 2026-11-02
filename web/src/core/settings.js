// Player settings, saved separately from characters. UI writes with set(); systems read with get()
// and listen for the "settings" event.
import { storage } from "./storage.js";

const KEY = "dragonlegend.settings";
const touch = typeof navigator !== "undefined" && navigator.maxTouchPoints > 0 && /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent);

/** Every setting: default value and allowed values/range. */
export const SETTINGS_SCHEMA = {
  // automated test browsers (no GPU) default to low; phones to medium; desktops to high
  quality: { default: typeof navigator !== "undefined" && navigator.webdriver ? "low" : touch ? "medium" : "high", options: ["low", "medium", "high"] },
  masterVolume: { default: 0.8, min: 0, max: 1 },
  musicVolume: { default: 0.6, min: 0, max: 1 },
  sfxVolume: { default: 0.8, min: 0, max: 1 },
  voiceVolume: { default: 0.9, min: 0, max: 1 },
  mouseSensitivity: { default: 1, min: 0.1, max: 3 },
  invertY: { default: false, type: "boolean" },
  showFps: { default: false, type: "boolean" },
  /** Overrides on top of core/input.js DEFAULT_BINDINGS: { actionId: [code, ...] }. */
  bindings: { default: {}, type: "object" },
};

function sanitize(key, value) {
  const s = SETTINGS_SCHEMA[key];
  if (!s) return undefined;
  if (s.options) return s.options.includes(value) ? value : s.default;
  if (s.type === "boolean") return typeof value === "boolean" ? value : s.default;
  if (s.type === "object") return value && typeof value === "object" && !Array.isArray(value) ? value : s.default;
  const n = Number(value);
  return Number.isFinite(n) ? Math.min(s.max, Math.max(s.min, n)) : s.default;
}

export function createSettings(events = null) {
  let saved = {};
  try { saved = JSON.parse(storage.get(KEY) || "{}") || {}; } catch { saved = {}; }
  const values = {};
  for (const k of Object.keys(SETTINGS_SCHEMA)) values[k] = k in saved ? sanitize(k, saved[k]) : structuredClone(SETTINGS_SCHEMA[k].default);
  const persist = () => storage.set(KEY, JSON.stringify(values));

  return {
    get: (key) => values[key],
    all: () => structuredClone(values),
    /** Sets a value (clamped / validated). Returns the stored value. */
    set(key, value) {
      if (!(key in SETTINGS_SCHEMA)) throw new Error(`Unknown setting "${key}"`);
      values[key] = sanitize(key, value);
      persist();
      events && events.emit("settings", { key, value: values[key] });
      return values[key];
    },
    reset() {
      for (const k of Object.keys(SETTINGS_SCHEMA)) {
        values[k] = structuredClone(SETTINGS_SCHEMA[k].default);
        events && events.emit("settings", { key: k, value: values[k] });
      }
      persist();
    },
  };
}
