import assert from 'node:assert/strict';
import { createGame, emptyIntents } from '../web/src/game/game.js';
import { newSlot } from '../web/src/game/schema.js';
import { defaultLook } from '../web/src/game/look.js';
import { MOVEMENT as M } from '../web/src/data/movement.js';
const dt = 1 / 60;
const fresh = () => createGame(0, newSlot(defaultLook('Saiyan')));
const step = (g, intent = {}, n = 1) => { for (let i = 0; i < n; i++) g.update(dt, { ...emptyIntents(), ...intent }); };
let count = 0;
const test = (name, fn) => { fn(); console.log('ok', name); count++; };
test('diagonal input is normalized', () => {
  const a = fresh(), b = fresh();
  step(a, { moveZ: 1 }, 120); step(b, { moveX: 1, moveZ: 1 }, 120);
  assert.ok(Math.abs(Math.hypot(b.player.vel.x, b.player.vel.z) - a.player.runSpeed) < 1e-8);
});
test('dash pays once, follows input, respects cooldown and ends', () => {
  const g = fresh(), p = g.player, start = { ...p.pos };
  step(g, { dash: true, moveX: 1 });
  assert.equal(p.ki, p.maxKi - M.dashCost); assert.ok(p.dashing);
  step(g, { dash: true, moveX: 1 }, 9);
  assert.equal(p.ki, p.maxKi - M.dashCost);
  assert.ok(p.pos.x - start.x > 4); assert.equal(p.pos.z, start.z);
  step(g, {}, 3); assert.equal(p.dashing, false);
  step(g, {}, 60); const ki = p.ki;
  step(g, { dash: true }); assert.equal(p.ki, ki - M.dashCost);
});
test('dash refuses insufficient ki and stun cancels actions', () => {
  const g = fresh(), p = g.player;
  p.ki = 0; step(g, { dash: true }); assert.equal(p.dashing, false);
  p.ki = p.maxKi; step(g, { dash: true }); p.stun = 1;
  step(g, { flight: true, charge: true, dash: true });
  assert.equal(p.dashing, false); assert.equal(p.flying, false); assert.equal(p.charging, false);
});
test('flight ascends, hovers, drains ki, descends and lands', () => {
  const g = fresh(), p = g.player, y = p.pos.y;
  step(g, { flight: true, ascend: true }); step(g, { ascend: true }, 59);
  assert.ok(p.flying && !p.onGround); assert.ok(p.pos.y > y + 9);
  assert.ok(Math.abs(p.ki - (p.maxKi - M.flightDrain)) < 1e-8);
  const height = p.pos.y; step(g, {}, 60); assert.equal(p.pos.y, height);
  step(g, { descend: true }, 65); assert.ok(!p.flying && p.onGround);
});
test('empty ki drops flight and airborne charge cannot refill it', () => {
  const g = fresh(), p = g.player;
  step(g, { flight: true, ascend: true }, 1); step(g, { ascend: true }, 30);
  p.ki = M.flightDrain * dt / 2;
  step(g, { charge: true }); assert.equal(p.flying, false); assert.equal(p.charging, false);
  assert.ok(p.vel.y < 0);
});
test('ground charge refills at tuned rate, caps and suppresses movement', () => {
  const g = fresh(), p = g.player; p.ki = 10;
  step(g, { charge: true, moveZ: 1, jump: true, dash: true }, 60);
  assert.ok(p.charging && p.onGround); assert.equal(p.ki, 10 + M.chargeRate);
  assert.equal(p.vel.z, 0); step(g, { charge: true }, 600); assert.equal(p.ki, p.maxKi);
  step(g); assert.equal(p.charging, false);
});
test('flight toggle falls, boundaries clamp and runtime state is not saved', () => {
  const g = fresh(), p = g.player;
  step(g, { flight: true, ascend: true }); step(g, { ascend: true }, 30);
  step(g, { flight: true }); assert.equal(p.flying, false); assert.ok(p.vel.y < 0);
  p.pos.x = g.zone.size; step(g, { moveX: 1, dash: true });
  assert.equal(p.pos.x, g.zone.size / 2 - 1); assert.equal(p.vel.x, 0);
  assert.equal(g.toSave().dashRemaining, undefined);
});
test('airborne saves restore falling without a free jump or charge tick', () => {
  const g = fresh(); step(g, { flight: true, ascend: true }); step(g, { ascend: true }, 60);
  const restored = createGame(0, structuredClone(g.toSave()));
  assert.equal(restored.player.onGround, false);
  step(restored, { jump: true, charge: true });
  assert.equal(restored.player.charging, false); assert.ok(restored.player.vel.y < 0);
});
test('world gravity scales the jump acceleration', () => {
  const normal = fresh();
  const slot = newSlot(defaultLook('Saiyan')); slot.zone = 'king_kai';
  const heavy = createGame(0, slot);
  step(normal, { jump:true });step(heavy, { jump:true });
  assert.ok(heavy.player.vel.y < normal.player.vel.y - 3);
});
console.log(`${count} movement checks passed`);
