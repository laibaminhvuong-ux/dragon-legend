// Procedural appearance recipes. Positions are relative to the 1.8 m base fighter.
export const CHARACTER = {
  dark: 0x202535, white: 0xf1eee5, accent: 0x313c78, armor: 0xe5e8ec,
  gold: 0xc8a253, frost: 0x8759bb, namekPatch: 0xc87597,
  tailBrown: 0x765038,
};
export const HAIR_SHAPES = {
  // [x, y, z, radius, length, tiltX, tiltZ], relative to the head centre.
  Spiky: [[0, .15, -.03, .12, .32, -.1, -.2], [.12, .12, -.02, .10, .25, -.15, -.6], [-.12, .12, -.02, .10, .25, -.15, .6], [0, .08, -.13, .12, .27, -.8, 0]],
  Wild: [[0, .16, 0, .11, .36, -.2, .2], [.16, .08, 0, .11, .3, -.2, -.9], [-.16, .09, 0, .11, .3, -.2, .9], [.12, .04, -.15, .1, .3, -1, -.5], [-.12, .04, -.15, .1, .3, -1, .5]],
  Swept: [[0, .12, -.08, .14, .33, -1, 0], [.12, .08, -.08, .1, .26, -1, -.3], [-.12, .08, -.08, .1, .26, -1, .3]],
  LongSpiky: [[0, .16, -.02, .13, .38, -.3, 0], [.14, .1, -.05, .12, .3, -.7, -.6], [-.14, .1, -.05, .12, .3, -.7, .6], [.12, -.1, -.15, .13, .53, -2.6, -.25], [-.12, -.1, -.15, .13, .53, -2.6, .25]],
};
export const FACE_SHAPES = {
  Calm: { brow: 0, eye: .027, mouth: 0 },
  Fierce: { brow: .35, eye: .022, mouth: 0 },
  Smirk: { brow: -.12, eye: .025, mouth: .18 },
  Determined: { brow: .22, eye: .024, mouth: -.08 },
  Cold: { brow: -.06, eye: .016, mouth: 0 },
};
export const OUTFIT_SHAPES = {
  TurtleGi: 'gi', CraneGi: 'gi', WeightedGi: 'weighted',
  SaiyanArmor: 'armor', EliteArmor: 'elite', FrostArmor: 'frost',
  NamekRobe: 'robe', GiantsRobe: 'robe', AngelRobe: 'angel',
  CapsuleCorp: 'jacket', SaiyanSuit: 'suit', PrideTrooper: 'suit', MajinVest: 'vest',
};
