import { accessoryAvailable } from "../data/accessories.js";
import { gainFormMastery, MASTERY } from "./mastery.js";
import { validateLook } from "./look.js";
import { usableForms, chooseFormPath } from "./forms.js";
import { outfitAllowed } from "../data/outfits.js";
// A play session for one character slot: the authority for health, ki, XP, stats and position.
// Rendering, input and UI never change this state directly. They send intents to update() and
// call the methods below. No three.js in here, so it runs in node checks (and could run on a
// server later).
import { derive, xpToNext, addXP as progressionAddXP, spendStatPoint as progressionSpend } from "./progression.js";
import { getRace } from "../data/races.js";
import { FORMS } from "../data/forms.js";
import { getZone } from "./zones.js";
import { stepMovement } from "./movement.js";
import { createCombat } from "./combat.js";
import { createKaioken } from "./kaioken.js";
import { resolveCollisions } from "./collision.js";
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
  flyPitch: 0, // -1..1 while flying: where the camera looks, up (+) or down (-), times forward input
  charge: false, // held
  melee: false, // edge
  block: false, // held
  kiBlast: false, // edge
  beam: false, // held (charge), fires on release
  transform: false, // edge
  kaioken: false, // edge: independent technique overlay
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
    onGround: spawn.y <= zone.heightAt(spawn.x, spawn.z),
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
    player.kiCostScale=d.kiCostScale;
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
      formName: (player.form ? FORMS[player.form]?.name || player.form : "Base")+(player.kaioken?` + Kaiyoken x${player.kaioken}`:''),
      level: slot.level,
      xp: slot.xp,
      xpNext: xpToNext(slot.level),
      statPoints: slot.statPoints,
      zeni: slot.zeni,
      health: player.health, maxHealth: player.maxHealth,
      ki: Math.floor(player.ki), maxKi: player.maxKi,
      powerLevel: Math.floor(player.powerLevel*(game.kaioken?.multiplier() || 1)),
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

    refreshDerived,
    addFormMastery(amount) {
      if(!player.form || player.health<=0)return [];
      const evolved=gainFormMastery(slot,player.form,amount);
      if(evolved.length){player.form=evolved.at(-1);refreshDerived();emit('notify',{text:`Mastery evolution: ${FORMS[player.form].name}!`});}
      return evolved;
    },
    selectForm(id) {
      if(player.health<=0 || player.stun>0)return 'You cannot transform right now.';
      if(id && !usableForms(slot).includes(id))return 'Unlock this form, its level and its chosen path first.';
      if(id && player.ki<FORMS[id].kiDrain*player.kiCostScale)return 'Charge more ki first.';
      player.form=id;if(id!=='UltraEgo')player.egoBoost=0;refreshDerived();game.kaioken.update(0);return null;
    },
    customizeAppearance(changes) {
      const next={race:slot.race,...slot.appearance,...changes};
      if(next.race!==slot.race)return 'Choose a new character slot to change race.';
      if(!slot.outfits.includes(next.outfit) || !outfitAllowed(next.outfit,slot.race))return 'You do not own that outfit.';
      // Owned shop/quest outfits are valid; creator validation checks body/hair palettes separately.
      const error=validateLook({...next,outfit:slot.outfits.find(id=>id==='TurtleGi') || 'TurtleGi'});
      if(error)return error;
      const {race,...appearance}=next;Object.assign(slot.appearance,appearance);return null;
    },
    chooseFormPath(path) {
      const err=chooseFormPath(slot,path);
      if(!err)emit("notify",{text:`Chosen transformation path: ${path}. Speak to its trainers for unlock quests.`});
      return err;
    },
    equipAccessory(id) {
      if(!accessoryAvailable(slot,id))return 'Complete the accessory’s unlock quest first.';
      slot.loadout.accessory=id;slot.appearance.accessory=id;return null;
    },
    equipOutfit(id) {
      if (!slot.outfits.includes(id) || !outfitAllowed(id, slot.race)) return false;
      slot.appearance.outfit = id; return true;
    },

    /** One fixed simulation step. */
    update(dt, intents) {
      game.time += dt;
      slot.playTime += dt;
      const previous = { ...player.pos };
      if (player.health > 0) stepMovement(player, intents, dt, zone);
      resolveCollisions(player, zone, previous);
      if (intents.transform && player.health > 0 && player.stun <= 0) {
        const unlocked = usableForms(slot);
        const next = unlocked[(unlocked.indexOf(player.form) + 1) % (unlocked.length + 1)] || "";
        if (next && player.ki < FORMS[next].kiDrain*player.kiCostScale) emit("notify", { text: "Charge more ki before transforming." });
        else {
          player.form = next; refreshDerived();
          emit("notify", { text: next ? FORMS[next].name : "Returned to base form." });
        }
        if (!unlocked.length) emit("notify", { text: "Complete your race's transformation quests to unlock a form." });
      }
      if(intents.kaioken){const error=game.kaioken.toggle();if(error)emit('notify',{text:error});}
      game.kaioken.update(dt);
      game.combat.update(dt, intents);
      if(player.form && (player.charging || Math.hypot(player.vel.x,player.vel.y,player.vel.z)>.5))game.addFormMastery(MASTERY.perSecond*dt);
      if (!player.flying && !player.dashing && !player.charging && !player.form && player.health > 0) regenKi(player, dt);
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
  game.kaioken = createKaioken(game);
  game.combat = createCombat(game, events);
  return game;
}
