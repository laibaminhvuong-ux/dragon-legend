// Character appearance ("look") validation and defaults. A look is what the creator produces and
// what a slot stores in `appearance`:
//   { race, skin, face, hair, hairColor, build, outfit, outfitTint }
//   race/face/hair/build/outfit = string ids; skin/hairColor/outfitTint = 0-based palette indexes.
import { getRace } from "../data/races.js";
import { FACES, HAIR_STYLES, HAIR_COLORS, BUILDS, TINTS, findById } from "../data/appearance.js";
import { OUTFITS, outfitAllowed } from "../data/outfits.js";

const isIndex = (v, list) => Number.isInteger(v) && v >= 0 && v < list.length;

/** Returns null if the look is valid for a new character, else a message for the player. */
export function validateLook(look) {
  if (!look || typeof look !== "object") return "Missing appearance";
  const race = getRace(look.race);
  if (!race) return "Pick a race";
  if (!isIndex(look.skin, race.skins)) return "Bad skin colour";
  if (!findById(FACES, look.face)) return "Bad face";
  if (!findById(HAIR_STYLES, look.hair) || !race.hairStyles.includes(look.hair)) return "That hair isn't available for this race";
  if (!isIndex(look.hairColor, HAIR_COLORS)) return "Bad hair colour";
  if (!findById(BUILDS, look.build)) return "Bad build";
  if (!OUTFITS[look.outfit]?.starter || !outfitAllowed(look.outfit, look.race)) return "That outfit isn't available for this race";
  if (!isIndex(look.outfitTint, TINTS)) return "Bad outfit colour";
  return null;
}

/** A valid default look for a race (the creator's starting point when the race changes). */
export function defaultLook(raceId = "Saiyan") {
  const race = getRace(raceId) || getRace("Saiyan");
  const outfit = Object.keys(OUTFITS).find((id) => OUTFITS[id].starter && outfitAllowed(id, race.id));
  return { race: race.id, skin: 0, face: FACES[0].id, hair: race.hairStyles[0], hairColor: 0, build: "Average", outfit, outfitTint: 0 };
}

/** Resolves a stored look into actual colours/objects for renderers. */
export function resolveLook(look) {
  const race = getRace(look.race);
  return {
    race,
    skinColor: race.skins[look.skin] ?? race.skins[0],
    hairColor: HAIR_COLORS[look.hairColor] ?? HAIR_COLORS[0],
    tintColor: TINTS[look.outfitTint] ?? TINTS[0],
    face: look.face,
    hair: look.hair,
    build: findById(BUILDS, look.build) || BUILDS[1],
    outfit: look.outfit,
  };
}
