import { formForRace } from "../web/src/game/forms.js";
// Node checks for the rules (data/, game/, core/save + settings). No browser needed.
//   node tools/check_core.mjs
import assert from "node:assert/strict";
import { RACES, RACE_ORDER } from "../web/src/data/races.js";
import { FORMS } from "../web/src/data/forms.js";
import { OUTFITS, OUTFIT_ORDER, starterOutfits } from "../web/src/data/outfits.js";
import { HAIR_STYLES, findById } from "../web/src/data/appearance.js";
import * as P from "../web/src/game/progression.js";
import { validateLook, defaultLook } from "../web/src/game/look.js";
import { newSlot, migrate, SCHEMA_VERSION } from "../web/src/game/schema.js";
import { createSaveStore } from "../web/src/core/save.js";
import { createSettings } from "../web/src/core/settings.js";
import { createEvents } from "../web/src/core/events.js";
import { createGame, emptyIntents } from "../web/src/game/game.js";
import { ZONES } from "../web/src/game/zones.js";

let n = 0;
const t = (name, fn) => { fn(); n++; console.log("ok", name); };

t("data tables are consistent", () => {
  assert.equal(RACE_ORDER.length, 6);
  for (const id of RACE_ORDER) {
    const r = RACES[id];
    assert.equal(r.id, id);
    for (const f of r.forms) assert.ok(formForRace(f,id), `form ${f} of ${id}`);
    for (const h of r.hairStyles) assert.ok(findById(HAIR_STYLES, h), `hair ${h}`);
    assert.ok(starterOutfits(id).length > 0, `${id} has a starter outfit`);
    const levels = r.forms.map((f) => FORMS[f].unlockLevel);
    assert.deepEqual(levels, [...levels].sort((a, b) => a - b), `${id} forms in unlock order`);
  }
  for (const id of OUTFIT_ORDER) assert.equal(OUTFITS[id].id, id);
});

t("progression ports the Roblox numbers", () => {
  assert.equal(P.xpToNext(1), 100);
  assert.equal(P.xpToNext(4), 800);
  assert.equal(P.xpToNext(2000), 0);
  assert.equal(P.applyXPBonus("HalfSaiyan", 10, 100), 125);
  assert.equal(P.applyXPBonus("HalfSaiyan", 500, 100), 100);
  assert.equal(P.applyXPBonus("Human", 149, 100), 110);
  assert.equal(P.applyXPBonus("Saiyan", 1, 100), 100);
  const s = newSlot(defaultLook("Saiyan"));
  const d = P.derive(s);
  assert.equal(d.maxHealth, 100);
  assert.equal(d.powerLevel, Math.floor((50 + 5 * 25) * 1.1)); // Saiyan +5 Strength
  assert.equal(P.derive(s, "SSJ").maxHealth, 150);
  assert.ok(P.formsAtLevel("Saiyan",250).includes("SSJ"));
  assert.ok(!P.formsAtLevel("Saiyan",250).includes("SSJ2"));
});

t("addXP levels up and grants points", () => {
  const s = newSlot(defaultLook("Saiyan"));
  assert.equal(P.addXP(s, 100 + 282 + 50), 2); // 1->2 (100), 2->3 (282)
  assert.equal(s.level, 3);
  assert.equal(s.xp, 50);
  assert.equal(s.statPoints, 6);
  assert.equal(P.spendStatPoint(s, "Health", 2), null);
  assert.equal(s.stats.Health, 2);
  assert.equal(P.spendStatPoint(s, "Health", 9), "Not enough stat points");
  assert.equal(P.spendStatPoint(s, "Luck", 1), "Unknown stat");
  P.addXP(s, 1e12);
  assert.equal(s.level, 2000);
  assert.equal(s.xp, 0);
});

t("look validation", () => {
  for (const id of RACE_ORDER) assert.equal(validateLook(defaultLook(id)), null, id);
  assert.match(validateLook({ ...defaultLook("Namekian"), hair: "Spiky" }), /hair/);
  assert.match(validateLook({ ...defaultLook("Saiyan"), skin: 0.5 }), /skin/);
  assert.match(validateLook({ ...defaultLook("Saiyan"), outfit: "NamekRobe" }), /outfit/);
  assert.match(validateLook({ ...defaultLook("Saiyan"), outfit: "CraneGi" }), /outfit/); // not a starter
  assert.match(validateLook({ ...defaultLook("Saiyan"), race: "toString" }), /race/);
});

t("migrate fills missing fields and survives junk", () => {
  assert.equal(migrate(null).slots.length, 3);
  assert.equal(migrate("x").version, SCHEMA_VERSION);
  const old = { slots: [{ race: "Human", appearance: defaultLook("Human"), level: 4 }, 7], lastSlot: 0 };
  const m = migrate(old);
  assert.equal(m.slots[0].stats.Speed, 0);
  assert.equal(m.slots[0].level, 40);
  assert.equal(m.slots[1], null);
  assert.equal(m.slots[2], null);
});

t("save store: create, load, save, delete, export/import", () => {
  const ev = createEvents();
  let changes = 0;
  ev.on("slots", () => changes++);
  const save = createSaveStore(ev);
  assert.equal(save.listSlots().length, 3);
  assert.equal(save.createSlot(0, defaultLook("Majin")).ok, true);
  assert.equal(save.createSlot(0, defaultLook("Majin")).ok, false);
  assert.equal(save.createSlot(3, defaultLook("Majin")).ok, false);
  assert.equal(save.createSlot(1, { ...defaultLook("Majin"), hair: "Spiky" }).ok, false);
  const slot = save.loadSlot(0);
  slot.level = 9;
  save.saveSlot(0, slot);
  assert.equal(save.listSlots()[0].level, 9);
  assert.equal(save.lastSlot(), 0);
  const code = save.exportCode();
  assert.equal(save.deleteSlot(0).ok, true);
  assert.equal(save.listSlots()[0], null);
  assert.equal(save.importCode(code).ok, true);
  assert.equal(save.listSlots()[0].raceName, "Majinn"); // the game's own race name (data/names.js)
  assert.equal(save.importCode("nope").ok, false);
  assert.equal(save.importCode("DL1:!!!").ok, false);
  assert.equal(changes, 3); // create, delete, import (saveSlot is silent)
  // a second store reads what the first wrote
  assert.equal(createSaveStore().listSlots()[0].level, 9);
});

t("settings clamp and validate", () => {
  const s = createSettings();
  assert.equal(s.set("masterVolume", 5), 1);
  assert.equal(s.set("quality", "ultra"), s.get("quality"));
  assert.equal(s.set("quality", "low"), "low");
  assert.throws(() => s.set("nope", 1));
});

t("game session: moves, stays on the ground, levels, saves position", () => {
  const ev = createEvents();
  const notes = [];
  ev.on("notify", (n) => notes.push(n.text));
  const slot = newSlot(defaultLook("Saiyan"));
  const g = createGame(0, slot, ev);
  const zone = ZONES.test;
  const it = emptyIntents();
  it.moveZ = 1;
  for (let i = 0; i < 120; i++) g.update(1 / 60, it);
  assert.ok(g.player.pos.z > 8 && g.player.pos.z < 15, `ran ${g.player.pos.z} m in 2 s`);
  assert.ok(Math.abs(g.player.pos.y - zone.heightAt(g.player.pos.x, g.player.pos.z)) < 1e-6);
  const jump = { ...emptyIntents(), jump: true };
  g.update(1 / 60, jump);
  for (let i = 0; i < 10; i++) g.update(1 / 60, emptyIntents());
  assert.ok(g.player.pos.y > zone.heightAt(g.player.pos.x, g.player.pos.z) + 0.5, "jumped");
  for (let i = 0; i < 120; i++) g.update(1 / 60, emptyIntents());
  assert.ok(g.player.onGround, "landed");
  g.addXP(100);
  assert.equal(g.hud().level, 2);
  assert.equal(g.hud().statPoints, 3);
  assert.equal(g.spendStatPoint("Health", 1), null);
  assert.equal(g.hud().maxHealth, 100 + 5 + 12);
  assert.ok(notes.some((t) => /level 2/.test(t)));
  const saved = g.toSave();
  assert.ok(saved.position.z > 8);
  const g2 = createGame(0, saved);
  assert.equal(g2.player.pos.z, saved.position.z);
});

console.log(`\n${n} checks passed`);
