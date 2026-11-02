import * as THREE from 'three';
import { CAMERA as C } from '../data/camera.js';

/** Third-person orbit. Optional lock position is supplied by the gameplay authority. */
export function createFollowCamera(camera, zone) {
  const state = { yaw: Math.PI, pitch: C.pitch };
  const pos = new THREE.Vector3(), look = new THREE.Vector3(), want = new THREE.Vector3();
  let first = true;
  const blend = (dt, rate) => 1 - Math.exp(-Math.max(0, dt) * rate);
  return {
    get yaw() { return state.yaw; },
    addLook(d) {
      if (!d) return;
      state.yaw -= Number.isFinite(d.x) ? d.x : 0;
      state.pitch = THREE.MathUtils.clamp(state.pitch + (Number.isFinite(d.y) ? d.y : 0), C.minPitch, C.maxPitch);
    },
    setYaw(yaw) { if (Number.isFinite(yaw)) state.yaw = yaw; },
    // target = interpolated feet position. lockTarget = optional interpolated enemy feet position.
    update(target, frameDt, lockTarget = null) {
      look.set(target.x, target.y + C.height, target.z);
      let distance = C.distance;
      if (lockTarget) {
        const dx = lockTarget.x - target.x, dz = lockTarget.z - target.z;
        if (Math.hypot(dx, dz) > .001) {
          const angle = Math.atan2(dx, dz);
          const delta = Math.atan2(Math.sin(angle - state.yaw), Math.cos(angle - state.yaw));
          state.yaw += delta * blend(frameDt, C.lockTurnRate);
        }
        distance = Math.min(C.maxLockDistance, C.distance + Math.hypot(dx, dz) * C.lockDistanceScale);
        look.lerp(want.set(lockTarget.x, lockTarget.y + C.lockHeight, lockTarget.z), .5);
      }
      const cp = Math.cos(state.pitch);
      want.set(
        target.x - Math.sin(state.yaw) * cp * distance,
        target.y + C.height + Math.sin(state.pitch) * distance,
        target.z - Math.cos(state.yaw) * cp * distance,
      );
      want.y = Math.max(want.y, zone.heightAt(want.x, want.z) + C.clearance);
      if (first) { pos.copy(want); first = false; }
      else pos.lerp(want, blend(frameDt, C.followRate));
      // Smoothing across a slope must not put the actual camera below the terrain.
      pos.y = Math.max(pos.y, zone.heightAt(pos.x, pos.z) + C.clearance);
      camera.position.copy(pos);
      camera.lookAt(look);
    },
  };
}
