// What each transformation looks like, following the story. Read by character/cage_model.js
// (hair, eyes, brows, skin, size) and fx/aura.js (the aura). Stats live in data/forms.js.
//
//   hair   null = keep the fighter's own hair; otherwise { style, color, glow }
//          styles: "ssj1" (tall golden spikes, a few bangs), "ssj2" (sharper and more upright, one
//          lone bang), "ssj3" (a mane down to the waist), "ssj4" (a wild black mane to the
//          shoulder blades), "beast" (a towering swept-up crest),
//          "same" (the fighter's own shape, recoloured, e.g. God and Blue)
//   eyes   iris colour, or null to keep the fighter's own
//   brows  false hides the eyebrows (Super Saiyan 3)
//   skin   body colour, or null; flush [colour, amount] blends the own skin toward it (Kaioken's red)
//   scale  size multiplier (Giant Namekian, Kid Buu)
//   aura   { color, core (inner colour), size, flicker (0..1 speed), sparks (0 none, 1 crackles,
//            2 constant lightning), sparkColor, motes (rising glitter: God, Blue, Ultimate),
//            style: "flame" (Super Saiyan) | "calm" (God, Ultimate: a smooth, quiet glow) }
const GOLD = 0xffc81e, GOLD_HAIR = 0xf2b90c; // rich gold, not pale yellow
const SSJ_EYES = 0x1fa98f; // Super Saiyans have teal-green eyes

export const FORM_LOOKS = {
  // ---- Saiyan
  SSJ: {
    hair: { style: "ssj1", color: GOLD_HAIR, glow: 0.18 }, eyes: SSJ_EYES,
    aura: { color: GOLD, core: 0xfff4c0, size: 1, flicker: 0.8, sparks: 0 },
  },
  SSJ2: { // sharper hair, one bang left over the forehead, blue-white lightning crackling in the aura
    hair: { style: "ssj2", color: 0xf7c616, glow: 0.24 }, eyes: SSJ_EYES,
    aura: { color: 0xffcc22, core: 0xfff4c0, size: 1.08, flicker: 1, sparks: 1, sparkColor: 0xbfe6ff },
  },
  SSJ3: { // waist-long mane, no eyebrows, constant lightning
    hair: { style: "ssj3", color: 0xf2b80c, glow: 0.24 }, eyes: SSJ_EYES, brows: false,
    aura: { color: 0xffc928, core: 0xfff6c8, size: 1.18, flicker: 1, sparks: 2, sparkColor: 0xcdeaff },
  },
  SSJGod: { // slimmer, calm, crimson-magenta hair and eyes, a soft red-orange flame
    hair: { style: "same", color: 0xc8143c, glow: 0.25 }, eyes: 0xb4143c, slim: true,
    aura: { color: 0xff4a2a, core: 0xffc89a, size: 1.05, flicker: 0.45, sparks: 0, motes: 0xffb070, style: "calm" },
  },
  SSJBlue: { // Super Saiyan hair shape in blue, a steady blue flame with glitter
    hair: { style: "ssj1", color: 0x2ab4f0, glow: 0.3 }, eyes: 0x2a7cff,
    aura: { color: 0x2aa8ff, core: 0xd8f6ff, size: 1.1, flicker: 0.6, sparks: 0, motes: 0xc8f2ff },
  },

  // ---- shared Saiyan path (Codex's progression: IDs from data/forms.js)
  FalseSSJ: { // Lord Slug: hair stands up but stays dark, pale eyes, a hot red-gold aura
    hair: { style: "ssj1", color: 0x2a2014, glow: 0.05 }, eyes: 0xd8d4c8,
    aura: { color: 0xff8a2a, core: 0xffe0a0, size: 1.05, flicker: 1, sparks: 1, sparkColor: 0xffe0b0 },
  },
  SSJGrade2: { // Ascended / "Super Vegeta": bulkier, the hair a little taller
    hair: { style: "ssj1", color: GOLD_HAIR, glow: 0.2 }, eyes: SSJ_EYES, scale: 1.04,
    aura: { color: GOLD, core: 0xfff4c0, size: 1.1, flicker: 0.9, sparks: 0 },
  },
  SSJGrade3: { // "Super Trunks": huge, slow muscle and spikier hair
    hair: { style: "ssj2", color: 0xf2b90c, glow: 0.2 }, eyes: SSJ_EYES, scale: 1.1,
    aura: { color: GOLD, core: 0xfff0b0, size: 1.2, flicker: 0.7, sparks: 0 },
  },
  SSJFullPower: { // Full Power Super Saiyan (Cell saga): calm, steady, always on
    hair: { style: "ssj1", color: 0xf5c21e, glow: 0.22 }, eyes: SSJ_EYES,
    aura: { color: 0xffcc33, core: 0xfff6d0, size: 0.95, flicker: 0.35, sparks: 0, style: "calm" },
  },
  LegendarySSJ: { // Broly: green-tinged gold hair, blank white eyes, huge, a green aura
    hair: { style: "ssj1", color: 0xd6e04a, glow: 0.3 }, eyes: 0xf2f2f2, scale: 1.25,
    aura: { color: 0x4cff6a, core: 0xe0ffd8, size: 1.25, flicker: 1, sparks: 2, sparkColor: 0xc8ffd0 },
  },
  SSJ4: { // black wild mane, golden eyes, a red-gold aura (the red fur needs a body texture: not yet)
    hair: { style: "ssj4", color: 0x16100e, glow: 0.0 }, eyes: 0xf0b41e, flush: [0xb4281e, 0.18],
    aura: { color: 0xff3a24, core: 0xffd890, size: 1.1, flicker: 0.9, sparks: 1, sparkColor: 0xffc8a0 },
  },
  // Great Ape: stand-in until there is an ape model (a giant, brown-furred fighter with red eyes)
  Oozaru: { hair: null, eyes: 0xd0141e, flush: [0x5a3418, 0.55], scale: 3.2, aura: { color: 0xff5a3a, core: 0xffc0a0, size: 1.0, flicker: 0.5, sparks: 0 } },
  GoldenOozaru: { hair: null, eyes: 0xd0141e, flush: [0xe0b030, 0.55], scale: 3.2, aura: { color: 0xffc81e, core: 0xfff0b0, size: 1.1, flicker: 0.7, sparks: 1, sparkColor: 0xfff0c0 } },
  UIOmen: { // Ultra Instinct -Sign-: own dark hair, silver eyes, a calm silver-blue glow
    hair: { style: "same", color: 0x16161e, glow: 0.05 }, eyes: 0xc8cedc,
    aura: { color: 0x9ab8ff, core: 0xffffff, size: 1.0, flicker: 0.3, sparks: 0, motes: 0xe0ecff, style: "calm" },
  },
  UIPerfected: { // Mastered Ultra Instinct: silver hair and eyes, a silver-white glow
    hair: { style: "same", color: 0xdfe4f0, glow: 0.4 }, eyes: 0xc8cedc,
    aura: { color: 0xd8e4ff, core: 0xffffff, size: 1.05, flicker: 0.3, sparks: 0, motes: 0xffffff, style: "calm" },
  },
  UITrue: { // True Ultra Instinct (Granolah arc): dark hair, silver eyes, a stronger glow
    hair: { style: "same", color: 0x16161e, glow: 0.05 }, eyes: 0xc8cedc, scale: 1.03,
    aura: { color: 0xb8ccff, core: 0xffffff, size: 1.12, flicker: 0.45, sparks: 0, motes: 0xf0f4ff, style: "calm" },
  },
  UltraEgo: { // Vegeta's Ultra Ego: purple hair, magenta eyes, bulkier, a dark purple flame
    hair: { style: "same", color: 0x6a2ab8, glow: 0.3 }, eyes: 0xd03aa0, scale: 1.05,
    aura: { color: 0x9a2aff, core: 0xf0c8ff, size: 1.15, flicker: 0.85, sparks: 0 },
  },

  // ---- Half-Saiyan (Gohan's path)
  HSSJ: {
    hair: { style: "ssj1", color: GOLD_HAIR, glow: 0.18 }, eyes: SSJ_EYES,
    aura: { color: GOLD, core: 0xfff4c0, size: 1, flicker: 0.8, sparks: 0 },
  },
  HSSJ2: { // Cell Games Gohan
    hair: { style: "ssj2", color: 0xf7c616, glow: 0.24 }, eyes: SSJ_EYES,
    aura: { color: 0xffcc22, core: 0xfff4c0, size: 1.08, flicker: 1, sparks: 1, sparkColor: 0xbfe6ff },
  },
  SSJRage: { // Future Trunks: Super Saiyan 2 hair with a blue edge, blue-gold aura and lightning
    hair: { style: "ssj2", color: 0xf0cc3a, glow: 0.24 }, eyes: SSJ_EYES,
    aura: { color: 0x7ac8ff, core: 0xfff2b0, size: 1.12, flicker: 1, sparks: 2, sparkColor: 0xaee2ff },
  },
  Ultimate: { // Elder Kai's Potential Unleashed: own black hair, a clear white glow
    hair: null, eyes: null,
    aura: { color: 0xe8f0ff, core: 0xffffff, size: 1.0, flicker: 0.35, sparks: 0, motes: 0xffffff, style: "calm" },
  },
  Beast: { // a towering silver-white crest, red eyes, violet aura with crackling energy
    hair: { style: "beast", color: 0xeceaf6, glow: 0.3 }, eyes: 0xd0203a,
    aura: { color: 0xa64dff, core: 0xf0e0ff, size: 1.15, flicker: 1, sparks: 1, sparkColor: 0xe4c8ff },
  },

  // ---- Human
  Kaioken: { // King Kai's technique: red flush over the body, red flame
    hair: null, eyes: null, flush: [0xe02a1e, 0.4],
    aura: { color: 0xff2a1e, core: 0xff9c84, size: 1.05, flicker: 0.9, sparks: 0 },
  },
  Kaioken10: {
    hair: null, eyes: null, flush: [0xe8180e, 0.62],
    aura: { color: 0xff1a12, core: 0xffb4a0, size: 1.22, flicker: 1, sparks: 1, sparkColor: 0xffc8b8 },
  },
  PotentialUnleashed: {
    hair: null, eyes: null,
    aura: { color: 0xeef2ff, core: 0xffffff, size: 0.95, flicker: 0.35, sparks: 0, motes: 0xffffff, style: "calm" },
  },

  // ---- Namekian
  NamekFusion: { // fused with another Namekian: bigger, a pale green-white glow
    hair: null, eyes: null, scale: 1.08,
    aura: { color: 0xd8f6d0, core: 0xffffff, size: 1.0, flicker: 0.5, sparks: 0 },
  },
  Giant: { scale: 1.9, hair: null, eyes: null, aura: { color: 0x78e678, core: 0xe0ffd8, size: 1.0, flicker: 0.5, sparks: 0 } },
  Orange: { // Orange Piccolo: orange skin, bigger and bulkier, red eyes
    hair: null, eyes: 0xc81e28, skin: 0xf08a2c, scale: 1.3,
    aura: { color: 0xff8a2a, core: 0xffe0b0, size: 1.1, flicker: 0.8, sparks: 1, sparkColor: 0xffd8a0 },
  },

  // ---- Frost Demon
  FinalForm: { // smooth white body, purple dome
    hair: null, eyes: 0xb4142a, skin: 0xf6f4fa, dome: 0x9a3ad0,
    aura: { color: 0xc878ff, core: 0xf4e4ff, size: 1.0, flicker: 0.6, sparks: 0 },
  },
  FullPower: { // muscles swell; violet aura crackles
    hair: null, eyes: 0xb4142a, skin: 0xf6f4fa, dome: 0x9a3ad0, scale: 1.1,
    aura: { color: 0xb45cff, core: 0xf0dcff, size: 1.12, flicker: 1, sparks: 1, sparkColor: 0xe6ccff },
  },
  Golden: { // gold body with purple dome and face patches
    hair: null, eyes: 0xb4142a, skin: 0xf2c230, skinMetal: 0.55, dome: 0x7a2ab8,
    aura: { color: 0xffd23c, core: 0xfff4c8, size: 1.12, flicker: 0.8, sparks: 0 },
  },
  Black: { // black body, glossy purple, red eyes, dark violet aura with red lightning
    hair: null, eyes: 0xe0142a, skin: 0x1c1a22, skinMetal: 0.3, dome: 0x7a2ab8,
    aura: { color: 0x6a1aa8, core: 0xd08cff, size: 1.15, flicker: 1, sparks: 2, sparkColor: 0xff5a6a },
  },

  // ---- Majin
  SuperMajin: { // Super Buu: bulkier, pink steam-like aura
    hair: null, eyes: 0xc81e46, scale: 1.08,
    aura: { color: 0xff7ac8, core: 0xffe0f2, size: 1.05, flicker: 0.7, sparks: 0 },
  },
  KidForm: { // Kid Buu: small and wild
    hair: null, eyes: 0xc81e46, scale: 0.78,
    aura: { color: 0xff4cb4, core: 0xffd0ec, size: 1.1, flicker: 1, sparks: 1, sparkColor: 0xffc0e8 },
  },
  PureMajin: {
    hair: null, eyes: 0xe0143c, scale: 0.84,
    aura: { color: 0xff3ca0, core: 0xffe0f0, size: 1.2, flicker: 1, sparks: 2, sparkColor: 0xffb0dc },
  },
};
