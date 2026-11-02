// Character movement rules: run, jump, gravity, ground. Pure (no rendering), runs at the fixed step.
// PLACEHOLDER: basic ground movement only. Dash, flight and ki charge are Codex's lane (see
// COLLABORATION.md) and extend `stepMovement`; keep the signature.
import { MOVEMENT as M } from "../data/movement.js";

/**
 * @param e   entity: { pos, vel, yaw, onGround, runSpeed, flying, dashing, charging, stun }
 * @param it  intents (see game/game.js INTENTS)
 * @param dt  seconds (fixed step)
 * @param zone zone from game/zones.js (heightAt, size)
 */
export function stepMovement(e, it, dt, zone) {
  const wish = { x: it.moveX || 0, z: it.moveZ || 0 };
  const len = Math.hypot(wish.x, wish.z);
  if (len > 1) { wish.x /= len; wish.z /= len; }
  const canMove = !(e.stun > 0);
  const target = { x: canMove ? wish.x * e.runSpeed : 0, z: canMove ? wish.z * e.runSpeed : 0 };
  const accel = M.groundAccel * (e.onGround ? 1 : M.airControl) * dt;
  e.vel.x += clamp(target.x - e.vel.x, -accel, accel);
  e.vel.z += clamp(target.z - e.vel.z, -accel, accel);

  if (canMove && len > 0.05) e.yaw = turnTowards(e.yaw, Math.atan2(wish.x, wish.z), M.turnSpeed * dt);

  if (e.onGround && it.jump && canMove) {
    e.vel.y = M.jumpSpeed;
    e.onGround = false;
  }
  e.vel.y -= M.gravity * dt;

  e.pos.x += e.vel.x * dt;
  e.pos.y += e.vel.y * dt;
  e.pos.z += e.vel.z * dt;

  const half = zone.size / 2 - 1;
  e.pos.x = clamp(e.pos.x, -half, half);
  e.pos.z = clamp(e.pos.z, -half, half);

  const ground = zone.heightAt(e.pos.x, e.pos.z);
  if (e.pos.y <= ground) {
    e.pos.y = ground;
    if (e.vel.y < 0) e.vel.y = 0;
    e.onGround = true;
  } else if (e.pos.y > ground + 0.05) {
    e.onGround = false;
  }
}

export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

/** Rotates angle a towards b by at most `step` radians, the short way round. */
export function turnTowards(a, b, step) {
  let d = ((b - a + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
  return Math.abs(d) <= step ? b : a + Math.sign(d) * step;
}
