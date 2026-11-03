// The first-play tutorial (pure rules; ui/tutorial.js shows it). New characters walk through the controls
// one step at a time; each step finishes when the player actually does it. Progress lives in
// slot.story.flags.tutorial: a step index while running, "done" or "skipped" afterwards.
// Characters that already played (level > 1 or any quest touched) never see it.

/** k = key labels by action id (from the player's bindings). */
export const TUTORIAL_STEPS = [
  { id: "look", text: () => "Move the mouse to look around. (Click the game first if the mouse isn't captured.)", done: (c) => c.look > 1.2 },
  { id: "move", text: () => "Walk around with W A S D.", done: (c) => c.moved > 6 },
  { id: "jump", text: (k) => `Press ${k.jump} to jump.`, done: (c) => c.count.jump >= 1 },
  { id: "dash", text: (k) => `Press ${k.dash} while moving to dash.`, done: (c) => c.count.dash >= 1 },
  { id: "fly", text: (k) => `Press ${k.flight} to fly. Hold ${k.ascend} to rise and ${k.descend} to sink.`, done: (c) => c.flying > 1.5 },
  { id: "land", text: (k) => `Press ${k.flight} again to land.`, done: (c) => !c.player.flying && c.player.onGround },
  { id: "melee", text: (k) => `${k.melee}: punch. Throw three punches in a row for a combo.`, done: (c) => c.count.swing >= 3 },
  { id: "blast", text: (k) => `Press ${k.kiBlast} to fire a ki blast.`, done: (c) => c.count.kiBlast >= 1 },
  { id: "beam", text: (k) => `Hold ${k.beam} to charge your Energy Wave, then let go to fire it.`, done: (c) => c.count.beamRelease >= 1 },
  { id: "charge", text: (k) => `Attacks use ki (the blue bar). Hold ${k.charge} to charge it back up.`, done: (c) => c.charging > 1.5 },
  { id: "guard", text: (k) => `Hold ${k.block} to guard and take less damage.`, done: (c) => c.blocking > 1 },
  { id: "lock", text: (k) => `Press ${k.lockOn} to lock on to the nearest enemy (press again to switch or release).`, done: (c) => c.count.lockOn >= 1 },
  { id: "talk", text: (k) => `People with "!" over their head have quests. Walk up to Gokan and press ${k.interact} to start the story.`, done: (c) => c.talked },
  { id: "menu", text: (k) => `Character, Stats, Forms and Techniques are in the bar at the bottom; ${k.pause} pauses. ${k.transform} transforms and ${k.base} takes you back to base form. Bosses talk before you fight them. When a planet's story is done, a pilot ✈ flies you onward. Good luck!`, done: (c) => c.time > 10 },
];

export function createTutorial(slot) {
  const flags = ((slot.story ||= {}).flags ||= {});
  if (flags.tutorial === undefined) {
    const veteran = slot.level > 1 || Object.keys(slot.quests || {}).length > 0;
    flags.tutorial = veteran ? "done" : 0;
  }
  let c = null;
  const reset = () => (c = { time: 0, look: 0, moved: 0, flying: 0, charging: 0, blocking: 0, talked: false, count: { jump: 0, dash: 0, swing: 0, kiBlast: 0, beamRelease: 0, lockOn: 0 }, player: null });
  reset();
  let lastSerial = null, beamWasHeld = false, lastPos = null;
  const t = {
    get active() { return typeof flags.tutorial === "number" && flags.tutorial < TUTORIAL_STEPS.length; },
    get index() { return t.active ? flags.tutorial : -1; },
    get step() { return t.active ? TUTORIAL_STEPS[flags.tutorial] : null; },
    total: TUTORIAL_STEPS.length,
    /** Camera movement this frame (radians), from the renderer. */
    look(amount) { if (t.active) c.look += Math.abs(amount); },
    /** Something the player did outside the game step (talked to someone, accepted a quest). */
    note(what) { if (t.active && what === "talk") c.talked = true; },
    /** Once per game step. Returns the finished step's id when a step completes, else null. */
    update(dt, it, player) {
      if (!t.active) return null;
      c.player = player; c.time += dt;
      if (lastPos) c.moved += Math.hypot(player.pos.x - lastPos.x, player.pos.z - lastPos.z);
      lastPos = { x: player.pos.x, z: player.pos.z };
      if (player.flying) c.flying += dt;
      if (player.charging || it.charge) c.charging += dt;
      if (player.blocking || it.block) c.blocking += dt;
      for (const a of ["jump", "dash", "kiBlast", "lockOn"]) if (it[a]) c.count[a]++;
      if (lastSerial !== null && player.attackSerial !== lastSerial) c.count.swing++;
      lastSerial = player.attackSerial;
      if (beamWasHeld && !it.beam) c.count.beamRelease++;
      beamWasHeld = !!it.beam;
      const step = TUTORIAL_STEPS[flags.tutorial];
      if (!step.done(c)) return null;
      flags.tutorial++;
      if (flags.tutorial >= TUTORIAL_STEPS.length) flags.tutorial = "done";
      reset();
      return step.id;
    },
    skip() { if (t.active) flags.tutorial = "skipped"; },
    restart() { flags.tutorial = 0; reset(); },
  };
  return t;
}
