// WebGL renderer, scene, camera, sun, sky lighting, post-processing and quality presets.
import * as THREE from "three";
import { createSky } from "./sky.js";
import { createPost } from "./post.js";

/**
 * Quality presets. World modules read these too (grass, water, terrain detail).
 * low = phones / weak laptops; medium = most PCs; high = gaming GPUs (default on desktop).
 */
export const QUALITY = {
  low: { pixelRatio: 0.85, shadows: false, shadowSize: 0, shadowRange: 0, post: false, msaa: 0, ao: false, grassDensity: 0, grassTiles: 0, terrainSegments: 160, midSegments: 110, farSegments: 90, leafDensity: 0.45, waterReflections: false, viewDistance: 2000, motes: 0, antialias: true },
  medium: { pixelRatio: 1, shadows: true, shadowSize: 2048, shadowRange: 45, post: true, msaa: 4, ao: false, grassDensity: 22, grassTiles: 3, terrainSegments: 384, midSegments: 300, farSegments: 220, leafDensity: 1, waterReflections: false, viewDistance: 3200, motes: 300, antialias: false },
  high: { pixelRatio: 1.25, shadows: true, shadowSize: 2048, shadowRange: 48, post: true, msaa: 4, ao: true, grassDensity: 30, grassTiles: 4, terrainSegments: 512, midSegments: 400, farSegments: 220, leafDensity: 1, waterReflections: true, viewDistance: 4000, motes: 500, antialias: false },
};

export function createRenderer(canvas, settings, events) {
  const q0 = QUALITY[settings.get("quality")] || QUALITY.high;
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: q0.antialias, powerPreference: "high-performance", stencil: false });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.85;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xb5c9dc);
  scene.fog = new THREE.FogExp2(0xa6bfd8, 0.00036);
  const camera = new THREE.PerspectiveCamera(62, 1, 0.1, 4000);
  // layer 1 = small detail (grass, pollen) the main camera sees but water reflections skip
  camera.layers.enable(1);
  let sky = createSky(renderer, scene);

  const hemi = new THREE.HemisphereLight(0xcfe3ff, 0x5a5236, 0.35);
  const sun = new THREE.DirectionalLight(0xfff0d8, 3.1);
  sun.shadow.bias = -0.0002;
  sun.shadow.normalBias = 0.03;
  sun.shadow.camera.near = 1;
  sun.shadow.camera.far = 400;
  scene.add(hemi, sun, sun.target);

  let quality = q0, post = null;
  // dynamic resolution: the 3D view renders at scale * pixelRatio to hold 60 fps (UI stays sharp)
  const dyn = { scale: 1, min: 0.6, acc: 0, frames: 0, cooldown: 3, upLocked: 0 };
  // automated test browsers render on the CPU: keep their internal resolution tiny so checks run
  // at a usable speed (players never hit this)
  const automated = typeof navigator !== "undefined" && navigator.webdriver;
  if (automated) dyn.min = dyn.scale = 0.3;
  function applyQuality() {
    quality = QUALITY[settings.get("quality")] || QUALITY.high;
    dyn.scale = automated ? 0.3 : 1;
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, quality.pixelRatio) * dyn.scale);
    renderer.shadowMap.enabled = quality.shadows;
    sun.castShadow = quality.shadows;
    if (quality.shadows) {
      const r = quality.shadowRange;
      Object.assign(sun.shadow.camera, { left: -r, right: r, top: r, bottom: -r });
      sun.shadow.camera.updateProjectionMatrix();
      sun.shadow.mapSize.set(quality.shadowSize, quality.shadowSize);
      sun.shadow.map?.dispose();
      sun.shadow.map = null;
    }
    camera.far = quality.viewDistance;
    camera.updateProjectionMatrix();
    post?.dispose();
    post = null;
    resize();
    post = createPost(renderer, scene, camera, quality);
    gfx.post = post;
    // materials compiled for the old shadow settings need recompiling
    scene.traverse((o) => { if (o.material) [].concat(o.material).forEach((m) => (m.needsUpdate = true)); });
  }
  function resize() {
    const w = canvas.clientWidth || innerWidth, h = canvas.clientHeight || innerHeight;
    renderer.setSize(w, h, false);
    post?.setSize(w, h, renderer.getPixelRatio());
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  addEventListener("resize", resize);

  const gfx = {
    THREE,
    /** post-processing chain or null (low quality) */
    post: null,
    renderer,
    scene,
    camera,
    sun,
    /** Unit vector towards the sun (water glints, clouds, shaders). */
    sunDirection: sky.sun.clone(),
    get quality() { return quality; },
    /** Keeps the shadow box centred on the player, snapped to shadow-map texels so edges don't shimmer. */
    followSun(target) {
      const d = gfx.sunDirection;
      if (quality.shadows) {
        const texel = (quality.shadowRange * 2) / quality.shadowSize;
        const right = new THREE.Vector3().crossVectors(d, new THREE.Vector3(0, 1, 0)).normalize();
        const up = new THREE.Vector3().crossVectors(right, d).normalize();
        const t = new THREE.Vector3(target.x, target.y, target.z);
        const a = Math.round(t.dot(right) / texel) * texel, b = Math.round(t.dot(up) / texel) * texel, c = t.dot(d);
        t.copy(right).multiplyScalar(a).addScaledVector(up, b).addScaledVector(d, c);
        sun.target.position.copy(t);
        sun.position.copy(t).addScaledVector(d, 200);
      } else {
        sun.target.position.set(target.x, target.y, target.z);
        sun.position.copy(sun.target.position).addScaledVector(d, 200);
      }
    },
    /** Current dynamic resolution scale (1 = full). */
    get resolutionScale() { return dyn.scale; },
    /**
     * Switches sky, sun and ambient light to a world's look (zone.biome). World modules built after
     * this pick up gfx.sunDirection.
     */
    setEnvironment(biome = {}) {
      sky.dispose();
      const ground = biome.tints?.grass ? new THREE.Color(0x4d5a33).multiply(new THREE.Color(...biome.tints.grass)) : new THREE.Color(biome.ground === "white" ? 0xf0f0f0 : 0x4d5a33);
      sky = createSky(renderer, scene, biome.sky || { type: "physical" }, ground);
      gfx.sunDirection.copy(sky.sun);
      const S = biome.sun || {};
      sun.color.setHex(S.color ?? (biome.sky?.sunColor ?? 0xfff0d8));
      sun.intensity = S.intensity ?? 3.1;
      hemi.color.setHex(biome.sky?.type === "gradient" ? biome.sky.horizon : 0xcfe3ff);
      hemi.intensity = biome.sky?.type === "gradient" ? 0.5 : 0.35;
    },
    render(frameDt = 1 / 60) {
      adapt(frameDt);
      sky.update(camera);
      if (post) post.render(frameDt);
      else renderer.render(scene, camera);
    },
  };
  /** Every 1.5 s: drop resolution if under ~54 fps, creep back up when there is headroom. */
  function adapt(dt) {
    if (!(dt > 0) || dt > 0.25) return;
    dyn.acc += dt; dyn.frames++;
    dyn.cooldown -= dt; dyn.upLocked -= dt;
    if (dyn.acc < 1.5) return;
    const fps = dyn.frames / dyn.acc;
    dyn.acc = 0; dyn.frames = 0;
    if (dyn.cooldown > 0) return;
    let next = dyn.scale;
    if (fps < 54 && dyn.scale > dyn.min) { next = Math.max(dyn.min, dyn.scale - (fps < 40 ? 0.15 : 0.07)); dyn.upLocked = 12; }
    else if (fps > 58.5 && dyn.scale < 1 && dyn.upLocked <= 0) next = Math.min(1, dyn.scale + 0.05);
    if (next !== dyn.scale) {
      dyn.scale = next;
      dyn.cooldown = 1.5;
      renderer.setPixelRatio(Math.min(devicePixelRatio || 1, quality.pixelRatio) * dyn.scale);
      resize();
    }
  }
  events.on("settings", ({ key }) => key === "quality" && (applyQuality(), events.emit("qualityChanged", quality)));
  applyQuality();
  return gfx;
}
