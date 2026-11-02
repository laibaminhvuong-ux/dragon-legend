// Outfit sets. races null = every race. starter = offered in the creator.
// Others come from quests or the shop (unlock "quest" / "shop", price in zeni).
export const OUTFIT_ORDER = [
  "TurtleGi", "SaiyanArmor", "NamekRobe", "CapsuleCorp", "CraneGi", "FrostArmor", "MajinVest",
  "WeightedGi", "EliteArmor", "SaiyanSuit", "GiantsRobe", "PrideTrooper", "AngelRobe",
];

export const OUTFITS = {};
function outfit(id, name, starter, races, unlock, price) {
  OUTFITS[id] = { id, name, starter, races, unlock, price };
}

outfit("TurtleGi", "Turtle School Gi", true, null, "starter", 0);
outfit("SaiyanArmor", "Saiyan Battle Armor", true, ["Saiyan", "HalfSaiyan", "FrostDemon"], "starter", 0);
outfit("NamekRobe", "Namekian Robe", true, ["Namekian"], "starter", 0);
outfit("CapsuleCorp", "Capsule Corp Jacket", true, ["HalfSaiyan", "Human", "Saiyan"], "starter", 0);
outfit("CraneGi", "Crane School Gi", false, null, "shop", 1500);
outfit("FrostArmor", "Frieza Force Armor", true, ["FrostDemon"], "starter", 0);
outfit("MajinVest", "Majin Vest", true, ["Majin"], "starter", 0);
outfit("WeightedGi", "Weighted Training Gi", false, null, "quest", null);
outfit("EliteArmor", "Elite Saiyan Armor", false, ["Saiyan", "HalfSaiyan"], "quest", null);
outfit("SaiyanSuit", "Saiyan Bodysuit", false, null, "shop", 3000);
outfit("GiantsRobe", "Demon Clan Robe", false, ["Namekian"], "quest", null);
outfit("PrideTrooper", "Pride Trooper Uniform", false, null, "quest", null);
outfit("AngelRobe", "Angel's Robe", false, null, "quest", null);

export function outfitAllowed(outfitId, raceId) {
  const o = Object.prototype.hasOwnProperty.call(OUTFITS, outfitId) ? OUTFITS[outfitId] : null;
  if (!o) return false;
  return o.races === null || o.races.includes(raceId);
}

/** Outfits the creator offers for a race. */
export function starterOutfits(raceId) {
  return OUTFIT_ORDER.filter((id) => OUTFITS[id].starter && outfitAllowed(id, raceId));
}
