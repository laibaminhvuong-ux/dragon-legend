// Authoritative fixed-step movement. Runtime dash state stays on the entity, never in saves.
import { MOVEMENT as M } from "../data/movement.js";
import { addKi, trySpendKi } from "./ki.js";

export function stepMovement(e, it, dt, zone) {
  if (!(dt > 0) || !Number.isFinite(dt)) return;
  const wish = { x: it.moveX || 0, z: it.moveZ || 0 };
  const len = Math.hypot(wish.x, wish.z);
  if (len > 1) { wish.x /= len; wish.z /= len; }
  const canMove = !(e.stun > 0) && e.health !== 0;
  e.dashCooldown = Math.max(0, (e.dashCooldown || 0) - dt);
  e.dashRemaining = Math.max(0, e.dashRemaining || 0);
  if (!canMove) e.dashRemaining = 0;

  if (canMove && it.flight) {
    e.flying = !e.flying && e.ki > 0;
    e.vel.y = 0;
    if (e.flying) e.onGround = false;
  }
  if (e.flying && (!canMove || !trySpendKi(e, M.flightDrain * dt))) {
    e.flying = false;
    e.vel.y = Math.min(0, e.vel.y);
  }

  e.charging = !!(canMove && it.charge && !e.flying && e.onGround && !e.dashRemaining);
  if (e.charging) addKi(e, M.chargeRate * dt);
  if (canMove && it.dash && !e.charging && e.dashCooldown === 0 && trySpendKi(e, M.dashCost)) {
    e.dashRemaining = M.dashDuration;
    e.dashCooldown = M.dashCooldown;
    e.dashX = len > 0 ? wish.x : Math.sin(e.yaw);
    e.dashZ = len > 0 ? wish.z : Math.cos(e.yaw);
  }
  e.dashing = e.dashRemaining > 0;
  e.blocking = !!(canMove && it.block && !e.dashing && !e.charging);

  const speed = e.flying ? M.flightSpeed : e.runSpeed;
  const target = { x: canMove && !e.charging ? wish.x * speed : 0, z: canMove && !e.charging ? wish.z * speed : 0 };
  const accel = M.groundAccel * (e.onGround || e.flying ? 1 : M.airControl) * dt;
  e.vel.x += clamp(target.x - e.vel.x, -accel, accel);
  e.vel.z += clamp(target.z - e.vel.z, -accel, accel);
  if (canMove && !e.charging && len > 0.05) e.yaw = turnTowards(e.yaw, Math.atan2(wish.x, wish.z), M.turnSpeed * dt);

  if (e.flying) {
    e.vel.y = ((it.ascend ? 1 : 0) - (it.descend ? 1 : 0)) * M.flightAscend;
  } else {
    if (e.onGround && it.jump && canMove && !e.charging) {
      e.vel.y = M.jumpSpeed;
      e.onGround = false;
    }
    e.vel.y -= M.gravity * (zone.gravity ?? 1) * dt;
  }

  // Integrate only the remaining dash fraction, so duration does not depend on step rounding.
  const dashDt = Math.min(dt, e.dashRemaining);
  e.pos.x += (e.dashX || 0) * M.dashSpeed * dashDt + e.vel.x * (dt - dashDt);
  e.pos.z += (e.dashZ || 0) * M.dashSpeed * dashDt + e.vel.z * (dt - dashDt);
  if (e.dashing) {
    e.vel.x = e.dashX * M.dashSpeed;
    e.vel.z = e.dashZ * M.dashSpeed;
  }
  e.dashRemaining = Math.max(0, e.dashRemaining - dt);
  e.pos.y += e.vel.y * dt;

  const half = zone.size / 2 - 1;
  const x = clamp(e.pos.x, -half, half), z = clamp(e.pos.z, -half, half);
  if (x !== e.pos.x) e.vel.x = 0;
  if (z !== e.pos.z) e.vel.z = 0;
  e.pos.x = x; e.pos.z = z;
  const ground = zone.heightAt(x, z);
  if (e.pos.y <= ground) {
    e.pos.y = ground;
    if (e.vel.y < 0) e.vel.y = 0;
    // A newly enabled flight can take off from ground; descending onto it lands.
    if (e.flying && it.descend) e.flying = false;
    e.onGround = !e.flying;
  } else e.onGround = false;
}

export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

/** Rotates angle a towards b by at most `step` radians, the short way round. */
export function turnTowards(a, b, step) {
  let d = ((b - a + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
  return Math.abs(d) <= step ? b : a + Math.sign(d) * step;
}
