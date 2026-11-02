// Tunable numbers for levels, stat points and what they produce. Units: metres, seconds.
export const MAX_LEVEL = 2000;
export const POINTS_PER_LEVEL = 3;
export const SLOT_COUNT = 3;
export const STARTING_ZENI = 100;

/** Stat ids in the order the stat screen lists them. */
export const STAT_NAMES = ["Health", "Ki", "Strength", "KiPower", "Speed"];
export const STAT_DISPLAY = { Health: "Health", Ki: "Ki", Strength: "Strength", KiPower: "Ki Power", Speed: "Speed" };

export const BASE_HEALTH = 100;
export const BASE_KI = 100;
export const HEALTH_PER_LEVEL = 5;
export const KI_PER_LEVEL = 3;

// what one allocated point adds
export const HEALTH_PER_POINT = 12;
export const KI_PER_POINT = 10;
export const RUN_SPEED_PER_POINT = 0.02; // m/s per Speed point
export const BASE_RUN_SPEED = 7; // m/s
export const MAX_RUN_SPEED = 14;

export const KI_REGEN_PER_SECOND = 2;
