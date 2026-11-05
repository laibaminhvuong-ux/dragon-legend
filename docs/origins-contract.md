# Origins childhood campaign (Godot)

Authored in `tools/origins.mjs`, applied before `applyGodotAdditions` by the normal exporter. Classic web data and its v1–v6 parity fixtures remain unchanged. Export with `node tools/export_godot_data.mjs`; never hand-edit generated JSON.

## Chapters

All seven rows have `main:true`, `origins:true`, `line:"Origins"`, `saga:"Origins"`, `chapter:1..7`. Each depends on the preceding chapter. Total: **97 objectives, 23 staged boss bouts**, each with authored before/after dialogue. All chapters work for every playable race.

| Quest | Entry level | Objectives | Bosses (level) | Quest XP / zeni |
|---|---:|---:|---|---:|
| `k01_emperor_pilav` | 1 | 22 | Pilav Battle Walker (2) | 100 / 120 |
| `k02_world_tournament_21` | 2 | 13 | Gyran (3), Namu (3), Jackie Chung (4) | 600 / 180 |
| `k03_red_ribbon` | 4 | 20 | Silvar (4), Murasake (4), Whyte (5), Bleu (5), Tau (6), Rudd (6) | 900 / 300 |
| `k04_fortuneteller_baaba` | 6 | 10 | Fangor (6), Veilor (6), Mummor (6), Devilon (7), Grandpa Gohin (7) | 650 / 400 |
| `k05_world_tournament_22` | 7 | 7 | Chaozo (7), Cyborg Tau (8), Tenzo (8) | 850 / 500 |
| `k06_king_piccor` | 8 | 14 | Tamburin (8), Cymbel (8), Drumm (9), King Piccor (10) | 1,050 / 650 |
| `k07_piccor_jr` | 9 | 11 | Piccor Jr. (10) | 1,250 / 800 |

XP/zeni here are quest rewards; normal combat rewards are additional. Each chapter restores health/Ki. The natural-reward test completes every chapter without grinding the entry levels; adult story levels/rewards and level cap 2000 stay unchanged. No forms, racial paths or advanced techniques are granted by this line. The player accompanies young Gokan; the full moon/Great Ape incident is described by the story speakers, never forced onto the player's race/model. Claude owns cinematic visuals and character/world presentation.

Chapter1 covers Bulna's radar, Ulong, Yamcho/Puir, the Ox-Lord's burning castle, Roshu's wave, Mae/Shoo/Pilav, the robot, the prison/full moon/ape escape and the scattered orbs. Chapter2 has milk deliveries, running and strength drills, preliminaries and the tournament. Chapter3 covers the army commanders, Muscle Tower, Cyborg8's choice, Korrin's training and HQ. Chapter4 has all five palace fighters and the grandfather reveal. Chapter5 follows the approved Crane School/cyborg-Tau tournament remix. Chapter6 covers the attacks, divine-water trial and castle. Chapter7 has Lookout training and the final before the adult handoff at `goku_plains`.

Collection is local to each objective: `RuleStory.advance` clears `collected`, as it already clears `t` and `count`. This prevents an earlier orb collection from blocking a later one. `origins_ball` is a separate story item and never sets the adult `shenron` flag. The childhood radar is the keepsake item `origins_radar`; it does not grant the adult radar quest. Chapter4's keepsake and chapter6's water are quest objectives, not repeatable wish/stat rewards.

## Save contract

Godot profile schema **8**, ten slots, existing `DL1:` prefix. `new_slot` starts in `mt_paozu`, unlocks it, sets `story.flags.originsRequired=true`. The first chapter is the first offered main quest; accepting through the normal NPC interaction starts it. All older missing markers normalize to **false**. Existing location, position, quests, balances, stats, inventory, mastery, appearance, style and scenes are retained. Normalization is idempotent; no second level conversion. Existing legacy codes remain importable.

Data `m01_arrival.after=["k07_piccor_jr"]`. Runtime **`RuleStory.required_after(q)`** removes only that edge for existing fighters. Use this helper for prerequisite logic; reading `q.after` directly incorrectly forces legacy replay. **`RuleStory.is_main(q)`** classifies childhood as main only when required, so legacy players keep their adult main navigation/priority/tracker/pilot prompts. Optional Origins quests can still be accepted, tracked and completed, with normal sequential chapter dependencies and one-time rewards. The original 41 adult main quests become 48 for a new fighter.

## Integrator map/character contract

Content runs BEFORE `applyGodotAdditions`, making all rows available to Claude's look assignments. Preserve the two additions-function fallback changes: supplied `character.style` survives without an explicit style assignment; schema version never falls below the input version. `origins.json` publishes `first_quest`, `last_quest`, `start_zone`, `required_flag`, ordered `chapters`, and `character_ids`.

Regions: `mt_paozu`, `fire_mountain`, `pilav_castle`, `muscle_tower`, `baaba_palace`, `korrin_tower`, `kamu_lookout`, `piccor_castle`, `tournament_island`, existing `kame_island`, `red_ribbon`, `earth_plains`. New region levels are 1/1/1/4/6/4/9/8/2 respectively. Only Kamu's Lookout uses a separate sky map. For the current active Origins objective (or the next offered main Origins chapter), `travel_level` admits its destination at the chapter entry level. This is needed because reused Kame House and Red Ribbon have adult travel requirements 10 and 1900. The exception ends when that objective changes; global region difficulty and adult patrol levels stay unchanged. Red Ribbon's early named boss positions are separated from its neutral endgame trainee camp; avoid provoking those trainees. New starter actors stand at local x=-4/+4,z=-65, beside the Mt. Paozu spawn. NPCs use separate approach positions outside the castle footprints. Boss NPCs have `boss:true`, `before:<chapter>`, `afterStep:[chapter,index]`, with the exact per-bout level on the step's `enemyLevel`.

New character ids (all have renamed display names and their own face seed):

`goku_kid`, `krillin_kid`, `bulma_young`, `oolong`, `puar`, `yamcha_young`, `ox_king`, `pilaf`, `shu`, `jackie_chun`, `giran`, `nam`, `silver`, `white`, `murasaki`, `android_8`, `blue`, `tao`, `red`, `baba`, `grandpa_gohan`, `tien_young`, `chiaotzu`, `tambourine`, `cymbal`, `drum`, `king_piccolo`, `korin`, `yajirobe`, `piccolo_jr`, `pilav_robot`, `baaba_fangs`, `baaba_invisible`, `baaba_mummy`, `baaba_devil`, `tao_cyborg`.

NPC ids equal those character ids. Reused adult aliases: `origins_roshi` -> `roshi`; `origins_mai` -> `mai`; `origins_kamu` -> `kami`; `origins_popo` -> `mr_popo`. Existing adult rows/NPC ids remain. Named bosses use their own valid Turtle/Brawler/Speedster/Crane style. Character fallback looks are seeds for Claude's dedicated model/costume pass; this release does not claim new character meshes or rendered ape/wave cinematics.

## Validation

`node tools/check_godot_export.mjs` checks deterministic export, manifest hashes, seven ordered chapters, unique NPC ids, all character/style/map/dialogue/boss references and the adult handoff, alongside unchanged classic parity.

`tools/godot_test.sh origins` exercises new starts for every race; all seven chapters with actual combat damage, once-only rewards, natural XP progression and saved completions; old v7 progress retention/optional classification; checkpoint collection/training/tracking/DL1 persistence and the new-save gate. The general schema tests still compare all six classic save migrations with the JS oracle plus the explicit Godot additions. The full-story rules fixture defaults to a legacy fighter to retain coverage of the 41 adult quests; the opt-in `story-play` scene bot now expects all 48 for a new fighter.

Claude's remaining integration checks: dedicated looks in the additions pass, actual GPU presentation of the world/actors/cutscenes, and the opt-in full `story-play` run before building/publishing. No Codex installer/build/publish.

Final verification (2026-11-05): `tools/godot_test.sh --check-data` **315 passed, 0 failed**, exit0; all42 generated tables verified (`/tmp/dragon-origins-release-suite.log`). Six Origins-specific cases passed within that run. `node tools/check_godot_export.mjs` **8 checks passed**, including unchanged classic parity and renamed prose/speaker validation. `git diff --check` passes. The first full run's two fixture failures were corrected: boost's unit-test route now explicitly uses the original clear Plains route; the animation reaction test places its target near the new spawn instead of targeting a culled Plains trainee. Product movement/rendering were not changed. Existing editor startup socket warnings and post-test focus/resource-exit diagnostics remain outside test failures. The opt-in eight-minute `story-play` run was updated for48 main quests but was not run by Codex; Claude retains that integration/GPU gate.
