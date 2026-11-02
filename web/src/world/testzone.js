// Builds everything you see in a zone: terrain, lake, trees, bushes, boulders, grass, clouds,
// pollen and fog. buildZone(gfx, zone) -> { update(dt, focus, camPos), dispose() }.
// Textures are generated once per zone and reused (menu backdrop -> play -> back).
import * as THREE from "three";
import { createTextures } from "./textures.js";
import { createTerrainMaterial, buildTerrain } from "./terrain.js";
import { createGrass } from "./grass.js";
import { createTrees } from "./trees.js";
import { createRocks } from "./rocks.js";
import { createWater } from "./water.js";
import { createClouds, createMotes } from "./sky_layers.js";

const textureCache = new Map();

export function buildZone(gfx, zone) {
  const { scene, quality, sunDirection } = gfx;
  if (!textureCache.has(zone.id)) textureCache.set(zone.id, createTextures(zone));
  const tex = textureCache.get(zone.id);

  scene.fog = new THREE.FogExp2(0xa6bfd8, 0.00036);
  const terrainMat = createTerrainMaterial(tex, zone);
  const terrain = buildTerrain(zone, terrainMat, quality);
  scene.add(terrain.object3d);
  const water = createWater(zone, scene, tex, quality, sunDirection);
  const trees = createTrees(zone, scene, tex, quality);
  const rocks = createRocks(zone, scene, tex, quality);
  const grass = createGrass(zone, scene, quality, sunDirection);
  const clouds = createClouds(scene, tex, sunDirection, quality);
  const motes = quality.motes ? createMotes(scene, quality.motes) : null;
  const parts = [terrain, water, trees, rocks, grass, clouds, motes].filter(Boolean);

  return {
    zone,
    /** Once per rendered frame. focus = player (or menu camera target), camPos = camera position. */
    update(dt, focus, camPos) {
      water.update(dt);
      trees.update(dt);
      grass.update(dt, focus, camPos);
      clouds.update(dt, camPos);
      motes?.update(dt, camPos);
    },
    dispose() {
      scene.remove(terrain.object3d);
      for (const p of parts) p.dispose();
      terrainMat.dispose();
    },
  };
}
