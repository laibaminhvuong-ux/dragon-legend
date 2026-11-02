// A play session for one character slot: the authority for health, ki, XP, stats and position.
// Rendering, input and UI never change this state directly. They send intents to update() and
// call the methods below. No three.js in here, so it runs in node checks (and could run on a
// server later).
import { derive, xpToNext, addXP as progressionAddXP, spendStatPoint as progressionSpend } from "./progression.js";
import { getRace } from "../data/races.js";
import { FORMS } from "../data/forms.js";
import { getZone } from "./zones.js";
import { stepMovement } from "./movement.js";
import { regenKi } from "./ki.js";

/**
 * Intents: what the controlling player wants this step. Movement is already world-space
 * (main.js turns stick/WASD + camera yaw into moveX/moveZ). Buttons marked "edge" are true only
 * on the step the button went down; the others are true while held.
 */
export const INTENTS = {
  moveX: 0, moveZ: 0, // world-space wish direction, length <= 1
  jump: false, // edge
  dash: false, // edge
  flight: false, // edge (toggle)
  ascend: false, descend: false, // held
  charge: false, // held
  melee: false, // edge
  block: false, // held
  kiBlast: false, // edge
  beam: false, // held (charge), fires on release
  transform: false, // edge
  lockOn: false, // edge
  interact: false, // edge
};

export function emptyIntents() {
  return { ...INTENTS };
}

/**
 * @param slotIndex 0-based save slot
 * @param slot      slot data from save.loadSlot() (the game owns it until toSave())
 * @param events    app.events (game emits "notify", "levelup", "stats")
 */
export function createGame(slotIndex, slot, events = null) {
  const emit = (name, data) => events && events.emit(name, data);
  const zone = getZone(slot.zone);
  const spawn = slot.position || { x: zone.spawn.x, y: zone.heightAt(zone.spawn.x, zone.spawn.z), z: zone.spawn.z };

  /** The player's entity. Enemies/NPCs (M2) use the same shape. */
  const player = {
    id: "player",
    kind: "player",
    pos: { ...spawn },
    vel: { x: 0, y: 0, z: 0 },
    yaw: 0, // radians, 0 = facing +Z
    onGround: true,
    form: "", // "" = base
    health: 0, maxHealth: 0,
    ki: 0, maxKi: 0,
    runSpeed: 0, strength: 1, kiPower: 1, powerLevel: 0,
    flying: false, dashing: false, charging: false, blocking: false,
    stun: 0, // seconds left
    lockTarget: null, // entity id or null
  };

  function refreshDerived(fillUp = false) {
    const d = derive(slot, player.form);
    const hpFrac = player.maxHealth ? player.health / player.maxHealth : 1;
    player.maxHealth = d.maxHealth;
    player.maxKi = d.maxKi;
    player.runSpeed = d.runSpeed;
    player.strength = d.strength;
    player.kiPower = d.kiPower;
    player.powerLevel = d.powerLevel;
    player.health = fillUp ? d.maxHealth : Math.round(d.maxHealth * hpFrac);
    player.ki = fillUp ? d.maxKi : Math.min(player.ki, d.maxKi);
    emit("stats", hud());
  }

  function hud() {
    return {
      slot: slotIndex,
      race: slot.race,
      raceName: getRace(slot.race)?.name || slot.race,
      form: player.form,
      formName: player.form ? FORMS[player.form]?.name || player.form : "",
      level: slot.level,
      xp: slot.xp,
      xpNext: xpToNext(slot.level),
      statPoints: slot.statPoints,
      zeni: slot.zeni,
      health: player.health, maxHealth: player.maxHealth,
      ki: Math.floor(player.ki), maxKi: player.maxKi,
      powerLevel: player.powerLevel,
      flying: player.flying, charging: player.charging, dashing: player.dashing, blocking: player.blocking,
      lockTarget: player.lockTarget,
      zone: zone.id, zoneName: zone.name,
    };
  }

  const game = {
    slotIndex,
    slot,
    zone,
    player,
    /** Every live entity, player first. M2 adds enemies here. */
    entities: [player],
    time: 0,

    /** One fixed simulation step. */
    update(dt, intents) {
      game.time += dt;
      slot.playTime += dt;
      stepMovement(player, intents, dt, zone);
      regenKi(player, dt);
      if (player.stun > 0) player.stun = Math.max(0, player.stun - dt);
    },

    /** Read-only snapshot for the HUD. Cheap; fine to call every frame. */
    hud,

    addXP(amount) {
      const gained = progressionAddXP(slot, amount);
      if (gained > 0) {
        refreshDerived(true);
        emit("levelup", { level: slot.level, gained });
        emit("notify", { text: `Level up! You are now level ${slot.level}.` });
      } else emit("stats", hud());
      return gained;
    },

    /** Returns null on success, else an error message. */
    spendStatPoint(stat, amount = 1) {
      const err = progressionSpend(slot, stat, amount);
      if (!err) refreshDerived();
      return err;
    },

    addZeni(n) {
      slot.zeni = Math.max(0, slot.zeni + Math.floor(n));
      emit("stats", hud());
    },

    /** The slot data to write with save.saveSlot(); includes the current position. */
    toSave() {
      slot.position = { x: player.pos.x, y: player.pos.y, z: player.pos.z };
      slot.playedAt = Date.now();
      return slot;
    },
  };

  refreshDerived(true);
  return game;
}
