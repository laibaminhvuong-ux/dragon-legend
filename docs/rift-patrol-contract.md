# Rift Patrol rules and integration contract

Godot-only post-game content, authored in `tools/rift_patrol.mjs` before `applyGodotAdditions`. Export normally with `node tools/export_godot_data.mjs`. Classic web data and its six legacy migration oracles remain unchanged. Claude owns hub/map/character/UI/scene presentation; Codex owns these rules, data, network hooks and tests.

## Entry and catalogue

Unlock comes from completing `m34_super_hero`, the actual final adult main quest after `m41_black_frieza`; no new Origins replay is required for existing fighters. Completion or a prior completion count qualifies. Dynamic `rift_recruiter` uses character `archivist_tem`, appears beside the current pilot/region travel point, and speaks as Archivist Tem. Interaction enters the Nexus. `game.enter_rift_hub()` also serves the post-mission return button. Solo travel uses the ordinary travel/rebuild event and `leaving_to`; co-op routes through the room and moves the whole patrol.

`rift_missions.json` is an object with `unlock_quest`, `hub`, `arcs`, `missions`. Mission rows contain `id`, `arc`, `name`, `zone`, `level`, `after`, `corrupted`, `arena`, `spawn`, `waves[].spawns`, `allies`, `objectives`, `stars` and `rewards`.

| ID | Arc | Map | Mission |
|---|---:|---|---|
| rp01_dark_crystal | 1 | earth_plains | A Crystal at the Landing |
| rp02_shattered_landing | 1 | gizard_wasteland | The Shattered Landing |
| rp03_nameck_storm | 1 | namek | Storm over Nameck |
| rp04_shard_emperor | 1 | namek | The Shard Emperor |
| rp05_vael | 1 | yardrat | Vael’s Stolen Hour |
| rp06_echo_breakout | 2 | echo_prison | Breakout from Echo Prison |
| rp07_cyborg_riot | 2 | echo_prison | Cyborg Riot |
| rp08_prison_tournament | 2 | echo_prison | The Prison-Yard Tournament |
| rp09_morrigath | 2 | echo_prison | Morrigath’s Last Chain |
| rp10_hollow_games | 3 | cell_games | The Hollow Games |
| rp11_crown_rampage | 3 | papaya_island | The Crown’s Rampage |
| rp12_arena_of_night | 3 | world_of_void | Arena of Night |
| rp13_nyxara | 3 | kai_world | The Obsidian Crown |
| rp14_remnants | 4 | time_nexus | Remnants of the Unwound |
| rp15_zero_origin | 4 | time_nexus | The End of Time |

Arcs: The Fractured Timeline; Prison of Echoes; The Dark Crown War; The End of Time. Every mission requires a clear of its predecessor. Two waves: four Shardlings, then the named opponents (one to three). Each stage spawns once under stable `rift:<mission>:<wave>:<index>` ids; dead enemies never respawn during the run. Ordinary quest objectives, doors, portals and travel are paused/blocked, and ordinary patrols are removed from the encounter. The room's previous ambient entities return with their health preserved after the run. Nexus and Echo Prison do not spawn ordinary training patrols.

All actors are Lv2000. Shardlings use health scale0.45/damage scale0.55. Bosses use health scale1.5 (Zero-Origin3) and damage scale0.85; ordinary boss tuning still applies. Boss phases cross 100%,66%,33% health: Breach, Fracture, Collapse; damage multipliers1/1.2/1.4 and movement1/1.1/1.2. Phases never regress after healing. They emit a phase cue; Claude owns its visible treatment. Existing style combat drives attacks; no extra damage is scheduled by visuals.

## Public game API

- `rift_missions() -> Array`: `{id,arc,name,zone,unlocked,stars,done}`.
- `start_rift_mission(id) -> Variant`: null on accepted launch, refusal String otherwise. Requires Nexus, unlocked mission, standing fighter, no other active/in-flight run. A different map emits travel; the destination rebuild starts the encounter. Callers must not grant rewards when null is returned.
- `active_rift_mission() -> Dictionary`: empty before any run; otherwise `{id,name,zone,arc,status,corrupted,objectives,timer,wave,kills,ally_down,allies,stars,reason,serial}`. Status is active/complete/failed. `corrupted` is true only while active. Objectives contain `type,text,progress,count` for defeats and `type,text,progress,ally` for protection. Timer is simulated active time in seconds. Solo menus pause the simulation; the co-op room clock continues while a member opens a private menu.
- `enter_rift_hub() -> Variant`: normal return/entry travel. Refuses during active missions or while knocked out.
- `abandon_rift_mission() -> Variant`: fail without partial rewards; returns null or refusal String.
- `hero_cards() -> Array`: `{id,name,character,rarity,effect,owned,equipped}`. **Equipped is a zero-based slot index or -1**, not a bool.
- `equip_hero_card(id,index) -> Variant`: index0..2, empty id unequips. Rejects unowned cards, duplicate equips, nonintegral/out-of-range slots and changes during a run. Preserves current health fraction when max health changes.

Mission state/allies are read APIs; views should not mutate them. At landing, initialise presentation from `active_rift_mission()` as well as listening to events: the launch can occur during game construction before a view subscribes.

## Allies, rating and rewards

`combat.allies` holds 1–2 independently moving, attacking heroes. Rows include `id,key,character,kind:"ally",name,look,style,scale,pos,home,vel,yaw,health,maxHealth,ki,blocking,stun,hurtUntil,attackSerial,attackKind,onGround,flying,runSpeed`. Position/home/velocity are Vector3 in rules; the codec serializes them as objects and converts them back for online combat views. The AI selects living Rift enemies, moves with collision/ground checks, turns toward its target and deals real hits on cooldown. Its velocity is exposed for walk animation. Enemies choose the nearest living player or ally. Allies can be knocked out and stay down for that run; no kill rewards are granted for ally knockouts.

Protected-ally missions: rp03,rp06,rp09,rp11,rp14. A protected knockout fails immediately at the next rule update, including a knockout simultaneous with the last boss kill. Solo player knockout fails; rooms fail when every player is down. Falling below a floating arena's kill boundary counts as a knockout; enemies falling out count as defeats.

Stars: one for clear, one extra at timer<=240s, one extra if no ally fell. A fast clear with an ally down and a slow clear with everyone standing both award two. Best stars never decrease; clear count increments once per completed run. Replays are intentionally repeatable.

Every clear: 500,000XP and15,000zeni. First clear adds35,000zeni and that mission's rare Hero Card. First three-star clear grants its legendary prismatic card, including on a later replay. No per-enemy XP/zeni: abandoning/reloading/farming partial waves grants nothing. Existing form mastery from player hits still applies. Mission completion updates every participant's result/card/wallet before completion receipts are emitted; repeated finish/kill callbacks cannot duplicate awards.

## Hero Cards and save format

30 cards: `<mission>_hero` (rare, first clear) and `<mission>_prismatic` (legendary, three stars). Art reference is `character`; rarity frame and art rendering are Claude's. Rare passives cycle +2% Ki regeneration, +2% player damage, +2% max health, +3% ally health. Different cards can stack; duplicates cannot equip. Supported stat sums cap at9%. Ally-health contributions from all room fighters combine, capped at9%. Legendary `effect:{cosmetic:"rift_prismatic"}` is an equipped visual token for Claude's renderer, not an additional stat boost.

Schema9, ten slots, same DL1 prefix. Slot state:

```
rift: {
  results: { mission_id: { stars: 0..3, clears: nonnegative_int } },
  cards: [owned_known_card_ids],
  equipped: [card_id_or_empty, card_id_or_empty, card_id_or_empty],
  pending: optional_mission_id
}
```

Existing v1–v8 saves acquire empty results/cards/equipment without moving, rescaling or resetting them. Unknown/invalid ids and duplicate equipment are repaired; normalization grants no cards. Results/cards/equipment survive disk and DL1 roundtrips.

**Interrupted runs restart the full encounter.** Active `to_save` writes only the pending mission id for relaunch; no partial kills, timer or health checkpoint is trusted/persisted. Relaunch resets all enemies/allies, timer and rating eligibility together. Clear/failure removes pending. Offline pending is deliberately stripped on importing a fighter into a friend server; only the room owner launches room missions. Completed rewards still travel with the chosen fighter slot. No cloud ledger or cross-device transaction is claimed.

## Co-op and durable snapshots

Commands: `rift_start [id]`, `rift_hub []`, `rift_abandon []`, `hero_card [id,index]`. Mirrors queue commands with no reward/card/AI prediction. The owner alone launches, brings the room to Nexus, or abandons. Every connected member must be in-game, standing and have finished the adult story; each must have the mission unlocked. Validation happens before any travel. Late joins are refused during active missions; a member disconnect aborts the run without rewards. Existing ephemeral server lifetime remains unchanged.

The whole room shares one run, enemy array and ally array. The room updates its timer and ally AI once per step, independent of player count; players still have their own forms, stats, cards and wallets. All participants receive their own once-only reward result. Snapshots add `rift` and `allies` alongside the existing fields. Stage/counter/reward mutation stays on the host.

The existing monotonic `zeniRevision` is reused as the durable **fighter-progress revision** for mission settlements, hub transition saves and card equips. Both local-host and WebSocket clients already persist when it advances, retry failed writes, and retain autosave/exit saves. This is why no separate revision counter can mask a later wallet change. The refusal message now says "server fighter changed" to cover both wallets and cards. Separate client disks remain independent; a disconnect before the latest snapshot can retain the last received state.

Completion/start/failure receipts displace old FX events if a queue is full. Scene event forwarding exists in `network/play_session.gd`. Solo scene allowlist/presentation remain Claude-owned.

## Events and Claude's integration

Core Events signals are declared:

| Event | Typed signal | Payload |
|---|---|---|
| riftMissionStarted | rift_mission_started | id, stars, rewards |
| riftMissionComplete | rift_mission_complete | id, stars, rewards |
| riftMissionFailed | rift_mission_failed | id, reason |
| riftBossPhase | rift_boss_phase | id(entity), character, phase(0..2), name, pos |
| riftAllyDown | rift_ally_down | id(entity), character |

Completion `rewards.zeni` is the actual payout; `rewards.cards` is the array of newly granted ids. Other reward keys describe the catalogue, so do not announce `rewards.card` again on every replay. AI uses existing attack/damage events with ally actor ids. Phase/down cues replicate across the room; completion rewards are private to each participant.

Original character ids: vael,shardling,morrigath,nyxara,hollow_gokan,hollow_vegara,hollow_piccor,zero_origin,archivist_tem. Rows exist before Claude's appearance pass; fallback base looks are not a claim of finished new meshes. `time_nexus` and `echo_prison` bootstrap data are separate floating/prison maps using established builders. Claude's Nexus block overrides the fallback, and Claude owns Echo Prison's presentation upgrade. Story-area completeness tests exclude saga Rift Patrol; those places become available only after the adult campaign.

Claude's gates: finish models, card/mission screens, board/gate interaction, ally views and event forwarding in the solo scene; initialise corruption/mission views at landing; GPU-check arenas and phase cues; exercise two real socket peers with a room launch/clear/return and persisted cards; build/publish only after those checks. No Codex build/install/commit/publish.

## Verified release (2026-11-05)

Native Godot4.7.2: `tools/godot_test.sh --check-data` **330 passed,0 failed**, exit0,44 data tables verified (`/tmp/dragon-rift-release-suite.log`). Fifteen new Rift cases cover all15 missions with actual combat damage and all30 card rewards, unlocks/replays/once-only payouts,1/3-star outcomes and best-star upgrades, protected/simultaneous knockouts, ally movement/attacks/enemy retaliation, phase progression, floating-arena fall, save restart and legacy migration, card validation/stat effects, shared room timer/enemies/allies, owner/eligibility checks, disconnects, roster admission, private pending suppression, ambient world preservation, full-queue completion receipts and a client disk save from an authoritative completion snapshot. Existing315 regression cases pass.

`node tools/check_godot_export.mjs`: **9 checks passed** (deterministic export/hash/stale detection,44 tables, mission/card/reference graph, bounded passives and original-villain rows, classic JS parity). `git diff --check` passes. Usual startup socket-denial warnings and existing post-test focus/resource diagnostics remain outside test failures. No new real two-peer socket/GPU/scene-presentation pass is claimed; those remain the integrator gate described above.
