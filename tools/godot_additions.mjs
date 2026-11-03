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

export function applyGodotAdditions(tables) {
  const zones = structuredClone(tables.zones);
  const npcs = structuredClone(tables.npcs);
  const characters = structuredClone(tables.characters);
  const changed = [...checkInStation(zones, npcs)];
  // giant, seated behind the desk: red skin, black beard, judge's hat (Parts.costume "yemmo")
  Object.assign(characters.king_yemma, {scale: 4.2, look: {race: 'Human', skin: 0, skinHex: 0xc8463c, face: 'Fierce', hair: 'None',
    hairColor: 0, build: 'Muscular', outfit: 'CraneGi', outfitTint: 2, costume: 'yemmo'}});
  return {
    ...tables, zones, npcs, characters,
    godot_additions: {zones: [...new Set(changed)].sort(), note: 'Zones changed for the Godot game only; JS parity skips them.'},
  };
}
