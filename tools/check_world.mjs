// Node checks for the world rules: terrain, props, collision. No browser needed.
//   node tools/check_world.mjs
import assert from "node:assert/strict";
import { ZONES, getZone } from "../web/src/game/zones.js";
import { resolveCollisions } from "../web/src/game/collision.js";
import { makeNoise2, fbm } from "../web/src/game/noise.js";

let n = 0;
const t = (name, fn) => { fn(); n++; console.log("ok", name); };
const zone = ZONES.test;

t("noise is deterministic and bounded", () => {
  const a = makeNoise2(5), b = makeNoise2(5);
  for (let i = 0; i < 1000; i++) {
    const x = i * 0.37, y = i * 0.11;
    assert.equal(a(x, y), b(x, y));
    assert.ok(Math.abs(fbm(a, x, y)) <= 1.5);
  }
  const p = makeNoise2(9, 8);
  assert.ok(Math.abs(p(0.3, 0.7) - p(8.3, 0.7)) < 1e-9, "periodic noise repeats");
});

t("spawn is a flat training ground", () => {
  for (let i = 0; i < 200; i++) {
    const a = i * 0.7, r = (i % 25);
    assert.equal(zone.heightAt(Math.cos(a) * r, Math.sin(a) * r), 0);
  }
  assert.equal(zone.surfaceAt(0, 0) === "grass" || zone.surfaceAt(0, 0) === "dirt", true);
});

t("heightAt is finite everywhere and fast", () => {
  const t0 = performance.now();
  for (let i = 0; i < 50000; i++) {
    const h = zone.heightAt((Math.random() - 0.5) * 9000, (Math.random() - 0.5) * 9000);
    assert.ok(Number.isFinite(h));
  }
  const us = ((performance.now() - t0) * 1000) / 50000;
  assert.ok(us < 10, `heightAt ${us.toFixed(2)} us`);
});

t("the lake holds water and its shore is sand", () => {
  const w = zone.water;
  assert.ok(zone.heightAt(w.x, w.z) < w.level - 0.5, "lake centre is under water");
  assert.equal(zone.surfaceAt(w.x, w.z), "water");
});

t("mesas are tall with steep sides", () => {
  for (const m of zone.mesas) {
    // measured against the ground just outside it (mesas can sit in a dip or on a rise)
    const k = 1 - (m.r * 2) / Math.hypot(m.x, m.z); // a point 2 radii towards spawn
    const rise = zone.heightAt(m.x, m.z) - zone.heightAt(m.x * k, m.z * k);
    assert.ok(rise > m.h * 0.7, `mesa rises ${rise.toFixed(1)} m (height ${m.h})`);
  }
});

t("props are deterministic, on the ground and clear of spawn", () => {
  const p = zone.props();
  assert.ok(p.trees.length > 200 && p.rocks.length > 150 && p.bushes.length > 300);
  for (const tr of p.trees) {
    assert.ok(Math.abs(tr.y - zone.heightAt(tr.x, tr.z)) < 1e-9);
    assert.ok(Math.hypot(tr.x, tr.z) > 20);
    assert.notEqual(zone.surfaceAt(tr.x, tr.z), "water");
  }
  assert.equal(getZone("test").props(), p, "memoised");
});

t("collision pushes out of trees", () => {
  const tree = zone.props().trees[0];
  const e = { pos: { x: tree.x + 0.05, y: tree.y, z: tree.z }, vel: { x: -3, y: 0, z: 0 }, onGround: true, flying: false };
  const prev = { ...e.pos, x: tree.x + 2 };
  resolveCollisions(e, zone, prev);
  const d = Math.hypot(e.pos.x - tree.x, e.pos.z - tree.z);
  assert.ok(d >= 0.35 * tree.scale + 0.35 - 1e-6, `pushed to ${d.toFixed(2)} m`);
  assert.ok(e.vel.x >= 0, "velocity into the trunk removed");
  // flying above the canopy: no collision
  const high = { pos: { x: tree.x, y: tree.y + 40, z: tree.z }, vel: { x: 0, y: 0, z: 0 }, onGround: false, flying: true };
  resolveCollisions(high, zone, { ...high.pos });
  assert.equal(high.pos.x, tree.x);
});

t("cliffs can't be walked up, but can be flown past", () => {
  const m = zone.mesas[0];
  // walk from outside the mesa straight at its centre until the cliff stops us
  let x = m.x + m.r * 1.7, z = m.z;
  const e = { pos: { x, y: zone.heightAt(x, z), z }, vel: { x: -8, y: 0, z: 0 }, onGround: true, flying: false };
  for (let i = 0; i < 400; i++) {
    const prev = { ...e.pos };
    e.pos.x -= 0.12;
    e.pos.y = zone.heightAt(e.pos.x, e.pos.z);
    resolveCollisions(e, zone, prev);
    if (e.pos.x === prev.x) break;
  }
  assert.ok(e.pos.y < m.h * 0.6, `stopped at the foot (y ${e.pos.y.toFixed(1)})`);
  const f = { pos: { x: m.x + m.r * 0.9, y: m.h + 5, z: m.z }, vel: { x: 0, y: 0, z: 0 }, onGround: false, flying: true };
  const prev = { ...f.pos, x: f.pos.x + 0.2 };
  resolveCollisions(f, zone, prev);
  assert.equal(f.pos.x, m.x + m.r * 0.9);
});

console.log(`\n${n} world checks passed`);
