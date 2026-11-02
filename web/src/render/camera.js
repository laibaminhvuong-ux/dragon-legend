// Third-person orbit camera that follows a target and stays above the ground.
// PLACEHOLDER: Codex's lane (camera feel, lock-on framing) replaces the internals; keep the API.
import * as THREE from "three";

export function createFollowCamera(camera, zone) {
  const state = { yaw: Math.PI, pitch: 0.25, distance: 6, height: 1.6 };
  const pos = new THREE.Vector3();
  const look = new THREE.Vector3();
  let first = true;

  return {
    /** Yaw (radians) of where the camera looks, used to turn WASD into world directions. */
    get yaw() { return state.yaw; },
    /** Apply look deltas from input.takeLook(). */
    addLook(d) {
      state.yaw -= d.x;
      state.pitch = Math.min(1.2, Math.max(-0.6, state.pitch + d.y));
    },
    /** Snap behind a direction (radians, 0 = +Z). */
    setYaw(yaw) { state.yaw = yaw; },
    /** target: {x, y, z} feet position (already interpolated for rendering). */
    update(target, frameDt) {
      look.set(target.x, target.y + state.height, target.z);
      const cp = Math.cos(state.pitch);
      const want = new THREE.Vector3(
        look.x - Math.sin(state.yaw) * cp * state.distance,
        look.y + Math.sin(state.pitch) * state.distance,
        look.z - Math.cos(state.yaw) * cp * state.distance,
      );
      const ground = zone.heightAt(want.x, want.z) + 0.4;
      if (want.y < ground) want.y = ground;
      if (first) { pos.copy(want); first = false; } else pos.lerp(want, 1 - Math.exp(-frameDt * 18));
      camera.position.copy(pos);
      camera.lookAt(look);
    },
  };
}
