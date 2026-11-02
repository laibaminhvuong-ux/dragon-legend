// Shape of saved data. Rules: add fields with defaults in migrate(), never rename or remove one,
// and bump SCHEMA_VERSION with every change.
import { STAT_NAMES, SLOT_COUNT, STARTING_ZENI } from "../data/stats.js";
import { ensureStoryState } from "./story.js";

// v2: slot.story (unlocked/visited worlds, items, flags); zone "test" became "earth_plains"
export const SCHEMA_VERSION = 2;

export function newProfile() {
  return { version: SCHEMA_VERSION, slots: new Array(SLOT_COUNT).fill(null), lastSlot: -1 };
}

/** A fresh character from an already-validated look. */
export function newSlot(look, now = Date.now()) {
  const { race, ...appearance } = look;
  return withStory({
    race,
    appearance,
    level: 1,
    xp: 0,
    statPoints: 0,
    stats: Object.fromEntries(STAT_NAMES.map((n) => [n, 0])),
    zeni: STARTING_ZENI,
    outfits: [look.outfit], // owned outfit ids
    forms: [], // unlocked form ids
    moves: [], // unlocked move ids (M2)
    quests: {}, // questId -> { status, step, t, count, collected, completions } (game/story.js)
    story: null, // filled by ensureStoryState below
    zone: "earth_plains",
    position: null, // {x, y, z} or null = zone spawn
    createdAt: now,
    playedAt: now,
    playTime: 0, // seconds
  });
}

function withStory(slot) {
  ensureStoryState(slot);
  return slot;
}

function fillSlot(s) {
  s.stats ||= {};
  for (const n of STAT_NAMES) s.stats[n] ??= 0;
  s.outfits ||= [s.appearance.outfit];
  s.forms ||= [];
  s.moves ||= [];
  s.quests ||= {};
  s.zeni ??= STARTING_ZENI;
  s.statPoints ??= 0;
  s.xp ??= 0;
  s.level ??= 1;
  s.zone ||= "earth_plains";
  if (s.zone === "test") s.zone = "earth_plains";
  ensureStoryState(s);
  s.position ??= null;
  s.createdAt ??= Date.now();
  s.playedAt ??= s.createdAt;
  s.playTime ??= 0;
}

/** Brings any older (or damaged) save up to the current shape. */
export function migrate(data) {
  if (!data || typeof data !== "object" || !Array.isArray(data.slots)) return newProfile();
  const slots = new Array(SLOT_COUNT).fill(null);
  for (let i = 0; i < SLOT_COUNT; i++) {
    const s = data.slots[i];
    if (s && typeof s === "object" && s.race && s.appearance) {
      fillSlot(s);
      slots[i] = s;
    }
  }
  data.slots = slots;
  data.lastSlot = Number.isInteger(data.lastSlot) ? data.lastSlot : -1;
  data.version = SCHEMA_VERSION;
  return data;
}
