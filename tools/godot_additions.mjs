// Content that exists only in the Godot game (the classic web game in web/ stays as it was).
// export_godot_data.mjs applies these on top of the evaluated JS tables before writing godot/data/.
// Every zone changed here is listed in godot_additions.json so the JS-parity tests skip it and test
// the Godot version instead.

// User request 2026-11-03: Other World starts at King Yemmo's Check-In Station: you arrive in his hall,
// he sits at his giant desk judging the line of souls, and Serpent Road starts behind it.
function checkInStation(zones, npcs) {
  const road = zones.snake_way;
  const path = road.terrain.path;
  // Points on a road world are shifted sideways by the road's curve at their z (RuleZone._on_road / place),
  // so everything here is placed relative to the station's centre and un-shifted for its own z.
  const curve = z => Math.sin(z / path.wave) * path.amp + Math.sin(z / (path.wave * 0.37)) * path.amp * 0.18;
  // The station sits straight in front of where the road starts (z -396), so the road leaves the floor.
  const CZ = -447, DX = curve(-398) - curve(CZ), CX = curve(CZ) + DX;
  const at = (x, z) => ({x: CX + x - curve(CZ + z), z: CZ + z});
  road.terrain.size = 1000;                                   // room south of the road for the station
  road.terrain.plaza = {x: DX, z: CZ, radius: 54, height: 0}; // flat round floor in front of the road
  road.terrain.spawn = at(0, -45);                            // arrive at the hall's south steps, facing the king
  road.travelPoint = at(20, -37);                             // the pilot waits by the arrival steps
  road.landmarks = [
    {type: 'checkin', name: "King Yemmo's Check-In Station", ...at(0, 0), collide: 5.5},
    ...road.landmarks,
  ];
  const king = npcs.find(n => n.id === 'king_yemma');
  Object.assign(king, at(0, 8.5), {y: 1.4, rot: Math.PI, sit: true});   // seated on a raised dais
  const guide = npcs.find(n => n.id === 'guide_snake_way');
  if (guide) Object.assign(guide, at(-14, -39));
  return ['snake_way'];
}

// User request 2026-11-03: open world, one map per planet (docs/superpowers/specs/2026-11-03-open-world-design.md).
// New towns are ordinary areas (zones) so NPCs, shops and quests attach to them like anywhere else.
function town(zones, id, name, style, {size = 480, radius = 200, terrain = {}, biomeFrom = 'earth_plains', biome = {}, seed = 1} = {}) {
  zones[id] = {
    name, planet: 'Earth', saga: 'Open world', kind: 'town',
    terrain: {size, hills: {amp: 2, scale: 120}, flatSpawn: radius, spawn: {x: 0, z: -radius * 0.75}, ...terrain},
    biome: {...structuredClone(zones[biomeFrom].biome), treeCount: 60, bushes: 120, rocks: 30, ...biome},
    landmarks: [{type: 'town', name, x: 0, z: 0, style, radius, seed, flatten: radius}],
    travelPoint: {x: 18, z: -radius * 0.75},
  };
  return id;
}

function openWorld(zones, zoneOrder) {
  const towns = [
    town(zones, 'amber_city', 'Amber City', 'city', {radius: 210, seed: 11}),
    town(zones, 'pepper_village', 'Pepper Village', 'village', {size: 340, radius: 120, seed: 23}),
    town(zones, 'snowpeak_village', 'Snowpeak Village', 'snowvillage', {size: 320, radius: 110, seed: 37,
      terrain: {ground: 'snow'}, biomeFrom: 'broly_glacier', biome: {treeCount: 30}}),
    town(zones, 'harbor_town', 'Harbor Town', 'harbor', {size: 400, radius: 120, seed: 41,
      terrain: {ocean: {level: 0}, islands: [{x: 0, z: 30, r: 130, h: 3}], hills: {amp: 1.2, scale: 60}, flatSpawn: 0, spawn: {x: 0, z: -40}},
      biomeFrom: 'kame_island'}),
  ];
  for (const t of towns) if (!zoneOrder.includes(t)) zoneOrder.push(t);
  const R = (zone, x, z, radius, blend = 90) => ({zone, x, z, radius, blend});
  const planets = {
    earth: {
      name: 'Earth', size: 3200, seed: 4242, start: 'earth_plains', biome: 'earth_plains',
      props: {treeCount: 2600, rocks: 900, bushes: 3200, stones: 5000},
      base: {amp: 14, scale: 260, northFrom: 600, northTo: 1300, lift: 20},
      sea: {level: 0, southFrom: -900, southTo: -1060, bays: [{x: 1350, z: 1150, r: 420}]},
      regions: [
        R('earth_plains', 0, 0, 300), R('west_city', 1100, 150, 260), R('red_ribbon', 1250, 1050, 280),
        R('gero_lab', 0, 1150, 280), R('broly_glacier', -1100, 1150, 300), R('gizard_wasteland', -1150, 100, 300),
        R('babidi_ship', -700, -650, 260), R('cell_games', 300, -900, 260), R('kame_island', 1150, -1250, 200),
        R('papaya_island', -200, -1300, 260),
        R('amber_city', 650, -350, 240), R('pepper_village', -450, 450, 150), R('snowpeak_village', -550, 1350, 140),
        R('harbor_town', 700, -1300, 160),
      ],
    },
  };
  return {planets, changed: towns};
}

export function applyGodotAdditions(tables) {
  const zones = structuredClone(tables.zones);
  const npcs = structuredClone(tables.npcs);
  const characters = structuredClone(tables.characters);
  const zoneOrder = [...tables.zone_order];
  const world = openWorld(zones, zoneOrder);
  const changed = [...checkInStation(zones, npcs)];
  // giant, seated behind the desk: red skin, black beard, judge's hat (Parts.costume "yemmo")
  Object.assign(characters.king_yemma, {scale: 4.2, look: {race: 'Human', skin: 0, skinHex: 0xc8463c, face: 'Fierce', hair: 'None',
    hairColor: 0, build: 'Muscular', outfit: 'CraneGi', outfitTint: 2, costume: 'yemmo'}});
  return {
    ...tables, zones, npcs, characters, zone_order: zoneOrder, planets: world.planets,
    godot_additions: {zones: [...new Set(changed)].sort(), note: 'Zones changed for the Godot game only; JS parity skips them.'},
  };
}
