// Action RPG tuning. Rules consume these values; views only display the outcome.
export const COMBAT = {
  meleeDamage: 12, meleeRange: 2.8, meleeArc: .15, meleeCooldown: .32,
  comboWindow: 1.1, comboFinish: 1.65, hitStun: .12, stunLimit: .45,
  knockback: 4, guardDamage: .22, guardCost: 7,
  blastCooldown: .55, projectileSpeed: 27, projectileLife: 2.6, projectileRadius: .65,
  beamCooldown: 2.8, beamCharge: 1.5, beamRange: 42, beamRadius: 1.25,
  aggroRange: 16, leashRange: 32, enemyRange: 2.3, enemySpeed: 3.4,
  enemyWindup: .65, enemyCooldown: 1.8, enemyDamage: 9,
  enemyHealth: 56, healthPerLevel: 9, enemyDamagePerLevel: .45,
  bossHealth: 2.2, bossDamage: 1.35,
  respawnSeconds: 3, enemyRespawn: 6, bossRespawn: 10,
  lockRange: 45, playerRegen: .025, regenDelay: 7,
  utilityDuration: 3, utilityCooldown: 8, utilityRange: 12, utilityHeal: .35,
  powerBuff: 1.5, powerHealthDrain: .025, shieldReduction: .4,
  candyThreshold: .25, candyDamage: 20, teleportOffset: 2,
  enemyRegen: .15, respawnSafeRange: 6, spawnProtection: 2, syncInterval: .2,
  starterMove: { name: 'Energy Wave', kind: 'beam', kiCost: 18, power: 2.2 },
};
