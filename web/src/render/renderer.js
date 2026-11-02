// WebGL renderer, the scene, lights and quality presets.
import * as THREE from "three";

export const QUALITY = {
  low: { pixelRatio: 0.75, shadows: false, shadowSize: 0, antialias: false, viewDistance: 180 },
  medium: { pixelRatio: 1, shadows: true, shadowSize: 1024, antialias: true, viewDistance: 260 },
  high: { pixelRatio: 2, shadows: true, shadowSize: 2048, antialias: true, viewDistance: 400 },
};

export function createRenderer(canvas, settings, events) {
  // antialias can only be chosen at creation; changing it needs a restart (settings screen can say so)
  const q0 = QUALITY[settings.get("quality")] || QUALITY.high;
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: q0.antialias, powerPreference: "high-performance" });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(65, 1, 0.1, 1000);

  const hemi = new THREE.HemisphereLight(0xcfe6ff, 0x4a5a30, 1.1);
  const sun = new THREE.DirectionalLight(0xfff2dd, 2.2);
  sun.position.set(40, 80, 25);
  sun.shadow.camera.left = sun.shadow.camera.bottom = -40;
  sun.shadow.camera.right = sun.shadow.camera.top = 40;
  sun.shadow.camera.far = 200;
  sun.shadow.bias = -0.0005;
  scene.add(hemi, sun, sun.target);

  let quality = q0;
  function applyQuality() {
    quality = QUALITY[settings.get("quality")] || QUALITY.high;
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, quality.pixelRatio));
    renderer.shadowMap.enabled = quality.shadows;
    sun.castShadow = quality.shadows;
    if (quality.shadows) {
      sun.shadow.mapSize.set(quality.shadowSize, quality.shadowSize);
      sun.shadow.map?.dispose();
      sun.shadow.map = null;
    }
    camera.far = quality.viewDistance;
    camera.updateProjectionMatrix();
    resize();
  }
  function resize() {
    const w = canvas.clientWidth || innerWidth, h = canvas.clientHeight || innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  addEventListener("resize", resize);
  events.on("settings", ({ key }) => key === "quality" && applyQuality());
  applyQuality();

  return {
    THREE,
    renderer,
    scene,
    camera,
    sun,
    get quality() { return quality; },
    /** Keeps the shadow box centred on the player so shadows stay sharp. */
    followSun(target) {
      sun.position.set(target.x + 40, target.y + 80, target.z + 25);
      sun.target.position.set(target.x, target.y, target.z);
    },
    render() { renderer.render(scene, camera); },
  };
}
