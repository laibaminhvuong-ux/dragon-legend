import { renameDeep } from "../data/names.js";
import { COMBAT } from "../data/combat.js";
// Shared eligibility and endgame choice authority. UI and combat use the same rules.
import { FORMS } from '../data/forms.js';
import { MAX_LEVEL } from '../data/stats.js';
export const SAIYAN_RACES = ['Saiyan','HalfSaiyan'];
export const FORM_PATHS = {
  beast:{name:'Beast',description:'Unleash your potential through Gohan and Piccolo training.'},
  instinct:{name:'Ultra Instinct',description:'Sign/Omen -> Perfected Ultra Instinct -> True Ultra Instinct, with Moro-era mastery training.'},
  ego:{name:'Ultra Ego',description:'Learn the power of Destruction from Beerus and Vegeta.'},
};
export function formForRace(id,race) {
  const f=FORMS[id];return !!f && !f.legacy && (f.races || [f.race]).includes(race);
}
/** True when this character may use the given level-2000 path. `loadout.testAllPaths` (set by hand on a developer's
 *  own test save, never by the game) opens all three; ordinary saves have exactly one chosen path. */
export function hasFormPath(slot,path) {
  return slot.loadout?.testAllPaths===true || slot.loadout?.formPath===path;
}
export function formAvailable(slot,id) {
  const f=FORMS[id];return formForRace(id,slot.race) && slot.level>=f.unlockLevel && (!f.path || hasFormPath(slot,f.path));
}
export function chooseFormPath(slot,path) {
  if(!SAIYAN_RACES.includes(slot.race))return 'These paths are for Saiyans and Half-Saiyans.';
  if(slot.level<MAX_LEVEL)return `Reach level ${MAX_LEVEL} before choosing a path.`;
  if(!Object.hasOwn(FORM_PATHS,path))return 'Choose Beast, Ultra Instinct or Ultra Ego.';
  if(slot.loadout?.formPath && slot.loadout.formPath!==path)return 'This character already chose a path.';
  (slot.loadout ||= {}).formPath=path;return null;
}
export function usableForms(slot) {return slot.forms.filter(id=>formAvailable(slot,id));}

export function instinctBenefits(player,time) {
  const chance=FORMS[player.form]?.dodgeChance;
  if(chance)return {chance,cost:COMBAT.uiDodgeCost,cooldown:COMBAT.uiFormDodgeCooldown,kind:'form'};
  if(player.uiTechniqueUntil>time)return {chance:COMBAT.uiTechniqueChance,cost:COMBAT.uiDodgeCost,cooldown:COMBAT.uiTechniqueDodgeCooldown,kind:'technique'};
  return {chance:0,cost:0,cooldown:0,kind:'none'};
}

// player-facing names are the game's own (data/names.js)
renameDeep(FORM_PATHS);
