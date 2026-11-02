// Physically based daytime sky (three's Sky: Rayleigh/Mie scattering with a sun disc) and the
// image-based lighting baked from it, so everything picks up sky-coloured ambient light and
// reflections. One sun direction drives the sky, the sun light, the water and the clouds.
import * as THREE from "three";
import { Sky } from "../../vendor/three/addons/objects/Sky.js";

export const SUN = { elevation: 34, azimuth: 205 }; // degrees: mid-afternoon, sun behind the start view

export function sunDirection() {
  const phi = THREE.MathUtils.degToRad(90 - SUN.elevation), theta = THREE.MathUtils.degToRad(SUN.azimuth);
  return new THREE.Vector3().setFromSphericalCoords(1, phi, theta);
}

/** @param maxBrightness clamp for the sun disc (the baked lighting needs a low one or it floods). */
function makeSky(sun, maxBrightness = 2.5) {
  const sky = new Sky();
  const u = sky.material.uniforms;
  u.turbidity.value = 2.2;
  u.rayleigh.value = 1.8;
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

/** Adds the sky to the scene and sets scene.environment. Returns { update(camera), dispose() }. */
export function createSky(renderer, scene) {
  const sun = sunDirection();
  const sky = makeSky(sun);
  sky.frustumCulled = false;
  sky.userData.noAO = true;
  scene.add(sky);

  // environment: the sky above, a sunlit grass/earth tone below (bounce light)
  const envScene = new THREE.Scene();
  const envSky = makeSky(sun, 1.0);
  envSky.scale.setScalar(900);
  envScene.add(envSky);
  const ground = new THREE.Mesh(new THREE.CircleGeometry(400, 32).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x4d5a33 }));
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
