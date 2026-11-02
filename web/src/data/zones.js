import { renameDeep } from "./names.js";
// Every world in the game: terrain recipe, look (biome) and landmarks. game/zones.js turns these
// into height functions and props; world/ draws them. Coordinates are metres (x east, z north).
//
// terrain: { size, spawn, gravity, hills: {amp, scale} | false, flatSpawn, lake, ocean, islands,
//            mesas, edge: "mountains" | "none", platform, path, killY, ground }
//   ground: "grass" (default) | "dirt" | "sand" | "snow" | "white" | "stone"
// biome:   { sky, fog, sun, tints, trees, treeCount, rocks, bushes, grass, water, cloudSea, clouds }
// landmarks: [{ type, x, z, rot, scale, name, flatten (radius), collide (radius), dig }]
// travelPoint: where the travel pads to other worlds stand

const physical = (elevation = 34, azimuth = 205, extra = {}) => ({ type: "physical", elevation, azimuth, ...extra });
const gradient = (top, horizon, bottom, extra = {}) => ({ type: "gradient", top, horizon, bottom, elevation: 40, azimuth: 200, ...extra });

export const ZONE_DEFS = {
  // ---------------------------------------------------------------- DBZ: Saiyan Saga (Earth)
  earth_plains: {
    name: "Training Plains", planet: "Earth", saga: "Saiyan Saga",
    terrain: {
      size: 640, spawn: { x: 0, z: 0 },
      lake: { x: -135, z: 125, radius: 58, level: 0.35 },
      mesas: [
        { x: 150, z: -70, r: 36, h: 32 }, { x: 225, z: 150, r: 52, h: 46 }, { x: -60, z: -215, r: 30, h: 26 },
        { x: -235, z: -95, r: 44, h: 40 }, { x: 70, z: 235, r: 24, h: 21 }, { x: 255, z: -225, r: 42, h: 58 },
        { x: -25, z: -120, r: 15, h: 15 }, { x: 95, z: 95, r: 11, h: 12 },
      ],
      edge: "mountains",
    },
    biome: { sky: physical(), trees: "broadleaf", treeCount: 340 },
    landmarks: [
      { type: "crater", x: 48, z: 52, name: "Crashed Saiyan pod", dig: { radius: 9, depth: 2.6 } },
      { type: "farmhouse", x: -58, z: 34, rot: 0.6, name: "Farmer's house", flatten: 14, collide: 5 },
    ],
    travelPoint: { x: 0, z: -16 },
  },
  kame_island: {
    name: "Kame House", planet: "Earth", saga: "Saiyan Saga",
    terrain: { size: 400, spawn: { x: 0, z: -10 }, hills: { amp: 1.2, scale: 30 }, ocean: { level: 0 }, islands: [{ x: 0, z: 0, r: 34, h: 2.2 }], ground: "sand", flatSpawn: 0 },
    biome: { sky: physical(48, 160), trees: "palm", treeCount: 7, rocks: 12, bushes: 20, grass: 0.4, water: 0x1d8fae },
    landmarks: [{ type: "kamehouse", x: 0, z: 8, name: "Kame House", flatten: 9, collide: 5 }],
    travelPoint: { x: -12, z: -18 },
  },
  snake_way: {
    name: "Snake Way", planet: "Other World", saga: "Saiyan Saga",
    terrain: { size: 820, spawn: { x: 0, z: -380 }, path: { width: 4.2, amp: 70, wave: 70, from: -390, to: 390 }, killY: -40 },
    biome: {
      sky: gradient(0xf0b860, 0xffe7a8, 0xf5d76e, { sunColor: 0xfff2c0 }), fog: [0xffe7a8, 0.0016],
      cloudSea: { color: 0xf3cf5c, y: -18 }, trees: "none", rocks: 0, bushes: 0, grass: 0, clouds: false,
    },
    landmarks: [{ type: "snakehead", x: 0, z: -386, name: "Snake Way gate" }],
    travelPoint: { x: 0, z: -372 },
  },
  king_kai: {
    name: "King Kai's Planet", planet: "Other World", saga: "Saiyan Saga",
    terrain: { size: 140, spawn: { x: 0, z: -14 }, gravity: 10, planetoid: { radius: 58 }, killY: -60 },
    biome: {
      sky: gradient(0xeeb35a, 0xffe6a0, 0xf5d76e, { sunColor: 0xfff2c0 }), fog: [0xffe6a0, 0.002],
      cloudSea: { color: 0xf3cf5c, y: -45 }, tints: { grass: [1.15, 1.12, 0.75] }, trees: "broadleaf", treeCount: 1, rocks: 0, bushes: 6, clouds: false,
    },
    landmarks: [
      { type: "kingkaihouse", x: 10, z: 6, name: "King Kai's house", flatten: 7, collide: 4 },
      { type: "car", x: -6, z: 10, rot: 1.2, name: "King Kai's car", collide: 2 },
    ],
    travelPoint: { x: -8, z: -20 },
  },
  gizard_wasteland: {
    name: "Gizard Wasteland", planet: "Earth", saga: "Saiyan Saga · Resurrection 'F'",
    terrain: {
      size: 640, spawn: { x: 0, z: 0 }, hills: { amp: 9, scale: 160 }, ground: "dirt", edge: "mountains",
      mesas: [
        { x: 90, z: 60, r: 26, h: 30 }, { x: -110, z: 80, r: 34, h: 38 }, { x: 60, z: -140, r: 40, h: 44 },
        { x: -150, z: -120, r: 28, h: 52 }, { x: 200, z: -30, r: 22, h: 26 }, { x: 160, z: 200, r: 48, h: 60 },
        { x: -230, z: 180, r: 36, h: 40 }, { x: 10, z: 190, r: 18, h: 22 }, { x: -40, z: -70, r: 9, h: 14 },
      ],
    },
    biome: { sky: physical(40, 230), tints: { dirt: [1.12, 0.95, 0.8], rock: [1.1, 0.92, 0.78] }, trees: "dead", treeCount: 40, rocks: 420, bushes: 60, grass: 0.12 },
    landmarks: [],
    travelPoint: { x: 0, z: -16 },
  },
  // ---------------------------------------------------------------- DBZ: Namek / Frieza Saga
  namek: {
    name: "Planet Namek", planet: "Namek", saga: "Namek & Frieza Saga",
    terrain: {
      size: 700, spawn: { x: 0, z: 0 }, hills: { amp: 4, scale: 70 }, ocean: { level: 0 }, flatSpawn: 0,
      islands: [
        { x: 0, z: 0, r: 70, h: 4 }, { x: 160, z: 90, r: 55, h: 6 }, { x: -170, z: 60, r: 60, h: 5 },
        { x: 40, z: -190, r: 65, h: 5 }, { x: -120, z: -170, r: 40, h: 4 }, { x: 230, z: -150, r: 50, h: 7 },
        { x: -40, z: 230, r: 48, h: 5 },
      ],
      mesas: [
        { x: 160, z: 90, r: 9, h: 70 }, // Grand Elder Guru's pillar
        { x: 90, z: -60, r: 6, h: 34 }, { x: -90, z: 130, r: 7, h: 42 }, { x: 260, z: 40, r: 8, h: 48 },
        { x: -240, z: -40, r: 6, h: 30 }, { x: 120, z: 210, r: 9, h: 55 }, { x: -200, z: 200, r: 7, h: 38 },
        { x: 300, z: -260, r: 10, h: 62 }, { x: -60, z: -280, r: 8, h: 44 },
      ],
    },
    biome: {
      sky: gradient(0x58c49a, 0xbff0d6, 0x2f8f78, { sunColor: 0xf6fff0, elevation: 48 }), fog: [0xaee6cc, 0.0009],
      tints: { grass: [0.55, 1.05, 1.25], rock: [0.85, 1.0, 0.95], sand: [0.9, 1.0, 0.95] },
      trees: "ajisa", treeCount: 260, rocks: 140, bushes: 200, water: 0x2aa79b,
    },
    landmarks: [
      { type: "namekhouse", x: -20, z: 22, name: "Elder Moori's village", flatten: 7, collide: 4 },
      { type: "namekhouse", x: -34, z: 8, flatten: 6, collide: 4, scale: 0.8 },
      { type: "namekhouse", x: -8, z: 38, flatten: 6, collide: 4, scale: 0.9 },
      { type: "gurutower", x: 160, z: 90, name: "Grand Elder Guru's house" },
      { type: "friezaship", x: 40, z: -190, name: "Frieza's spaceship", flatten: 28, collide: 16 },
      { type: "capsuleship", x: 18, z: -22, name: "Capsule Corp ship", flatten: 9, collide: 5 },
    ],
    travelPoint: { x: 8, z: -30 },
  },
  yardrat: {
    name: "Planet Yardrat", planet: "Yardrat", saga: "After the Frieza Saga",
    terrain: { size: 520, spawn: { x: 0, z: 0 }, hills: { amp: 10, scale: 120 }, lake: { x: 90, z: 70, radius: 40, level: 0.3 }, edge: "mountains" },
    biome: {
      sky: gradient(0x8a76d6, 0xf3c8e6, 0x6a5aa6, { sunColor: 0xffe6f6, elevation: 30 }), fog: [0xe9c6e4, 0.001],
      tints: { grass: [1.05, 0.8, 1.2], rock: [0.9, 0.85, 1.1] }, trees: "crystal", treeCount: 180, rocks: 120, bushes: 150, water: 0x6c4fb0,
    },
    landmarks: [
      { type: "yardrathut", x: -18, z: 20, name: "Yardrat village", flatten: 8, collide: 4 },
      { type: "yardrathut", x: 6, z: 30, flatten: 7, collide: 4, scale: 0.8 },
      { type: "crashpod", x: 30, z: -20, name: "Goku's crashed pod", dig: { radius: 6, depth: 1.5 } },
    ],
    travelPoint: { x: 0, z: -16 },
  },
  // ---------------------------------------------------------------- DBZ: Android & Cell Saga
  west_city: {
    name: "West City · Capsule Corporation", planet: "Earth", saga: "Android Saga · Battle of Gods",
    terrain: { size: 520, spawn: { x: 0, z: -30 }, hills: { amp: 3, scale: 120 }, flatSpawn: 120, edge: "mountains" },
    biome: { sky: physical(42, 190), trees: "broadleaf", treeCount: 120, rocks: 30, bushes: 220 },
    landmarks: [
      { type: "capsulecorp", x: 0, z: 30, name: "Capsule Corporation", flatten: 30, collide: 17 },
      { type: "dome", x: -55, z: 10, flatten: 10, collide: 7, scale: 0.9 }, { type: "dome", x: 52, z: 6, flatten: 10, collide: 7, scale: 1.1 },
      { type: "dome", x: -60, z: 70, flatten: 10, collide: 7 }, { type: "dome", x: 66, z: 72, flatten: 10, collide: 7, scale: 0.8 },
      { type: "dome", x: -90, z: -40, flatten: 10, collide: 7, scale: 1.2 }, { type: "dome", x: 95, z: -38, flatten: 10, collide: 7 },
      { type: "capsuleship", x: 30, z: -8, name: "Capsule Corp ship", flatten: 9, collide: 5 },
      { type: "timemachine", x: -24, z: -6, name: "Trunks' time machine", collide: 2 },
    ],
    travelPoint: { x: 0, z: -46 },
  },
  gero_lab: {
    name: "Northern Mountains · Dr. Gero's Lab", planet: "Earth", saga: "Android & Cell Saga",
    terrain: {
      size: 560, spawn: { x: 0, z: 0 }, hills: { amp: 26, scale: 150 }, edge: "mountains",
      mesas: [{ x: 120, z: 120, r: 40, h: 46 }, { x: -140, z: 60, r: 30, h: 34 }],
    },
    biome: { sky: physical(28, 160, { turbidity: 1.8 }), snowLine: 52, trees: "pine", treeCount: 420, rocks: 260, bushes: 120, grass: 0.7, tints: { grass: [0.9, 1.0, 0.95] } },
    landmarks: [
      { type: "labdoor", x: 120, z: 81, rot: Math.PI, name: "Dr. Gero's lab", collide: 4 },
      { type: "ruin", x: -60, z: -80, name: "Ginger Town", flatten: 26, collide: 9 },
      { type: "ruin", x: -84, z: -62, flatten: 14, collide: 6, scale: 0.7 },
      { type: "husk", x: 70, z: -40, name: "Cell's empty shell" },
    ],
    travelPoint: { x: 0, z: -18 },
  },
  lookout: {
    name: "Kami's Lookout", planet: "Earth", saga: "Android & Cell Saga",
    terrain: { size: 180, spawn: { x: 0, z: -40 }, platform: { radius: 62, height: 0 }, killY: -50, ground: "stone" },
    biome: { sky: physical(38, 210, { turbidity: 1.6 }), cloudSea: { color: 0xffffff, y: -60 }, trees: "palm", treeCount: 6, rocks: 0, bushes: 14, grass: 0.5 },
    landmarks: [
      { type: "palace", x: 0, z: 18, name: "Kami's Palace", collide: 12 },
      { type: "htcdoor", x: 30, z: -10, rot: -1.2, name: "Hyperbolic Time Chamber", collide: 4 },
    ],
    travelPoint: { x: -20, z: -44 },
  },
  htc: {
    name: "Hyperbolic Time Chamber", planet: "Other Dimension", saga: "Android & Cell Saga",
    terrain: { size: 900, spawn: { x: 0, z: 0 }, hills: false, gravity: 10, ground: "white", flatSpawn: 0 },
    biome: {
      sky: gradient(0xfdfbf4, 0xffffff, 0xffffff, { sunColor: 0xffffff }), fog: [0xfffdf6, 0.006],
      trees: "none", rocks: 0, bushes: 0, grass: 0, clouds: false, sun: { intensity: 1.6 },
    },
    landmarks: [{ type: "htcroom", x: 0, z: 14, name: "Living quarters", collide: 9 }],
    travelPoint: { x: 0, z: -10 },
  },
  cell_games: {
    name: "Cell Games Arena", planet: "Earth", saga: "Cell Saga",
    terrain: {
      size: 560, spawn: { x: 0, z: -60 }, hills: { amp: 8, scale: 140 }, ground: "dirt", edge: "mountains", flatSpawn: 90,
      mesas: [{ x: 130, z: 90, r: 30, h: 34 }, { x: -150, z: 60, r: 40, h: 28 }, { x: 40, z: 190, r: 34, h: 40 }, { x: -120, z: -160, r: 26, h: 30 }],
    },
    biome: { sky: physical(36, 240), tints: { dirt: [1.08, 0.96, 0.82] }, trees: "dead", treeCount: 20, rocks: 300, bushes: 40, grass: 0.1 },
    landmarks: [{ type: "cellarena", x: 0, z: 0, name: "Cell's ring", flatten: 40 }],
    travelPoint: { x: 0, z: -76 },
  },
  // ---------------------------------------------------------------- DBZ: Majin Buu Saga
  papaya_island: {
    name: "World Martial Arts Tournament", planet: "Earth", saga: "Majin Buu Saga",
    terrain: { size: 600, spawn: { x: 0, z: -50 }, hills: { amp: 3, scale: 80 }, ocean: { level: 0 }, islands: [{ x: 0, z: 0, r: 130, h: 3 }], flatSpawn: 0 },
    biome: { sky: physical(52, 170), trees: "palm", treeCount: 60, rocks: 30, bushes: 120, water: 0x1f8fb0 },
    landmarks: [{ type: "budokai", x: 0, z: 20, name: "Tournament ring", flatten: 36 }],
    travelPoint: { x: 0, z: -66 },
  },
  babidi_ship: {
    name: "Babidi's Spaceship", planet: "Earth", saga: "Majin Buu Saga",
    terrain: {
      size: 560, spawn: { x: 0, z: -60 }, hills: { amp: 12, scale: 150 }, ground: "dirt", edge: "mountains",
      mesas: [{ x: 120, z: 80, r: 28, h: 30 }, { x: -130, z: 110, r: 36, h: 36 }, { x: -60, z: -160, r: 22, h: 26 }],
    },
    biome: { sky: physical(30, 250), trees: "dead", treeCount: 30, rocks: 260, bushes: 60, grass: 0.25 },
    landmarks: [{ type: "babidiship", x: 0, z: 30, name: "Babidi's spaceship", flatten: 40, collide: 22 }],
    travelPoint: { x: 0, z: -76 },
  },
  kai_world: {
    name: "Sacred World of the Kai", planet: "Sacred World", saga: "Majin Buu Saga",
    terrain: { size: 560, spawn: { x: 0, z: 0 }, hills: { amp: 12, scale: 140 }, lake: { x: -70, z: 90, radius: 46, level: 0.3 }, edge: "mountains", mesas: [{ x: 120, z: -90, r: 14, h: 18 }] },
    biome: { sky: physical(46, 200, { turbidity: 1.5, rayleigh: 2.2 }), tints: { grass: [0.95, 1.08, 0.9] }, trees: "broadleaf", treeCount: 160, rocks: 160, bushes: 260 },
    landmarks: [
      { type: "zsword", x: 120, z: -90, name: "The Z Sword" },
      { type: "crystals", x: 30, z: 60, name: "Kai crystals", collide: 4 },
      { type: "crystals", x: -40, z: -50, collide: 4, scale: 0.7 },
    ],
    travelPoint: { x: 0, z: -18 },
  },
  // ---------------------------------------------------------------- DBS
  beerus_planet: {
    name: "Beerus's Planet", planet: "Beerus's Planet", saga: "Battle of Gods",
    terrain: {
      size: 600, spawn: { x: 0, z: -30 }, hills: { amp: 14, scale: 120 }, lake: { x: 60, z: 40, radius: 30, level: 0.3 }, edge: "mountains",
      mesas: [
        { x: -90, z: 80, r: 8, h: 90 }, { x: 140, z: -60, r: 10, h: 120 }, { x: -160, z: -90, r: 7, h: 70 }, { x: 190, z: 150, r: 12, h: 110 },
        { x: -40, z: 200, r: 9, h: 95 }, { x: 60, z: -180, r: 8, h: 80 },
      ],
    },
    biome: {
      sky: gradient(0x4d3a8a, 0xe6b8e6, 0x3a2a66, { sunColor: 0xfff0e0, elevation: 36 }), fog: [0xd9b2df, 0.0009],
      tints: { grass: [0.85, 1.05, 1.0], rock: [0.95, 0.85, 1.05] }, trees: "broadleaf", treeCount: 200, rocks: 120, bushes: 240, water: 0x3b6fb0,
    },
    landmarks: [{ type: "pyramid", x: 0, z: 40, name: "Beerus's temple", flatten: 30, collide: 20 }],
    travelPoint: { x: 0, z: -46 },
  },
  nameless_planet: {
    name: "Nameless Planet", planet: "Universe 6 border", saga: "Universe 6 Saga",
    terrain: { size: 520, spawn: { x: 0, z: -60 }, hills: { amp: 6, scale: 140 }, ground: "dirt", edge: "mountains", flatSpawn: 90 },
    biome: {
      sky: gradient(0xd99a5a, 0xf6dcb6, 0x8a6a4a, { sunColor: 0xfff0d0, elevation: 30 }), fog: [0xf0d4b0, 0.0011],
      tints: { dirt: [1.0, 0.95, 0.9] }, trees: "none", rocks: 200, bushes: 0, grass: 0,
    },
    landmarks: [{ type: "cellarena", x: 0, z: 10, scale: 1.3, name: "Champa's arena", flatten: 50 }, { type: "stands", x: 0, z: 70, name: "Spectator stands", collide: 14 }],
    travelPoint: { x: 0, z: -76 },
  },
  future_earth: {
    name: "Future Earth", planet: "Earth (Trunks' timeline)", saga: "Future Trunks Saga",
    terrain: { size: 560, spawn: { x: 0, z: -40 }, hills: { amp: 4, scale: 120 }, ground: "dirt", edge: "mountains", flatSpawn: 140 },
    biome: {
      sky: gradient(0x6c7078, 0xb8b4aa, 0x55524c, { sunColor: 0xd8d0c0, elevation: 22 }), fog: [0xa8a49a, 0.0016],
      trees: "dead", treeCount: 60, rocks: 300, bushes: 30, grass: 0.15,
    },
    landmarks: [
      { type: "ruin", x: -40, z: 30, scale: 1.4, collide: 10, name: "Ruined West City" }, { type: "ruin", x: 30, z: 50, scale: 1.1, collide: 9 },
      { type: "ruin", x: 70, z: 10, scale: 1.6, collide: 11 }, { type: "ruin", x: -80, z: -20, scale: 0.9, collide: 7 },
      { type: "ruin", x: 10, z: 100, scale: 1.8, collide: 12 }, { type: "ruin", x: -110, z: 80, scale: 1.2, collide: 9 },
      { type: "bunker", x: 20, z: -10, name: "Resistance hideout", collide: 6 },
    ],
    travelPoint: { x: 0, z: -56 },
  },
  world_of_void: {
    name: "World of Void", planet: "World of Void", saga: "Tournament of Power",
    terrain: { size: 260, spawn: { x: 0, z: -70 }, platform: { radius: 100, height: 0, broken: true }, killY: -60, ground: "stone" },
    biome: {
      sky: gradient(0x0a0820, 0x4a3a8a, 0x05040f, { sunColor: 0xe8e0ff, stars: true, elevation: 50 }), fog: [0x2a2450, 0.0008],
      trees: "none", rocks: 40, bushes: 0, grass: 0, clouds: false, sun: { intensity: 2.4 },
    },
    landmarks: [
      { type: "pillar", x: 70, z: 40 }, { type: "pillar", x: -60, z: 60 }, { type: "pillar", x: -75, z: -30 }, { type: "pillar", x: 40, z: -70 },
      { type: "zenobox", x: 0, z: 160, name: "Grand Zeno's stand" },
    ],
    travelPoint: { x: 0, z: -86 },
  },
  broly_glacier: {
    name: "Northern Glacier", planet: "Earth", saga: "Dragon Ball Super: Broly",
    terrain: {
      size: 600, spawn: { x: 0, z: -40 }, hills: { amp: 14, scale: 160 }, ground: "snow", edge: "mountains",
      mesas: [{ x: 120, z: 80, r: 34, h: 26 }, { x: -140, z: 120, r: 46, h: 34 }, { x: 80, z: -160, r: 28, h: 22 }],
    },
    biome: { sky: physical(18, 200, { turbidity: 2.2 }), snowLine: -50, fog: [0xd6e2ee, 0.0012], trees: "none", rocks: 160, bushes: 0, grass: 0, tints: { rock: [0.85, 0.92, 1.05] } },
    landmarks: [{ type: "friezaship", x: 90, z: -40, scale: 0.6, name: "Frieza Force ship", flatten: 18, collide: 10 }],
    travelPoint: { x: 0, z: -56 },
  },
  red_ribbon: {
    name: "Red Ribbon Army Base", planet: "Earth", saga: "Dragon Ball Super: Super Hero",
    terrain: { size: 600, spawn: { x: 0, z: -80 }, hills: { amp: 6, scale: 90 }, ocean: { level: 0 }, islands: [{ x: 0, z: 0, r: 160, h: 6 }], flatSpawn: 0, mesas: [{ x: 90, z: 90, r: 30, h: 24 }] },
    biome: { sky: physical(26, 260), trees: "broadleaf", treeCount: 80, rocks: 120, bushes: 140, water: 0x245f86 },
    landmarks: [
      { type: "hangar", x: 0, z: 20, name: "Red Ribbon base", flatten: 30, collide: 16 },
      { type: "hangar", x: -50, z: -10, scale: 0.6, flatten: 18, collide: 10 },
      { type: "radartower", x: 40, z: -20, name: "Radar tower", collide: 3 },
    ],
    travelPoint: { x: 0, z: -96 },
  },
};

// Manga-era destinations reuse the same terrain/landmark engine.
ZONE_DEFS.new_namek={...structuredClone(ZONE_DEFS.namek),name:'New Namek',planet:'New Namek',saga:'Galactic Patrol Prisoner Saga'};
ZONE_DEFS.planet_cereal={...structuredClone(ZONE_DEFS.gizard_wasteland),name:'Planet Cereal',planet:'Cereal',saga:'Granolah the Survivor Saga',
  landmarks:[{type:'farmhouse',x:-24,z:-10,name:'Monaito’s home',flatten:8,collide:4}]};

/** Story order of the worlds (travel pads list them in this order). */
export const ZONE_ORDER = [
  "earth_plains", "kame_island", "snake_way", "king_kai", "gizard_wasteland", "namek", "yardrat", "west_city",
  "gero_lab", "lookout", "htc", "cell_games", "papaya_island", "babidi_ship", "kai_world", "beerus_planet",
  "nameless_planet", "future_earth", "world_of_void", "broly_glacier", "new_namek", "planet_cereal", "red_ribbon",
];

// player-facing names are the game's own (data/names.js)
renameDeep(ZONE_DEFS);
