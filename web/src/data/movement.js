// Movement tuning (metres, seconds). Ported from the Roblox Movement/Tuning.luau, scaled from studs.
export const MOVEMENT = {
  gravity: 24, // m/s^2 (a bit floatier than real life)
  jumpSpeed: 9,
  airControl: 0.35, // 0..1 how much you can steer mid-air
  turnSpeed: 14, // rad/s the body turns to face movement
  groundAccel: 60, // m/s^2

  // Codex's lane fills these in (dash, flight, charge):
  dashCost: 12, dashSpeed: 30, dashDuration: 0.18, dashCooldown: 0.85,
  flightSpeed: 17, flightAscend: 10, flightDrain: 4,
  chargeRate: 15,
};
