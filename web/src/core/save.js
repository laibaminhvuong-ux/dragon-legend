// Save slots. All slot indexes are 0-based (0..SLOT_COUNT-1).
// The profile is one JSON value in storage; the previous copy is kept as a backup so a bad write
// can't lose everything. Shapes are in game/schema.js.
import { storage } from "./storage.js";
import { SCHEMA_VERSION, newProfile, newSlot, migrate } from "../game/schema.js";
import { validateLook } from "../game/look.js";
import { getRace } from "../data/races.js";
import { SLOT_COUNT } from "../data/stats.js";

const KEY = "dragonball.profile";
const BACKUP = "dragonball.profile.bak";
const CODE_PREFIX = "DB1:";

export { SCHEMA_VERSION };

function read() {
  for (const key of [KEY, BACKUP]) {
    const raw = storage.get(key);
    if (!raw) continue;
    try { return migrate(JSON.parse(raw)); } catch { /* try the backup */ }
  }
  return newProfile();
}

function write(profile) {
  const prev = storage.get(KEY);
  if (prev) storage.set(BACKUP, prev);
  storage.set(KEY, JSON.stringify(profile));
}

const clone = (v) => JSON.parse(JSON.stringify(v));
const badIndex = (i) => !Number.isInteger(i) || i < 0 || i >= SLOT_COUNT;

export function createSaveStore(events = null) {
  let profile = read();
  const changed = () => events && events.emit("slots", null);

  return {
    SLOT_COUNT,
    SCHEMA_VERSION,
    /** true if saves survive closing the app (false in a private window). */
    persistent: storage.persistent,

    /** SLOT_COUNT entries: a summary for the slot-select cards, or null for an empty slot. */
    listSlots() {
      return profile.slots.map((s, index) => s && {
        index, race: s.race, raceName: getRace(s.race)?.name || s.race, level: s.level,
        appearance: clone(s.appearance), createdAt: s.createdAt, playedAt: s.playedAt, playTime: s.playTime,
      });
    },

    /** Creates a character. look = { race, ...appearance } (see game/look.js). */
    createSlot(index, look) {
      if (badIndex(index)) return { ok: false, error: "Bad slot" };
      if (profile.slots[index]) return { ok: false, error: "That slot is taken" };
      const err = validateLook(look);
      if (err) return { ok: false, error: err };
      profile.slots[index] = newSlot(look);
      write(profile);
      changed();
      return { ok: true };
    },

    /** A copy of the slot's data, or null. Hand it to createGame(). */
    loadSlot(index) {
      if (badIndex(index) || !profile.slots[index]) return null;
      profile.lastSlot = index;
      write(profile);
      return clone(profile.slots[index]);
    },

    /** Writes the game's slot data back (game.toSave()). */
    saveSlot(index, slot) {
      if (badIndex(index) || !slot) return false;
      profile.slots[index] = clone(slot);
      write(profile);
      return true;
    },

    deleteSlot(index) {
      if (badIndex(index) || !profile.slots[index]) return { ok: false, error: "That slot is empty" };
      profile.slots[index] = null;
      if (profile.lastSlot === index) profile.lastSlot = -1;
      write(profile);
      changed();
      return { ok: true };
    },

    /** Last played slot index, or -1. */
    lastSlot: () => profile.lastSlot,

    /** Whole profile as a text code the player can copy (move saves between devices). */
    exportCode() {
      const bytes = new TextEncoder().encode(JSON.stringify(profile));
      let bin = "";
      for (const b of bytes) bin += String.fromCharCode(b);
      return CODE_PREFIX + btoa(bin);
    },

    /** Replaces every slot with the ones in the code. */
    importCode(code) {
      try {
        const text = String(code || "").trim();
        if (!text.startsWith(CODE_PREFIX)) return { ok: false, error: "That isn't a Dragon Ball save code" };
        const bin = atob(text.slice(CODE_PREFIX.length));
        const data = JSON.parse(new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0))));
        if (!data || !Array.isArray(data.slots)) return { ok: false, error: "The save code is damaged" };
        if ((data.version || 0) > SCHEMA_VERSION) return { ok: false, error: "That save is from a newer version. Update the game first." };
        profile = migrate(data);
        write(profile);
        changed();
        return { ok: true };
      } catch {
        return { ok: false, error: "The save code is damaged" };
      }
    },
  };
}
