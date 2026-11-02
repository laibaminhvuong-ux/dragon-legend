import { formForRace, hasFormPath } from "./forms.js";
import { freePosition } from "./placement.js";
import { SHOP } from "../data/rpg.js";
import { OUTFITS, outfitAllowed } from "../data/outfits.js";
// The story engine: NPCs, quests, rewards, travel between worlds. Pure rules (no rendering), run
// once per fixed step after game.update(). State lives in the save slot (slot.quests, slot.story).
//
//   const story = createStory(game, events)
//   story.update(dt, intents)   objectives, pickups, travel pads, falling off void worlds
//   story.interact()            what the Interact button does (main.js calls it on intents.interact)
//   story.npcs()                visible NPCs here, with marker: "!" (quest), "?" (talk to them), "⚔" (fight), null
//   story.pads()                travel pads here: [{ zone, name, x, y, z }]
//   story.pickups()             pickups to grab here: [{ item, x, y, z }]
//   story.waypoint()            current objective position here, or null
//   story.tracker()             quest log: [{ id, title, saga, main, objective, progress }]
//   story.journal()             { done: [ids], unlocked: [zones], visited: [zones], moves, forms }
// Events: "dialogue" { speaker, text, kind: "offer" | "progress" | "done" | "ambient", questId },
//         "questAccepted" / "questCompleted" { id, title }, "questProgress" { id, objective },
//         "travel" { zone }, "notify" { text }, "stats" (via game)
import { QUESTS, NPCS, CHARACTERS, LINKS, START_ZONES, COMBAT_AVAILABLE } from "../data/story.js";
import { MOVES } from "../data/moves.js";
import { FORMS } from "../data/forms.js";
import { ZONES, getZone } from "./zones.js";
import { xpToNext, xpForLevels } from "./progression.js";

const QUEST = Object.fromEntries(QUESTS.map((q) => [q.id, q]));
const NPC = Object.fromEntries(NPCS.map((n) => [n.id, n]));
const TALK_RANGE = 4.5;
const PICKUP_RANGE = 2.6;
const PAD_RANGE = 1.8;

/** Fills in slot.story / slot.quests (also used by the save migration). */
export function ensureStoryState(slot) {
  slot.quests = slot.quests && typeof slot.quests === "object" ? slot.quests : {};
  const s = (slot.story ||= {});
  s.unlocked = Array.isArray(s.unlocked) ? s.unlocked : [...START_ZONES];
  for (const z of START_ZONES) if (!s.unlocked.includes(z)) s.unlocked.push(z);
  s.visited = Array.isArray(s.visited) ? s.visited : [];
  s.items = s.items && typeof s.items === "object" ? s.items : {};
  s.flags = s.flags && typeof s.flags === "object" ? s.flags : {};
  // Reconcile newly added destinations for saves that completed earlier versions of a quest.
  for(const q of QUESTS)if(slot.quests[q.id]?.status==='done' || (slot.quests[q.id]?.completions || 0)>0){
    for(const id of q.rewards?.unlock || [])if(!s.unlocked.includes(id))s.unlocked.push(id);
  }
  return s;
}

export function createStory(game, events = null) {
  const slot = game.slot, zone = game.zone, player = game.player;
  const S = ensureStoryState(slot);
  const emit = (n, d) => events && events.emit(n, d);
  const say = (speaker, text, kind, questId) => {
    emit("dialogue", { speaker, text, kind, questId });
    emit("notify", { text: `${speaker}: ${text}` });
  };
  if (!S.visited.includes(zone.id)) S.visited.push(zone.id);
  if (!S.unlocked.includes(zone.id)) S.unlocked.push(zone.id);

  const qs = (id) => slot.quests[id];
  const isDone = (id) => qs(id)?.status === "done" || (qs(id)?.completions || 0) > 0;
  const isActive = (id) => qs(id)?.status === "active";

  function visible(n) {
    if (n.zone !== zone.id) return false;
    if (n.after && !isDone(n.after)) return false;
    // appears partway through a quest: [questId, step index]
    if (n.afterStep && !isDone(n.afterStep[0]) && !(isActive(n.afterStep[0]) && qs(n.afterStep[0]).step >= n.afterStep[1])) return false;
    if (n.before && isDone(n.before)) return false;
    if (n.flagged && !S.flags[n.flagged]) return false;
    return true;
  }
  const npcPositions = new Map();
  function npcPos(n) {
    if (!npcPositions.has(n.id)) {
      const { x, z } = zone.place(n.x, n.z);
      npcPositions.set(n.id, freePosition(zone, { x, z, y:n.y }));
    }
    return npcPositions.get(n.id);
  }
  /** A step's x/z in this world (Snake Way coordinates follow the road). */
  const at = (step) => (step.zone === zone.id ? zone.place(step.x, step.z) : { x: step.x, z: step.z });

  function canAccept(q) {
    if(q.legacy || q.automatic)return false;
    if(q.path && !hasFormPath(slot,q.path))return false;
    if (isActive(q.id)) return false;
    if (isDone(q.id) && !q.repeat) return false;
    if (slot.level < (q.level || 1)) return false;
    if (q.races && !q.races.includes(slot.race)) return false;
    return (q.after || []).every(isDone);
  }
  const activeQuests = () => QUESTS.filter((q) => isActive(q.id));
  const stepOf = (q) => q.steps[qs(q.id).step];

  // ------------------------------------------------------------ objectives
  function stepZone(step) { return step.zone ?? null; }
  function stepTarget(step) {
    if (step.type === "talk") { const n = NPC[step.npc]; return n && { zone: n.zone, ...(n.zone === zone.id && visible(n) ? npcPos(n) : { x: n.x, z: n.z }) }; }
    if (step.type === "defeat") {
      const live = game.combat?.enemies.filter(e => e.key === step.enemy && e.health > 0)
        .sort((a,b) => Math.hypot(a.pos.x-player.pos.x,a.pos.z-player.pos.z)-Math.hypot(b.pos.x-player.pos.x,b.pos.z-player.pos.z))[0];
      if (live && step.zone === zone.id) return { zone: zone.id, ...live.pos };
      const n = NPC[step.enemy];
      if (n && n.zone === zone.id && visible(n)) return { zone: n.zone, ...npcPos(n) };
      return { zone: step.zone, ...at(step) };
    }
    if (step.type === "reach" || (step.type === "train" && step.x !== undefined)) return { zone: step.zone, ...at(step) };
    if (step.type === "travel") return { zone: step.zone };
    if (step.type === "collect") {
      const p = qs(currentCollect(step))?.collected || [];
      const spot = step.spots.find((s, i) => !p.includes(i) && (s.zone ?? step.zone) === zone.id);
      return spot ? { zone: zone.id, x: spot.x, z: spot.z } : { zone: (step.spots.find((s, i) => !p.includes(i)) || {}).zone ?? step.zone };
    }
    return null;
  }
  function currentCollect(step) { return activeQuests().find((q) => stepOf(q) === step)?.id; }

  function progressText(q) {
    const st = qs(q.id), step = stepOf(q);
    if (step.type === "train") return `${Math.floor(st.t || 0)} / ${step.seconds} s`;
    if (step.type === "collect") return `${(st.collected || []).length} / ${step.spots.length}`;
    if (step.type === "defeat" && step.count > 1) return `${st.count || 0} / ${step.count}`;
    if (step.type === "level") return `level ${slot.level} / ${step.level}`;
    return "";
  }

  function advance(q, quiet = false) {
    const st = qs(q.id);
    st.step++;
    st.t = 0;
    st.count = 0;
    if (st.step >= q.steps.length) return complete(q);
    if (!quiet) emit("questProgress", { id: q.id, objective: q.steps[st.step].text });
    emit("notify", { text: `${q.title}: ${q.steps[st.step].text}` });
    checkInstant(q);
  }
  /** Steps that may already be satisfied when they start (level, already in the right world). */
  function checkInstant(q) {
    if (!isActive(q.id)) return;
    const step = stepOf(q);
    // a "go to X" objective opens the way to X
    if (step.type === "travel" && !S.unlocked.includes(step.zone)) {
      S.unlocked.push(step.zone);
      padCache = null;
      emit("notify", { text: `New world: ${ZONES[step.zone].name}` });
    }
    if (step.type === "level" && slot.level >= step.level) advance(q);
    else if (step.type === "travel" && zone.id === step.zone) advance(q);
  }

  function accept(q) {
    const prev = qs(q.id);
    slot.quests[q.id] = { status: "active", step: 0, t: 0, count: 0, collected: [], completions: prev?.completions || 0 };
    say(CHARACTERS[NPC[q.giver].who].name, q.offer, "offer", q.id);
    emit("questAccepted", { id: q.id, title: q.title });
    emit("notify", { text: `New quest: ${q.title}. ${q.steps[0].text}` });
    checkInstant(q);
  }

  function complete(q) {
    const st = qs(q.id);
    st.status = q.repeat ? "repeatable" : "done";
    st.completions = (st.completions || 0) + 1;
    const giver = CHARACTERS[NPC[q.giver].who].name;
    say(giver, q.done, "done", q.id);
    const R = q.rewards || {};
    const lines = [];
    let xpGain = R.xp;
    if (typeof xpGain === "string" && xpGain.startsWith("levels:")) xpGain=xpForLevels(slot.level,Number(xpGain.slice(7)));
    if (typeof xpGain === "string" && xpGain.startsWith("level:")) xpGain = Math.max(40, Math.round(xpToNext(slot.level) * Number(xpGain.slice(6))));
    if (R.zeni) { game.addZeni(R.zeni); lines.push(`${R.zeni} zeni`); }
    if (R.statPoints) { slot.statPoints += R.statPoints; lines.push(`${R.statPoints} stat points`); }
    for (const m of R.moves || []) if (!slot.moves.includes(m) && (!MOVES[m].races || MOVES[m].races.includes(slot.race))) { slot.moves.push(m); lines.push(`technique: ${MOVES[m].name}`); }
    for (const f of R.forms || []) if (formForRace(f,slot.race) && !slot.forms.includes(f)) { slot.forms.push(f); lines.push(`transformation: ${FORMS[f].name}`); }
    for (const o of R.outfits || []) if (!slot.outfits.includes(o)) { slot.outfits.push(o); lines.push(`outfit: ${o}`); }
    for (const z of R.unlock || []) if (!S.unlocked.includes(z)) { S.unlocked.push(z); lines.push(`new world: ${ZONES[z].name}`); }
    for (const [k, v] of Object.entries(R.items || {})) S.items[k] = (S.items[k] || 0) + v;
    emit("questCompleted", { id: q.id, title: q.title });
    emit("notify", { text: `Quest complete: ${q.title}${xpGain ? ` (+${xpGain} XP)` : ""}${lines.length ? ". Rewards: " + lines.join(", ") : ""}` });
    if (xpGain) game.addXP(xpGain); // last: may announce a level up
    else emit("stats", game.hud());
    // quests whose steps are "reach a level" may now be satisfied
    for (const a of activeQuests()) checkInstant(a);
  }

  // ------------------------------------------------------------ travel pads
  function destinations() {
    const it = S.items.instantTransmission > 0;
    const linked = it ? Object.keys(LINKS) : LINKS[zone.id] || [];
    return linked.filter((z) => z !== zone.id && S.unlocked.includes(z) && ZONES[z]);
  }
  let padCache = null, padKey = "";
  function pads() {
    const key = destinations().join(",");
    if (padCache && key === padKey) return padCache;
    padKey = key;
    const tp = zone.travelPoint;
    if (!tp) return (padCache = []);
    const list = destinations();
    const n = list.length;
    padCache = list.map((z, i) => {
      // an arc of pads facing spawn, 3 m apart
      const row=Math.floor(i/8),columns=Math.min(8,n-row*8);
      const span=Math.max(0,columns-1)*3;
      const off=-span/2+(i%8)*3;
      let x, zz;
      if (zone.def.terrain.path) {
        // Snake Way is too narrow for a row: line the pads up along the road
        ({ x, z: zz } = zone.place(0, tp.z + 3 + i * 3.5));
      } else {
        const dx = zone.spawn.x - tp.x, dz = zone.spawn.z - tp.z;
        const len = Math.hypot(dx, dz) || 1;
        const sx = -dz / len, sz = dx / len; // sideways
        x = tp.x + sx * off + dx/len*row*3.5; zz = tp.z + sz * off + dz/len*row*3.5;
      }
      return { zone: z, name: ZONES[z].name, planet: ZONES[z].planet, x, y: zone.heightAt(x, zz), z: zz };
    });
    return padCache;
  }
  let padArmed = false; // arriving players stand on the travel point: wait until they step away

  // ------------------------------------------------------------ public
  let trackedId = null;
  const story = {
    trackQuest(id) { if (!isActive(id)) return false; trackedId = id; return true; },
    zone,
    combatAvailable: COMBAT_AVAILABLE,

    npcs() {
      return NPCS.filter(visible).map((n) => {
        let marker = null;
        for (const q of activeQuests()) {
          const s = stepOf(q);
          if (s.type === "talk" && s.npc === n.id) marker = "?";
          if (s.type === "defeat" && s.enemy === n.id) marker = "⚔";
        }
        if (!marker && QUESTS.some((q) => q.giver === n.id && canAccept(q))) marker = "!";
        const c = CHARACTERS[n.who];
        return { id: n.id, name: c.name, look: c.look, scale: c.scale || 1, ...npcPos(n), rot: n.rot || 0, boss: !!n.boss, marker,
          main: marker === "!" && QUESTS.some((q) => q.giver === n.id && q.main && canAccept(q)) };
      });
    },

    shop() {
      return [...Object.entries(SHOP).map(([id, item]) => ({ id, ...item })),
        ...Object.values(OUTFITS).filter(o => o.unlock === "shop" && outfitAllowed(o.id, slot.race)).map(o => ({ id: o.id, name:o.name, price:o.price, description:"Cosmetic outfit. Equip it from your fighter journal.", owned:slot.outfits.includes(o.id) }))];
    },
    buy(id) {
      const near = story.interaction();
      if (player.health <= 0 || !near?.id.startsWith("guide_")) return "Visit a nearby Training Guide to shop.";
      const item = story.shop().find(i => i.id === id);
      if (!item || item.owned) return "That item is unavailable or already owned.";
      if (slot.zeni < item.price) return "Not enough zeni. Complete patrols and story quests to earn more.";
      game.addZeni(-item.price);
      if (SHOP[id]) S.items[id] = (S.items[id] || 0) + 1;
      else slot.outfits.push(id);
      emit("notify", { text: `Purchased ${item.name}.` });
      return null;
    },
    useItem(id) {
      const item = SHOP[id];
      if (player.health <= 0 || !item || !(S.items[id] > 0)) return false;
      if (player.health >= player.maxHealth && player.ki >= player.maxKi) return false;
      S.items[id]--;
      player.health = Math.min(player.maxHealth, player.health + player.maxHealth * item.heal);
      player.ki = Math.min(player.maxKi, player.ki + player.maxKi * item.heal);
      emit("notify", { text: `Used ${item.name}.` });return true;
    },

    /** Validated command used by the dialogue buttons. */
    acceptQuest(id) {
      if (player.health <= 0) return false;
      const q = QUEST[id], n = q && NPC[q.giver];
      if (!q || !n || !visible(n) || !canAccept(q)) return false;
      const p = npcPos(n);
      if (Math.hypot(p.x - player.pos.x, p.z - player.pos.z) > TALK_RANGE * 1.1 || Math.abs(p.y - player.pos.y) > 4) return false;
      accept(q); return true;
    },
    abandonQuest(id) {
      if (!isActive(id)) return false;
      slot.quests[id].status = "abandoned";
      emit("notify", { text: "Quest abandoned. Speak to its giver to start again." });
      return true;
    },
    interaction() {
      const p = player.pos;
      const near = story.npcs().map(n => ({ ...n, distance: Math.hypot(n.x-p.x, n.z-p.z) }))
        .filter(n => n.distance < TALK_RANGE && Math.abs(n.y-p.y) < 4 && !n.boss).sort((a,b) => a.distance-b.distance)[0];
      return near ? { id: near.id, name: near.name, action: near.marker === "!" ? "Quests" : "Talk", distance: near.distance } : null;
    },
    /** Only combat calls this after a real enemy death. Interaction cannot complete fights. */
    enemyDefeated(enemy, defeatedZone = zone.id) {
      if (defeatedZone !== zone.id) return;
      for (const q of activeQuests()) {
        const s = stepOf(q), st = qs(q.id);
        if (s.type !== "defeat" || s.enemy !== enemy || s.zone !== zone.id) continue;
        st.count = (st.count || 0) + 1;
        emit("questProgress", { id: q.id, objective: s.text });
        if (st.count >= (s.count || 1)) advance(q);
      }
    },
    encounters() {
      return activeQuests().flatMap(q => {
        const s = stepOf(q);
        if (s.type !== "defeat" || s.zone !== zone.id || s.enemy.startsWith("patrol_")) return [];
        const n = NPC[s.enemy], c = n && CHARACTERS[n.who];
        const p = n && visible(n) ? npcPos(n) : at(s);
        return [{ key: s.enemy, name: c?.name || s.enemy.replace(/_/g, " "), look: c?.look,
          scale: c?.scale || 1, x: p.x, y: p.y ?? zone.heightAt(p.x,p.z), z: p.z, level: q.level || 1, boss: (s.count || 1) === 1 }];
      });
    },

    pads,

    pickups() {
      const out = [];
      for (const q of activeQuests()) {
        const step = stepOf(q);
        if (step.type !== "collect") continue;
        const got = qs(q.id).collected || [];
        step.spots.forEach((s, i) => {
          if (got.includes(i) || (s.zone ?? step.zone) !== zone.id) return;
          out.push({ item: step.item, questId: q.id, index: i, x: s.x, y: zone.heightAt(s.x, s.z) + 0.6, z: s.z });
        });
      }
      return out;
    },

    waypoint() {
      const order = [...activeQuests()].sort((a, b) => (b.id === trackedId ? 10 : b.main ? 1 : 0) - (a.id === trackedId ? 10 : a.main ? 1 : 0));
      for (const q of order) {
        const t = stepTarget(stepOf(q));
        if (t && t.zone === zone.id && t.x !== undefined) return { x: t.x, y: t.y ?? zone.heightAt(t.x, t.z), z: t.z, questId: q.id, text: stepOf(q).text };
        if (t && t.zone && t.zone !== zone.id) {
          // objective is in another world: point at the travel pad that goes there (or towards it)
          const pad = pads().find((p) => p.zone === t.zone);
          if (pad) return { x: pad.x, y: pad.y, z: pad.z, questId: q.id, text: `${stepOf(q).text} (travel to ${ZONES[t.zone].name})` };
        }
      }
      // nothing active: point at the next main-story quest giver if they're here
      const next = QUESTS.find((q) => q.main && canAccept(q));
      const n = next && NPC[next.giver];
      if (n && n.zone === zone.id && visible(n)) return { ...npcPos(n), questId: next.id, text: `Talk to ${CHARACTERS[n.who].name}` };
      return null;
    },

    tracker() {
      return activeQuests().map((q) => ({ id: q.id, title: q.title, saga: q.saga, main: !!q.main, objective: stepOf(q).text, progress: progressText(q),
        where: stepTarget(stepOf(q))?.zone ? ZONES[stepTarget(stepOf(q)).zone]?.name : null }));
    },

    /** Next main-story quest you can take, and who gives it (for a HUD hint). */
    nextMain() {
      const q = QUESTS.find((x) => x.main && canAccept(x));
      if (!q) {
        const blocked = QUESTS.find((x) => x.main && !isDone(x.id) && !isActive(x.id));
        return blocked ? { title: blocked.title, level: blocked.level, locked: slot.level < blocked.level } : null;
      }
      const n = NPC[q.giver];
      return { title: q.title, saga: q.saga, giver: CHARACTERS[n.who].name, zone: ZONES[n.zone].name };
    },

    journal() {
      return { done: QUESTS.filter((q) => isDone(q.id)).map((q) => q.id), unlocked: [...S.unlocked], visited: [...S.visited], moves: [...slot.moves], forms: [...slot.forms], items: { ...S.items } };
    },

    /** The Interact button. Returns what happened (for tests). */
    interact({ choose = false } = {}) {
      if (player.health <= 0) return null;
      const p = player.pos;
      const here = story.npcs().map((n) => ({ ...n, d: Math.hypot(n.x - p.x, n.z - p.z), dy: Math.abs(n.y - p.y) })).filter((n) => n.d < TALK_RANGE * Math.max(1, n.scale * 0.8) && n.dy < 4 + n.scale * 2).sort((a, b) => a.d - b.d);
      // 1. finish a "talk to" step
      for (const n of here) for (const q of activeQuests()) {
        const s = stepOf(q);
        if (s.type === "talk" && s.npc === n.id) {
          // the last step's reply is the quest-giver's closing line (said by complete())
          if (qs(q.id).step < q.steps.length - 1 || n.id !== q.giver) say(n.name, TALK_REPLIES[n.id] || "Alright. Let's go.", "progress", q.id);
          advance(q);
          return "talk";
        }
      }
      // 3. take a quest
      for (const n of here) {
        const q = QUESTS.filter((x) => x.giver === n.id && canAccept(x)).sort((a, b) => priority(a) - priority(b))[0];
        if (q) {
          if (choose) {
            emit("dialogue", { speaker: n.name, text: "Choose a quest.", kind: "choice", npcId: n.id,
              choices: QUESTS.filter(x => x.giver === n.id && canAccept(x)).map(x => ({ id: x.id, title: x.title, text: x.offer, level: x.level || 1, rewards: x.rewards, objective: x.steps[0].text })) });
            return "offer";
          }
          accept(q); return "accept";
        }
      }
      // 4. small talk
      if (here.length) {
        const n = here[0];
        const blocked = QUESTS.find((x) => x.giver === n.id && !isDone(x.id) && !isActive(x.id) && (x.after || []).every(isDone) && (!x.races || x.races.includes(slot.race)));
        if (blocked && slot.level < blocked.level) say(n.name, `Come back when you're stronger (level ${blocked.level}).`, "ambient");
        else if (n.boss) say(n.name, "...", "ambient");
        else say(n.name, AMBIENT[n.id] || "Train hard!", "ambient");
        return "ambient";
      }
      return null;
    },

    /** Once per fixed step, after game.update. */
    update(dt, intents) {
      if (player.health <= 0) return;
      const p = player.pos;
      // fell off a floating world / Snake Way: back to the start
      if (zone.killY !== null && p.y < zone.killY) {
        Object.assign(p, { x: zone.spawn.x, y: zone.heightAt(zone.spawn.x, zone.spawn.z) + 0.5, z: zone.spawn.z });
        player.vel.x = player.vel.y = player.vel.z = 0;
        emit("notify", { text: zone.id === "snake_way" ? "You fell off Snake Way! King Yemma's ogres carry you back to the start." : "You fell off! Back to the start." });
      }
      if (intents?.interact) story.interact({ choose: true });
      const speed = Math.hypot(player.vel.x, player.vel.z);
      for (const q of activeQuests()) {
        const st = qs(q.id), step = stepOf(q);
        if (step.type === "reach" && step.zone === zone.id && Math.hypot(at(step).x - p.x, at(step).z - p.z) < step.r) advance(q);
        else if (step.type === "travel" && step.zone === zone.id) advance(q);
        else if (step.type === "level" && slot.level >= step.level) advance(q);
        else if (step.type === "train" && step.zone === zone.id) {
          if(step.requiredForms && !step.requiredForms.includes(player.form))continue;
          if (step.x !== undefined && Math.hypot(at(step).x - p.x, at(step).z - p.z) > step.r) continue;
          const charging = player.charging || (intents?.charge && speed < 1.5);
          const ok = step.mode === "move" ? speed > 1.5 || (player.flying && Math.hypot(player.vel.x, player.vel.y, player.vel.z) > 1.5)
            : step.mode === "charge" ? charging
            : step.mode === "fly" ? player.flying || !player.onGround
            : step.mode === "still" ? speed < 0.4 && !charging
            : true;
          if (!ok) continue;
          const before = Math.floor(st.t / 10);
          st.t += dt;
          if (Math.floor(st.t / 10) > before && st.t < step.seconds) emit("notify", { text: `${step.text}: ${Math.floor(st.t)} / ${step.seconds} s` });
          if (st.t >= step.seconds) advance(q);
        } else if (step.type === "collect") {
          st.collected ||= [];
          step.spots.forEach((s, i) => {
            if (st.collected.includes(i) || (s.zone ?? step.zone) !== zone.id) return;
            const y = zone.heightAt(s.x, s.z);
            if (Math.hypot(s.x - p.x, s.z - p.z) < PICKUP_RANGE && Math.abs(y - p.y) < 3.5) {
              st.collected.push(i);
              const label = ITEM_NAMES[step.item] || step.item;
              emit("notify", { text: `Found ${label} (${st.collected.length} / ${step.spots.length})` });
              if (st.collected.length >= step.spots.length) {
                if (step.item === "dragon_ball") S.flags.shenron = true;
                advance(q);
              }
            }
          });
        }
      }
      // travel pads
      const onPad = pads().find((pd) => Math.hypot(pd.x - p.x, pd.z - p.z) < PAD_RANGE && Math.abs(pd.y - p.y) < 2.5);
      if (!onPad) padArmed = true;
      else if (padArmed) {
        padArmed = false;
        emit("notify", { text: `Travelling to ${onPad.name}...` });
        emit("travel", { zone: onPad.zone });
      }
    },
  };
  // re-check steps that complete on arrival
  for (const q of activeQuests()) checkInstant(q);
  game.combat?.setStory(story);
  return story;
}

/** Replies when a quest sends you to talk to someone. */
const TALK_REPLIES = {
  farmer: "It came down like a meteor out yonder! And then a feller with crazy long hair shrugged off my shotgun!",
  goku_plains: "I'm okay... Piccolo, finish him!",
  dende: "Thank you for saving us. Come, I'll show you the way to the Grand Elder.",
  guru: "Kneel, child. Let me see what sleeps inside you...",
  king_kai: "Why did the... no, wait. You tell one. ...HAHAHA! Okay, okay, you pass!",
  android_16: "I will not fight unless it is to protect the birds... and Goku.",
  supreme_kai: "You can see me? Then you are strong. Listen: a wizard named Babidi...",
  goten_lookout: "Fu... sion... HA! Hehe, your fingers have to touch!",
  gohan_kai: "It's so heavy! And then... it snapped?!",
  elder_kai: "Ooh, what a nice young fighter. Sit down, sit down.",
  mai: "Trunks told me about you. We could use the help.",
  bulma_cc: "Everyone calm down! Beerus, would you like some more pudding?",
  shenron: "I AM THE ETERNAL DRAGON. SPEAK YOUR WISH.",
  goku_top: "Alright! Let's give it everything we've got!",
  vegeta_top: "Don't drag us down.",
  android_17_top: "I'm only here for the cruise.",
  frieza_top: "Ohoho. Temporarily, we are allies.",
  vegeta_cc: "Fine. Take it. And don't waste it.",
  gohan_cc: "Here. I hope it helps.",
  goten_cc: "Hnnngh! Did it work?",
  trunks_kid_cc: "This is so weird. Okay, go!",
  cheelai: "I wish... that Broly goes back to Vampa! Shenron, now!",
};

/** Which quest a giver offers first: story, then transformations, then side quests, then repeatable training. */
const priority = (q) => (q.main ? 0 : q.id.startsWith("Form_") ? 1 : q.repeat ? 3 : 2);

const ITEM_NAMES = { dragon_ball: "a Dragon Ball", namek_ball: "a Namekian Dragon Ball", supplies: "a supply crate" };

/** What people say when you have nothing to do with them. */
const AMBIENT = {
  goku_plains: "Hey! Want to spar later? I'm starving though.",
  piccolo_plains: "Stop staring and train.",
  farmer: "Strange folks flyin' around these days.",
  roshi: "Ho ho! Training is good, but so is a nap.",
  krillin_kame: "Eighteen is way stronger than me now. It's fine. It's fine!",
  king_yemma: "NEXT!",
  king_kai: "Did you hear the one about the cow who couldn't fly? Me neither, heh!",
  bubbles: "Ook ook!",
  moori: "Namek will recover. Namekians are patient.",
  dende: "I can heal people! Well, I'm still learning.",
  guru: "...zzz...",
  yardrat_elder: "Feel the ki. Be the ki. Arrive.",
  bulma_cc: "If it breaks, I can fix it. If it's Vegeta, I can't.",
  dr_brief: "Have you seen my cat?",
  vegeta_cc: "Tch.",
  mr_popo: "Mr. Popo waters the plants every day.",
  mr_satan: "Ha ha ha! I'm the champ! ...Who are you again?",
  announcer: "The crowd is going wild!",
  whis: "Ohoho. Is that food you're holding?",
  beerus: "Don't wake me unless there's pudding.",
  champa: "My universe is better. Obviously.",
  vados: "My brother is... a lot.",
  trunks_future: "Thank you for coming back to this timeline.",
  mai: "Keep your head down out there.",
  grand_priest: "Grand Zeno is enjoying himself.",
  cheelai: "Broly's sweet once you get to know him!",
  lemo: "I'm too old for this.",
  piccolo_rr: "Pan, stay close.",
  pan_rr: "Fly fly fly!",
};

/** For tests/tools: is a zone reachable at all? */
export function questById(id) { return QUEST[id]; }
export { getZone };
