import { ZONE_DEFS } from './zones.js';
import { xpToNext } from '../game/progression.js';
export const ZONE_LEVELS = {
  earth_plains: 1, kame_island: 1, snake_way: 2, king_kai: 3,
  gizard_wasteland: 5, west_city: 10, namek: 12, yardrat: 18,
  gero_lab: 24, lookout: 28, htc: 32, cell_games: 36,
  papaya_island: 43, babidi_ship: 48, kai_world: 55, beerus_planet: 68,
  nameless_planet: 80, future_earth: 95, world_of_void: 110,
  broly_glacier: 125, red_ribbon: 135,
};
export const RPG = { huntCount: 3, huntXp: .8, killXp: .16, zeniPerLevel: 12 };
export function camp(zone) {
  const p = zone.spawn, path = zone.def.terrain.path;
  const raw = { x: path ? 0 : p.x + 18, z: p.z + 22 };
  return zone.place(raw.x, raw.z);
}
export function installRpgContent(npcs, quests, characters) {
  characters.training_guide = { name: 'Training Guide', look: {
    race: 'Human', skin: 2, hair: 'Short', hairColor: 0, face: 'Calm', build: 'Average', outfit: 'TurtleGi', outfitTint: 1,
  } };
  for (const [id, def] of Object.entries(ZONE_DEFS)) {
    const level = ZONE_LEVELS[id] || 1, p = def.terrain.spawn;
    const giver = `guide_${id}`, enemy = `patrol_${id}`;
    npcs.push({ id: giver, who: 'training_guide', zone: id, x: def.terrain.path ? 1.5 : p.x + 5, z: p.z + 3 });
    quests.push({ id: `hunt_${id}`, title: `${def.name}: Patrol`, saga: 'Training contracts', giver, repeat: true, level,
      offer: `Defeat ${RPG.huntCount} hostile trainees near camp. Practice your melee combo, guard and ki attacks. Return for another contract whenever you need XP and zeni.`,
      done: 'Good work! Spend your stat points, learn techniques from story trainers, and take another contract when you are ready.',
      steps: [{ type: 'defeat', enemy, count: RPG.huntCount, zone: id, x: def.terrain.path ? 0 : p.x + 18, z: p.z + 22, r: 12, text: `Defeat ${RPG.huntCount} hostile trainees` }],
      rewards: { xp: Math.round(xpToNext(level) * RPG.huntXp), zeni: level * 35 + 50 },
    });
  }
}
export const SHOP = {
  capsule: { name: 'Recovery Capsule', price: 75, description: 'Restore 40% health and ki. Keep it in your inventory for later.', heal: .4 },
};
