// Shape of saved data. Rules: add fields with defaults in migrate(), never rename or remove one,
// and bump SCHEMA_VERSION with every change.
import { STAT_NAMES, SLOT_COUNT, STARTING_ZENI } from "../data/stats.js";
import { ensureStoryState } from "./story.js";

// v2: slot.story (unlocked/visited worlds, items, flags); zone "test" became "earth_plains"
// v3: persistent equipped technique; all v1/v2 fields are retained.
// v4: shared Saiyan legacy unlocks and a persistent max-level form path.
export const SCHEMA_VERSION = 4;

export function newProfile() {
  return { version: SCHEMA_VERSION, slots: new Array(SLOT_COUNT).fill(null), lastSlot: -1 };
}

/** A fresh character from an already-validated look. */
export function newSlot(look, now = Date.now()) {
  const { race, ...appearance } = look;
  return withStory({
    race,
    appearance: {...appearance,accessory:appearance.accessory || "None"},
    level: 1,
    xp: 0,
    statPoints: 0,
    stats: Object.fromEntries(STAT_NAMES.map((n) => [n, 0])),
    zeni: STARTING_ZENI,
    outfits: [look.outfit], // owned outfit ids
    forms: [], // unlocked form ids
    moves: [], // unlocked move ids
    loadout: { technique: "EnergyWave", formPath: null, accessory: "None" },
    formMastery: {},
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
  if (!s.loadout || typeof s.loadout !== "object" || Array.isArray(s.loadout)) s.loadout = {};
  if (typeof s.loadout.technique !== "string") s.loadout.technique = "EnergyWave";
  s.loadout.accessory ??= s.appearance.accessory || "None";
  s.appearance.accessory ??= s.loadout.accessory;
  if(!s.formMastery || typeof s.formMastery!=="object" || Array.isArray(s.formMastery))s.formMastery={};
  for(const key of Object.keys(s.formMastery))if(!Number.isFinite(s.formMastery[key]) || s.formMastery[key]<0)s.formMastery[key]=0;
  if (!['beast','instinct','ego'].includes(s.loadout.formPath)) s.loadout.formPath=null;
  s.quests ||= {};
  if (['Saiyan','HalfSaiyan'].includes(s.race)) {
    for(const [oldId,newId] of [['HSSJ','SSJ'],['HSSJ2','SSJ2']]) {
      if(s.forms.includes(oldId) && !s.forms.includes(newId))s.forms.push(newId);
      if(s.quests['Form_'+oldId] && !s.quests['Form_'+newId])s.quests['Form_'+newId]=structuredClone(s.quests['Form_'+oldId]);
    }
  }
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
      if((data.version || 1)<4 && Number.isFinite(s.level) && s.level>1){
        const oldLevel=s.level, fraction=(s.xp || 0)/(oldLevel<150?Math.floor(100*oldLevel**1.5):1);
        s.level=Math.min(2000,oldLevel*10);s.statPoints=(s.statPoints || 0)+(s.level-oldLevel)*3;
        s.xp=s.level<2000?Math.floor(Math.max(0,Math.min(.999,fraction))*100*s.level**1.5):0;
      }
      fillSlot(s);
      slots[i] = s;
    }
  }
  data.slots = slots;
  data.lastSlot = Number.isInteger(data.lastSlot) ? data.lastSlot : -1;
  data.version = SCHEMA_VERSION;
  return data;
}
