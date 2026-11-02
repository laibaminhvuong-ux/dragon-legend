// Boss cutscenes, the first-play tutorial and the travel guide (node, no browser).
//   node tools/check_scenes.mjs
import assert from "node:assert/strict";
import { BOSS_SCENES } from "../web/src/data/cutscenes.js";
import { NPCS, QUESTS } from "../web/src/data/story.js";
import { STORY_BOSSES, createSceneDirector, sceneLines } from "../web/src/game/cutscene.js";
import { createTutorial, TUTORIAL_STEPS } from "../web/src/game/tutorial.js";
import { newSlot } from "../web/src/game/schema.js";
import { defaultLook } from "../web/src/game/look.js";
import { createGame, emptyIntents } from "../web/src/game/game.js";
import { createStory } from "../web/src/game/story.js";
import { createEvents } from "../web/src/core/events.js";

let checks = 0;
const ok = (name) => { checks++; console.log("ok", name); };
const npcIds = new Set(NPCS.map((n) => n.id));

// ---- cutscene data
for (const [enemy, scene] of Object.entries(BOSS_SCENES)) {
  assert.ok(STORY_BOSSES.has(enemy), `${enemy} is a story boss`);
  for (const kind of ["before", "after"]) {
    assert.ok(scene[kind]?.length, `${enemy} has a ${kind} scene`);
    for (const [who, text] of scene[kind]) {
      assert.ok(who === "you" || who === "boss" || npcIds.has(who), `${enemy}/${kind}: speaker ${who} exists`);
      assert.ok(typeof text === "string" && text.length > 0 && text.length < 160, `${enemy}/${kind}: line length`);
    }
  }
}
const missing = [...STORY_BOSSES].filter((b) => !BOSS_SCENES[b]);
assert.deepEqual(missing, [], "every story boss has its own scene");
ok(`${Object.keys(BOSS_SCENES).length} boss scenes, every speaker exists, every story boss covered`);
const lines = sceneLines("raditz", "before");
assert.ok(lines.length >= 2 && lines.every((l) => l.name && l.text));
assert.ok(sceneLines("unknown_boss", "before", "Someone").length >= 1, "generic fallback");
ok("scene lines resolve speaker names; unknown bosses get a generic scene");

// ---- director: once per boss, only when close
{
  const slot = newSlot(defaultLook("Saiyan"));
  const d = createSceneDirector(slot);
  const enc = [{ key: "raditz", boss: true, x: 0, z: 0, name: "Raditz" }];
  assert.equal(d.beforeFor(enc, { x: 60, z: 0 }), null, "too far: nothing");
  const s = d.beforeFor(enc, { x: 10, z: 0 });
  assert.equal(s?.enemy, "raditz");
  assert.equal(d.beforeFor(enc, { x: 5, z: 0 }), null, "plays once");
  assert.ok(d.afterFor("raditz"), "after scene");
  assert.equal(d.afterFor("raditz"), null, "after plays once");
  assert.equal(d.afterFor("patrol_earth_plains"), null, "patrol enemies have no scenes");
  assert.ok(slot.story.flags.scenes["before:raditz"], "seen scenes are saved");
  ok("cutscenes trigger near the boss, once each, and are saved");
}

// ---- tutorial
{
  const slot = newSlot(defaultLook("Saiyan"));
  const t = createTutorial(slot);
  assert.ok(t.active && t.index === 0, "new characters start the tutorial");
  const player = { pos: { x: 0, y: 0, z: 0 }, flying: false, onGround: true, charging: false, blocking: false, attackSerial: 0 };
  const step = (it = {}, dt = 0.1) => t.update(dt, { ...emptyIntents(), ...it }, player);
  t.look(2); assert.equal(step(), "look");
  for (let i = 0; i < 20; i++) { player.pos.x += 0.5; step(); }
  assert.equal(t.index, 2, "walking finishes the move step");
  assert.equal(step({ jump: true }), "jump");
  assert.equal(step({ dash: true }), "dash");
  player.flying = true; player.onGround = false; for (let i = 0; i < 20; i++) step();
  assert.equal(t.step.id, "land");
  player.flying = false; player.onGround = true; step();
  for (let i = 0; i < 4; i++) { player.attackSerial++; step(); }
  assert.equal(t.step.id, "blast");
  step({ kiBlast: true }); step({ beam: true }); step();
  assert.equal(t.step.id, "charge");
  for (let i = 0; i < 20; i++) step({ charge: true });
  for (let i = 0; i < 12; i++) step({ block: true });
  step({ lockOn: true });
  assert.equal(t.step.id, "talk");
  t.note("talk"); step();
  for (let i = 0; i < 120; i++) step();
  assert.equal(slot.story.flags.tutorial, "done");
  assert.ok(!t.active);
  ok(`tutorial: all ${TUTORIAL_STEPS.length} steps finish by doing them`);
  const vet = newSlot(defaultLook("Saiyan")); vet.level = 30;
  assert.ok(!createTutorial(vet).active, "veterans skip");
  const sk = newSlot(defaultLook("Saiyan")); const ts = createTutorial(sk); ts.skip();
  assert.equal(sk.story.flags.tutorial, "skipped");
  ok("characters that already played skip the tutorial; Skip works");
}

// ---- travel guide
{
  const ev = createEvents();
  let went = null; ev.on("travel", (t) => (went = t.zone));
  const slot = newSlot(defaultLook("Saiyan"));
  slot.zone = "earth_plains";
  let game = createGame(0, slot, ev), story = createStory(game, ev);
  assert.ok(story.tasksHere().length > 0, "the story starts on Earth");
  assert.equal(story.travelGuide(), null, "no guide while story tasks remain here");
  assert.ok(!story.npcs().some((n) => n.guide));
  assert.deepEqual(story.pads(), [], "no travel pads");
  // the first two chapters done: the story moves on to Snake Way
  for (const id of ["m01_arrival", "m02_raditz"]) slot.quests[id] = { status: "done", step: 0, completions: 1 };
  slot.story.unlocked.push("snake_way", "gizard_wasteland");
  game = createGame(0, slot, ev); story = createStory(game, ev);
  const g = story.travelGuide();
  assert.ok(g && g.guide && g.marker === "✈", "guide appears once Earth's chapter is done");
  const opts = story.travelOptions();
  assert.ok(opts.some((o) => o.zone === "snake_way" && o.story), "Snake Way is next in the story");
  assert.ok(opts.findIndex((o) => !o.story) === -1 || opts.findIndex((o) => !o.story) > opts.findIndex((o) => o.story), "story worlds come first");
  assert.equal(story.travelTo("snake_way"), false, "must stand next to the pilot");
  Object.assign(game.player.pos, { x: g.x + 1, y: g.y, z: g.z });
  assert.equal(story.interaction()?.action, "Travel");
  let menu = null; ev.on("dialogue", (d) => (menu = d));
  story.interact({ choose: true });
  assert.equal(menu?.kind, "travel");
  assert.ok(story.travelTo("snake_way")); assert.equal(went, "snake_way");
  assert.equal(story.travelTo("namek"), false, "worlds the story hasn't opened are not offered");
  ok("travel guide: hidden while the planet's story tasks remain, then offers the next story world first");
}

console.log(`\n${checks} scene/tutorial/travel checks passed`);
