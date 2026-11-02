// Grass: tiles of instanced blades around the player, swaying in the wind and fading out with
// distance. Blades only grow where the ground is grass (same rules as zone.surfaceAt).
import * as THREE from "three";
import { rng } from "../game/noise.js";

const TILE = 16;

function bladeGeometry() {
  // 2 segments + tip, bent forward slightly; height 1, width 1 (scaled per instance)
  const pos = [-0.5, 0, 0, 0.5, 0, 0, -0.36, 0.5, 0.06, 0.36, 0.5, 0.06, 0, 1, 0.2];
  const col = [0.32, 0.32, 0.32, 0.32, 0.32, 0.32, 0.7, 0.7, 0.7, 0.7, 0.7, 0.7, 1, 1, 1];
  const g = new THREE.BufferGeometry();
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute("color", new THREE.Float32BufferAttribute(col, 3));
  g.setAttribute("normal", new THREE.Float32BufferAttribute([0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0], 3));
  g.setIndex([0, 1, 2, 2, 1, 3, 2, 3, 4]);
  return g;
}

export function createGrass(zone, scene, quality, sunDir) {
  const density = quality.grassDensity; // blades per m^2
  if (!density) return { update() {}, dispose() {} };
  const radius = quality.grassTiles; // tiles each side of the player
  const perTile = Math.round(TILE * TILE * density);
  const uniforms = { uTime: { value: 0 }, uCam: { value: new THREE.Vector3() }, uFade: { value: new THREE.Vector2(radius * TILE * 0.55, radius * TILE * 0.95) } };
  const mat = new THREE.MeshStandardMaterial({ vertexColors: true, side: THREE.DoubleSide, roughness: 0.75, color: 0xffffff, envMapIntensity: 0.6 });
  mat.onBeforeCompile = (s) => {
    Object.assign(s.uniforms, uniforms);
    s.vertexShader = s.vertexShader
      .replace("#include <common>", "#include <common>\nuniform float uTime;\nuniform vec3 uCam;\nuniform vec2 uFade;")
      .replace("#include <project_vertex>", /* glsl */ `
        vec4 mvPosition = vec4(transformed, 1.0);
        mvPosition = instanceMatrix * mvPosition;
        vec3 root = vec3(instanceMatrix[3][0], instanceMatrix[3][1], instanceMatrix[3][2]);
        float h = position.y;
        float gust = sin(uTime * 0.7 + root.x * 0.035 + root.z * 0.02) * 0.5 + 0.5;
        float sway = sin(uTime * 2.3 + root.x * 0.6 + root.z * 0.4) * 0.12 + gust * 0.32;
        mvPosition.xz += vec2(0.8, 0.6) * sway * h * h * (mvPosition.y - root.y + 0.2);
        float dist = distance(root, uCam);
        float keep = 1.0 - smoothstep(uFade.x, uFade.y, dist);
        mvPosition.y = root.y + (mvPosition.y - root.y) * keep;
        mvPosition = modelViewMatrix * mvPosition;
        gl_Position = projectionMatrix * mvPosition;`);
    // both sides lit like the ground (no black back faces)
    s.fragmentShader = s.fragmentShader.replace("#include <normal_fragment_begin>", "#include <normal_fragment_begin>\n  normal = normalize(vNormal);");
  };

  const geo = bladeGeometry();
  const group = new THREE.Group();
  scene.add(group);
  const tiles = new Map(); // "tx,tz" -> mesh
  const pool = [];
  const queue = [];
  const m = new THREE.Matrix4(), q = new THREE.Quaternion(), e = new THREE.Euler(), s = new THREE.Vector3(), v = new THREE.Vector3(), c = new THREE.Color();
  const half = zone.size / 2;

  function fillTile(mesh, tx, tz) {
    // sample the ground on a 1 m grid once, then place blades by interpolation (fast)
    const G = TILE + 1, x0 = tx * TILE, z0 = tz * TILE;
    const hs = new Float32Array(G * G), ok = new Float32Array(G * G), dirt = new Float32Array(G * G);
    for (let j = 0; j < G; j++) for (let i = 0; i < G; i++) hs[j * G + i] = zone.heightAt(x0 + i, z0 + j);
    for (let j = 0; j < G; j++) for (let i = 0; i < G; i++) {
      const k = j * G + i;
      const dx = (hs[j * G + Math.min(G - 1, i + 1)] - hs[j * G + Math.max(0, i - 1)]) / 2;
      const dz = (hs[Math.min(G - 1, j + 1) * G + i] - hs[Math.max(0, j - 1) * G + i]) / 2;
      const ny = 1 / Math.hypot(dx, 1, dz);
      const w = zone.water;
      const lakeD = w ? Math.hypot(x0 + i - w.x, z0 + j - w.z) : 1e9;
      const wet = w && hs[k] < w.level + 0.8 && lakeD < w.radius * 1.5;
      ok[k] = ny > 0.8 && !wet ? 1 : 0;
      dirt[k] = zone.dirtAt(x0 + i, z0 + j);
    }
    const lerp2 = (arr, fx, fz) => {
      const i = Math.min(G - 2, Math.floor(fx)), j = Math.min(G - 2, Math.floor(fz)), u = fx - i, w = fz - j;
      return (arr[j * G + i] * (1 - u) + arr[j * G + i + 1] * u) * (1 - w) + (arr[(j + 1) * G + i] * (1 - u) + arr[(j + 1) * G + i + 1] * u) * w;
    };
    const r = rng((tx * 73856093) ^ (tz * 19349663));
    let n = 0;
    for (let b = 0; b < perTile; b++) {
      const fx = r() * TILE, fz = r() * TILE;
      const x = x0 + fx, z = z0 + fz;
      if (Math.abs(x) > half + 40 || Math.abs(z) > half + 40) continue;
      if (lerp2(ok, fx, fz) < 0.99) continue;
      const d = lerp2(dirt, fx, fz);
      if (r() < d * 1.4) continue; // thin out on bare earth
      const y = lerp2(hs, fx, fz) - 0.02;
      const tall = 0.16 + r() * 0.26 + (1 - d) * 0.16;
      e.set((r() - 0.5) * 0.5, r() * Math.PI * 2, (r() - 0.5) * 0.5);
      q.setFromEuler(e);
      m.compose(v.set(x, y, z), q, s.set(0.028 + r() * 0.02, tall, 1));
      mesh.setMatrixAt(n, m);
      const dry = r() * 0.35 + d * 0.5;
      c.setRGB(0.2 + dry * 0.25 + r() * 0.04, 0.34 + dry * 0.12 + r() * 0.06, 0.08 + dry * 0.05);
      mesh.setColorAt(n, c);
      n++;
    }
    mesh.count = n;
    mesh.instanceMatrix.needsUpdate = true;
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    mesh.computeBoundingSphere();
  }

  function getMesh() {
    const mesh = pool.pop() || new THREE.InstancedMesh(geo, mat, perTile);
    mesh.receiveShadow = true;
    mesh.castShadow = false;
    mesh.frustumCulled = true;
    mesh.userData.noAO = true;
    mesh.layers.set(1);
    if (!mesh.instanceColor) mesh.setColorAt(0, c.setRGB(1, 1, 1));
    return mesh;
  }

  let lastKey = "";
  return {
    /** focus = player position. Builds at most `budget` new tiles per call. */
    update(dt, focus, camPos) {
      uniforms.uTime.value += dt;
      uniforms.uCam.value.copy(camPos);
      const ftx = Math.floor(focus.x / TILE), ftz = Math.floor(focus.z / TILE);
      const key = ftx + "," + ftz;
      if (key !== lastKey) {
        lastKey = key;
        const want = new Set();
        for (let dz = -radius; dz <= radius; dz++) for (let dx = -radius; dx <= radius; dx++) {
          if (dx * dx + dz * dz > (radius + 0.5) ** 2) continue;
          want.add(ftx + dx + "," + (ftz + dz));
        }
        for (const [k, mesh] of tiles) if (!want.has(k)) { group.remove(mesh); pool.push(mesh); tiles.delete(k); }
        queue.length = 0;
        for (const k of want) if (!tiles.has(k)) queue.push(k);
        // nearest first
        queue.sort((a, b2) => {
          const [ax, az] = a.split(",").map(Number), [bx, bz] = b2.split(",").map(Number);
          return (ax - ftx) ** 2 + (az - ftz) ** 2 - ((bx - ftx) ** 2 + (bz - ftz) ** 2);
        });
      }
      for (let budget = tiles.size === 0 ? 999 : 3; budget > 0 && queue.length; budget--) {
        const k = queue.shift();
        const [tx, tz] = k.split(",").map(Number);
        const mesh = getMesh();
        fillTile(mesh, tx, tz);
        tiles.set(k, mesh);
        group.add(mesh);
      }
    },
    dispose() {
      scene.remove(group);
      geo.dispose();
      mat.dispose();
      for (const mesh of [...tiles.values(), ...pool]) mesh.dispose();
    },
  };
}
