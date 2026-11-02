// Plays the whole story with a bot: every main quest from the Saiyan Saga to Super Hero, plus every
// race's transformation quests and the side quests, travelling between worlds like a player.
// Catches unreachable NPCs, impossible steps, broken unlocks and bad references.
//   node tools/check_story.mjs
import assert from "node:assert/strict";
import { createGame, emptyIntents } from "../web/src/game/game.js";
import { createStory } from "../web/src/game/story.js";
import { newSlot, migrate } from "../web/src/game/schema.js";
import { defaultLook } from "../web/src/game/look.js";
import { QUESTS, NPCS, CHARACTERS } from "../web/src/data/story.js";
import { ZONES } from "../web/src/game/zones.js";
import { createEvents } from "../web/src/core/events.js";
import { xpToNext } from "../web/src/game/progression.js";
import { RACE_ORDER } from "../web/src/data/races.js";

const STEP = 1 / 60;
let checks = 0;
const ok = (name) => { checks++; console.log("ok", name); };

function session(race) {
  const ev = createEvents();
  const log = [];
  ev.on("notify", (n) => log.push(n.text));
  let travelTo = null;
  ev.on("travel", (t) => (travelTo = t.zone));
  const slot = newSlot(defaultLook(race));
  const s = { ev, log, slot, game: null, story: null, grindXP: 0 };
  s.enter = (zoneId) => {
    slot.zone = zoneId;
    slot.position = null;
    s.game = createGame(0, slot, ev);
    s.story = createStory(s.game, ev);
    travelTo = null;
  };
  s.tick = (intents = emptyIntents()) => {
    s.story.update(STEP, intents);
    if (travelTo) { const z = travelTo; s.enter(z); }
  };
  s.at = (x, z, y = null) => {
    const p = s.game.player;
    p.pos.x = x; p.pos.z = z; p.pos.y = y ?? s.game.zone.heightAt(x, z);
    p.vel.x = p.vel.y = p.vel.z = 0;
    p.onGround = true; p.flying = false;
  };
  /** Walk onto the travel pad for zoneId (the bot's way of travelling). */
  s.goTo = (zoneId) => {
    if (s.game.zone.id === zoneId) return;
    // route: direct pad, else hop through linked worlds (breadth-first over unlocked links)
    for (let hops = 0; hops < 6 && s.game.zone.id !== zoneId; hops++) {
      const pads = s.story.pads();
      let pad = pads.find((p) => p.zone === zoneId);
      if (!pad) {
        const path = route(s.game.zone.id, zoneId, slot.story.unlocked, s.slot.story.items.instantTransmission > 0);
        assert.ok(path, `no route from ${s.game.zone.id} to ${zoneId} (unlocked: ${slot.story.unlocked.join(", ")})`);
        pad = pads.find((p) => p.zone === path[1]);
      }
      assert.ok(pad, `no pad in ${s.game.zone.id} towards ${zoneId}`);
      s.at(pad.x + 6, pad.z + 6); s.tick(); // step off first (pads arm once you leave them)
      const from = s.game.zone.id;
      s.at(pad.x, pad.z); s.tick();
      if (process.env.DEBUG) console.log("hop", from, "->", pad.zone, "now", s.game.zone.id, "pad", pad.x.toFixed(1), pad.z.toFixed(1), "y", pad.y.toFixed(1), "player y", s.game.player.pos.y.toFixed(1));
    }
    assert.equal(s.game.zone.id, zoneId, `travel to ${zoneId}`);
  };
  s.grindTo = (lv) => { while (slot.level < lv) { const n = xpToNext(slot.level); s.grindXP += n; s.game.addXP(n); } };
  return s;
}

import { LINKS } from "../web/src/data/story.js";
function route(from, to, unlocked, it) {
  const q = [[from]], seen = new Set([from]);
  while (q.length) {
    const path = q.shift(), at = path[path.length - 1];
    if (at === to) return path;
    for (const n of it ? Object.keys(LINKS) : LINKS[at] || []) if (!seen.has(n) && unlocked.includes(n)) { seen.add(n); q.push([...path, n]); }
  }
  return null;
}

const npcById = Object.fromEntries(NPCS.map((n) => [n.id, n]));

/** Do one quest from start to finish. */
function play(s, q) {
  s.grindTo(q.level || 1);
  const giver = npcById[q.giver];
  s.goTo(giver.zone);
  const g = s.story.npcs().find((n) => n.id === giver.id);
  assert.ok(g, `${q.id}: giver ${giver.id} not visible in ${giver.zone}`);
  assert.equal(g.marker, "!", `${q.id}: giver ${giver.id} should show "!" (shows ${g.marker})`);
  // a giver may hand out another quest first: finish it, then ask again
  for (let tries = 0; tries < 5 && s.slot.quests[q.id]?.status !== "active"; tries++) {
    const active = new Set(Object.keys(s.slot.quests).filter((id) => s.slot.quests[id].status === "active"));
    s.at(g.x + 1, g.z + 1, g.y);
    assert.equal(s.story.interact(), "accept", `${q.id}: accept from ${giver.id}`);
    const other = Object.keys(s.slot.quests).find((id) => s.slot.quests[id].status === "active" && !active.has(id) && id !== q.id);
    if (other) { runSteps(s, QUESTS.find((x) => x.id === other)); s.goTo(giver.zone); }
  }
  runSteps(s, q);
}

function runSteps(s, q) {
  for (let guard = 0; guard < 40 && s.slot.quests[q.id].status === "active"; guard++) {
    const st = s.slot.quests[q.id], step = q.steps[st.step];
    if (step.type === "talk") {
      const n = npcById[step.npc];
      s.goTo(n.zone);
      const v = s.story.npcs().find((x) => x.id === n.id);
      assert.ok(v, `${q.id}: ${n.id} not visible for talk step`);
      assert.equal(v.marker, "?", `${q.id}: ${n.id} should show "?"`);
      s.at(v.x + 1, v.z + 1, v.y);
      assert.equal(s.story.interact(), "talk", `${q.id}: talk to ${n.id}`);
    } else if (step.type === "reach") {
      s.goTo(step.zone); const w = s.game.zone.place(step.x, step.z); s.at(w.x, w.z); s.tick();
    } else if (step.type === "travel") {
      s.goTo(step.zone); s.tick();
    } else if (step.type === "defeat") {
      s.goTo(step.zone);
      const w = s.story.waypoint();
      assert.ok(w, `${q.id}: no waypoint for ${step.enemy}`);
      s.at(w.x + 1, w.z + 1);
      const before = st.step;
      assert.notEqual(s.story.interact(), "confront", "interaction never defeats an enemy");
      assert.equal(st.step, before, "fight waits for combat kill credit");
      for (let i = 0; i < (step.count || 1); i++) s.story.enemyDefeated(step.enemy, step.zone);
    } else if (step.type === "collect") {
      for (const spot of step.spots) {
        s.goTo(spot.zone ?? step.zone); s.at(spot.x, spot.z); s.tick();
      }
    } else if (step.type === "train") {
      s.goTo(step.zone);
      const w = step.x !== undefined ? s.game.zone.place(step.x, step.z) : { x: s.game.zone.spawn.x + 3, z: s.game.zone.spawn.z + 3 };
      const x = w.x, z = w.z;
      const frames = Math.ceil(step.seconds / STEP) + 5;
      for (let i = 0; i < frames && s.slot.quests[q.id].status === "active" && q.steps[s.slot.quests[q.id].step] === step; i++) {
        s.at(x, z);
        const it = emptyIntents();
        const p = s.game.player;
        if (step.mode === "move") p.vel.x = 4;
        if (step.mode === "charge") it.charge = true;
        if (step.mode === "fly") p.flying = true;
        s.tick(it);
      }
    } else if (step.type === "level") {
      s.grindTo(step.level); s.tick();
    }
  }
  assert.notEqual(s.slot.quests[q.id].status, "active", `${q.id} finished`);
}

// ---------------------------------------------------------------- the main story, start to end
{
  const s = session("Saiyan");
  s.enter("earth_plains");
  const w = s.story.waypoint();
  assert.ok(w && w.text.includes("Goku"), "first waypoint points at Goku");
  const mains = QUESTS.filter((q) => q.main);
  for (const q of mains) play(s, q);
  ok(`main story: all ${mains.length} quests from "${mains[0].title}" to "${mains[mains.length - 1].title}" (reached level ${s.slot.level}, ${s.slot.story.unlocked.length} worlds unlocked)`);
  assert.equal(s.slot.story.unlocked.length, Object.keys(ZONES).length - 1, "every world unlocked by the end");
  ok("every world gets unlocked by the story");
  // side quests and trainers available to a Saiyan
  const sides = QUESTS.filter((q) => !q.main && !q.id.startsWith("Form_") && (!q.races || q.races.includes("Saiyan")));
  for (const q of sides) play(s, q);
  ok(`${sides.length} side and trainer quests (moves learned: ${s.slot.moves.length})`);
  assert.ok(s.slot.moves.includes("InstantTransmission") && s.slot.moves.includes("Kamehameha") && s.slot.moves.includes("SpiritBomb"));
  assert.ok(s.slot.story.flags.shenron, "Shenron summoned");
  // Instant Transmission: pads to every unlocked world
  s.goTo("htc");
  assert.equal(s.story.pads().length, Object.keys(ZONES).length - 2, "Instant Transmission opens every world");
  ok("Instant Transmission shows pads to every unlocked world");
  // repeatable training can be redone
  const r = QUESTS.find((q) => q.id === "r_kingkai_gravity");
  const before = s.slot.quests[r.id].completions;
  play(s, r);
  assert.equal(s.slot.quests[r.id].completions, before + 1);
  ok("repeatable training quests repeat");
  // the save round-trips through migration
  const copy = migrate(JSON.parse(JSON.stringify({ version: 2, slots: [s.slot], lastSlot: 0 })));
  assert.deepEqual(copy.slots[0].story.unlocked, s.slot.story.unlocked);
  ok("story state survives save + migrate");
}

// ---------------------------------------------------------------- every race's transformations
for (const race of RACE_ORDER) {
  const s = session(race);
  s.enter("earth_plains");
  const forms = QUESTS.filter((q) => q.id.startsWith("Form_") && q.races.includes(race));
  const needed = new Set(forms.flatMap((q) => q.after || []));
  // play the story far enough for every form's prerequisites, in story order
  for (const q of QUESTS.filter((x) => x.main)) {
    if (![...needed].some((id) => QUESTS.findIndex((x) => x.id === id) >= QUESTS.findIndex((x) => x.id === q.id))) break;
    play(s, q);
  }
  for (const q of forms) {
    for (const pre of q.after || []) if (s.slot.quests[pre]?.status !== "done") play(s, QUESTS.find((x) => x.id === pre));
    play(s, q);
  }
  assert.deepEqual([...s.slot.forms].sort(), forms.flatMap((q) => q.rewards.forms).sort());
  ok(`${race}: all ${forms.length} transformations unlock (${s.slot.forms.join(", ")})`);
  // this race's own side quests (finish the story first so every giver is around)
  const own = QUESTS.filter((q) => !q.main && !q.id.startsWith("Form_") && q.races?.includes(race));
  for (const q of QUESTS.filter((x) => x.main)) if (s.slot.quests[q.id]?.status !== "done" && own.some((o) => (o.after || []).length)) play(s, q);
  for (const q of own) play(s, q);
  if (own.length) ok(`${race}: race quests ${own.map((q) => q.title).join(", ")}`);
}

// ---------------------------------------------------------------- old saves
{
  const old = { version: 1, slots: [{ race: "Human", appearance: defaultLook("Human"), level: 3, zone: "test", quests: {} }], lastSlot: 0 };
  const m = migrate(old);
  assert.equal(m.slots[0].zone, "earth_plains");
  assert.deepEqual(m.slots[0].story.unlocked, ["earth_plains", "kame_island"]);
  ok("v1 saves migrate to the story worlds");
}

// ---------------------------------------------------------------- void worlds respawn you
{
  const s = session("Saiyan");
  s.enter("snake_way");
  s.game.player.pos.y = -100;
  s.tick();
  assert.ok(s.game.player.pos.y > -5, "back on the road");
  ok("falling off Snake Way puts you back at the start");
}

console.log(`\n${checks} story checks passed`);
