import { SHARED_SAIYAN_FORMS } from "./forms.js";
// Playable races. `forms` = form ids in unlock order; `skins` = colours the creator offers (0xRRGGBB).
// Saves store the skin *index* into `skins`, never the colour.
const HUMAN_SKINS = [0xffdcb4, 0xf0c396, 0xc8966e, 0x966446, 0x5f412d];
const HUMAN_HAIR = ["Spiky", "Wild", "Swept", "Bowl", "LongSpiky", "Short", "Ponytail", "None"];

export const RACE_ORDER = ["Saiyan", "HalfSaiyan", "Human", "Namekian", "FrostDemon", "Majin"];

export const RACES = {
  Saiyan: {
    id: "Saiyan", name: "Saiyan", description: "A warrior race that grows stronger after every battle.",
    skins: HUMAN_SKINS, hairStyles: ["Spiky", "Wild", "Swept", "LongSpiky"], tail: true,
    powerMultiplier: 1.1, xpBonusBelowLevel: null, statBonus: { Strength: 5 },
    forms: [...SHARED_SAIYAN_FORMS],
  },
  HalfSaiyan: {
    id: "HalfSaiyan", name: "Half-Saiyan", description: "Saiyan and human blood. Grows fast early and hides huge potential.",
    skins: HUMAN_SKINS, hairStyles: HUMAN_HAIR, tail: false,
    powerMultiplier: 1.05, xpBonusBelowLevel: { level: 500, bonus: 0.25 }, statBonus: { KiPower: 5 },
    forms: [...SHARED_SAIYAN_FORMS],
  },
  Human: {
    id: "Human", name: "Human", description: "Disciplined fighters whose technique makes up for raw power.",
    skins: HUMAN_SKINS, hairStyles: HUMAN_HAIR, tail: false,
    powerMultiplier: 1.0, xpBonusBelowLevel: { level: 2000, bonus: 0.1 }, statBonus: { Speed: 5 },
    forms: ["Kaioken", "Kaioken10", "PotentialUnleashed"],
  },
  Namekian: {
    id: "Namekian", name: "Namekian", description: "Calm warriors from Namek who can regenerate and stretch their limbs.",
    skins: [0x6eb450, 0x5aa046, 0x82c364], hairStyles: ["None"], tail: false,
    powerMultiplier: 1.0, xpBonusBelowLevel: null, statBonus: { Health: 5 },
    forms: ["NamekFusion", "Giant", "Orange"],
  },
  FrostDemon: {
    id: "FrostDemon", name: "Frost Demon", description: "A ruthless race that holds back power in smaller forms.",
    skins: [0xf0f0f5, 0xc8b4dc, 0xaabee6, 0x3c3c46], hairStyles: ["None"], tail: true,
    powerMultiplier: 1.05, xpBonusBelowLevel: null, statBonus: { Ki: 5 },
    forms: ["FinalForm", "FullPower", "Golden", "Black"],
  },
  Majin: {
    id: "Majin", name: "Majin", description: "Rubbery magical beings with endless stamina.",
    skins: [0xf5a0c8, 0xe682b4, 0xb4b4be, 0x785aa0], hairStyles: ["None"], tail: false,
    powerMultiplier: 1.0, xpBonusBelowLevel: null, statBonus: { Health: 3, Ki: 3 },
    forms: ["SuperMajin", "KidForm", "PureMajin"],
  },
};

export function getRace(id) {
  return Object.prototype.hasOwnProperty.call(RACES, id) ? RACES[id] : null;
}
