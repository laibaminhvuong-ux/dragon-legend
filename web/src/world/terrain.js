// Terrain: a detailed mesh for the play area, a coarse mesh for the far mountains, and the
// splatting shader (grass / dirt / sand / layered rock on cliffs / snow on peaks).
import * as THREE from "three";

/** Shared GLSL: triplanar rock with sandstone strata. Needs uniforms tRock, tRockN. */
export const ROCK_GLSL = /* glsl */ `
vec3 triplanarRock(vec3 p, vec3 n) {
  vec3 w = pow(abs(n), vec3(4.0)); w /= (w.x + w.y + w.z);
  vec3 cx = texture2D(tRock, vec2(p.z * 0.07, p.y * 0.11)).rgb;
  vec3 cy = texture2D(tRock, p.xz * 0.07).rgb;
  vec3 cz = texture2D(tRock, vec2(p.x * 0.07, p.y * 0.11)).rgb;
  vec3 c = cx * w.x + cy * w.y + cz * w.z;
  // broad red/ochre bands like desert buttes
  float band = smoothstep(0.2, 0.8, sin(p.y * 0.18 + cy.r * 4.0) * 0.5 + 0.5);
  return c * mix(vec3(0.92, 0.9, 0.88), vec3(1.08, 0.93, 0.8), band * 0.7);
}`;

function patchShader(material, uniforms, fragmentBody, { wantsRock = true, normalBody = "" } = {}) {
  material.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, uniforms);
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vWPos;\nvarying vec3 vWNormal;")
      .replace("#include <fog_vertex>", `#include <fog_vertex>
        vec4 wp4 = vec4(transformed, 1.0);
        #ifdef USE_INSTANCING
          wp4 = instanceMatrix * wp4;
        #endif
        vWPos = (modelMatrix * wp4).xyz;
        vec3 on = objectNormal;
        #ifdef USE_INSTANCING
          on = mat3(instanceMatrix) * on;
        #endif
        vWNormal = normalize(mat3(modelMatrix) * on);`);
    const decl = Object.keys(uniforms).map((k) => {
      const v = uniforms[k].value;
      const type = v && v.isTexture ? "sampler2D" : v && v.isVector3 ? "vec3" : v && v.isColor ? "vec3" : "float";
      return `uniform ${type} ${k};`;
    }).join("\n");
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", `#include <common>\nvarying vec3 vWPos;\nvarying vec3 vWNormal;\n${decl}\n${wantsRock ? ROCK_GLSL : ""}`)
      .replace("#include <map_fragment>", fragmentBody)
      .replace("#include <normal_fragment_maps>", "#include <normal_fragment_maps>\n" + normalBody);
  };
}
export { patchShader };

export function createTerrainMaterial(tex, zone) {
  const m = new THREE.MeshStandardMaterial({ roughness: 0.93, metalness: 0, normalMap: tex.groundNormal, normalScale: new THREE.Vector2(0.9, 0.9), envMapIntensity: 0.7 });
  patchShader(m, {
    tGrass: { value: tex.grass }, tDirt: { value: tex.dirt }, tRock: { value: tex.rock }, tSand: { value: tex.sand },
    tZone: { value: tex.zoneMap }, uZoneSize: { value: tex.zoneMapSize }, uWater: { value: zone.water ? zone.water.level : -999 },
    tRockN: { value: tex.rockNormal },
  }, /* glsl */ `
    vec3 P = vWPos; vec3 N = normalize(vWNormal);
    vec4 zm = texture2D(tZone, P.xz / uZoneSize + 0.5);
    // two scales of each ground texture, mixed, so the repeat doesn't show
    vec3 grass = mix(texture2D(tGrass, P.xz * 0.21).rgb, texture2D(tGrass, P.xz * 0.037).rgb, 0.45);
    grass *= mix(vec3(0.86, 0.92, 0.78), vec3(1.12, 1.06, 0.88), zm.g);
    vec3 dirt = mix(texture2D(tDirt, P.xz * 0.24).rgb, texture2D(tDirt, P.xz * 0.05).rgb, 0.4);
    vec3 sand = texture2D(tSand, P.xz * 0.3).rgb;
    float breakup = texture2D(tGrass, P.xz * 0.011).g * 2.0 - 0.6;
    vec3 col = mix(grass, dirt, smoothstep(0.42, 0.62, zm.r + (breakup - 0.2) * 0.25));
    float slope = 1.0 - N.y;
    float rockW = smoothstep(0.17, 0.26, slope + (breakup - 0.2) * 0.05);
    col = mix(col, triplanarRock(P, N), rockW);
    float sandW = smoothstep(uWater + 1.1, uWater + 0.35, P.y) * zm.b;
    col = mix(col, sand, sandW);
    // wet band and lakebed
    col *= mix(1.0, 0.55, smoothstep(uWater + 0.12, uWater - 0.3, P.y) * zm.b);
    // snow caps on the far mountains
    float snowW = smoothstep(120.0, 160.0, P.y + breakup * 25.0) * smoothstep(0.3, 0.75, N.y);
    col = mix(col, vec3(0.86, 0.89, 0.95), snowW * 0.95);
    diffuseColor.rgb *= col;
  `, { normalBody: CLIFF_NORMALS });
  return m;
}

/** Cliffs: triplanar rock bump map (world space, whiteout blend), mixed in where the ground is steep. */
export const CLIFF_NORMALS = /* glsl */ `
  {
    vec3 Nw = normalize(vWNormal);
    float steep = smoothstep(0.15, 0.3, 1.0 - Nw.y);
    if (steep > 0.001) {
      vec3 w = pow(abs(Nw), vec3(4.0)); w /= (w.x + w.y + w.z);
      vec3 tx = texture2D(tRockN, vec2(vWPos.z * 0.07, vWPos.y * 0.11)).xyz * 2.0 - 1.0;
      vec3 ty = texture2D(tRockN, vWPos.xz * 0.07).xyz * 2.0 - 1.0;
      vec3 tz = texture2D(tRockN, vec2(vWPos.x * 0.07, vWPos.y * 0.11)).xyz * 2.0 - 1.0;
      tx.xy *= 1.6; ty.xy *= 1.6; tz.xy *= 1.6;
      vec3 nX = vec3(tx.xy + Nw.zy, abs(tx.z) * Nw.x);
      vec3 nY = vec3(ty.xy + Nw.xz, abs(ty.z) * Nw.y);
      vec3 nZ = vec3(tz.xy + Nw.xy, abs(tz.z) * Nw.z);
      vec3 wn = normalize(nX.zyx * w.x + nY.xzy * w.y + nZ.xyz * w.z);
      vec3 vn = normalize((viewMatrix * vec4(wn, 0.0)).xyz);
      normal = normalize(mix(normal, vn, steep));
    }
  }`;

/** Plane mesh following heightAt. uv = world xz (for the detail normal map). */
function heightMesh(zone, size, segs, cx, cz, { skirt = 0, sink = null } = {}) {
  const geo = new THREE.PlaneGeometry(size, size, segs, segs);
  geo.rotateX(-Math.PI / 2);
  const p = geo.attributes.position, uv = geo.attributes.uv;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i) + cx, z = p.getZ(i) + cz;
    let h = zone.heightAt(x, z);
    if (sink) h -= sink(x, z);
    p.setXYZ(i, x, h, z);
    uv.setXY(i, x * 0.23, z * 0.23);
  }
  geo.computeVertexNormals();
  if (skirt) {
    // drop the outer ring of vertices so no gap shows against the far mesh
    const row = segs + 1;
    for (let i = 0; i < row; i++) for (const idx of [i, segs * row + i, i * row, i * row + segs]) p.setY(idx, p.getY(idx) - skirt);
  }
  geo.computeBoundingSphere();
  return geo;
}

export function buildTerrain(zone, material, quality) {
  const group = new THREE.Group();
  const nearSize = zone.size + 120;
  const nearSegs = quality.terrainSegments;
  const near = new THREE.Mesh(heightMesh(zone, nearSize, nearSegs, 0, 0, { skirt: 30 }), material);
  near.receiveShadow = true;
  near.castShadow = quality.shadows;
  group.add(near);
  // surrounding ranges at medium detail, then the far horizon coarse; each is sunk out of sight
  // where the finer mesh covers it (skirts hide the seams)
  const inside = (half, depth) => (x, z) => (Math.abs(x) < half && Math.abs(z) < half ? depth : 0);
  const midSize = 2600;
  const mid = new THREE.Mesh(heightMesh(zone, midSize, quality.midSegments, 0, 0, { skirt: 40, sink: inside(nearSize / 2 - 20, 6) }), material);
  const far = new THREE.Mesh(heightMesh(zone, 9000, quality.farSegments, 0, 0, { sink: inside(midSize / 2 - 60, 12) }), material);
  group.add(mid, far);
  return { object3d: group, dispose() { near.geometry.dispose(); mid.geometry.dispose(); far.geometry.dispose(); } };
}
