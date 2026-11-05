# Rift Patrol — post-game timeline missions (design, 2026-11-05)

User: "after we finished every task, lead the game to another story line where unique villains start invading timelines and our character helps them. The format should be like Super Dragon Ball Heroes."

All villains, places and names are ORIGINAL (no SDBH characters/names). Format inspiration only: mission-based arcs, altered famous battles, team-ups, star ratings, collectible cards.

## Unlock and hub
- Unlocks when the last adult main quest is done (and works for existing saves already past it). A recruiter NPC, **Archivist Tem**, appears near the player's current pilot and offers "Rift Patrol".
- **Time Nexus** (`time_nexus` zone, Claude): a floating sanctum in a starry time void; the Mission Board terminal (interact) opens the mission screen; a rift gate launches the chosen mission.

## Missions
- A mission = a twisted replay of a famous story battle on its existing map, under a corrupted-timeline look. Objectives: defeat N corrupted enemies, protect/assist an ally, defeat the arc villain's lieutenant or the villain.
- **Allies:** 1–2 hero NPCs from that era fight beside the player (their own AI, target enemies, can be knocked out but not killed; mission fails if the protect target falls where stated).
- **Rating:** 1–3 stars (clear / clear under time T / clear with no ally down). Replayable for higher stars.
- **Rewards:** XP, zeni, and a **Hero Card** per mission's first clear (plus a rarer card at 3 stars). Cards: collectible list (name, art = character + rarity frame), some give a cosmetic or a small passive (e.g., +2% ki regen) — equip up to 3.

## Arcs (original villains)
1. **The Fractured Timeline** — *Vael the Unwound*, a time thief (lean, coat of clock-shards, a pale mask) and his **Shardlings** (crystal imps). Missions: Radix empowered by a dark crystal (Plains), Saiyar landing with Shardlings (Gizard), Nameck under a rift storm, Frigor's final form fused with shards, Vael.
2. **Prison of Echoes** — *Warden Morrigath* (armoured jailer, chain-whip, cage helm) holds fighters from every era on the **Echo Prison** world. Missions: break out allies, cyborg riot, a prison-yard tournament, Morrigath.
3. **The Dark Crown War** — *Empress Nyxara* (regal, obsidian crown, cloak of night) and the **Hollow Kings** (shadow copies of heroes: Hollow Gokan, Hollow Vegara, Hollow Piccor). Missions at the Cel Games, Boo's rampage, Tournament of Might arena, Nyxara.
4. **The End of Time** — *Zero-Origin* (a towering faceless being of light and void) behind them all; the four villains' remnants; final mission in the collapsing Time Nexus.

## Ownership
- **Codex:** unlock rule, recruiter + dialogue, mission catalogue/state (`rift_missions` table: id, arc, map zone, spawn sets, allies, objectives, star rules, rewards), ally AI in combat, villain/minion stats and boss phases, Hero Cards (catalogue, collection, equip, passives), save schema, co-op behaviour (missions run for the room), tests.
- **Claude:** `time_nexus` map + landmarks, Mission Board + Hero Card screens, corrupted-timeline visuals (sky/fog tint, rifts, floating shards) driven by an active-mission flag, villain/minion models (Vael, Shardlings, Morrigath, Nyxara, Hollow Kings as dark variants, Zero-Origin), rift gate/portal FX, ally rendering in combat, GPU review, builds.
