import { INSTINCT_AVATAR } from "./avatar.js";
import { renameDeep } from "./names.js";
// Techniques learned through story/training quests. Combat validates costs and requirements.
//   kind: "beam" (hold to charge) | "blast" | "barrage" | "melee" | "utility" | "ultimate" | "avatar"
//   races: null = anyone can learn it
export const MOVES = {
  KiBlast: { name: "Ki Blast", kind: "blast", kiCost: 5, power: 1, races: null, desc: "A quick ball of ki." },
  Kamehameha: { name: "Kamehameha", kind: "beam", kiCost: 30, power: 4, races: null, desc: "The Turtle School's signature wave, taught by Master Roshi." },
  DestructoDisc: { name: "Destructo Disc", kind: "blast", kiCost: 25, power: 3.5, races: null, desc: "A razor-thin spinning disc of ki that cuts through anything." },
  SolarFlare: { name: "Solar Flare", kind: "utility", kiCost: 15, power: 0, races: null, desc: "A blinding flash that stuns everyone facing you." },
  TriBeam: { name: "Tri-Beam", kind: "beam", kiCost: 45, power: 5, races: null, desc: "Tien's devastating triangle blast. Costs a lot of ki." },
  WolfFangFist: { name: "Wolf Fang Fist", kind: "melee", kiCost: 12, power: 2.5, races: null, desc: "Yamcha's flurry of wolf-like strikes." },
  Kaioken: { name: "Kaioken", kind: "utility", kiCost: 0, power: 0, races: null, desc: "An independent technique: toggle it in Forms / Techniques or with K. Combine it with a Saiyan form while keeping your beam equipped. Extra power costs continuous Ki and health; a cooldown follows. Train Kaioken x10 to unlock the higher intensity." },
  SpiritBomb: { name: "Spirit Bomb", kind: "ultimate", kiCost: 100, power: 12, races: null, desc: "Gather energy from all living things into one giant sphere. Takes a long charge." },
  SpecialBeamCannon: { name: "Special Beam Cannon", kind: "beam", kiCost: 40, power: 5.5, races: null, desc: "Piccolo's piercing spiral beam." },
  Masenko: { name: "Masenko", kind: "beam", kiCost: 25, power: 3.5, races: null, desc: "A quick overhead beam Piccolo taught Gohan." },
  GalickGun: { name: "Galick Gun", kind: "beam", kiCost: 30, power: 4.2, races: ["Saiyan", "HalfSaiyan"], desc: "Vegeta's purple Saiyan beam." },
  FinalFlash: { name: "Final Flash", kind: "beam", kiCost: 60, power: 7, races: ["Saiyan", "HalfSaiyan"], desc: "Vegeta's all-out beam, fired with both palms." },
  BigBangAttack: { name: "Big Bang Attack", kind: "blast", kiCost: 40, power: 5, races: ["Saiyan", "HalfSaiyan"], desc: "A single overwhelming sphere of ki." },
  DeathBeam: { name: "Death Beam", kind: "blast", kiCost: 10, power: 2.4, races: ["FrostDemon"], desc: "Frieza's fingertip laser. Fast and precise." },
  DeathBall: { name: "Death Ball", kind: "ultimate", kiCost: 90, power: 10, races: ["FrostDemon"], desc: "A planet-destroying sphere of energy." },
  Regeneration: { name: "Regeneration", kind: "utility", kiCost: 35, power: 0, races: ["Namekian", "Majin"], desc: "Restore lost health by spending ki." },
  CandyBeam: { name: "Candy Beam", kind: "utility", kiCost: 30, power: 0, races: ["Majin"], desc: "Turn a weakened enemy into candy." },
  InstantTransmission: { name: "Instant Transmission", kind: "utility", kiCost: 20, power: 0, races: null, desc: "Taught by the Yardrats: lock onto a ki signature and teleport. Lets you travel to any world you have visited." },
  Afterimage: { name: "Afterimage Technique", kind: "utility", kiCost: 10, power: 0, races: null, desc: "Move so fast you leave an image of yourself behind." },
  ExplodingDemonWave: { name: "Exploding Demon Wave", kind: "beam", kiCost: 35, power: 4.5, races: ["Namekian"], desc: "A powerful two-handed Namekian wave." },
  FusionDance: { name: "Fusion Dance", kind: "utility", kiCost: 0, power: 0, races: null, desc: "The Metamoran dance. Perfect poses fuse two fighters for thirty minutes." },
  Hakai: { name: "Hakai", kind: "ultimate", kiCost: 80, power: 11, races: null, desc: "A God of Destruction's erasure. Beerus allows only the worthy to learn its basics." },
  GodKi: { name: "God Ki Control", kind: "utility", kiCost: 0, power: 0, races: null, desc: "Whis's training: calm, efficient ki. Your ki drains more slowly while transformed." },
  UltraInstinctSign: { name: "Ultra Instinct -Sign-", kind: "utility", kiCost: 10, power: 0, races: null, desc: "Brief focus with a small dodge chance and no transformation stat boost. Much weaker than an Ultra Instinct form." },
  UltraInstinctAvatar: { name: "Ultra Instinct Energy Avatar", kind: "avatar", kiCost: 60, power: 4, races: ["Saiyan","HalfSaiyan"], desc: `Manifest a giant energy body for ${INSTINCT_AVATAR.duration} seconds. It strikes a wide area in front of you. Requires learned Avatar training and active Perfected or True Ultra Instinct; ${INSTINCT_AVATAR.cooldown}-second cooldown.` },
  EnergyField: { name: "Energy Field", kind: "utility", kiCost: 20, power: 0, races: null, desc: "A ki barrier that blocks blasts. Taught by Jiren's rival, Toppo." },
};
export const MOVE_ORDER = Object.keys(MOVES);

// player-facing names are the game's own (data/names.js)
renameDeep(MOVES);
