// Pure functions for XP, levels and derived stats. Used by the game for the real values and by the
// UI for previews (stat screen, creator), so both always agree. Ported from Progression.luau.
import * as S from "../data/stats.js";
import { getRace } from "../data/races.js";
import { FORMS } from "../data/forms.js";

/** XP needed to go from `level` to `level + 1` (0 at max level). */
export function xpToNext(level) {
  return level >= S.MAX_LEVEL ? 0 : Math.floor(100 * Math.pow(level, 1.5));
}

/** XP after the race's early-growth bonus (Half-Saiyan, Human). */
export function applyXPBonus(raceId, level, amount) {
  const b = getRace(raceId)?.xpBonusBelowLevel;
  return b && level < b.level ? Math.floor(amount * (1 + b.bonus)) : amount;
}

/** Points in a stat, counting the race bonus. */
export function points(slot, stat) {
  return (slot.stats[stat] || 0) + (getRace(slot.race)?.statBonus[stat] || 0);
}

export function formMultiplier(formId) {
  return (formId && FORMS[formId]?.multiplier) || 1;
}

/** Everything derived from a saved slot plus the active form ("" or null = base). */
export function derive(slot, formId = "") {
  const race = getRace(slot.race);
  const mult = formMultiplier(formId);
  const level = slot.level;
  const maxHealth = S.BASE_HEALTH + (level - 1) * S.HEALTH_PER_LEVEL + points(slot, "Health") * S.HEALTH_PER_POINT;
  const maxKi = S.BASE_KI + (level - 1) * S.KI_PER_LEVEL + points(slot, "Ki") * S.KI_PER_POINT;
  const runSpeed = Math.min(S.MAX_RUN_SPEED, S.BASE_RUN_SPEED + points(slot, "Speed") * S.RUN_SPEED_PER_POINT * mult);
  let total = 0;
  for (const n of S.STAT_NAMES) total += points(slot, n);
  return {
    maxHealth: Math.floor(maxHealth * mult),
    maxKi, // forms drain ki instead of raising the pool
    runSpeed,
    strength: (1 + points(slot, "Strength") * 0.02) * mult, // melee damage multiplier
    kiPower: (1 + points(slot, "KiPower") * 0.02) * mult, // ki attack damage multiplier
    powerLevel: Math.floor((level * 50 + total * 25) * (race?.powerMultiplier || 1) * mult),
  };
}

/** Forms this race has the level for, in unlock order. */
export function formsAtLevel(raceId, level) {
  return (getRace(raceId)?.forms || []).filter((id) => FORMS[id].unlockLevel <= level);
}

/**
 * Adds XP to a slot (mutates it), applying the race bonus and levelling up as many times as it
 * covers. Returns the levels gained (0 if none).
 */
export function addXP(slot, amount) {
  if (!(amount > 0) || slot.level >= S.MAX_LEVEL) return 0;
  slot.xp += applyXPBonus(slot.race, slot.level, Math.floor(amount));
  let gained = 0;
  while (slot.level < S.MAX_LEVEL && slot.xp >= xpToNext(slot.level)) {
    slot.xp -= xpToNext(slot.level);
    slot.level++;
    slot.statPoints += S.POINTS_PER_LEVEL;
    gained++;
  }
  if (slot.level >= S.MAX_LEVEL) slot.xp = 0;
  return gained;
}

/** Spends stat points on a slot (mutates it). Returns null on success or an error message. */
export function spendStatPoint(slot, stat, amount = 1) {
  if (!S.STAT_NAMES.includes(stat)) return "Unknown stat";
  if (!Number.isInteger(amount) || amount < 1) return "Bad amount";
  if (slot.statPoints < amount) return "Not enough stat points";
  slot.statPoints -= amount;
  slot.stats[stat] = (slot.stats[stat] || 0) + amount;
  return null;
}
