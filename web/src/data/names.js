// The game's own character names. Dragon Legend is inspired by the story, but every named character
// uses a slightly altered name of our own. Data modules run their player-facing text through
// renameText() when they load, so quest lines, cutscenes, form and world names all stay consistent.
// Ids (goku_plains, m02_raditz...) are internal and never shown, so they stay as they are.
//
// Order matters only for overlapping names (longer first). Words that are also ordinary English
// ("Hit", "Gas", "Frost", "Pan", "Nail", "Mai", "Kale") are only renamed where they are names: see SAFE.

export const NAMES = [
  ["Kakarot", "Kakarro"], ["Gotenks", "Gotinks"], ["Goku", "Gokan"], ["Gohan", "Gohin"], ["Goten", "Gotin"],
  ["Trunks", "Tronks"], ["Piccolo", "Piccor"], ["Krillin", "Krilan"], ["Roshi", "Roshu"], ["Bulma", "Bulna"],
  ["Dr. Brief", "Dr. Brisk"], ["Chi-Chi", "Chi-Mei"], ["Yamcha", "Yamcho"], ["Tien", "Tenzo"], ["Raditz", "Radix"],
  ["Nappa", "Nappo"], ["Vegeta", "Vegara"], ["Saibamen", "Saiblings"], ["Saibaman", "Saibling"],
  ["Kai", "Kae"], ["Bubbles", "Bubbo"], ["Yemma", "Yemmo"], ["Princess Snake", "Princess Serpa"], ["Moori", "Mooru"],
  ["Dende", "Dendo"], ["Guru", "Gura"], ["Frieza", "Frigor"], ["Zarbon", "Zarvon"], ["Dodoria", "Dodorra"],
  ["Ginyu", "Ginnu"], ["Recoome", "Rekume"], ["Burter", "Burtor"], ["Jeice", "Jayce"], ["Guldo", "Guldor"],
  ["Yardrat", "Yardran"], ["King Cold", "King Kold"], ["Androids", "Cyborgs"], ["Android", "Cyborg"], ["Gero", "Gerro"],
  ["Cell", "Cel"], ["Kami", "Kamu"], ["Mr. Popo", "Mr. Pobo"], ["Popo", "Pobo"], ["Mr. Satan", "Mr. Sadan"], ["Hercule", "Herkul"],
  ["Videl", "Vidal"], ["Kibito", "Kibitto"], ["Spopovich", "Spopovik"], ["Babidi", "Babido"], ["Bibidi", "Bibido"],
  ["Dabura", "Dabora"], ["Pui Pui", "Poi Poi"], ["Yakon", "Yakkon"], ["Buu", "Boo"], ["Beerus", "Beeros"],
  ["Whis", "Wiss"], ["Sorbet", "Sorbel"], ["Tagoma", "Tagomo"], ["Champa", "Champo"], ["Vados", "Vadosa"],
  ["Cabba", "Kabba"], ["Botamo", "Botama"], ["Magetta", "Magetto"], ["Zamasu", "Zamazu"], ["Zeno", "Zenno"],
  ["Jiren", "Jiran"], ["Toppo", "Toppa"], ["Kefla", "Kafla"], ["Caulifla", "Kaulifla"], ["Broly", "Brolo"],
  ["Paragus", "Paragos"], ["Cheelai", "Chelai"], ["Lemo", "Lemmo"], ["Gamma", "Gama"], ["Hedo", "Heddo"],
  ["Magenta", "Majenta"], ["Shenron", "Shenra"], ["Porunga", "Porunda"], ["Merus", "Meros"], ["Moro", "Morro"],
  ["Saganbo", "Sagambo"], ["Granolah", "Granolo"], ["Monaito", "Monaido"], ["Toronbo", "Toronba"], ["Elec", "Elek"], ["Bardock", "Bardak"],
  ["Uub", "Uubo"], ["Gogeta", "Gogeto"], ["Vegito", "Vegitto"], ["Pikkon", "Pikko"], ["Bojack", "Bojak"], ["Cooler", "Kooler"],
  ["Mai", "Mae"], ["Hit", "Hitto"], ["Frost", "Frosk"], ["Gas", "Gaz"], ["Pan", "Panna"], ["Nail", "Nael"], ["Kale", "Kael"],
];
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/** Technique, item and place names. Some techniques are also ids ("Kamehameha", "Kaioken"), so these are
 *  only applied to on-screen text: prose fields and anything with a space in it (ids never have spaces). */
export const TERMS = [
  ["Dragon Ball Super", "Legend Super"], ["Dragon Ball Z", "Legend Z"], ["Dragon Balls", "Dragon Orbs"], ["Dragon Ball", "Dragon Orb"],
  ["Kamehameha", "Kamehamera"], ["Destructo Disc", "Destro Disc"], ["Solar Flare", "Solar Flash"], ["Tri-Beam", "Triad Beam"],
  ["Wolf Fang Fist", "Wolf Claw Fist"], ["Kaioken", "Kaiyoken"], ["Spirit Bomb", "Spirit Sphere"], ["Special Beam Cannon", "Spiral Beam Cannon"],
  ["Masenko", "Masenka"], ["Galick Gun", "Galik Blaster"], ["Final Flash", "Final Blaze"], ["Big Bang Attack", "Big Burst Attack"],
  ["Death Beam", "Doom Beam"], ["Death Ball", "Doom Orb"], ["Candy Beam", "Sweet Beam"], ["Instant Transmission", "Instant Transfer"],
  ["Exploding Demon Wave", "Bursting Demon Wave"], ["Fusion Dance", "Fusion Step"], ["Hakai", "Hakaido"], ["Potara", "Potaro"],
  ["Senzu", "Senzo"], ["Capsule Corporation", "Kapsule Corporation"], ["Capsule Corp", "Kapsule Corp"],
  ["Namekians", "Nameckians"], ["Namekian", "Nameckian"], ["Namek", "Nameck"], ["Kame House", "Kama House"], ["Kame Island", "Kama Island"], ["Kame", "Kama"],
  ["Snake Way", "Serpent Road"], ["Gizard Wasteland", "Gizzard Wastes"], ["West City", "West Capital"],
  ["Hyperbolic Time Chamber", "Hyperbolic Time Room"], ["World Martial Arts Tournament", "Grand Martial Arts Tournament"],
  ["Papaya Island", "Pawpaw Island"], ["World of Void", "Null Realm"], ["Red Ribbon", "Crimson Ribbon"], ["Planet Cereal", "Planet Grain"],
  ["Cereal", "Grain"], ["Tournament of Power", "Tournament of Might"], ["Galactic Patrol", "Star Patrol"], ["Vampa", "Vampo"],
  // transformations and races (ids like "Saiyan", "FrostDemon", "UIOmen" have no spaces and stay as they are)
  ["Saiyans", "Saiyars"], ["Saiyan", "Saiyar"], ["Oozaru", "Ohzaru"], ["Ultra Instinct", "Ultra Intuition"], ["Ultra Ego", "Ultra Self"],
  ["Frost Demons", "Frost Fiends"], ["Frost Demon", "Frost Fiend"], ["Majin", "Majinn"],
];
const PROSE = new Set(["name", "title", "text", "offer", "done", "desc", "description", "saga", "planet", "label", "objective", "hint", "message", "line"]);
const TERM_RULES = TERMS.map(([from, to]) => [new RegExp(`\\b${esc(from)}\\b`, "g"), to]);

/** Names that are also common words: renamed only in these contexts (as a name, not "Hit him!"). */
const SAFE = {
  Hit: /\bHit\b(?=[ ,.!?:;'’)]|$)(?! (?:him|her|it|them|me|us|you|the|a|an|his|every|everything|hard|back|again|fast|where|with)\b)/g,
  Gas: /\bGas\b(?! (?:station|can|cloud|giant)\b)/g,
  Frost: /\bFrost\b(?! (?:Demon|Demons|demon|Armor|armour|Armour)\b)/g,
  Pan: /\bPan\b/g, Nail: /\bNail\b/g, Mai: /\bMai\b/g, Kale: /\bKale\b/g,
};
const RULES = NAMES.map(([from, to]) => [SAFE[from] || new RegExp(`\\b${esc(from)}\\b`, "g"), to]);

/** Replaces story names in a piece of player-facing text. */
export function renameText(text, terms = true) {
  if (typeof text !== "string" || !text) return text;
  let out = text;
  for (const [re, to] of RULES) out = out.replace(re, to);
  if (terms) for (const [re, to] of TERM_RULES) out = out.replace(re, to);
  return out;
}

/** Renames the given string fields of every object in a list/map (in place). */
export function renameFields(objects, fields) {
  for (const o of Array.isArray(objects) ? objects : Object.values(objects)) {
    if (!o || typeof o !== "object") continue;
    for (const f of fields) if (typeof o[f] === "string") o[f] = renameText(o[f]);
  }
  return objects;
}

/** Renames every string inside plain objects/arrays (in place). Object keys are left alone. */
export function renameDeep(value, seen = new Set()) {
  if (!value || typeof value !== "object" || seen.has(value)) return value;
  seen.add(value);
  for (const k of Object.keys(value)) {
    const v = value[k];
    if (typeof v === "string") value[k] = renameText(v, PROSE.has(k) || /\s/.test(v)); // ids have no spaces
    else if (v && typeof v === "object" && (Array.isArray(v) || Object.getPrototypeOf(v) === Object.prototype)) renameDeep(v, seen);
  }
  return value;
}
