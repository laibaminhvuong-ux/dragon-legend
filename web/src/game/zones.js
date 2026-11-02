// Zone layouts as pure data + functions, so gameplay (ground height, bounds) works without
// rendering and the renderer in world/ draws the same ground. Units: metres, Y up.
export const ZONES = {
  test: {
    id: "test",
    name: "Training Plains",
    size: 400, // square, centred on 0,0
    spawn: { x: 0, z: 0 },
    sky: 0x87b8e8,
    ground: 0x6aa84f,
    /** Ground height at x,z: gentle rolling hills, flat near spawn. */
    heightAt(x, z) {
      const d = Math.hypot(x, z);
      const flat = Math.min(1, Math.max(0, (d - 25) / 40));
      return flat * (3 * Math.sin(x * 0.03) * Math.cos(z * 0.025) + 1.5 * Math.sin((x + z) * 0.07));
    },
  },
};

export function getZone(id) {
  return ZONES[id] || ZONES.test;
}
