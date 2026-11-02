// Physically based daytime sky (three's Sky: Rayleigh/Mie scattering with a sun disc) and the
// image-based lighting baked from it, so everything picks up sky-coloured ambient light and
// reflections. One sun direction drives the sky, the sun light, the water and the clouds.
import * as THREE from "three";
import { Sky } from "../../vendor/three/addons/objects/Sky.js";

export const SUN = { elevation: 34, azimuth: 205 }; // degrees: mid-afternoon, sun behind the start view

export function sunDirection(elevation = SUN.elevation, azimuth = SUN.azimuth) {
  const phi = THREE.MathUtils.degToRad(90 - elevation), theta = THREE.MathUtils.degToRad(azimuth);
  return new THREE.Vector3().setFromSphericalCoords(1, phi, theta);
}

/** Painted gradient sky for alien worlds (Namek's green sky, Other World, the World of Void's stars). */
function makeGradientSky(cfg, sun, maxBrightness = 4) {
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: {
      uTop: { value: new THREE.Color(cfg.top) }, uHorizon: { value: new THREE.Color(cfg.horizon) }, uBottom: { value: new THREE.Color(cfg.bottom ?? cfg.horizon) },
      uSun: { value: sun.clone() }, uSunColor: { value: new THREE.Color(cfg.sunColor ?? 0xffffff) }, uStars: { value: cfg.stars ? 1 : 0 }, uMax: { value: maxBrightness },
    },
    vertexShader: /* glsl */ `
      varying vec3 vDir;
      void main() { vDir = normalize((modelMatrix * vec4(position, 1.0)).xyz - cameraPosition); gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0); }`,
    fragmentShader: /* glsl */ `
      uniform vec3 uTop, uHorizon, uBottom, uSun, uSunColor; uniform float uStars, uMax;
      varying vec3 vDir;
      float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
      void main() {
        vec3 d = normalize(vDir);
        vec3 col = d.y > 0.0 ? mix(uHorizon, uTop, pow(smoothstep(0.0, 0.85, d.y), 0.7)) : mix(uHorizon, uBottom, smoothstep(0.0, -0.3, d.y));
        float s = max(dot(d, uSun), 0.0);
        col += uSunColor * (pow(s, 12.0) * 0.35 + pow(s, 200.0) * 2.0 + smoothstep(0.9993, 0.9996, s) * 6.0);
        if (uStars > 0.5) {
          vec3 g = floor(d * 380.0);
          float h = hash(g);
          col += vec3(0.9, 0.9, 1.0) * step(0.9975, h) * (0.6 + 0.4 * hash(g + 3.1)) * smoothstep(-0.1, 0.3, d.y + 0.4);
        }
        gl_FragColor = vec4(min(col, vec3(uMax)), 1.0);
      }`,
  });
  return new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1), mat);
}

function makeSky(sun, maxBrightness = 2.5, cfg = {}) {
  if (cfg.type === "gradient") return makeGradientSky(cfg, sun, maxBrightness === 1.0 ? 1.2 : 4);
  const sky = new Sky();
  const u = sky.material.uniforms;
  u.turbidity.value = cfg.turbidity ?? 2.2;
  u.rayleigh.value = cfg.rayleigh ?? 1.8;
  u.mieCoefficient.value = 0.002;
  u.mieDirectionalG.value = 0.92;
  u.sunPosition.value.copy(sun);
  // Sky.js outputs gamma-encoded colour; the pipeline expects linear light (it tone-maps and
  // sRGB-encodes at the end), so decode here or the sky washes out to white.
  sky.material.onBeforeCompile = (shader) => {
    shader.fragmentShader = shader.fragmentShader.replace(
      "gl_FragColor = vec4( retColor, 1.0 );",
      `gl_FragColor = vec4( pow( min( retColor, vec3( ${maxBrightness.toFixed(2)} ) ), vec3( 2.2 ) ), 1.0 );`);
  };
  return sky;
}

/**
 * Adds the sky to the scene and sets scene.environment. cfg = a zone's biome.sky
 * ({ type: "physical" | "gradient", elevation, azimuth, ... }). Returns { sun, update(camera), dispose() }.
 */
export function createSky(renderer, scene, cfg = { type: "physical" }, groundColor = 0x4d5a33) {
  const sun = sunDirection(cfg.elevation ?? SUN.elevation, cfg.azimuth ?? SUN.azimuth);
  const sky = makeSky(sun, 2.5, cfg);
  sky.frustumCulled = false;
  sky.userData.noAO = true;
  scene.add(sky);

  // environment: the sky above, a sunlit grass/earth tone below (bounce light)
  const envScene = new THREE.Scene();
  const envSky = makeSky(sun, 1.0, cfg);
  envSky.scale.setScalar(900);
  envScene.add(envSky);
  const ground = new THREE.Mesh(new THREE.CircleGeometry(400, 32).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: groundColor }));
  ground.position.y = -12;
  envScene.add(ground);
  // automated test browsers run on a software GPU where baking this is very slow to tear down,
  // so they light with the hemisphere light only
  const automated = typeof navigator !== "undefined" && navigator.webdriver;
  let env = { texture: null, dispose() {} };
  if (!automated) {
    const pmrem = new THREE.PMREMGenerator(renderer);
    env = pmrem.fromScene(envScene, 0.02, 0.1, 2000);
    pmrem.dispose();
  }
  scene.environment = env.texture;
  envSky.geometry.dispose(); envSky.material.dispose(); ground.geometry.dispose(); ground.material.dispose();

  return {
    sun,
    /** Keeps the sky box centred on the camera and inside its far plane. */
    update(camera) {
      sky.position.copy(camera.position);
      sky.scale.setScalar(camera.far * 0.95);
    },
    dispose() {
      scene.remove(sky);
      sky.geometry.dispose();
      sky.material.dispose();
      env.dispose();
      scene.environment = null;
    },
  };
}
