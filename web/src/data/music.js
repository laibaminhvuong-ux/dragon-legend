import { renameDeep } from "./names.js";
// The soundtrack: original compositions in the style of 90s anime action scores (rock drums,
// distorted power chords, brass leads, string pads), played live by audio/music.js.
// Players can replace any of them with their own files: see web/assets/music/README.md.
//
// A track: { name, bpm, swing, key (MIDI root), sections: { name: { bars, chords, drums, bass, guitar, lead, pad, arp } }, order }
//   chords: one per bar, "i" | "bVI" | "V" ... (roman numerals relative to the key, minor-key friendly)
//   drums:  pattern name from DRUMS          bass/guitar/pad/arp: style name (see audio/music.js)
//   lead:   melody, space-separated "note:steps" in 16th notes, e.g. "D5:4 F5:2 r:2" (r = rest);
//           repeats to fill the section
export const DRUMS = {
  // 16 steps per bar: K = kick, S = snare, h = closed hat, o = open hat, C = crash
  rock: { K: "x.......x.x.....", S: "....x.......x...", h: "x.x.x.x.x.x.x.x.", o: "................" },
  drive: { K: "x...x...x...x...", S: "....x.......x...", h: "xxxxxxxxxxxxxxxx", o: "..............x." },
  battle: { K: "x.x.x.x.x.x.x.xx", S: "....x.......x..x", h: "x.x.x.x.x.x.x.x.", o: "......x.......x." },
  halftime: { K: "x.........x.....", S: "........x.......", h: "x...x...x...x...", o: "................" },
  shuffle: { K: "x.....x...x.....", S: "....x.......x...", h: "x..x..x..x..x..x", o: "................" },
  fill: { K: "x.x.x.x.x.x.x.x.", S: "........xxxxxxxx", h: "x.x.x.x.........", o: "................" },
  none: { K: "................", S: "................", h: "................", o: "................" },
};

export const TRACKS = {
  hero: {
    name: "Rising Fighter", bpm: 152, key: 50, // D minor
    sections: {
      intro: { bars: 4, chords: ["i", "bVI", "bVII", "i"], drums: "fill", bass: "eighths", guitar: "stabs", pad: "strings", lead: "D5:6 F5:2 G5:4 A5:4 | Bb5:6 A5:2 G5:8 | C6:6 Bb5:2 A5:4 G5:4 | A5:16" },
      verse: { bars: 8, chords: ["i", "i", "bVII", "bVII", "bVI", "bVI", "V", "V"], drums: "rock", bass: "gallop", guitar: "chug", lead: "A4:2 D5:2 E5:2 F5:4 E5:2 D5:4 | C5:2 D5:2 E5:4 C5:4 A4:4 | G4:2 A4:2 C5:4 D5:4 E5:4 | F5:8 E5:8" },
      chorus: { bars: 8, chords: ["bVI", "bVII", "i", "i", "bVI", "bVII", "V", "V"], drums: "drive", bass: "eighths", guitar: "power", pad: "strings", lead: "F5:4 G5:4 A5:6 C6:2 | D6:8 C6:4 A5:4 | F5:4 G5:4 A5:4 G5:4 | F5:6 E5:2 D5:8 | Bb5:4 C6:4 D6:6 F6:2 | E6:8 D6:4 C6:4 | A5:4 C6:4 E6:8 | D6:16" },
      bridge: { bars: 4, chords: ["bVI", "bVII", "bVI", "V"], drums: "halftime", bass: "whole", guitar: "power", pad: "strings", arp: "up" },
    },
    order: ["intro", "verse", "chorus", "bridge", "verse", "chorus"],
  },
  alien: {
    name: "Green Sky of Namek", bpm: 100, key: 52, // E phrygian-ish minor
    sections: {
      a: { bars: 8, chords: ["i", "bII", "i", "bVII", "i", "bII", "bVI", "V"], drums: "halftime", bass: "whole", pad: "choir", arp: "up", lead: "E5:8 F5:4 G5:4 | B5:12 A5:4 | G5:6 F5:2 E5:8 | D5:16" },
      b: { bars: 8, chords: ["bVI", "bVII", "i", "i", "bVI", "bVII", "bII", "bII"], drums: "shuffle", bass: "eighths", pad: "choir", arp: "updown", guitar: "swells" },
    },
    order: ["a", "b", "a"],
  },
  otherworld: {
    name: "At the End of Snake Way", bpm: 128, key: 55, mode: "major", // G major
    sections: {
      a: { bars: 8, chords: ["I", "IV", "I", "V", "I", "IV", "ii", "V"], drums: "shuffle", bass: "bounce", arp: "bells", pad: "strings", lead: "G5:3 A5:1 B5:4 D6:4 B5:4 | C6:4 A5:4 G5:8 | E5:3 G5:1 A5:4 B5:4 G5:4 | A5:12 r:4" },
      b: { bars: 8, chords: ["IV", "V", "iii", "vi", "IV", "V", "I", "I"], drums: "rock", bass: "bounce", arp: "bells", guitar: "stabs", lead: "C6:4 D6:4 E6:4 D6:4 | B5:8 G5:8 | C6:4 B5:4 A5:4 G5:4 | G5:16" },
    },
    order: ["a", "b"],
  },
  training: {
    name: "A Year in a Day", bpm: 124, key: 45, // A minor
    sections: {
      a: { bars: 8, chords: ["i", "i", "bVI", "bVII", "i", "i", "iv", "V"], drums: "drive", bass: "octaves", guitar: "chug", pad: "strings" },
      b: { bars: 8, chords: ["i", "bVII", "bVI", "bVII", "i", "bVII", "V", "V"], drums: "rock", bass: "octaves", guitar: "power", lead: "A5:4 C6:4 E6:6 D6:2 | C6:8 B5:8 | A5:4 G5:4 A5:4 C6:4 | B5:16" },
    },
    order: ["a", "b"],
  },
  ruins: {
    name: "Hope in a Ruined Future", bpm: 84, key: 48, // C minor
    sections: {
      a: { bars: 8, chords: ["i", "bVI", "bIII", "bVII", "i", "bVI", "iv", "V"], drums: "none", bass: "whole", pad: "strings", arp: "piano", lead: "G5:8 Eb5:4 F5:4 | G5:12 r:4 | Ab5:8 G5:4 F5:4 | Eb5:8 D5:8" },
      b: { bars: 8, chords: ["bVI", "bVII", "i", "i", "bVI", "bVII", "V", "V"], drums: "halftime", bass: "whole", pad: "strings", arp: "piano", guitar: "swells", lead: "C6:8 Bb5:4 Ab5:4 | G5:16 | Ab5:4 Bb5:4 C6:8 | D6:16" },
    },
    order: ["a", "b"],
  },
  battle: {
    name: "Power Level Over 9000", bpm: 172, key: 52, // E minor
    sections: {
      a: { bars: 8, chords: ["i", "i", "bVI", "bVII", "i", "i", "bIII", "V"], drums: "battle", bass: "gallop", guitar: "chug", lead: "E5:2 E5:2 G5:2 E5:2 A5:4 G5:4 | B5:2 A5:2 G5:2 E5:2 D5:8 | E5:2 G5:2 B5:4 D6:4 B5:4 | C6:8 B5:8" },
      b: { bars: 8, chords: ["bVI", "bVII", "i", "i", "bVI", "bVII", "V", "V"], drums: "drive", bass: "eighths", guitar: "power", pad: "strings", lead: "C6:4 D6:4 E6:8 | D6:4 B5:4 G5:8 | C6:4 D6:4 E6:4 G6:4 | F#6:16" },
      c: { bars: 4, chords: ["bVI", "bVII", "bVI", "V"], drums: "fill", bass: "eighths", guitar: "stabs", arp: "updown" },
    },
    order: ["a", "b", "a", "c"],
  },
  calm: {
    name: "Kame House Afternoon", bpm: 96, key: 53, mode: "major", // F major
    sections: {
      a: { bars: 8, chords: ["I", "vi", "IV", "V", "I", "vi", "ii", "V"], drums: "shuffle", bass: "bounce", arp: "piano", pad: "strings", lead: "A5:4 C6:4 F6:6 E6:2 | D6:8 C6:8 | Bb5:4 A5:4 G5:4 F5:4 | G5:16" },
    },
    order: ["a"],
  },
};

/** Which track plays where. A world not listed uses "hero". Bosses nearby switch to "battle". */
export const ZONE_MUSIC = {
  menu: "hero", earth_plains: "hero", kame_island: "calm", snake_way: "otherworld", king_kai: "otherworld",
  gizard_wasteland: "battle", namek: "alien", yardrat: "alien", west_city: "calm", gero_lab: "training",
  lookout: "otherworld", htc: "training", cell_games: "battle", papaya_island: "hero", babidi_ship: "alien",
  kai_world: "otherworld", beerus_planet: "otherworld", nameless_planet: "battle", future_earth: "ruins",
  world_of_void: "battle", broly_glacier: "battle", red_ribbon: "training",
};

// player-facing names are the game's own (data/names.js)
renameDeep(TRACKS);
