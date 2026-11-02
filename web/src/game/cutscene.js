// When boss cutscenes play (pure rules; ui/cutscene.js shows them). A story boss is the single enemy of a
// quest's "defeat" step. Its "before" scene plays the first time you come within SCENE_RANGE of it, and
// its "after" scene right after you beat it. Each plays once per character (slot.story.flags.scenes).
import { BOSS_SCENES, genericScene } from "../data/cutscenes.js";
import { QUESTS, NPCS, CHARACTERS } from "../data/story.js";

export const SCENE_RANGE = 24;
const NPC = Object.fromEntries(NPCS.map((n) => [n.id, n]));
/** Every enemy that is a story boss (the lone target of a defeat step). */
export const STORY_BOSSES = new Set(QUESTS.flatMap((q) => q.steps.filter((s) => s.type === "defeat" && (s.count || 1) === 1 && !s.enemy.startsWith("patrol_")).map((s) => s.enemy)));

/** The lines of a boss scene: [{ speaker: "you" | npcId, name, text }]. */
export function sceneLines(enemyKey, kind, bossName = null) {
  const name = (id) => (id === "you" ? "You" : CHARACTERS[NPC[id]?.who]?.name || bossName || id);
  const lines = BOSS_SCENES[enemyKey]?.[kind] || genericScene(bossName || name(enemyKey), kind);
  return lines.map(([who, text]) => {
    const speaker = who === "boss" ? enemyKey : who;
    return { speaker, name: name(speaker), text };
  });
}

/** Per-character bookkeeping of which scenes were seen. */
export function createSceneDirector(slot) {
  const flags = ((slot.story ||= {}).flags ||= {});
  const seen = (flags.scenes && typeof flags.scenes === "object") ? flags.scenes : (flags.scenes = {});
  const key = (kind, enemy) => `${kind}:${enemy}`;
  return {
    /** The "before" scene to start now, given story.encounters() and the player's position, or null. */
    beforeFor(encounters, pos) {
      for (const e of encounters || []) {
        if (!e.boss || !STORY_BOSSES.has(e.key) || seen[key("before", e.key)]) continue;
        if (Math.hypot(e.x - pos.x, e.z - pos.z) > SCENE_RANGE) continue;
        seen[key("before", e.key)] = true;
        return { kind: "before", enemy: e.key, lines: sceneLines(e.key, "before", e.name) };
      }
      return null;
    },
    /** The "after" scene for a defeated enemy, or null (not a story boss, or already seen). */
    afterFor(enemy, bossName = null) {
      if (!STORY_BOSSES.has(enemy) || seen[key("after", enemy)]) return null;
      seen[key("after", enemy)] = true;
      return { kind: "after", enemy, lines: sceneLines(enemy, "after", bossName) };
    },
  };
}
