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
