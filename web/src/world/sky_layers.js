// Clouds (a high procedural layer that drifts) and floating pollen/dust motes near the camera.
import * as THREE from "three";

export function createClouds(scene, tex, sunDir, quality) {
  const uniforms = {
    uTime: { value: 0 }, tNoise: { value: tex.cloudNoise }, uSun: { value: sunDir.clone() },
    uCam: { value: new THREE.Vector3() }, uHorizon: { value: new THREE.Color(0xa6bfd8) },
  };
  const mat = new THREE.ShaderMaterial({
    uniforms, transparent: true, depthWrite: false, side: THREE.DoubleSide, fog: false,
    vertexShader: /* glsl */ `
      varying vec3 vW;
      void main() { vec4 w = modelMatrix * vec4(position, 1.0); vW = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
    fragmentShader: /* glsl */ `
      uniform float uTime; uniform sampler2D tNoise; uniform vec3 uSun; uniform vec3 uCam; uniform vec3 uHorizon;
      varying vec3 vW;
      void main() {
        vec2 p = vW.xz * 0.00045 + vec2(uTime * 0.004, uTime * 0.0015);
        float n = texture2D(tNoise, p).r * 0.55 + texture2D(tNoise, p * 2.7 + 0.3).r * 0.3 + texture2D(tNoise, p * 7.1 - uTime * 0.002).r * 0.15;
        float d = smoothstep(0.44, 0.74, n);
        if (d < 0.01) discard;
        // thicker = darker underside; sun-facing edges glow
        float shade = mix(1.0, 0.72, smoothstep(0.6, 1.0, d));
        vec3 col = vec3(1.0, 0.98, 0.95) * shade + vec3(0.12, 0.1, 0.06) * max(0.0, uSun.y) * (1.0 - d);
        float dist = length(vW.xz - uCam.xz);
        col = mix(col, uHorizon, smoothstep(900.0, 3000.0, dist));
        float a = d * 0.92 * (1.0 - smoothstep(2200.0, 3400.0, dist));
        gl_FragColor = vec4(col, a);
        #include <colorspace_fragment>
      }`,
  });
  const geo = new THREE.PlaneGeometry(8000, 8000, 1, 1);
  geo.rotateX(Math.PI / 2);
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.y = 480;
  mesh.renderOrder = -1;
  mesh.frustumCulled = false;
  mesh.userData.noAO = true;
  scene.add(mesh);
  return {
    update(dt, camPos) {
      uniforms.uTime.value += dt;
      uniforms.uCam.value.copy(camPos);
      mesh.position.x = camPos.x;
      mesh.position.z = camPos.z;
    },
    dispose() { scene.remove(mesh); geo.dispose(); mat.dispose(); },
  };
}

/** Pollen / dust drifting in the light around the camera. */
export function createMotes(scene, count = 500) {
  const BOX = 26;
  const pos = new Float32Array(count * 3), seed = new Float32Array(count);
  for (let i = 0; i < count; i++) {
    pos.set([Math.random() * BOX, Math.random() * BOX * 0.5, Math.random() * BOX], i * 3);
    seed[i] = Math.random();
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
  geo.setAttribute("seed", new THREE.BufferAttribute(seed, 1));
  const uniforms = { uTime: { value: 0 }, uCam: { value: new THREE.Vector3() }, uBox: { value: BOX } };
  const mat = new THREE.ShaderMaterial({
    uniforms, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: /* glsl */ `
      uniform float uTime; uniform vec3 uCam; uniform float uBox; attribute float seed; varying float vA;
      void main() {
        vec3 p = position + vec3(uTime * 0.35, sin(uTime * 0.5 + seed * 6.3) * 0.6, uTime * 0.18 + seed * 2.0);
        vec3 origin = uCam - vec3(uBox * 0.5, uBox * 0.15, uBox * 0.5);
        p = origin + mod(p - origin, vec3(uBox, uBox * 0.5, uBox));
        vec4 mv = viewMatrix * vec4(p, 1.0);
        float d = -mv.z;
        vA = (0.5 + 0.5 * sin(uTime * 2.0 + seed * 20.0)) * smoothstep(0.5, 2.0, d) * (1.0 - smoothstep(9.0, 13.0, d));
        gl_PointSize = (1.0 + seed * 1.5) * 5.0 / max(d, 0.5);
        gl_Position = projectionMatrix * mv;
      }`,
    fragmentShader: /* glsl */ `
      varying float vA;
      void main() { float r = length(gl_PointCoord - 0.5); gl_FragColor = vec4(1.0, 0.95, 0.8, smoothstep(0.5, 0.0, r) * vA * 0.3); }`,
  });
  const pts = new THREE.Points(geo, mat);
  pts.frustumCulled = false;
  pts.layers.set(1);
  scene.add(pts);
  return {
    update(dt, camPos) { uniforms.uTime.value += dt; uniforms.uCam.value.copy(camPos); },
    dispose() { scene.remove(pts); geo.dispose(); mat.dispose(); },
  };
}
