// Creator options shared by every race. Saves store ids and palette *indexes*, never colours.
export const FACES = [
  { id: "Calm", name: "Calm" },
  { id: "Fierce", name: "Fierce" },
  { id: "Smirk", name: "Smirk" },
  { id: "Determined", name: "Determined" },
  { id: "Cold", name: "Cold" },
];

// Races list which of these they may use (RACES[x].hairStyles). "None" = bald / hairless.
export const HAIR_STYLES = [
  { id: "None", name: "None" },
  { id: "Spiky", name: "Spiky" },
  { id: "Wild", name: "Wild" },
  { id: "Swept", name: "Swept Back" },
  { id: "Bowl", name: "Bowl Cut" },
  { id: "LongSpiky", name: "Long Spiky" },
  { id: "Short", name: "Short" },
  { id: "Ponytail", name: "Ponytail" },
];

export const HAIR_COLORS = [0x141418, 0x462d1e, 0x966ec8, 0xe6c878, 0xb42828, 0xf0f0f0];

// height/width/depth scale the 1.8 m base body
export const BUILDS = [
  { id: "Slim", name: "Slim", height: 1.0, width: 0.9, depth: 0.9 },
  { id: "Average", name: "Average", height: 1.0, width: 1.0, depth: 1.0 },
  { id: "Muscular", name: "Muscular", height: 1.05, width: 1.15, depth: 1.1 },
  { id: "Tall", name: "Tall", height: 1.15, width: 1.0, depth: 1.0 },
  { id: "Short", name: "Short", height: 0.85, width: 0.95, depth: 0.95 },
];

export const TINTS = [0xf0781e, 0x2846a0, 0x6e288c, 0x1e1e23, 0xebebeb, 0xaa1e1e, 0x28783c];

export function findById(list, id) {
  return list.find((e) => e.id === id) || null;
}
