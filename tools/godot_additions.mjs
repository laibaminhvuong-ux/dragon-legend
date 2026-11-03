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
  road.biome = {...road.biome, rocks: 0, stones: 0};          // no pebbles on the hall's marble floor
  road.terrain.size = 1000;                                   // room south of the road for the station
  road.terrain.plaza = {x: DX, z: CZ, radius: 54, height: 0}; // flat round floor in front of the road
  road.terrain.spawn = at(0, -45);                            // arrive at the hall's south steps, facing the king
  road.travelPoint = at(20, -37);                             // the pilot waits by the arrival steps
  road.landmarks = [
    {type: 'checkin', name: "King Yemmo's Check-In Station", ...at(0, 0), collide: 5.5},
    ...road.landmarks,
  ];
  // King Kae's planet hangs in the sky just past the road's end: look up to see it, fly into it to land there.
  // (Points on a road world follow the road's curve, so x is relative to the road at that z.)
  // straight ahead of where the road ends (z 390), so it hangs right in front of you when you look up
  const kaiZ = 520;
  const kai = {x: curve(390) - curve(kaiZ), z: kaiZ, alt: 110, radius: 34};
  road.landmarks.push({type: 'kaiplanet', name: "King Kae's Planet", x: kai.x, z: kai.z, alt: kai.alt, radius: kai.radius});
  road.portals = [{zone: 'king_kai', x: kai.x, z: kai.z, y: kai.alt, r: kai.radius + 14, locked: 'Run to the end of Serpent Road first.'}];
  const king = npcs.find(n => n.id === 'king_yemma');
  Object.assign(king, at(0, 8.5), {y: 1.4, rot: Math.PI, sit: true});   // seated on a raised dais
  const guide = npcs.find(n => n.id === 'guide_snake_way');
  if (guide) Object.assign(guide, at(-14, -39));
  return ['snake_way'];
}

// User request 2026-11-03: open world, one map per planet (docs/superpowers/specs/2026-11-03-open-world-design.md).
// New towns are ordinary areas (zones) so NPCs, shops and quests attach to them like anywhere else.
function town(zones, id, name, style, {size = 480, radius = 200, terrain = {}, biomeFrom = 'earth_plains', biome = {}, seed = 1, planet = 'Earth'} = {}) {
  zones[id] = {
    name, planet, saga: 'Open world', kind: 'town',
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
  // the other planets: bigger maps with new places (spec "Other planets")
  const island = {terrain: {ocean: {level: 0}, islands: [{x: 0, z: 0, r: 120, h: 4}], hills: {amp: 1.5, scale: 60}, flatSpawn: 0, spawn: {x: 0, z: -60}}};
  const more = [];
  const add = (planetFrom, id, name, style, opts) => {
    more.push(town(zones, id, name, style, {planet: zones[planetFrom].planet, biomeFrom: planetFrom, ...opts}));
    return id;
  };
  const R = (zone, x, z, radius, blend = 90) => ({zone, x, z, radius, blend});
  const planet = (start, size, seed, base, sea, regions, props) =>
    ({name: zones[start].planet, size, seed, start, biome: start, props, base, sea, regions});
  const others = {
    nameck: planet('namek', 2000, 501, {amp: 6, scale: 200, lift: 0, islands: true}, {level: 0}, [R('namek', 0, 0, 340),
      R(add('namek', 'nameck_east', 'Elder Grove Village', 'domevillage', {size: 300, radius: 110, seed: 61, ...island}), 700, 250, 130),
      R(add('namek', 'nameck_south', 'Ajisa Shore Village', 'domevillage', {size: 300, radius: 110, seed: 67, ...island}), -150, -720, 130),
      R(add('namek', 'nameck_west', 'Westwind Village', 'domevillage', {size: 300, radius: 110, seed: 71, ...island}), -720, 200, 130)],
      {treeCount: 700, rocks: 300, bushes: 700, stones: 1500}),
    new_nameck: planet('new_namek', 2000, 502, {amp: 6, scale: 200, lift: 0, islands: true}, {level: 0}, [R('new_namek', 0, 0, 340),
      R(add('new_namek', 'new_nameck_east', 'Sunrise Village', 'domevillage', {size: 300, radius: 110, seed: 73, ...island}), 700, 250, 130),
      R(add('new_namek', 'new_nameck_south', 'Twin Pools Village', 'domevillage', {size: 300, radius: 110, seed: 79, ...island}), -150, -720, 130),
      R(add('new_namek', 'new_nameck_west', 'New Elder Village', 'domevillage', {size: 300, radius: 110, seed: 83, ...island}), -720, 200, 130)],
      {treeCount: 700, rocks: 300, bushes: 700, stones: 1500}),
    yardran: planet('yardrat', 1800, 503, {amp: 12, scale: 220, lift: 20}, {}, [R('yardrat', 0, 0, 250),
      R(add('yardrat', 'yardran_east', 'Crystal Hollow', 'domevillage', {size: 300, radius: 100, seed: 89}), 560, 320, 120),
      R(add('yardrat', 'yardran_west', 'Spirit Step Village', 'domevillage', {size: 300, radius: 100, seed: 97}), -520, -360, 120)],
      {treeCount: 1200, rocks: 500, bushes: 1400, stones: 2500}),
    grain: planet('planet_cereal', 1800, 504, {amp: 10, scale: 220, lift: 20}, {}, [R('planet_cereal', 0, 0, 310),
      R(add('planet_cereal', 'grain_farms', 'Harvest Farms', 'village', {size: 320, radius: 110, seed: 101}), 600, -330, 130),
      R(add('planet_cereal', 'grain_market', 'Grain Market', 'domevillage', {size: 340, radius: 120, seed: 103}), -560, 360, 140)],
      {treeCount: 1200, rocks: 500, bushes: 1400, stones: 2500}),
    beeros: planet('beerus_planet', 1600, 505, {amp: 10, scale: 200, lift: 20}, {}, [R('beerus_planet', 0, 0, 290),
      R(add('beerus_planet', 'beeros_gardens', 'Temple Gardens', 'garden', {size: 300, radius: 100, seed: 107}), 540, 360, 120)],
      {treeCount: 1000, rocks: 400, bushes: 1100, stones: 2000}),
    future_earth: planet('future_earth', 2000, 506, {amp: 10, scale: 240, lift: 20}, {}, [R('future_earth', 0, 0, 270),
      R(add('future_earth', 'future_ruins', 'Ruined District', 'ruins', {size: 520, radius: 200, seed: 109}), 680, -220, 230)],
      {treeCount: 400, rocks: 900, bushes: 600, stones: 3500}),
    kae_world: planet('kai_world', 1400, 507, {amp: 10, scale: 200, lift: 20}, {}, [R('kai_world', 0, 0, 270),
      R(add('kai_world', 'kae_shrine', "Elder Kae's Shrine", 'garden', {size: 240, radius: 80, seed: 113}), 470, 280, 90)],
      {treeCount: 900, rocks: 400, bushes: 1000, stones: 1500}),
    nameless: planet('nameless_planet', 1400, 508, {amp: 10, scale: 200, lift: 20}, {}, [R('nameless_planet', 0, 0, 250),
      R(add('nameless_planet', 'nameless_outpost', 'Abandoned Outpost', 'ruins', {size: 240, radius: 90, seed: 127}), 470, -300, 100)],
      {treeCount: 400, rocks: 600, bushes: 500, stones: 2000}),
  };
  for (const t of [...towns, ...more]) if (!zoneOrder.includes(t)) zoneOrder.push(t);
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
  Object.assign(planets, others);
  return {planets, changed: [...towns, ...more]};
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
