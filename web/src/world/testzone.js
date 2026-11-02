// Builds everything you see in a world: sky and light, terrain, water, trees, bushes, boulders,
// grass, landmarks, clouds (or a sea of clouds below floating worlds), pollen and fog.
// buildZone(gfx, zone) -> { zone, update(dt, focus, camPos), dispose() }.
// Textures are generated once per zone and reused (menu backdrop -> play -> back).
import * as THREE from "three";
import { createTextures } from "./textures.js";
import { createTerrainMaterial, buildTerrain } from "./terrain.js";
import { createGrass } from "./grass.js";
import { createTrees } from "./trees.js";
import { createRocks } from "./rocks.js";
import { createWater } from "./water.js";
import { createClouds, createMotes, createCloudSea } from "./sky_layers.js";
import { buildLandmarks } from "./landmarks.js";

const textureCache = new Map();

export function buildZone(gfx, zone) {
  const B = zone.biome || {};
  // sky, sun and ambient light first: everything below reads the sun direction
  gfx.setEnvironment(B);
  const { scene, quality, sunDirection } = gfx;
  if (!textureCache.has(zone.id)) {
    // keep the last two worlds' textures (menu backdrop + where you are); free the rest
    while (textureCache.size >= 2) {
      const [oldest, t] = textureCache.entries().next().value;
      for (const v of Object.values(t)) v?.isTexture && v.dispose();
      textureCache.delete(oldest);
    }
    textureCache.set(zone.id, createTextures(zone));
  }
  const tex = textureCache.get(zone.id);

  const [fogColor, fogDensity] = B.fog || [0xa6bfd8, 0.00036];
  scene.fog = new THREE.FogExp2(fogColor, fogDensity);
  const terrainMat = createTerrainMaterial(tex, zone);
  const terrain = buildTerrain(zone, terrainMat, quality);
  scene.add(terrain.object3d);
  const water = createWater(zone, scene, tex, quality, sunDirection);
  const trees = createTrees(zone, scene, tex, quality);
  const rocks = createRocks(zone, scene, tex, quality);
  const grass = createGrass(zone, scene, quality, sunDirection);
  const landmarks = buildLandmarks(zone, scene, quality);
  const clouds = B.clouds === false ? null : createClouds(scene, tex, sunDirection, quality, fogColor);
  const cloudSea = B.cloudSea ? createCloudSea(scene, tex, B.cloudSea) : null;
  const motes = quality.motes && zone.ground !== "white" ? createMotes(scene, quality.motes) : null;
  const parts = [terrain, water, trees, rocks, grass, landmarks, clouds, cloudSea, motes].filter(Boolean);

  return {
    zone,
    /** Once per rendered frame. focus = player (or menu camera target), camPos = camera position. */
    update(dt, focus, camPos) {
      water.update(dt);
      trees.update(dt);
      grass.update(dt, focus, camPos);
      clouds?.update(dt, camPos);
      cloudSea?.update(dt, camPos);
      motes?.update(dt, camPos);
    },
    dispose() {
      scene.remove(terrain.object3d);
      for (const p of parts) p.dispose();
      terrainMat.dispose();
    },
  };
}
