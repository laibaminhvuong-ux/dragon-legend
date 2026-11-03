// Transformation auras: two shells of rising, flickering flame (shader), optional lightning that
// crackles around the body (Super Saiyan 2/3, Rage, Black...) and rising glitter (God, Blue,
// Ultimate). Looks come from data/form_looks.js. The aura sits on a model root (origin at the feet).
import * as THREE from "three";

const NOISE = /* glsl */ `
  float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
  float n3(vec3 x) {
    vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
  }`;

const VERT = /* glsl */ `
  uniform float uTime, uFlicker, uCalm, uBurst;
  varying vec3 vN, vView, vP;
  ${NOISE}
  void main() {
    vec3 p = position; // unit sphere
    float h = p.y;
    // flame silhouette: narrow at the feet, full at the chest, drawn up into tongues above the head
    float r = mix(0.62, 1.0, smoothstep(-1.0, -0.2, h)) * mix(1.0, 0.55, smoothstep(0.35, 1.0, h));
    p.xz *= r;
    float t = uTime * mix(2.6, 1.1, uCalm) * (0.6 + uFlicker * 0.6);
    float n = n3(vec3(p.x * 2.6, p.y * 2.0 - t, p.z * 2.6));
    float tongue = smoothstep(0.1, 1.0, h) * (0.35 + 0.9 * n) * mix(1.0, 0.35, uCalm);
    p.y += tongue * 0.75;
    p += normal * (n - 0.5) * mix(0.16, 0.05, uCalm);
    p *= 1.0 + uBurst * 0.45;
    vP = vec3(position.xz, h).xzy;
    vec4 mv = modelViewMatrix * vec4(p, 1.0);
    vView = -mv.xyz;
    vN = normalMatrix * normal;
    gl_Position = projectionMatrix * mv;
  }`;

const FRAG = /* glsl */ `
  uniform vec3 uColor, uCore;
  uniform float uTime, uIntensity, uFlicker, uCalm, uBurst;
  varying vec3 vN, vView, vP;
  ${NOISE}
  void main() {
    float f = 1.0 - abs(dot(normalize(vN), normalize(vView)));
    float a = atan(vP.z, vP.x);
    float t = uTime * mix(3.2, 1.2, uCalm) * (0.6 + uFlicker * 0.6);
    // vertical streaks of flame running upwards
    float s = n3(vec3(a * 2.5, vP.y * 3.0 - t, 0.5)) * 0.65 + n3(vec3(a * 6.0, vP.y * 7.0 - t * 1.7, 2.0)) * 0.35;
    s = mix(s, 0.62, uCalm * 0.7);
    float edge = pow(f, mix(0.9, 1.6, uCalm));
    // a fill through the whole body of the aura plus brighter licks at the edge
    float flame = smoothstep(0.22, 0.7, s);
    float alpha = (edge * 0.95 + 0.1 * flame) * mix(0.35, 1.0, flame) * smoothstep(-1.0, -0.55, vP.y);
    alpha *= uIntensity * (0.85 + 0.15 * sin(uTime * 23.0) * uFlicker) + uBurst * 0.6;
    vec3 col = mix(uCore, uColor, smoothstep(0.15, 0.8, f));
    gl_FragColor = vec4(col * alpha, alpha);
  }`;

let sphere = null, moteTex = null;
const sharedSphere = () => (sphere ||= new THREE.SphereGeometry(1, 40, 32));
function moteTexture() {
  if (moteTex) return moteTex;
  const c = document.createElement("canvas");
  c.width = c.height = 32;
  const g = c.getContext("2d");
  const gr = g.createRadialGradient(16, 16, 0, 16, 16, 16);
  gr.addColorStop(0, "rgba(255,255,255,1)"); gr.addColorStop(0.35, "rgba(255,255,255,0.5)"); gr.addColorStop(1, "rgba(255,255,255,0)");
  g.fillStyle = gr; g.fillRect(0, 0, 32, 32);
  return (moteTex = new THREE.CanvasTexture(c));
}

function shell(look, scale, intensity, core) {
  const m = new THREE.ShaderMaterial({
    vertexShader: VERT, fragmentShader: FRAG, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    uniforms: {
      uTime: { value: 0 }, uBurst: { value: 0 }, uIntensity: { value: intensity },
      uFlicker: { value: look.flicker ?? 0.8 }, uCalm: { value: look.style === "calm" ? 1 : 0 },
      uColor: { value: new THREE.Color(core ? look.core : look.color) }, uCore: { value: new THREE.Color(look.core ?? 0xffffff) },
    },
  });
  const mesh = new THREE.Mesh(sharedSphere(), m);
  const s = look.size ?? 1;
  mesh.scale.set(0.6 * s * scale, 1.05 * s * scale, 0.55 * s * scale);
  mesh.position.y = 0.92;
  mesh.userData.noAO = true;
  mesh.renderOrder = 20;
  mesh.frustumCulled = false; // the vertex shader stretches it past its bounds
  return mesh;
}

/** An aura for one form look. Add `object3d` to the model root; call update(dt) every frame. */
export function createAura(look) {
  const root = new THREE.Group();
  root.userData.noAO = true;
  const outer = shell(look, 1, 1.0, false), inner = shell(look, 0.8, 0.45, true);
  root.add(outer, inner);
  const mats = [outer.material, inner.material];

  // lightning: a few jagged bolts redrawn every few frames
  let bolts = null, boltClock = 0;
  const SEG = 9, MAX_BOLTS = 4;
  if (look.sparks) {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(new Float32Array(MAX_BOLTS * 2 * SEG * 2 * 3), 3));
    bolts = new THREE.LineSegments(geo, new THREE.LineBasicMaterial({ color: look.sparkColor ?? 0xcfe8ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
    bolts.frustumCulled = false;
    bolts.userData.noAO = true;
    bolts.renderOrder = 21;
    root.add(bolts);
  }
  const redrawBolts = () => {
    const P = bolts.geometry.attributes.position.array;
    P.fill(0);
    const n = look.sparks >= 2 ? 2 + (Math.random() < 0.5 ? 1 : 0) : Math.random() < 0.45 ? 1 : 0;
    let k = 0;
    for (let b = 0; b < n; b++) {
      const a = Math.random() * Math.PI * 2, y = 0.25 + Math.random() * 1.55;
      let x = Math.cos(a) * 0.28, z = Math.sin(a) * 0.22, yy = y;
      const dx = Math.cos(a) * 0.03, dz = Math.sin(a) * 0.03, dy = (Math.random() - 0.5) * 0.12;
      for (let s = 0; s < SEG; s++) {
        const nx = x + dx + (Math.random() - 0.5) * 0.07, ny = yy + dy + (Math.random() - 0.5) * 0.09, nz = z + dz + (Math.random() - 0.5) * 0.07;
        for (const off of [0, 0.006]) { // drawn twice, slightly offset, so it reads thicker
          P[k++] = x + off; P[k++] = yy; P[k++] = z; P[k++] = nx + off; P[k++] = ny; P[k++] = nz;
        }
        x = nx; yy = ny; z = nz;
      }
    }
    bolts.geometry.attributes.position.needsUpdate = true;
  };

  // glitter rising around the body
  let motes = null;
  const MOTES = 36, moteV = [];
  if (look.motes) {
    const geo = new THREE.BufferGeometry();
    const P = new Float32Array(MOTES * 3);
    for (let i = 0; i < MOTES; i++) {
      const a = Math.random() * Math.PI * 2, r = 0.3 + Math.random() * 0.35;
      P[i * 3] = Math.cos(a) * r; P[i * 3 + 1] = Math.random() * 2.2; P[i * 3 + 2] = Math.sin(a) * r;
      moteV.push(0.4 + Math.random() * 0.8);
    }
    geo.setAttribute("position", new THREE.BufferAttribute(P, 3));
    motes = new THREE.Points(geo, new THREE.PointsMaterial({ color: look.motes, size: 0.05, map: moteTexture(), transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
    motes.frustumCulled = false;
    motes.userData.noAO = true;
    root.add(motes);
  }

  let t = Math.random() * 10, burst = 1;
  return {
    object3d: root,
    setColor(hex) { outer.material.uniforms.uColor.value.setHex(hex); },
    /** A flare, as at the moment of transforming. */
    flare() { burst = 1; },
    update(dt) {
      t += dt;
      burst = Math.max(0, burst - dt * 1.8);
      for (const m of mats) { m.uniforms.uTime.value = t; m.uniforms.uBurst.value = burst * burst; }
      if (bolts && (boltClock -= dt) <= 0) { boltClock = 0.05 + Math.random() * 0.05; redrawBolts(); }
      if (motes) {
        const P = motes.geometry.attributes.position.array;
        for (let i = 0; i < MOTES; i++) {
          P[i * 3 + 1] += moteV[i] * dt;
          if (P[i * 3 + 1] > 2.3) P[i * 3 + 1] = 0;
        }
        motes.geometry.attributes.position.needsUpdate = true;
      }
    },
    dispose() {
      root.removeFromParent();
      for (const m of mats) m.dispose();
      if (bolts) { bolts.geometry.dispose(); bolts.material.dispose(); }
      if (motes) { motes.geometry.dispose(); motes.material.dispose(); }
    },
  };
}
