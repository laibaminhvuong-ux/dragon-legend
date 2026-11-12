import {fightingStyles} from './fighting_styles.mjs';
import {skillPresentation} from './skill_presentation.mjs';
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
    {type: 'checkinhall', name: "King Yemmo's Check-In Station", ...at(0, 0), collide: 5.5},   // 0.0.8 map pass: B3 hall builder (was 'checkin')
    ...road.landmarks,
  ];
  // King Kae's planet hangs in the sky just past the road's end: look up to see it, fly into it to land there.
  // (Points on a road world follow the road's curve, so x is relative to the road at that z.)
  // straight ahead of where the road ends (z 390), so it hangs right in front of you when you look up
  const kaiZ = 520;
  const kai = {x: curve(390) - curve(kaiZ), z: kaiZ, alt: 110, radius: 34};
  road.landmarks.push({type: 'kaiorb', name: "King Kae's Planet", x: kai.x, z: kai.z, alt: kai.alt, radius: kai.radius});
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

// User request 2026-11-04: big buildings have interiors. Each style is a small map holding one closed room
// (RuleInterior in godot/rules/interior.gd draws/collides it); doors on the open-world maps lead here.
function interiors(zones) {
  const styles = {home: ['House', 'stone', 4.2, 12], tower: ['Tower Lobby', 'stone', 7, 22], lab: ['Laboratory', 'stone', 6.5, 22],
    temple: ['Temple Hall', 'stone', 10, 26], hangar: ['Hangar', 'stone', 13, 28]};
  const ids = [];
  for (const [style, [name, ground, h, d]] of Object.entries(styles)) {
    const id = 'interior_' + style;
    const biome = structuredClone(zones.earth_plains.biome);
    for (const k of Object.keys(biome)) if (typeof biome[k] === 'number' && /count|bushes|rocks|stones|grass|flowers/i.test(k)) biome[k] = 0;
    zones[id] = {
      name, planet: 'Interior', saga: 'Interior', kind: 'interior',
      terrain: {size: 90, ground, hills: {amp: 0, scale: 50}, flatSpawn: 44, spawn: {x: 0, z: d / 2 - 2.6}},
      biome: {...biome, treeCount: 0, bushes: 0, rocks: 0, stones: 0},
      landmarks: [{type: 'interior', style, name, x: 0, z: 0}],
      ceiling: h - 2.1, spawnYaw: Math.PI,
    };
    ids.push(id);
  }
  return ids;
}

// User request 2026-11-05: Gokan's childhood arcs (docs/superpowers/specs/2026-11-05-childhood-arcs-design.md).
// New story areas on the Earth map (regions) plus Kamu's Lookout, a small sky map reached by flying above Korrin Tower.
function childhoodPlaces(zones) {
  const area = (id, name, from, landmarks, {size = 420, flat = 90, spawn = {x: 0, z: -70}, biome = {}, terrain = {}} = {}) => {
    zones[id] = {
      name, planet: 'Earth', saga: 'Origins',
      terrain: {size, hills: {amp: 4, scale: 140}, flatSpawn: flat, spawn, ...terrain},
      biome: {...structuredClone(zones[from].biome), ...biome},
      landmarks, travelPoint: {x: 16, z: spawn.z},
    };
    return id;
  };
  const ids = [
    area('mt_paozu', 'Mt. Paozu', 'earth_plains', [{type: 'paozucabin', name: "Grandpa Gohin's Hut", x: 0, z: 10, rot: Math.PI, collide: 4.5, flatten: 18}],
      {biome: {treeCount: 260, bushes: 260}, terrain: {hills: {amp: 9, scale: 110}}}),
    area('fire_mountain', 'Fire Mountain', 'gizard_wasteland', [{type: 'firekeep', name: "The Ox-Lord's Castle", x: 0, z: 40, rot: Math.PI, collide: 17, flatten: 36}],
      {biome: {treeCount: 10}}),
    area('pilav_castle', "Emperor Pilav's Castle", 'gizard_wasteland', [{type: 'pilavpalace', name: "Pilav's Castle", x: 0, z: 40, rot: Math.PI, collide: 23, flatten: 40}]),
    area('muscle_tower', 'Muscle Tower', 'broly_glacier', [{type: 'musclefort', name: 'Muscle Tower', x: 0, z: 40, rot: Math.PI, collide: 13, flatten: 30}]),
    area('baaba_palace', "Fortuneteller Baaba's Palace", 'earth_plains', [{type: 'baabaisle', name: "Baaba's Palace", x: 0, z: 40, collide: 8, flatten: 56}],
      {biome: {treeCount: 40}}),
    area('korrin_tower', 'Korrin Tower', 'earth_plains', [{type: 'korrinspire', name: 'Korrin Tower', x: 0, z: 30, collide: 7, flatten: 20}],
      {biome: {treeCount: 220}}),
    area('piccor_castle', "King Piccor's Castle", 'gizard_wasteland', [{type: 'kingcastle', name: "King Piccor's Castle", x: 0, z: 45, rot: Math.PI, collide: 19, flatten: 42}]),
    area('tournament_island', 'Tournament Island', 'earth_plains', [{type: 'budokaihall', name: 'World Tournament Arena', x: 0, z: 20, flatten: 50}],
      {biome: {treeCount: 30}}),
  ];
  // Kamu's Lookout: a floating platform in the sky, reached by flying up past Korrin Tower's top. There is nothing
  // around it (user report 2026-11-05, "can't leave the Lookout": it used to sit on a white floor, so the drop back
  // down never happened); step off the edge and you fall to Korrin Tower.
  zones.kamu_lookout = {
    name: "Kamu's Lookout", planet: 'Earth', saga: 'Origins',
    terrain: {size: 300, ground: 'white', platform: {radius: 40, height: 0}, killY: -300, spawn: {x: 0, z: -18}},
    biome: {...structuredClone(zones.earth_plains.biome), treeCount: 0, bushes: 0, rocks: 0, stones: 0},
    landmarks: [{type: 'lookoutpalace', name: "Kamu's Lookout", x: 0, z: 0, flatten: 40}],
    travelPoint: {x: 10, z: -18},
    // falling past ~75 m below the edge lands you at Korrin Tower (the sphere's top is 70 m under the platform, so
    // standing anywhere on it never triggers it); killY respawns you on top if the tower isn't open yet
    portals: [{zone: 'korrin_tower', x: 0, z: 0, y: -400, r: 330}],
  };
  zones.korrin_tower.portals = [{zone: 'kamu_lookout', x: 0, z: 30, y: 430, r: 40}];   // fly up past the tower's top
  ids.push('kamu_lookout');
  return ids;
}

// User request 2026-11-05: Rift Patrol post-game (docs/superpowers/specs/2026-11-05-rift-patrol-design.md).
// The Time Nexus: a floating sanctum outside time, the hub for timeline missions (reached through Rift Patrol only).
function timeNexus(zones) {
  zones.time_nexus = {
    name: 'Time Nexus', planet: 'Time Nexus', saga: 'Rift Patrol',
    terrain: {size: 240, spawn: {x: 0, z: -40}, platform: {radius: 70, height: 0}, killY: -60, ground: 'stone'},
    biome: {sky: {type: 'gradient', top: 0x141038, horizon: 0x6a3aa8, bottom: 0x0a0818, elevation: 60, azimuth: 200, sunColor: 0xc8b8ff, stars: true},
      fog: [0x1a1030, 0.0008], trees: 'none', treeCount: 0, rocks: 0, bushes: 0, stones: 0, grass: 0, clouds: false, sun: {intensity: 3.0}},
    landmarks: [{type: 'nexus', name: 'Time Nexus', x: 0, z: 10}],
    travelPoint: {x: 14, z: -40}, spawnYaw: 0,
  };
  // Echo Prison (Codex's Rift map): Warden Morrigath's prison world, walls and cell blocks round the arena
  if (zones.echo_prison) {
    zones.echo_prison.landmarks = [...zones.echo_prison.landmarks, {type: 'echoprison', name: 'Echo Prison', x: 0, z: 20}];
    zones.echo_prison.biome = {...zones.echo_prison.biome,
      sky: {type: 'gradient', top: 0x1a0f1e, horizon: 0x5a2a3a, bottom: 0x0f0a10, elevation: 25, azimuth: 240, sunColor: 0xff9a7a, stars: true},
      fog: [0x3a1a26, 0.0016]};
    return ['time_nexus', 'echo_prison'];
  }
  return ['time_nexus'];
}

// ---------------------------------------------------------------------------------------------------------------
// Zone patches, 0.0.8 map pass (integrator, 2026-11-11). Applies the builder batches' data requests
// (art/reference/map_data_requests*.md) to zones that come from the JS tables (web/src/data/zones.js) or were built
// above. Runs last, so towns/areas cloned from another zone's biome earlier keep their old values unless listed here.
// Every patched zone is deep-cloned first: the JS tables share objects between zones (namek / new_namek), and
// structuredClone keeps that sharing. Sky keys are merged into the existing `sky` dictionary (same as
// world/atmosphere.gd's old dev PREVIEW); other biome keys replace.
function mapPass008(zones) {
  const touched = new Set();
  const Z = id => {
    if (!zones[id]) throw new Error('map pass: missing zone ' + id);
    if (!touched.has(id)) { zones[id] = structuredClone(zones[id]); touched.add(id); }
    return zones[id];
  };
  const biome = (id, b) => {
    const z = Z(id);
    for (const [k, v] of Object.entries(b)) {
      if (k === 'sky') z.biome.sky = {...(z.biome.sky ?? {}), ...v};
      else if (k === 'tints') z.biome.tints = {...(z.biome.tints ?? {}), ...v};
      else z.biome[k] = v;
    }
  };
  // replace the first landmark of `type` (optionally the one at x,z) with new fields; keeps its name
  const swap = (id, type, fields, at = null) => {
    const z = Z(id);
    const i = z.landmarks.findIndex(l => l.type === type && (!at || (l.x === at[0] && l.z === at[1])));
    if (i < 0) throw new Error(`map pass: ${id} has no ${type} at ${at}`);
    const {x, z: lz, name, scale, collide, flatten} = z.landmarks[i];
    const out = {type: fields.type, x, z: lz, ...(name ? {name} : {}), ...(scale != null ? {scale} : {}),
      ...(collide != null ? {collide} : {}), ...(flatten != null ? {flatten} : {})};
    for (const [k, v] of Object.entries(fields)) if (v === undefined) delete out[k]; else out[k] = v;
    z.landmarks[i] = out;
  };
  const add = (id, ...ls) => Z(id).landmarks.push(...ls);
  const PI = 3.1416;

  // --- B5 sky / atmosphere / weather (map_data_requests.md) ----------------------------------------------------
  const NAMEK_SKY = {top: 0x3fa830, horizon: 0xc0e888, bodies: [
    {kind: 'sun', az: 200, el: 48, size: 2.6, color: 0xfff8d8},
    {kind: 'sun', az: 226, el: 30, size: 1.9, color: 0xfff2c0, light: 0.3},
    {kind: 'sun', az: 178, el: 22, size: 1.3, color: 0xffeeb0, light: 0.2}]};
  const FUTURE = {sky: {top: 0x60745a, horizon: 0xa8b89a, bottom: 0x4a5644, sunColor: 0xc8d0b0},
    fog: [0x94a48a, 0.0026], cloudColor: 0x76846e, cloudCoverage: 0.28, weather: {type: 'rain', density: 1.0}};
  const BEEROS = {sky: {top: 0xb25a80, horizon: 0xf6c49a, bottom: 0x5a3a52,
    nebula: {colors: [0xd0607a, 0xf8b890, 0xfff0d0], amount: 0.55, scale: 1.6},
    bodies: [{kind: 'bubble', az: 150, el: 26, size: 4.5, color: 0xf8e0b0, color2: 0xfff4e0},
      {kind: 'bubble', az: 250, el: 14, size: 3.2, color: 0xf0d0a8, color2: 0xffffff},
      {kind: 'bubble', az: 215, el: 40, size: 2.0, color: 0xf8e8c8, color2: 0xffffff}]}};
  const sky = {
    snake_way: {sky: {top: 0xe04cc4, horizon: 0xf6a8e0, bottom: 0xf2b840}, fog: [0xf2b0dc, 0.0014],
      cloudSea: {color: 0xf6c23a, y: -18}, cloudLayers: [{y: -70, color: 0xe89a20, coverage: 0.3, scale: 0.003, opacity: 0.95}]},
    king_kai: {sky: {top: 0xd84cc0, horizon: 0xf2a0da, bottom: 0xf0b040}, fog: [0xf0a8d8, 0.0018], cloudSea: {color: 0xf6c23a, y: -45}},
    kai_world: {sky: {zenith: 0x6c5cc8, horizon: 0xf2c8dc, bodies: [
      {kind: 'bubble', az: 170, el: 38, size: 6, color: 0xd8d0f8, color2: 0xffffff},
      {kind: 'bubble', az: 205, el: 22, size: 3.5, color: 0xe0d8ff, color2: 0xffffff},
      {kind: 'bubble', az: 228, el: 46, size: 4.5, color: 0xd0c8f0, color2: 0xffffff},
      {kind: 'bubble', az: 148, el: 18, size: 2.4, color: 0xe8e0ff, color2: 0xffffff},
      {kind: 'bubble', az: 250, el: 28, size: 2, color: 0xe0d8ff, color2: 0xffffff},
      {kind: 'bubble', az: 188, el: 56, size: 1.6, color: 0xe8e0ff, color2: 0xffffff}]}, cloudColor: 0xfff0ff},
    kae_shrine: {sky: {zenith: 0x6c5cc8, horizon: 0xf2c8dc}},
    namek: {sky: NAMEK_SKY, fog: [0xb8e0a0, 0.0009]}, new_namek: {sky: NAMEK_SKY, fog: [0xb8e0a0, 0.0009]},
    nameck_east: {sky: NAMEK_SKY}, nameck_south: {sky: NAMEK_SKY}, nameck_west: {sky: NAMEK_SKY},
    new_nameck_east: {sky: NAMEK_SKY}, new_nameck_south: {sky: NAMEK_SKY}, new_nameck_west: {sky: NAMEK_SKY},
    future_earth: FUTURE, future_ruins: FUTURE,
    world_of_void: {sky: {elevation: 30, sunHalo: false, nebula: {colors: [0x3a1650, 0xa8306e, 0x50e0a0], amount: 0.95, scale: 1.0},
      bodies: [{kind: 'eclipse', az: 200, el: 30, size: 13, color: 0xfff2dc, color2: 0x040306}]}},
    time_nexus: {sky: {top: 0x0e3036, horizon: 0x3cae86, nebula: {colors: [0x0c4a40, 0x3ccb8c, 0xe8f0a0], amount: 0.55, scale: 0.8},
      bodies: [{kind: 'moon', az: 160, el: 34, size: 4, color: 0xf0e0b0, color2: 0xc8b080},
        {kind: 'moon', az: 238, el: 20, size: 2.6, color: 0xf4ecd8, color2: 0xb8b0a0},
        {kind: 'moon', az: 196, el: 52, size: 1.6, color: 0xf0e0c0, color2: 0xc0a880}]}},
    echo_prison: {clouds: false, sky: {top: 0x0a1638, horizon: 0x2a5ab0, nebula: {colors: [0x0c2a6a, 0x3c8ce0, 0xc8f0ff], amount: 0.85, scale: 1.1},
      bodies: [{kind: 'planet', az: 228, el: 30, size: 9, color: 0xd04020, color2: 0xf09040},
        {kind: 'ringed', az: 244, el: 38, size: 5, color: 0xe0b850, color2: 0xd8b070, tilt: 0.28, roll: -18},
        {kind: 'planet', az: 236, el: 22, size: 5.5, color: 0x2a64c8, color2: 0xe8f0ff},
        {kind: 'moon', az: 214, el: 24, size: 3, color: 0x488060, color2: 0x203828}]}},
    beerus_planet: BEEROS, beeros_gardens: BEEROS,
    earth_plains: {cloudLayers: [{y: 260, color: 0xffffff, coverage: 0.52, scale: 0.0016, opacity: 0.9}], waterShallow: 0x3ad8cc, waterClarity: 6.0},
    mt_paozu: {cloudLayers: [{y: 18, mist: true, color: 0xf4f8ff, coverage: 0.42, scale: 0.004},
      {y: 230, color: 0xffffff, coverage: 0.55, scale: 0.0016, opacity: 0.9}]},
    korrin_tower: {cloudLayers: [{y: 22, mist: true, color: 0xf4f8ff, coverage: 0.45, scale: 0.004},
      {y: 260, color: 0xffffff, coverage: 0.5, scale: 0.0016, opacity: 0.9}]},
    muscle_tower: {weather: {type: 'snow', density: 0.5}, cloudLayers: [{y: 40, mist: true, color: 0xe8f4f8, coverage: 0.4, scale: 0.004}]},
    broly_glacier: {weather: {type: 'snow', density: 0.8}},
    snowpeak_village: {weather: {type: 'snow', density: 0.5}},
    gizard_wasteland: {weather: {type: 'dust', density: 0.6},
      cloudLayers: [{y: 12, mist: true, color: 0xe8dcc8, coverage: 0.48, scale: 0.004, opacity: 0.4}]},
    pilav_castle: {weather: {type: 'dust', density: 1.0}},
    fire_mountain: {weather: {type: 'embers', density: 1.0}},
    kamu_lookout: {cloudSea: {color: 0xffffff, y: -60}},   // B1 audit 041: clouds below the platform, like the Lookout
  };
  for (const [id, b] of Object.entries(sky)) if (zones[id]) biome(id, b);

  // --- B1 Origins leftover (map_data_requests_origins.md) --------------------------------------------------------
  swap('kame_island', 'kamehouse', {type: 'kamecottage', rot: PI, collide: 5, flatten: 12});

  // --- B2 Z-era Earth (map_data_requests_earth.md) ---------------------------------------------------------------
  swap('cell_games', 'cellarena', {type: 'cellring', flatten: 40});
  swap('west_city', 'capsulecorp', {type: 'capsulehq', rot: PI, collide: 17, flatten: 34});
  for (const l of Z('west_city').landmarks) if (l.type === 'dome') Object.assign(l, {type: 'capsulehouse', rot: PI, collide: 7, flatten: 10});
  add('west_city', {type: 'town', name: 'West Capital', x: 0, z: -165, style: 'city', radius: 90, seed: 23, flatten: 90},
    {type: 'town', name: 'West Capital west', x: -165, z: 60, style: 'city', radius: 85, seed: 29, flatten: 85});
  swap('htc', 'htcroom', {type: 'htcpalace', z: 16, rot: PI, collide: 8});
  swap('babidi_ship', 'babidiship', {type: 'babidihatch', rot: PI, collide: 20, flatten: 40});
  swap('red_ribbon', 'hangar', {type: 'rrhangar', rot: PI, collide: 16, flatten: 30}, [0, 20]);
  swap('red_ribbon', 'hangar', {type: 'rrhangar', rot: 1.5708, collide: 10, flatten: 18}, [-50, -10]);
  add('red_ribbon', {type: 'rrtower', name: 'Crimson Ribbon tower', x: -70, z: 60, rot: 0.4, collide: 11, flatten: 26},
    {type: 'archbridge', x: -70, z: 15, rot: 1.5708});
  swap('future_earth', 'ruin', {type: 'brokentower', scale: 1.2, collide: 8, flatten: 16}, [-40, 30]);
  swap('future_earth', 'ruin', {type: 'brokentower', scale: 1.4, collide: 9, flatten: 18}, [70, 10]);
  // the old collide-12 ruin at (10,100) swallowed Goku Black (10,90) and the m31 quest point (16,90): moved away
  swap('future_earth', 'ruin', {type: 'brokentower', x: -20, z: 130, scale: 1.6, collide: 10, flatten: 20}, [10, 100]);
  swap('gero_lab', 'ruin', {type: 'gingertower', z: -88, collide: 5.5, flatten: 26}, [-60, -80]);
  swap('gero_lab', 'ruin', {type: 'gingerhouse', scale: undefined, rot: 1.2, collide: 8, flatten: 18}, [-84, -62]);
  add('gero_lab', {type: 'gingerhouse', x: -40, z: -96, scale: 0.9, rot: -0.5, collide: 7, flatten: 16});
  swap('papaya_island', 'budokai', {type: 'budokaihall', flatten: 50});
  add('broly_glacier', {type: 'seracs', x: -60, z: 40, rot: 0.3, collide: 9},
    {type: 'seracs', x: 140, z: -10, scale: 1.3, rot: 2.2, collide: 11}, {type: 'seracs', x: -20, z: 170, scale: 1.5, rot: 3.6, collide: 13});
  add('amber_city', {type: 'herostatue', name: "Champion's statue", x: 18, z: 18, rot: -2.36, collide: 4});
  add('gizard_wasteland', {type: 'crater', name: 'Saiyar pod', x: 40, z: 40, dig: {radius: 9, depth: 2.6}},
    {type: 'crater', name: 'Saiyar pod', x: 58, z: 52, dig: {radius: 9, depth: 2.6}});

  // --- B3 Other World & divine (map_data_requests_divine.md) -----------------------------------------------------
  // snake_way: checkinhall / kaiorb are set in checkInStation above
  Z('snake_way').terrain.path = {...zones.snake_way.terrain.path, serpent: true};
  zones.snake_way.landmarks = zones.snake_way.landmarks.filter(l => l.type !== 'snakehead');
  add('snake_way', {type: 'serpenthead', name: 'Serpent Road gate', x: 38, z: -392},
    {type: 'serpentcoils', x: -110, z: -260, alt: 6}, {type: 'serpentcoils', x: 90, z: 20, alt: 4, span: 180},
    {type: 'serpentcoils', x: -120, z: 260, alt: 8, loops: 2});
  add('king_kai', {type: 'kaiband', x: 0, z: 0});
  Z('king_kai').terrain.planetoid = {...zones.king_kai.terrain.planetoid, road: 6.4};   // the white road is painted on the terrain (rules surface_at), not a floating strip
  add('world_of_void', {type: 'toparena', x: 0, z: 0});
  // beerus_planet: NOT the floating-platform terrain (it is a region of the 1600 m beeros planet map, where the
  // platform's void would become a 290 m pit); the temple + great tree stand on the existing ground instead.
  swap('beerus_planet', 'pyramid', {type: 'beeruscastle', collide: 10, flatten: 30});
  add('beerus_planet', {type: 'godtree', name: 'The great tree', x: -45, z: 60, collide: 4});
  // nameless_planet: B3's arena set (u6arena + Gods' box + 6 cup stands); B4's `floatcups` would sit on the
  // same arc as the Gods' box and the cup stands, so it is left out
  swap('nameless_planet', 'cellarena', {type: 'u6arena'});
  zones.nameless_planet.landmarks = zones.nameless_planet.landmarks.filter(l => l.type !== 'stands');
  add('nameless_planet', {type: 'shieldbox', name: "Gods' box", x: 0, z: 58, rot: PI},
    ...[[-50, 40], [50, 40], [-62, -5], [62, -5], [-48, -50], [48, -50]].map(([x, z], k) => ({type: 'cupstand', x, z, top: k % 2 ? 'seats' : 'dome'})));
  biome('nameless_planet', {tints: {dirt: [1.25, 0.55, 0.62]}, fog: [0xe8a0a8, 0.0011]});

  // --- B4 alien planets (map_data_requests_alien.md) -------------------------------------------------------------
  const NAMEK_GRASS = {root: 0x1a3f8a, tip: 0x49b4e6, dry: 0x8acfe0, forest: 0x1d4f96};
  biome('namek', {trees: 'ajisa_tall', grassColors: NAMEK_GRASS, tints: {rock: [1.15, 0.82, 0.95]}});
  swap('namek', 'namekhouse', {type: 'namekdome', rot: 0.6, collide: 4.5, flatten: 8}, [-20, 22]);
  swap('namek', 'namekhouse', {type: 'namekdome', rot: 1.2, collide: 4, flatten: 7}, [-34, 8]);
  swap('namek', 'namekhouse', {type: 'namekdome', rot: 0.1, collide: 4, flatten: 7}, [-8, 38]);
  swap('namek', 'gurutower', {type: 'elderspire'});
  swap('namek', 'friezaship', {type: 'tyrantship', collide: 15, flatten: 28});
  // new_namek: its own layout instead of a copy of namek (audit 142)
  const nn = Z('new_namek');
  nn.terrain = {size: nn.terrain.size, spawn: {x: 0, z: 0}, hills: {amp: 6, scale: 110}, lake: {x: -40, z: 60, radius: 55, level: 0.4},
    edge: 'mountains', mesas: [{x: 150, z: -60, r: 10, h: 46}, {x: -170, z: -120, r: 8, h: 36}, {x: 200, z: 160, r: 12, h: 58}, {x: -220, z: 150, r: 9, h: 40}]};
  biome('new_namek', {trees: 'ajisa_tall', treeCount: 200, grassColors: NAMEK_GRASS, tints: {rock: [1.15, 0.82, 0.95]}, bushes: 120, rocks: 100, water: 0x2aa79b});
  nn.landmarks = [{type: 'namekvillage', name: 'New Nameck village', x: 30, z: -20, count: 3, flatten: 16},
    {type: 'namekdome', x: -10, z: 0, collide: 4.5, flatten: 8}, {type: 'elderspire', name: "Elder's house", x: 150, z: -60}];
  nn.travelPoint = {x: 20, z: -45};
  biome('planet_cereal', {trees: 'purple_spire', treeCount: 520, tints: {rock: [1.25, 1.1, 0.85]}});
  swap('planet_cereal', 'farmhouse', {type: 'cerealhut', rot: 1.57, collide: 5, flatten: 14});
  add('planet_cereal', {type: 'heetersship', name: "Elek's landing ship", x: 70, z: -30, rot: -0.4, flatten: 26, collide: 14});
  biome('grain_market', {trees: 'purple_spire'});
  // yardrat: the two huts become a village, centred 18 m further north than asked so no hut lands on the
  // villagers standing at (-12,14) / (-24,26) / (8,22)
  Z('yardrat').landmarks = zones.yardrat.landmarks.filter(l => l.type !== 'yardrathut');
  add('yardrat', {type: 'yardratvillage', name: 'Yardran village', x: -10, z: 42, huts: 4, flatten: 18});
  return [...touched];
}

export function applyGodotAdditions(tables) {
  const zones = structuredClone(tables.zones);
  const npcs = structuredClone(tables.npcs);
  const characters = structuredClone(tables.characters);
  const appearance = structuredClone(tables.appearance);
  const races = structuredClone(tables.races);
  const form_looks = structuredClone(tables.form_looks);   // Godot-only form looks (cast batches add/fix entries below)
  const zoneOrder = [...tables.zone_order];
  const world = openWorld(zones, zoneOrder);
  const childhood = childhoodPlaces(zones);
  for (const id of childhood) if (!zoneOrder.includes(id)) zoneOrder.push(id);
  const changed = [...checkInStation(zones, npcs), ...interiors(zones), ...childhood, ...timeNexus(zones)];
  changed.push(...mapPass008(zones));   // 0.0.8 map pass: builder batches' zone data (see mapPass008)
  // giant, seated behind the desk: red skin, black beard, judge's hat (Parts.costume "yemmo")
  Object.assign(characters.king_yemma, {scale: 4.2, look: {race: 'Human', skin: 0, skinHex: 0xc8463c, face: 'Fierce', hair: 'None',
    hairColor: 0, build: 'Muscular', outfit: 'CraneGi', outfitTint: 2, costume: 'yemmo'}});
  // Presentation rebuild 2026-11-04: named fighters get their own body shape (BodySculpt.NAMED, by look.physique)
  const physiques = {goku: 'gokan', vegeta: 'vegara', majin_vegeta: 'vegara', piccolo: 'piccor', nappa: 'nappo', krillin: 'krilan',
    roshi: 'roshu', frieza: 'frigor', golden_frieza: 'frigor', mecha_frieza: 'frigor', recoome: 'recume', android_16: 'cyborg16',
    king_cold: 'kold', fat_buu: 'boo_fat', kid_buu: 'boo_kid', goku_black: 'gokan', broly: 'brolo', jiren: 'jiran', toppo: 'toppa',
    dodoria: 'dodorra', zarbon: 'zarvon', gohan: 'gohin', trunks: 'tronks', android_17: 'cyborg_slim', android_18: 'cyborg_slim',
    cell: 'cel', tien: 'tenzo', yamcha: 'yamcho', dabura: 'dabora', hit: 'hitto', beerus: 'beeros', whis: 'wiss', mr_satan: 'sadan',
    kefla: 'kafla', paragus: 'paragos', gamma1: 'gama', gamma2: 'gama', moro: 'morro', black_frieza: 'frigor', super_buu: 'boo_kid',
    raditz: 'gokan', cabba: 'tronks'};
  for (const [id, physique] of Object.entries(physiques)) if (characters[id]?.look) characters[id].look.physique = physique;
  // Cel-shaded cloth style (user request 2026-11-10): Gokan only until the custom model arrives
  if (characters.goku?.look) characters.goku.look.shading = 'cel';
  // Female fighters (user request 2026-11-04): two new hair styles for the races with hair
  for (const id of ['Long', 'Bun']) if (!appearance.HAIR_STYLES.some(h => h.id === id)) appearance.HAIR_STYLES.push({id, name: id});
  for (const r of ['Saiyan', 'HalfSaiyan', 'Human']) for (const id of ['Ponytail', 'Long', 'Bun']) if (!races[r].hairStyles.includes(id)) races[r].hairStyles.push(id);
  // Origins looks (Claude, 2026-11-05): each childhood character gets its own silhouette, colours and costume.
  // tint: 0 orange 1 blue 2 purple 3 black 4 white 5 red 6 green; hairColor: 0 black 1 brown 2 lilac 3 blond 4 red 5 white
  const origins = {
    goku_kid: [{race: 'Saiyan', age: 'child', build: 'Average', hair: 'Spiky', outfit: 'TurtleGi', outfitTint: 1, costume: 'powerpole'}, 0.62],
    krillin_kid: [{race: 'Human', age: 'child', build: 'Average', hair: 'None', outfit: 'TurtleGi', outfitTint: 0}, 0.6],
    oolong: [{race: 'Human', build: 'Short', hair: 'None', skinHex: 0xeaa2b4, outfit: 'TurtleGi', outfitTint: 6, sculpt: {belly: 0.05, head_w: 1.12, soft: 0.008}}, 0.68],
    puar: [{race: 'Human', build: 'Slim', hair: 'None', skinHex: 0x8ac4ee, outfit: 'TurtleGi', outfitTint: 4, sculpt: {head_w: 1.15, head_h: 1.1}}, 0.5],
    yamcha_young: [{race: 'Human', age: 'teen', build: 'Slim', hair: 'LongSpiky', outfit: 'CraneGi', outfitTint: 6, physique: 'yamcho'}, 0.95],
    ox_king: [{race: 'Human', build: 'Muscular', hair: 'None', outfit: 'SaiyanArmor', outfitTint: 2, costume: 'oxhelmet', physique: 'sadan', sculpt: {belly: 0.06}}, 2.2],
    pilaf: [{race: 'Human', build: 'Short', hair: 'None', skinHex: 0x7aaee0, outfit: 'CapsuleCorp', outfitTint: 3, sculpt: {head_w: 1.12, head_h: 1.06}}, 0.6],
    shu: [{race: 'Human', build: 'Slim', hair: 'None', skinHex: 0x6a7090, outfit: 'CraneGi', outfitTint: 2}, 0.8],
    jackie_chun: [{race: 'Human', build: 'Average', hair: 'Wild', hairColor: 5, outfit: 'CraneGi', outfitTint: 1, physique: 'yamcho'}, 0.92],
    giran: [{race: 'FrostDemon', build: 'Muscular', skinHex: 0x5aa04a, outfit: 'SaiyanArmor', outfitTint: 6, physique: 'kold'}, 1.55],
    nam: [{race: 'Human', build: 'Muscular', hair: 'None', outfit: 'CraneGi', outfitTint: 4, physique: 'tenzo'}, 1.0],
    silver: [{race: 'Human', build: 'Muscular', hair: 'Short', hairColor: 5, outfit: 'SaiyanArmor', outfitTint: 3}, 1.0],
    white: [{race: 'Human', build: 'Tall', hair: 'None', outfit: 'SaiyanArmor', outfitTint: 4, physique: 'zarvon'}, 1.0],
    murasaki: [{race: 'Human', build: 'Short', hair: 'None', outfit: 'CraneGi', outfitTint: 2}, 0.85],
    android_8: [{race: 'Human', build: 'Tall', hair: 'Short', skinHex: 0xd8b890, outfit: 'SaiyanArmor', outfitTint: 6, physique: 'cyborg16'}, 2.1],
    blue: [{race: 'Human', build: 'Average', hair: 'Short', hairColor: 3, outfit: 'SaiyanArmor', outfitTint: 1, physique: 'tronks'}, 1.0],
    tao: [{race: 'Human', build: 'Muscular', hair: 'None', outfit: 'CraneGi', outfitTint: 4, costume: 'braid', physique: 'tenzo'}, 1.0],
    tao_cyborg: [{race: 'Human', build: 'Muscular', hair: 'None', skinHex: 0xc8ccd4, outfit: 'SaiyanArmor', outfitTint: 3, costume: 'braid', physique: 'cyborg16'}, 1.05],
    red: [{race: 'Human', build: 'Short', hair: 'Short', hairColor: 4, outfit: 'SaiyanArmor', outfitTint: 5}, 0.7],
    baba: [{race: 'Human', build: 'Short', hair: 'None', female: true, skinHex: 0xf4dcc8, outfit: 'CraneGi', outfitTint: 2, costume: 'witchhat'}, 0.7],
    grandpa_gohan: [{race: 'Human', build: 'Short', hair: 'None', outfit: 'CraneGi', outfitTint: 6, physique: 'roshu'}, 0.85],
    tien_young: [{race: 'Human', age: 'teen', build: 'Average', hair: 'None', outfit: 'CraneGi', outfitTint: 6, physique: 'tenzo'}, 1.0],
    chiaotzu: [{race: 'Human', age: 'child', build: 'Average', hair: 'None', skinHex: 0xf6eceb, outfit: 'CraneGi', outfitTint: 0, sculpt: {head_w: 1.12, head_h: 1.06}}, 0.55],
    tambourine: [{race: 'Namekian', build: 'Slim', outfit: 'NamekRobe', outfitTint: 3, skinHex: 0x6aa860, physique: 'cel'}, 1.05],
    cymbal: [{race: 'Namekian', build: 'Muscular', outfit: 'NamekRobe', outfitTint: 6, skinHex: 0x4a8a44}, 1.2],
    drum: [{race: 'Namekian', build: 'Muscular', outfit: 'NamekRobe', outfitTint: 2, skinHex: 0x7a9a4a, physique: 'brolo'}, 1.5],
    king_piccolo: [{race: 'Namekian', build: 'Tall', outfit: 'NamekRobe', outfitTint: 3, physique: 'piccor', sculpt: {neck: 0.9, shoulders: 0.94}}, 1.45],
    korin: [{race: 'Human', build: 'Slim', hair: 'None', skinHex: 0xf2ece0, outfit: 'CraneGi', outfitTint: 4, sculpt: {head_w: 1.1}}, 0.6],
    yajirobe: [{race: 'Human', build: 'Muscular', hair: 'Wild', outfit: 'CraneGi', outfitTint: 1, sculpt: {belly: 0.07, waist: 1.25, hips: 1.15}}, 0.9],
    piccolo_jr: [{race: 'Namekian', build: 'Tall', outfit: 'NamekRobe', outfitTint: 2, physique: 'piccor'}, 1.0],
    pilav_robot: [{race: 'Human', build: 'Muscular', hair: 'None', skinHex: 0x8a96a8, outfit: 'SaiyanArmor', outfitTint: 3, physique: 'cyborg16'}, 1.9],
    baaba_fangs: [{race: 'Human', build: 'Slim', hair: 'Swept', hairColor: 3, skinHex: 0xb8c0d0, outfit: 'CraneGi', outfitTint: 3}, 1.0],
    baaba_invisible: [{race: 'Human', build: 'Average', hair: 'None', skinHex: 0xe8f0f8, outfit: 'TurtleGi', outfitTint: 4}, 1.0],
    baaba_mummy: [{race: 'Human', build: 'Muscular', hair: 'None', skinHex: 0xe4dcc4, outfit: 'TurtleGi', outfitTint: 4, physique: 'recume'}, 1.4],
    baaba_devil: [{race: 'Majin', build: 'Average', outfit: 'FrostArmor', outfitTint: 5, skinHex: 0x5a8ad0}, 1.05],
  };
  // Rift Patrol villains (Claude, 2026-11-05; rows come from Codex): all-original designs
  Object.assign(origins, {
    vael: [{race: 'Human', build: 'Slim', hair: 'Swept', hairColor: 5, skinHex: 0xd8d4e0, outfit: 'AngelRobe', outfitTint: 1, costume: 'vael', physique: 'hitto'}, 1.05],
    shardling: [{race: 'Majin', build: 'Short', skinHex: 0x6ad8f0, outfit: 'FrostArmor', outfitTint: 1, sculpt: {head_w: 1.15}}, 0.7],
    morrigath: [{race: 'Human', build: 'Muscular', hair: 'None', skinHex: 0x8a8090, outfit: 'SaiyanArmor', outfitTint: 3, costume: 'morrigath', physique: 'recume'}, 1.5],
    nyxara: [{race: 'FrostDemon', build: 'Tall', female: true, skinHex: 0x2a2440, outfit: 'AngelRobe', outfitTint: 2, costume: 'nyxara'}, 1.15],
    hollow_gokan: [{race: 'Saiyan', build: 'Muscular', hair: 'Spiky', hairColor: 0, skinHex: 0x3a3448, outfit: 'TurtleGi', outfitTint: 3, costume: 'hollow', physique: 'gokan'}, 1.0],
    hollow_vegara: [{race: 'Saiyan', build: 'Average', hair: 'LongSpiky', hairColor: 0, skinHex: 0x3a3448, outfit: 'SaiyanArmor', outfitTint: 3, costume: 'hollow', physique: 'vegara'}, 0.95],
    hollow_piccor: [{race: 'Namekian', build: 'Tall', skinHex: 0x2a3a2a, outfit: 'NamekRobe', outfitTint: 3, costume: 'hollow', physique: 'piccor'}, 1.0],
    zero_origin: [{race: 'Human', build: 'Tall', hair: 'None', skinHex: 0xf4ecd8, outfit: 'AngelRobe', outfitTint: 4, costume: 'zero', physique: 'cyborg16'}, 2.4],
    archivist_tem: [{race: 'Human', build: 'Slim', hair: 'Long', female: true, hairColor: 5, outfit: 'AngelRobe', outfitTint: 1}, 1.0],
  });
  origins.bulma_young = [{...(characters.bulma_young?.look ?? {race: 'Human', female: true, outfit: 'CapsuleCorp'}), age: 'teen', build: 'Slim', hair: 'Ponytail', hairColor: 2, outfitTint: 5}, 0.92];
  for (const [id, [look, scale]] of Object.entries(origins)) {
    if (!characters[id]) continue;
    characters[id].look = {...characters[id].look, ...look};
    characters[id].scale = scale;
  }
  // Cast batch B1 (Claude, 2026-11-10; art/reference/cast_audit.md): Kais, angels, gods and aliens. Uses the
  // per-look fields documented at the top of godot/characters/outfits.gd (race-part toggles, hairAnyRace, hairRgb,
  // eyeRgb, outfitRgb/outfitRgb2/outfitParts, costume arrays). Races stay as they were (forms/rules use them).
  const WHITE_HAIR = 0xf2f2f4, DARK_EYES = 0x2a1d14, KAI = {raceParts: false, ears: 'pointed', eyeRgb: DARK_EYES, hairAnyRace: true};
  const ANGEL = {raceParts: false, hairAnyRace: true, hair: 'AngelCrest', hairRgb: WHITE_HAIR, eyeRgb: 0x5a3a8a, costume: ['halo']};
  const b1 = {
    supreme_kai: {...KAI, hair: 'Mohawk', hairRgb: WHITE_HAIR, outfit: 'AngelRobe', outfitRgb: 0x2a9e9a, outfitRgb2: 0xe0552a, outfitParts: {shoes: 0xc8322a}, costume: ['potara']},
    elder_kai: {...KAI, hair: 'Mohawk', hairRgb: WHITE_HAIR, outfit: 'AngelRobe', outfitRgb: 0xc8322a, outfitRgb2: 0xe88a2a, outfitParts: {shoes: 0x2a9e9a}, costume: ['potara']},
    kibito: {...KAI, hair: 'Long', hairRgb: WHITE_HAIR, outfit: 'AngelRobe', outfitRgb: 0xc8322a, outfitRgb2: 0xe88a2a, outfitParts: {pants: 0x2a9e9a, shoes: 0xd8b04a}},
    zamasu: {...KAI, hair: 'Mohawk', hairRgb: WHITE_HAIR, outfit: 'AngelRobe', outfitRgb: 0x2c2a3c, outfitRgb2: 0x7a3aa8, outfitParts: {shoes: 0xf2f2f2}, costume: ['potara_green']},
    whis: {...ANGEL, outfit: 'AngelRobe', outfitRgb: 0x7a1e3a, outfitParts: {plate: 0x18181c, trim: 0xe88a2a}},
    vados: {...ANGEL, outfit: 'AngelRobe', outfitRgb: 0x1e5a58, outfitParts: {plate: 0x18181c, trim: 0xe88a2a}},
    grand_priest: {...ANGEL, eyeRgb: DARK_EYES, outfit: 'AngelRobe', outfitRgb: 0x3a7ab8, outfitRgb2: 0xc8322a},
    merus: {raceParts: false, hairAnyRace: true, hair: 'Short', hairRgb: WHITE_HAIR, eyeRgb: DARK_EYES, outfit: 'SaiyanSuit', outfitRgb: 0x3a54b0, outfitParts: {sash: 0xf2f2f2}},
    beerus: {raceParts: false, tail: 'cat', eyeRgb: 0xe8c030, costume: ['cat_ears'], outfit: 'AngelRobe', outfitRgb: 0x1a1a1e, outfitParts: {pants: 0x2a9e9a, wrist: 0xd8b04a}},
    champa: {raceParts: false, tail: 'cat', eyeRgb: 0xe8c030, costume: ['cat_ears'], outfit: 'AngelRobe', outfitRgb: 0x1a1a1e, outfitParts: {pants: 0xd8542a, wrist: 0xd8b04a}},
    king_kai: {raceParts: false, antenna: 'long', eyeRgb: DARK_EYES, costume: ['shades'], outfit: 'AngelRobe', outfitRgb: 0x1a1a1e, outfitRgb2: 0xc8324a},
    zeno: {raceParts: false, skinHex: 0xe8eaf2, eyeRgb: 0x101014, outfit: 'AngelRobe', outfitRgb: 0xd0408a, outfitParts: {collar: false, shoes: 0xe8c840}},
    hit: {raceParts: false, eyeRgb: 0xc81e1e, outfit: 'AngelRobe', outfitRgb: 0x3a3a46, outfitRgb2: 0x1a1a1a, outfitParts: {collar: false}},
    jiren: {raceParts: false, eyeRgb: 0x050505},
    gas: {raceParts: false, ears: 'pointed', hairAnyRace: true, hair: 'Dreadlocks', hairRgb: 0x4a2a6a, skinHex: 0x4fa8b0, eyeRgb: DARK_EYES,
      outfit: 'AngelRobe', outfitRgb: 0xb8202a, outfitRgb2: 0xd8b04a, outfitParts: {pants: 0xf2f0ea}},
    mr_popo: {raceParts: false, eyeRgb: DARK_EYES, costume: ['turban'], outfit: 'MajinVest', outfitParts: {top: 0xc8322a, pants: 0xf2f0ea, shoes: 0xc8322a, sash: 0xc8322a, wrist: false}},
    yardrat: {raceParts: false, skinHex: 0xf0c8c8, eyeRgb: DARK_EYES},
    yardrat_elder: {raceParts: false, skinHex: 0xe8c0c4, eyeRgb: DARK_EYES},
    magetta: {raceParts: false, skinHex: 0x7a8aa0, eyeRgb: 0xff8a1a},
    botamo: {raceParts: false, skinHex: 0xe8c040, outfitParts: {top: 0xc8322a, wrist: false}},
    saganbo: {raceParts: false},
    moro: {raceParts: false, skinHex: 0x8a9ab0, costume: ['ramhorns'], outfitParts: {pants: 0x5a3a7a, shoes: 0x1a1a1a, plate: 0xe8e4d8}},
    granolah: {hairRgb: 0x6ad8c0, outfit: 'CapsuleCorp', outfitRgb: 0x3a6a3a, outfitParts: {pants: 0x3a5a3a, shoes: 0x6a4a2a, gloves: 0x6a4a2a}},
    cheelai: {raceParts: false, hairAnyRace: true, hair: 'Short', hairRgb: WHITE_HAIR, eyeRgb: 0xc81e1e, outfitParts: {top: 0x5a2a7a, pants: 0x5a2a7a}},
  };
  for (const [id, look] of Object.entries(b1)) if (characters[id]?.look) characters[id].look = {...characters[id].look, ...look};
  // Cast batch B2 (Claude, 2026-11-10; cast_audit.md): Saiyans, fusions and their forms. Adults lose the tail; outfits
  // recoloured with outfitRgb/outfitParts; look.formLooks points a form at the character's own form_looks variant and
  // look.form draws an NPC in a form by default (Fighter.set_form; fields at the top of godot/characters/outfits.gd).
  {
    const FL = form_looks, GOLD = 0xffc81e, SSJ_EYES = 0x1fa98f, WHITE = 0xf2f2f2, GOLDTRIM = 0xd8b04a;
    // colour fixes on shared entries (audit "Colour mismatches")
    FL.SSJRage = {...FL.SSJRage, aura: {...FL.SSJRage.aura, color: GOLD, core: 0xfff2b0}};   // gold aura, blue sparks stay
    FL.FalseSSJ = {...FL.FalseSSJ, hair: {...FL.FalseSSJ.hair, color: 0x8a4a1c, glow: 0.08}, aura: {...FL.FalseSSJ.aura, color: 0xffb21e, core: 0xfff0b0}};
    FL.SSJ4 = {...FL.SSJ4, fur: 0xa72437};
    // new looks: per-character variants (via look.formLooks) and story forms that have no playable form yet
    Object.assign(FL, {
      SSJ4Gogeta: {...FL.SSJ4, hair: {style: 'ssj4', color: 0x3a0e12, glow: 0.05}, eyes: 0x2a9ad8, fur: 0xc8202a},
      SSJ4Daima: {...FL.SSJ4, hair: {style: 'ssj4', color: 0xc8283a, glow: 0.1}, fur: 0xb0243a},
      SSJBroly: {...FL.SSJ, aura: {...FL.SSJ.aura, color: 0x9ae03a, core: 0xf0ffc8}},
      SSJRestrained: {hair: {style: 'ssj1', color: 0x7a9ad8, glow: 0.2}, eyes: 0xe8f0f8, scale: 1.05,
        aura: {color: 0xffd23a, core: 0xfff4c8, size: 1.1, flicker: 0.8, sparks: 0}},
      Wrathful: {hair: {style: 'same', color: 0x141414, glow: 0.0}, eyes: 0xc8ffb0, bulk: [1.2, 1.04, 1.15],
        aura: {color: 0x3ad84a, core: 0xd8ffd0, size: 1.15, flicker: 1, sparks: 1, sparkColor: 0xc8ffd0}},
      SSJKefla: {hair: {style: 'ssj1', color: 0x4cc83a, glow: 0.3}, eyes: 0x2aa8d0,
        aura: {color: 0x3ad84a, core: 0xd8ffc8, size: 1.05, flicker: 0.9, sparks: 0}},
      SSJRose: {hair: {style: 'ssj1', color: 0xf0609a, glow: 0.3}, eyes: 0x9a9aa8,
        aura: {color: 0xff4ab0, core: 0xffd8ec, size: 1.1, flicker: 0.6, sparks: 0, motes: 0xffc8e8}},
      SSJBlueKaioken: {...FL.SSJBlue, flush: [0xe02a1e, 0.3],
        aura: {color: 0xff2a1e, core: 0x8ad8ff, size: 1.15, flicker: 1, sparks: 1, sparkColor: 0xc8f0ff}},
      SSJBlueEvolved: {hair: {style: 'ssj2', color: 0x1a6ad8, glow: 0.3}, eyes: 0x1a5ad0, scale: 1.04,
        aura: {color: 0x1a6aff, core: 0xc0e4ff, size: 1.15, flicker: 0.9, sparks: 1, sparkColor: 0xa8d8ff, motes: 0xa0d0ff}},
      SuperKaioken: {...FL.SSJ, flush: [0xe02a1e, 0.3], aura: {color: 0xff3a1e, core: 0xffd890, size: 1.1, flicker: 1, sparks: 1, sparkColor: 0xffc8a0}},
      SSJ2Majin: {...FL.SSJ2, aura: {...FL.SSJ2.aura, sparks: 2, sparkColor: 0x2a1a10}},   // dark veins through the gold
      JirenFullPower: {hair: null, eyes: null, scale: 1.05,
        aura: {color: 0xff2a2a, core: 0xffc0b0, size: 1.15, flicker: 0.9, sparks: 1, sparkColor: 0xff9a8a}},
      ToppoGoD: {hair: null, eyes: 0xf4e8f8, skin: 0x4a2a3a, scale: 1.08,
        aura: {color: 0xc040ff, core: 0xff8ad8, size: 1.2, flicker: 1, sparks: 1, sparkColor: 0xff7ad8}},
    });
    // the two fusions (names from names.js: Gogeto, Vegitto)
    characters.gogeta = {name: 'Gogeto', scale: 1.02, style: 'turtle', look: {race: 'Saiyan', skin: 0, face: 'Smirk', hair: 'Spiky', hairColor: 0,
      build: 'Muscular', physique: 'gokan', outfit: 'MajinVest'}};
    characters.vegito = {name: 'Vegitto', scale: 1.02, style: 'speedster', look: {race: 'Saiyan', skin: 0, face: 'Smirk', hair: 'Swept', hairColor: 0,
      build: 'Muscular', physique: 'gokan', outfit: 'TurtleGi'}};
    // Metamoran vest: dark vest with gold shoulder pads, white baggy pants, teal sash and boots, dark wristbands
    const METAMORAN = {outfit: 'MajinVest', outfitParts: {top: 0x24242c, plate: 0x24242c, trim: 0xe0d050, pads: true, pants: 0xeeeef0,
      sash: 0x1e7a9a, wrist: 0x2a2a30, shoes: 0x2a2a30, boot_trim: 0x1e7a9a}};
    const DBS_ARMOR = {pads: false, trim: GOLDTRIM, gloves: WHITE, shoes: WHITE, boot_trim: GOLDTRIM};
    const b2 = {
      goku: {tail: false},
      goku_kid: {outfitParts: {wrist: 0xc8322a, sash: WHITE}},
      vegeta: {tail: false, outfitParts: DBS_ARMOR},
      majin_vegeta: {tail: false, form: 'SSJ2', formLooks: {SSJ2: 'SSJ2Majin'}, outfitParts: {...DBS_ARMOR, plate: 0xf4f2ea}},
      goku_black: {tail: false, costume: ['potara_green'], formLooks: {SSJBlue: 'SSJRose'}, outfitRgb: 0x2c2c34,
        outfitParts: {undershirt: 0x5a5a64, sash: 0xb8202a, wrist: false, shoes: WHITE, boot_trim: 0x5a5a64}},
      broly: {tail: false, formLooks: {SSJ: 'SSJBroly'},   // shirtless (top shows the skin), green waist cloth (collar torus sat on the chest: left out)
        outfitParts: {top: 'skin', sleeves: false, gloves: false, pants: 0x26262c, sash: 0x2e7a3a, wrist: 0x3a54b0, shoes: 0xe8e8e8, boot_trim: 0x26262c}},
      paragus: {tail: false, outfitParts: {cape: WHITE}},
      cabba: {tail: false, outfitParts: {top: 0x1c2a5c, pants: 0x1c2a5c, plate: 0x2a3a7a, trim: 0x1c2a5c, pads: false, sash: 0x6a3a8a, shoes: WHITE}},
      kefla: {tail: false, costume: ['potara'], formLooks: {SSJ: 'SSJKefla'}, eyeRgb: 0x2a1d14, outfit: 'CraneGi',
        outfitParts: {top: 0xc8306a, pants: 0xa82a5c, sash: 0xa82a5c, wrist: 0xe8c840, shoes: 0x2a2a30, cloth: 0.5}},
      gotenks: {...METAMORAN, hairRgb: 0x3a2a48, eyeRgb: 0x1fa98f},
      gogeta: {tail: false, ...METAMORAN, formLooks: {SSJ4: 'SSJ4Gogeta'}},
      vegito: {tail: false, costume: ['potara'], outfitRgb: 0x1e2a6a,
        outfitParts: {undershirt: 0xe86a1a, sash: 0x1e2a6a, wrist: false, gloves: WHITE, shoes: WHITE, boot_trim: GOLDTRIM}},
      trunks: {eyeRgb: 0x3a7ad0, outfitParts: {pants: 0x3a3a42, shoes: 0xc89a3a}},
      trunks_kid: {eyeRgb: 0x3a7ad0, outfitRgb: 0x2a5a3a, outfitParts: {undershirt: false, sash: 0xe88a2a, wrist: 0xe88a2a, shoes: 0xb8963a}},
      gohan: {outfitParts: {undershirt: false, sash: 0xc8322a, wrist: 0x1a1a1a, shoes: 0x6a4a2a}},
      pan: {outfitParts: {undershirt: 0x1a1a1a, pants: 0xd8d0e8, sash: false, wrist: false, shoes: 0xc8322a}},
    };
    for (const [id, look] of Object.entries(b2)) if (characters[id]?.look) characters[id].look = {...characters[id].look, ...look};
  }
  // Cast batch B3 (Claude, 2026-11-10; cast_audit.md): Frieza Force, Frost Demons, Radix and Nappo. New look fields
  // (outfits.gd header): outfit FriezaForce (flared shoulder flaps) / FrostBody (no clothes), scouter and horn gear,
  // domeRgb/shellRgb/skinMetal; form_looks extras chitin/shells/gear (Parts.form_extras). Frigor's earlier forms are
  // look-only entries (no playable form in forms.json).
  {
    const FL = form_looks, PINK = 0xe0848e, CHITIN = 0xf2eef0, GEM = 0x8a3ab8, RED_EYES = 0xb4142a;
    const SMALL_AURA = {color: 0xc878ff, core: 0xf4e8ff, size: 0.95, flicker: 0.5, sparks: 0};
    Object.assign(FL, {
      // Frigor's 1st/2nd/3rd forms: pink limbs, white chitin torso and forearm guards, purple gems, horns or crest
      FirstForm: {hair: null, eyes: RED_EYES, skin: PINK, chitin: CHITIN, shells: CHITIN, dome: GEM, gear: ['frost_horns'], aura: SMALL_AURA},
      SecondForm: {hair: null, eyes: RED_EYES, skin: PINK, chitin: CHITIN, shells: CHITIN, dome: GEM, gear: ['frost_horns_big'], bulk: [1.2, 1.3, 1.2],
        aura: {...SMALL_AURA, size: 1.05}},
      ThirdForm: {hair: null, eyes: RED_EYES, skin: 0xe8828e, chitin: 0xdfe6e0, shells: GEM, dome: GEM, gear: ['third_crest'], bulk: [1.12, 1.18, 1.12],
        aura: {...SMALL_AURA, size: 1.05, flicker: 0.8}},
      // Frosk: mint body and blue gems in his final forms; his assault form is the crested third-form shape
      FinalFormFrost: {...FL.FinalForm, skin: 0xc4ece0, dome: 0x2a5ad8, shells: 0x2a5ad8, aura: {...FL.FinalForm.aura, color: 0x6aa8ff, core: 0xe8f4ff}},
      FullPowerFrost: {...FL.FullPower, skin: 0xc4ece0, dome: 0x2a5ad8, shells: 0x2a5ad8, aura: {...FL.FullPower.aura, color: 0x5a8aff, core: 0xe0eeff}},
      FrostAssault: {hair: null, eyes: RED_EYES, skin: 0x3a5ad8, chitin: 0xa8e0d0, shells: 0x2a5ad8, dome: 0x2a5ad8, gear: ['third_crest'], bulk: [1.12, 1.18, 1.12],
        aura: {color: 0x6aa8ff, core: 0xe8f4ff, size: 1.05, flicker: 0.8, sparks: 0}},
      // Zarvon transformed: bulky, green warty skin
      ZarbonMonster: {hair: null, eyes: 0xd8c040, skin: 0x5a9a5a, bulk: [1.28, 1.08, 1.28], aura: {color: 0x7ad86a, core: 0xe8ffe0, size: 1.1, flicker: 0.8, sparks: 0}},
    });
    const FF = 'FriezaForce', NAVY = 0x1c2a5c, BLACK_SUIT = 0x1a1a1e, WHITE = 0xf2f2f2;
    const GINYU_FORCE = {outfit: FF, outfitRgb: BLACK_SUIT, outfitParts: {trim: 0xc8862a, wrist: BLACK_SUIT, boot_trim: 0xc8862a}};
    const NEW_STYLE = {flaps: false, plate: 0xf2f2f0, trim: 0x3a8a4a};   // DBS Frieza Force: green/white armour, no flaps
    const b3 = {
      frieza: {outfit: 'FrostBody', shellRgb: GEM},
      golden_frieza: {outfit: 'FrostBody', shellRgb: GEM, form: 'Golden', build: 'Short', face: 'Smirk'},
      black_frieza: {outfit: 'FrostBody', shellRgb: GEM, form: 'Black'},
      mecha_frieza: {outfit: 'FrostBody', skinHex: 0xb8bec8, skinMetal: 0.65, shellRgb: 0x9aa0ac, build: 'Short'},
      king_cold: {skinHex: 0xc878d0, domeRgb: 0x2a5a66, shells: false, costume: ['cold_horns'], outfit: FF, outfitRgb: 0x2a3ab0,
        outfitParts: {plate: 0x2a3ab0, trim: 0xd02a3a, cape: 0x7a1424, wrist: 0xd8dce4, shoes: 'skin', boot_trim: 'skin'}},
      frost: {skinHex: 0x3a5ad8, domeRgb: 0x2a5ad8, shellRgb: 0xa8e0d0, costume: ['frost_horns'], outfit: 'FrostBody',
        outfitParts: {top: 0xa8e0d0, wrist: 0xa8e0d0, pants: 0x4a4a5a}, formLooks: {FinalForm: 'FinalFormFrost', FullPower: 'FullPowerFrost'}},
      ginyu: {...GINYU_FORCE, antenna: false, skinHex: 0xa890d8, costume: ['frost_horns', 'scouter']},
      recoome: {...GINYU_FORCE, costume: ['scouter']},
      burter: {...GINYU_FORCE, raceParts: false, skinHex: 0x3a8ad8, costume: ['scouter']},
      jeice: {...GINYU_FORCE, antenna: false, ears: 'pointed', skinHex: 0xd8443a, hairAnyRace: true, hair: 'Wild', hairRgb: 0xf2f2f4, costume: ['scouter_red']},
      guldo: {...GINYU_FORCE, raceParts: false, costume: ['four_eyes']},
      dodoria: {outfit: FF, antenna: false, outfitRgb: NAVY, outfitParts: {trim: 0xd8b040, pants: 0x3a1a4a, wrist: NAVY}, costume: ['head_spikes', 'scouter']},
      zarbon: {skinHex: 0x9ad0b8, hairRgb: 0x2a8a5a, costume: ['tiara'], outfit: FF, outfitRgb: 0xe07aa8,
        outfitParts: {sleeves: true, pants: 0x4a2a6a, cape: WHITE, wrist: 0xe07aa8}},
      frieza_soldier: {outfit: FF, outfitRgb: NAVY, costume: ['scouter']},
      sorbet: {raceParts: false, skinHex: 0x5a8ad8, outfit: FF, outfitRgb: BLACK_SUIT, outfitParts: {...NEW_STYLE, pants: 0xc8302a, cape: WHITE}},
      tagoma: {skinHex: 0xb8a0d8, outfit: FF, outfitRgb: BLACK_SUIT, outfitParts: {...NEW_STYLE, pants: 0xb8302a}, costume: ['scouter']},
      lemo: {skinHex: 0xe8904a, hair: 'None', costume: ['cap'], outfit: FF, outfitRgb: 0x3a6a3a, outfitParts: {...NEW_STYLE, plate: 0x3a6a3a, belly: false}},
      raditz: {outfit: FF, outfitRgb: 0x1a1e2e, outfitParts: {trim: 0xa8743a, wrist: 0x2a3a6a, shoes: 0x2a3a6a, boot_trim: WHITE}, costume: ['scouter', 'red_bands']},
      nappa: {outfit: FF, outfitRgb: NAVY, outfitParts: {trim: 0xd8b040, wrist: NAVY, shoes: WHITE}, costume: ['scouter_purple', 'mustache']},
      saibaman: {raceParts: false, outfit: 'FrostBody', skinHex: 0x5aa046, eyeRgb: 0xd8202a, sculpt: {head_w: 1.18, head_h: 1.2}},
      giran: {raceParts: false, tail: 'frost', outfit: 'FrostBody', outfitParts: {pants: 0x8a2a2a, sash: 0xd8b040}},
    };
    for (const [id, look] of Object.entries(b3)) if (characters[id]?.look) characters[id].look = {...characters[id].look, ...look};
    if (characters.golden_frieza) characters.golden_frieza.scale = 0.9;
  }
  // Cast batch B4 (Claude, 2026-11-10; cast_audit.md): Boo saga, Cyborgs, Cel, Red Ribbon. New look fields (outfits.gd
  // header, characters/cast_b4.gd): outfit RRUniform, outfitParts badge/epaulettes/cape_collar, skinPattern (spots /
  // plates / majin) + patternRgb, faceRgb, mark 'majin', wingRgb, B4 gear ids. Cel's stages are look-only form_looks.
  {
    const FL = form_looks;
    Object.assign(FL, {
      CellImperfect: {hair: null, skin: 0x5e8c3a, eyes: 0x8a1a5a, gear: ['cell_tail', 'cell_beak'], bulk: [0.94, 1.04, 0.94],
        aura: {color: 0x8ad84a, core: 0xe8ffd0, size: 1.0, flicker: 0.7, sparks: 0}},
      CellSemiPerfect: {hair: null, skin: 0x84c03a, gear: ['cell_tail'], bulk: [1.26, 1.06, 1.26],
        aura: {color: 0x9ae04a, core: 0xf0ffd8, size: 1.1, flicker: 0.8, sparks: 0}},
      CellPerfect: {hair: null, aura: {color: 0xffe060, core: 0xfff8d0, size: 1.05, flicker: 0.6, sparks: 0}},
      CellSuperPerfect: {hair: null, scale: 1.03, aura: {color: 0xffc81e, core: 0xfff2b0, size: 1.12, flicker: 1, sparks: 1, sparkColor: 0x8ad8ff}},
    });
    const PURPLE = 0x3a2e6a, CELL_FACE = 0xeceaf2, WHITE = 0xf2f2f2, BLACK = 0x1a1a1e, GOLD = 0xe0b040;
    const CELL = {raceParts: false, shells: true, shellRgb: PURPLE, skinPattern: 'spots', faceRgb: CELL_FACE, outfit: 'FrostBody',
      costume: ['cell_crest', 'cell_wings'], wingRgb: PURPLE, outfitParts: {shoes: PURPLE, boot_trim: GOLD, laces: PURPLE, sash: 0x2a1a3a}};
    const BOO = {skinPattern: 'majin', costume: ['m_belt']};
    const BARE_BOO = {...BOO, eyeRgb: 0xc81e1e, outfitParts: {top: 'skin', sleeves: false, vest: false, pants: 0xf2f0ea, wrist: BLACK, shoes: BLACK, boot_trim: GOLD, sash: BLACK}};
    const RR = 'RRUniform';
    const b4 = {
      // Cel and his family: spotted carapace skin, white face, crest horns, purple shoulder/chest shells and wings
      cell: {...CELL, skinHex: 0x9ad040, patternRgb: 0x1e3a12, eyeRgb: 0xb0207a},
      cell_jr: {...CELL, skinHex: 0x4a9ad8, patternRgb: 0x1a3a7a, shellRgb: 0x2a2a5a, wingRgb: 0x2a2a5a, eyeRgb: 0x5a1a6a},
      cell_max: {...CELL, skinHex: 0x6ab04a, patternRgb: 0x24401a, faceRgb: null, shellRgb: 0xa8242a, costume: ['cell_crest'], eyeRgb: 0xe8e0c0,
        outfitParts: {top: 0xa8242a, wrist: 0xa8242a, shoes: 0xa8242a, boot_trim: 0xa8242a, laces: 0xa8242a}},
      // Boo: soft glossy pink, gold M buckle; Kid/Super are bare-chested with red eyes, Fat Boo keeps the vest + purple cape
      fat_buu: {...BOO, outfitParts: {cape: 0x5a2a8a, gloves: 0xe8c040, wrist: 0xe8c040, shoes: 0xe8c040, boot_trim: 0xe8c040}},
      kid_buu: {...BARE_BOO, skinHex: 0xf0a0c0},
      super_buu: {...BARE_BOO},
      babidi: {raceParts: false, ears: 'pointed', skinHex: 0xd8c040, eyeRgb: 0x2a1d14, sculpt: {head_w: 1.5, head_h: 1.42, head_d: 1.45},
        outfit: 'AngelRobe', outfitRgb: BLACK, outfitParts: {pants: 0x6ac0c8, collar: false, sash: false, cape: 0xe8662a, cape_collar: 0xe8662a, shoes: 0x6a4a2a, boot_trim: 0x6a4a2a}},
      dabura: {raceParts: false, ears: 'pointed', skinHex: 0xc83a3a, eyeRgb: 0x2a1d14, costume: ['dabura_horns'], outfit: 'CraneGi', outfitRgb: 0x2a4a9a,
        outfitParts: {pants: 0x2a4a9a, cape: WHITE, shoes: WHITE, boot_trim: WHITE, sash: BLACK}},
      pui_pui: {costume: ['pui_helmet'], skinHex: 0xc8b8e0, outfitParts: {top: 0x2a4ab0, pants: 0x2a4ab0, plate: WHITE, trim: WHITE, shoes: WHITE, boot_trim: WHITE}},
      yakon: {raceParts: false, skinHex: 0x3a6a3a, eyeRgb: 0xe8d820, mark: 'majin', costume: ['head_spikes'], outfit: 'FrostBody', outfitParts: {gloves: BLACK}},
      spopovich: {mark: 'majin', outfitParts: {top: BLACK, vest: true, pants: BLACK, sash: BLACK, wrist: 0xe8c030, shoes: WHITE}},
      majin_vegeta: {mark: 'majin'},
      // Cyborgs
      android_16: {hair: 'Mohawk', hairRgb: 0xd8502a, eyeRgb: 0x3a7ad0, outfitParts: {top: 0x1a1a1e, plate: 0x3a7a3a, trim: 0x3a7a3a, pads: false, sleeves: false,
        pants: 0x7a6a8a, shoes: 0x2a4a2a, boot_trim: 0x1a1a1e, badge: 0xc8202a}},
      android_17: {hair: 'ShoulderStraight', eyeRgb: 0x3a7ad0, costume: ['scarf_orange'], outfitRgb: BLACK, outfitParts: {pants: 0x6a9ad0, shoes: WHITE, sash: 0x5a3a2a, badge: 0xc8202a}},
      android_18: {hair: 'Bob', hairRgb: 0xf0d070, eyeRgb: 0x3a7ad0, costume: ['hoops'], outfitRgb: 0x3a5a9a, outfitParts: {pants: BLACK, shoes: 0x6a4a2a, boot_trim: 0x6a4a2a}},
      android_19: {raceParts: false, skinHex: 0xf0f0f4, skinPattern: 'plates', patternRgb: 0xa8a8b4, eyeRgb: 0x1a1a1a, physique: 'boo_fat', costume: ['android_dome'],
        outfit: RR, outfitRgb: 0xe8c030, outfitParts: {pants: 0xe07a2a, sash: 0xc8202a, shoes: WHITE, boot_trim: WHITE}},
      gero: {hair: 'Long', hairRgb: 0xf2f2f2, skinHex: 0xf0dccc, costume: ['rr_cap', 'gero_beard'], outfit: RR, outfitRgb: BLACK,
        outfitParts: {pants: 0x6a4a2a, sash: 0xc8202a, shoes: WHITE, boot_trim: WHITE}},
      hedo: {build: 'Short', sculpt: {belly: 0.06, waist: 1.18}, outfitParts: {pants: 0x2a4a8a, shoes: 0xe8c030}},
      gamma1: {raceParts: false, hair: 'None', skinHex: 0xa8a8b4, skinPattern: 'plates', patternRgb: 0x7a7a88, eyeRgb: 0xe8d820, costume: ['gamma_helmet'],
        outfit: RR, outfitRgb: 0xe8b020, outfitParts: {pants: 0xe8b020, gloves: 0x2a2a34, shoes: 0x2a2a34, boot_trim: 0x2a2a34, sash: 0x3a2a2a, cape: 0xc8202a}},
      gamma2: {raceParts: false, hair: 'None', skinHex: 0xa8a8b4, skinPattern: 'plates', patternRgb: 0x7a7a88, eyeRgb: 0xe8d820, costume: ['gamma_helmet2'],
        outfit: RR, outfitRgb: 0xe8b020, outfitParts: {pants: 0xe8b020, gloves: 0x2a2a34, shoes: 0x2a2a34, boot_trim: 0x2a2a34, sash: 0x3a2a2a, cape: 0x2a4ac8}},
      magenta: {hairRgb: 0x141414, skinHex: 0xd8a070, costume: ['mustache', 'shades'], outfitRgb: 0xb02a7a, outfitParts: {pants: 0xb02a7a, shoes: BLACK}},
      // Red Ribbon officers
      android_8: {hairRgb: 0x141414, outfit: RR, outfitRgb: 0x3a6a3a},
      red: {costume: ['eyepatch'], outfit: RR, outfitRgb: 0xb8202a, outfitParts: {epaulettes: GOLD}},
      blue: {eyeRgb: 0x3a7ad0, outfit: RR, outfitRgb: 0x2a4ab0},
      white: {hair: 'Short', hairRgb: 0xd8c8a0, costume: ['rr_cap', 'scarf_red'], outfit: RR, outfitRgb: 0x6a7a5a},
      silver: {hairRgb: 0xd8702a, costume: ['scarf_red'], outfit: RR, outfitRgb: 0x5a3a8a, outfitParts: {shoes: 0x6a4a2a, boot_trim: 0x6a4a2a}},
      // leftover Buu antenna (race Majin) on non-Majin looks
      ginyu: {raceParts: false},
    };
    for (const [id, look] of Object.entries(b4)) if (characters[id]?.look) characters[id].look = {...characters[id].look, ...look};
  }
  // Cast batch B5 (Claude, 2026-11-10; cast_audit.md): Earth humans. New look fields (outfits.gd header): hair styles
  // CenterPart/Bob/TwinTails/Afro/BigCurly/Topknot/SidePonytail/ShoulderStraight/Slick, moustache/beard/facialHairRgb
  // (Parts.facial_hair), glasses, hat, thirdEye, faceMarks, jewellery, neckwear (+ colours; characters/face_gear.gd).
  {
    const WHITE = 0xf2f2f2, BLACK = 0x1e1e22, BLUE_EYES = 0x3a7ad0, RED = 0xc8322a;
    const b5 = {
      krillin: {faceMarks: ['dots']},
      krillin_kid: {faceMarks: ['dots']},
      yamcha: {hair: 'Spiky', faceMarks: ['scar_cheek', 'scar_eye']},
      tien: {thirdEye: true, outfitParts: {sash: RED}},
      tien_young: {thirdEye: true, hat: 'skullcap', hatRgb: BLACK},
      chiaotzu: {faceMarks: ['cheek_circles'], hat: 'pompom', hatRgb: BLACK, hatRgb2: 0xd8202a, outfitRgb: 0x1e9a8a,
        outfitParts: {pants: 0x2a8a3a, sash: RED, wrist: 0x2a8a3a}},
      roshi: {moustache: 'bushy', beard: 'long', glasses: 'sunglasses', costume: ['prop_turtle_shell', 'prop_cane'], outfit: 'CraneGi',
        outfitParts: {top: 0xf2f0ea, sleeves: false, pants: 0xc8a870, sash: false, shoes: 0x8a5a3a}},
      jackie_chun: {moustache: 'bushy', beard: 'short', glasses: 'round', outfitRgb: BLACK, outfitParts: {pants: BLACK, sash: WHITE}},
      grandpa_gohan: {moustache: 'bushy', hat: 'pompom', hatRgb: 0x2a2a30, hatRgb2: 0xd8202a, outfitRgb: 0xe8782a, outfitParts: {pants: 0x2a2a30, sash: 0x2a2a30}},
      bulma: {hair: 'Bob', hairRgb: 0x3ac0c0, eyeRgb: BLUE_EYES, neckwear: 'scarf', neckRgb: 0xf0c832, outfitRgb: 0xc8202a,
        outfitParts: {pants: 0xc8202a, sleeves: false, shoes: 0xc8202a}},
      bulma_young: {hair: 'SidePonytail', hairRgb: 0x3ab8b0, eyeRgb: BLUE_EYES, hat: 'ribbon', hatRgb: 0xd8202a, outfitRgb: 0xe878a8, outfitParts: {pants: 0xe878a8}},
      chichi: {hair: 'Bun', outfitRgb: 0xd83a5a, outfitParts: {pants: 0x7a1a2a, sash: false, shoes: 0xc8202a}},
      dr_brief: {hairRgb: 0xb8b0c8, moustache: 'bushy', glasses: 'round', outfitRgb: WHITE, outfitParts: {pants: 0x8a8a90}},
      videl: {hair: 'TwinTails', eyeRgb: BLUE_EYES, outfit: 'CapsuleCorp', outfitRgb: WHITE, outfitParts: {pants: 0x1a1a1e, gloves: 0x1a1a1e, shoes: WHITE}},
      mr_satan: {hair: 'Afro', moustache: 'bushy', jewellery: ['champion_belt'], outfitRgb: 0x3a1e4a,
        outfitParts: {pants: 0xe8c040, sash: false, shoes: WHITE, cape: 0xd8405a}},
      ox_king: {beard: 'full', glasses: 'round'},
      tao: {hair: 'Slick', moustache: 'long', outfitRgb: 0xe890b0, outfitParts: {pants: 0x1e2a5a, sash: 0x1e2a5a}},
      tao_cyborg: {hair: 'Slick', moustache: 'long', skinMetal: 0.5, outfitParts: {top: 0xc84a6a, pants: 0x1e2a5a}},
      murasaki: {hat: 'bandana', hatRgb: 0x5a2e7a, outfitRgb: 0x6a3a8a, outfitParts: {pants: 0x6a3a8a, sash: 0x2a1a3a}},
      nam: {hat: 'turban', hatRgb: 0xf2f0ea, skinHex: 0xc89060, outfitParts: {top: 'skin', sleeves: false, pants: 0x7a4a9a, sash: 0xf2f0ea}},
      yajirobe: {costume: ['prop_katana'], outfitRgb: 0xe08a2a, outfitParts: {pants: 0x6a5a4a, sash: 0x2a2a30}},
      baba: {hair: 'BigCurly', hairRgb: 0xd890c8, outfitRgb: BLACK},
      mai: {hair: 'Long', hat: 'beanie', hatRgb: 0x3a7a3a, outfitRgb: 0x2a4a8a, outfitParts: {pants: 0x1a1a1e, shoes: 0x1a1a1e}},
      princess_snake: {skinHex: 0x7ac8a0, hair: 'BigCurly', hairRgb: 0xe8782a, neckwear: 'fur_collar', neckRgb: 0xf4f2ee,
        jewellery: ['earrings'], jewelRgb: 0x9a3ad8},
      trunks: {hair: 'CenterPart'},
      trunks_kid: {hair: 'CenterPart'},
    };
    for (const [id, look] of Object.entries(b5)) if (characters[id]?.look) characters[id].look = {...characters[id].look, ...look};
  }
  // Cast batch B6 (Claude, 2026-11-10; cast_audit.md): Namekians, demons, animals and creatures. New costume ids in
  // godot/characters/creature_bodies.gd (turbans/hats/hood, animal-head pieces, bat wings, props, the Battle Walker
  // and Oracle Fish bodies); reuses B4 skinPattern and B5 neckwear. The wish dragons are WishDragon models (no change).
  {
    const WHITE = 0xf4f2ee, DARK_EYES = 0x1a1a1a, DEMON = {raceParts: false, ears: 'pointed'};
    const b6 = {
      piccolo: {antenna: false, costume: ['namek_turban']},
      piccolo_jr: {antenna: false, costume: ['namek_turban']},
      nail: {outfitParts: {cape: false}},
      kami: {outfit: 'NamekRobe', outfitRgb: WHITE, outfitParts: {cape: 0x3a4ab0, sash: 0x3a4ab0, wrist: false}, costume: ['prop_cane']},
      king_piccolo: {outfitRgb: WHITE, outfitParts: {sash: 0xc8322a, wrist: 0xc8322a}},
      dende: {outfitRgb: WHITE, outfitParts: {sash: 0x6a3aa8, wrist: false, cape: false}},
      guru: {outfitRgb: WHITE, neckwear: 'scarf', neckRgb: 0xe88aae, outfitParts: {cape: false, sash: false, wrist: false},
        sculpt: {belly: 0.12, waist: 1.35, hips: 1.2}},
      moori: {outfitRgb: WHITE, outfitParts: {top: 0xb8322a, vest: true, cape: false, sash: WHITE, wrist: false}},
      monaito: {outfit: 'NamekRobe', outfitRgb: 0x6a3a9a, outfitParts: {cape: 0x8a6ab8, wrist: false}, costume: ['prop_cane']},
      tambourine: {...DEMON, costume: ['bat_wings'], outfitParts: {cape: false}},
      cymbal: {...DEMON, outfit: 'FrostBody', skinPattern: 'spots', patternRgb: 0x2a5a2a, costume: ['bat_wings', 'demon_crest'], sculpt: {belly: 0.06}},
      drum: {...DEMON, skinPattern: 'spots', patternRgb: 0x4a6a2a, sculpt: {belly: 0.08},
        outfitParts: {top: 'skin', sleeves: false, pants: 0x2a4aa8, sash: 0xe8862a, wrist: false, cape: false}},
      oolong: {costume: ['pig_head', 'suspenders'], outfitParts: {top: WHITE, pants: 0x3a7a3a, undershirt: false, sash: false, wrist: false, shoes: 0x2a2a2a}},
      puar: {tail: 'cat', outfit: 'FrostBody', eyeRgb: DARK_EYES, costume: ['cat_head']},
      korin: {tail: 'cat', outfit: 'FrostBody', eyeRgb: DARK_EYES, costume: ['cat_head', 'prop_staff']},
      bubbles: {outfit: 'FrostBody', skinHex: 0x4a3226, faceRgb: 0xd8b48c, eyeRgb: DARK_EYES, costume: ['monkey_head']},
      shu: {skinHex: 0xe8902a, eyeRgb: DARK_EYES, costume: ['dog_head', 'ninja_hood', 'prop_katana'], outfitRgb: 0x3a2a6e,
        outfitParts: {pants: 0x3a2a6e, sash: 0xc8c8f0, shoes: 0x1a1a1e}},
      pilaf: {ears: 'pointed', eyeRgb: DARK_EYES, costume: ['pilaf_hat'], outfitRgb: 0xe8c832, outfitParts: {pants: 0x3a3a6a}},
      pilav_robot: {costume: ['battle_walker']},
      oracle_fish: {raceParts: false, costume: ['oracle_fish']},
      toppo: {costume: ['big_mustache']},
      saibaman: {costume: ['plant_head']},
    };
    for (const [id, look] of Object.entries(b6)) if (characters[id]?.look) characters[id].look = {...characters[id].look, ...look};
    for (const [id, scale] of [['monaito', 0.85], ['oracle_fish', 0.8]]) if (characters[id]) characters[id].scale = scale;
  }
  // Every character's own face (FaceShape): seeded by the character id, so identical looks still differ
  for (const [id, c] of Object.entries(characters)) if (c.look && c.look.faceSeed == null) c.look.faceSeed = id;
  const fighting_styles = fightingStyles(tables.combat);
  for (const [id, character] of Object.entries(characters)) character.style = fighting_styles.npc_assignments[id] ?? character.style ?? 'turtle';
  for (const [zone, x, z, radius] of [['mt_paozu', 1280, -560, 170], ['fire_mountain', -1300, -680, 160], ['pilav_castle', 525, 600, 170],
    ['muscle_tower', 650, 1290, 160], ['baaba_palace', -1320, 650, 150], ['korrin_tower', -550, 900, 150], ['piccor_castle', 920, -800, 170],
    ['tournament_island', -150, -575, 150]]) world.planets.earth.regions.push({zone, x, z, radius, blend: 80});
  return {
    ...tables, zones, npcs, characters, appearance, races, form_looks, zone_order: zoneOrder, planets: world.planets,
    fighting_styles, schema:{...tables.schema, version:Math.max(7,tables.schema.version), slots:10},
    skill_presentation: skillPresentation(tables.moves,tables.combat.starterMove),
    godot_additions: {zones: [...new Set(changed)].sort(), note: 'Zones changed for the Godot game only; JS parity skips them.'},
  };
}
