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
  ["Saganbo", "Sagambo"], ["Granolah", "Granolo"], ["Monaito", "Monaido"], ["Elec", "Elek"], ["Bardock", "Bardak"],
  ["Uub", "Uubo"], ["Gogeta", "Gogeto"], ["Vegito", "Vegitto"], ["Pikkon", "Pikko"], ["Bojack", "Bojak"], ["Cooler", "Kooler"],
  ["Mai", "Mae"], ["Hit", "Hitto"], ["Frost", "Frosk"], ["Gas", "Gaz"], ["Pan", "Panna"], ["Nail", "Nael"], ["Kale", "Kael"],
];
/** Names that are also common words: renamed only in these contexts (as a name, not "Hit him!"). */
const SAFE = {
  Hit: /\bHit\b(?=[ ,.!?:;'’)]|$)(?! (?:him|her|it|them|me|us|you|the|a|an|his|every|everything|hard|back|again|fast|where|with)\b)/g,
  Gas: /\bGas\b(?! (?:station|can|cloud|giant)\b)/g,
  Frost: /\bFrost\b(?! (?:Demon|Demons|demon|Armor|armour|Armour)\b)/g,
  Pan: /\bPan\b/g, Nail: /\bNail\b/g, Mai: /\bMai\b/g, Kale: /\bKale\b/g,
};
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const RULES = NAMES.map(([from, to]) => [SAFE[from] || new RegExp(`\\b${esc(from)}\\b`, "g"), to]);

/** Replaces story names in a piece of player-facing text. */
export function renameText(text) {
  if (typeof text !== "string" || !text) return text;
  let out = text;
  for (const [re, to] of RULES) out = out.replace(re, to);
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
    if (typeof v === "string") value[k] = renameText(v);
    else if (v && typeof v === "object" && (Array.isArray(v) || Object.getPrototypeOf(v) === Object.prototype)) renameDeep(v, seen);
  }
  return value;
}
