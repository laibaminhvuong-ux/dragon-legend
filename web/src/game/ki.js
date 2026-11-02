// Ki rules (ported from KiService). Works on any entity with { ki, maxKi }.
import { KI_REGEN_PER_SECOND } from "../data/stats.js";

export function addKi(e, n) {
  e.ki = Math.max(0, Math.min(e.maxKi, e.ki + n));
  return e.ki;
}

/** Spends n ki if the entity has it. Returns true if spent. */
export function trySpendKi(e, n) {
  if (e.ki < n) return false;
  e.ki -= n;
  return true;
}

/** Passive regen, once per fixed step. */
export function regenKi(e, dt) {
  if (e.ki < e.maxKi) addKi(e, KI_REGEN_PER_SECOND * dt);
}
