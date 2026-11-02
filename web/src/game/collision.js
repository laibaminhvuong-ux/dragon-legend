// World collision for entities: trees, boulders and cliffs. Pure (no rendering).
// Call once per step after movement: resolveCollisions(entity, zone, prevPos).
const BODY_RADIUS = 0.35;
const MAX_WALK_SLOPE = 0.62; // ground normal y below this (about 52 degrees) can't be walked up

/**
 * Pushes the entity out of props and stops it walking up cliffs. Mutates entity.pos / vel.
 * @param prev  position before this step's movement {x, y, z}
 */
export function resolveCollisions(e, zone, prev) {
  // cliffs: walking (not flying) onto ground that is both steep and higher is refused
  if (!e.flying && e.onGround) {
    const rise = zone.heightAt(e.pos.x, e.pos.z) - prev.y;
    if (rise > 0.05 && zone.normalAt(e.pos.x, e.pos.z).y < MAX_WALK_SLOPE) {
      e.pos.x = prev.x;
      e.pos.z = prev.z;
      e.pos.y = Math.max(prev.y, zone.heightAt(prev.x, prev.z));
      e.vel.x = 0;
      e.vel.z = 0;
    }
  }
  // props: push out horizontally if the entity is below the prop's top
  for (const c of zone.props().near(e.pos.x, e.pos.z, BODY_RADIUS)) {
    if (e.pos.y > c.top) continue;
    const dx = e.pos.x - c.x, dz = e.pos.z - c.z;
    const d = Math.hypot(dx, dz) || 1e-6;
    const min = c.radius + BODY_RADIUS;
    if (d >= min) continue;
    const nx = dx / d, nz = dz / d;
    e.pos.x = c.x + nx * min;
    e.pos.z = c.z + nz * min;
    const vn = e.vel.x * nx + e.vel.z * nz;
    if (vn < 0) { e.vel.x -= vn * nx; e.vel.z -= vn * nz; }
  }
}
