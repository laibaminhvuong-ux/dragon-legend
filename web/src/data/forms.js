// Transformations. Unlock levels are first guesses; tune them here.
// multiplier scales Health / Strength / KiPower / Speed while transformed; kiDrain = ki per second.
// hairColor null = keep the character's own hair colour. unlockQuest is granted in M3/M4.
export const FORMS = {};

function form(id, race, name, unlockLevel, multiplier, kiDrain, auraColor, hairColor = null) {
  FORMS[id] = { id, race, name, unlockLevel, multiplier, kiDrain, auraColor, hairColor, unlockQuest: "Form_" + id };
}

const GOLD = 0xffdc3c, RED = 0xe62828, CYAN = 0x3cc8ff;

form("SSJ", "Saiyan", "Super Saiyan", 25, 1.5, 2, GOLD, GOLD);
form("SSJ2", "Saiyan", "Super Saiyan 2", 50, 2.0, 4, GOLD, GOLD);
form("SSJ3", "Saiyan", "Super Saiyan 3", 75, 2.6, 8, GOLD, GOLD);
form("SSJGod", "Saiyan", "Super Saiyan God", 100, 3.2, 6, RED, 0xc81e3c);
form("SSJBlue", "Saiyan", "Super Saiyan Blue", 125, 4.0, 9, CYAN, CYAN);

form("HSSJ", "HalfSaiyan", "Super Saiyan", 25, 1.5, 2, GOLD, GOLD);
form("HSSJ2", "HalfSaiyan", "Super Saiyan 2", 50, 2.0, 4, GOLD, GOLD);
form("SSJRage", "HalfSaiyan", "Super Saiyan Rage", 80, 2.5, 6, 0x78c8ff, GOLD);
form("Ultimate", "HalfSaiyan", "Ultimate", 100, 3.0, 3, 0xf0f0ff);
form("Beast", "HalfSaiyan", "Beast", 135, 3.9, 9, 0xc83cff, 0xebebf5);

form("Kaioken", "Human", "Kaioken", 25, 1.4, 3, RED);
form("Kaioken10", "Human", "Kaioken x10", 50, 2.1, 8, RED);
form("PotentialUnleashed", "Human", "Potential Unleashed", 90, 3.0, 2, 0xf0f0ff);

form("NamekFusion", "Namekian", "Namekian Fusion", 25, 1.5, 1, 0xdcf0dc);
form("Giant", "Namekian", "Giant Form", 50, 2.1, 5, 0x78e678);
form("Orange", "Namekian", "Orange", 110, 3.4, 7, 0xff8c28);

form("FinalForm", "FrostDemon", "Final Form", 25, 1.5, 1, 0xc878ff);
form("FullPower", "FrostDemon", "100% Full Power", 55, 2.2, 6, 0xc878ff);
form("Golden", "FrostDemon", "Golden", 100, 3.1, 7, GOLD);
form("Black", "FrostDemon", "Black", 130, 3.9, 9, 0x963cc8);

form("SuperMajin", "Majin", "Super Majin", 25, 1.5, 2, 0xff78c8);
form("KidForm", "Majin", "Kid Form", 60, 2.3, 5, 0xff50b4);
form("PureMajin", "Majin", "Pure Majin", 110, 3.3, 7, 0xff3ca0);
