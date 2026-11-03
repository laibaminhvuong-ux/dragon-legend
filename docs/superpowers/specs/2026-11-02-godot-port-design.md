# Dragon Legend → Godot: design and work split

**Status:** approved direction (user, 2026-11-02): move the whole game to Godot 4 with better graphics and
detail, split between Codex (rules, data, tests) and Claude (graphics, characters, integration).

## Goal

Dragon Legend rebuilt in Godot 4.7 (standard edition, GDScript) with everything the current web/Electron game has
(23 worlds, characters and all races, every form, story, boss cutscenes, voices, combat, menus, saves,
Dragon Orb hunts and radar, travel pilot, tutorial), looking clearly better, and shipping as apps for Windows,
Mac, Linux and Android. The current game in `web/` stays playable and shippable until the Godot version is at
least as complete. Then the Godot version replaces it.

**Out of scope:** new gameplay features during the port, and multiplayer.

## Where things live

Everything new goes in `godot/` inside this repository. The current game (`web/`, `desktop/`, `mobile/`) is untouched.

```
godot/
  project.godot           Claude
  core/                   Claude: autoloads (Data, Events, SaveStore), input map, fixed-step clock
  data/                   Codex: generated JSON (never hand-edited) + the export tool's output manifest
  rules/                  Codex: pure game rules (RefCounted classes, no Nodes, no rendering)
  tests/                  Codex: headless tests for rules/ (Claude adds view smoke tests later)
  world/                  Claude: terrain, grass, water, sky, landmarks, NPC placement views
  characters/             Claude: fighter models, animation, forms, auras
  fx/                     Claude: VFX (aura, beams, blasts, impacts)
  ui/                     Claude (or Freebuff if the user assigns it): HUD, menus, creator, dialogue, radar
  scenes/                 Claude: main, play, menu scenes wiring rules ↔ views
tools/export_godot_data.mjs   Codex: JS data → godot/data/*.json
tools/godot_test.sh           Codex: runs godot/tests headless
```

## The contract (how rules and views talk)

The Godot rules mirror today's JavaScript modules, so porting is mechanical and both versions can be checked
against each other.

- **Coordinates and units:** identical to the JS game. Metres and seconds. Position `{x, y, z}` is a Godot
  `Vector3(x, y, z)`. Facing `yaw` means forward = `(sin yaw, 0, cos yaw)` (+Z at yaw 0). Views place models with
  `rotation.y = yaw`, with models built facing +Z. Simulation runs at a **fixed 1/60 s step**. Views interpolate.
- **Data (`Data` autoload, Claude writes the loader):** reads every `godot/data/*.json` once at start-up into
  Dictionaries/Arrays named after today's exports: `Data.quests`, `Data.npcs`, `Data.characters`, `Data.links`,
  `Data.forms`, `Data.mastery_evolutions`, `Data.moves`, `Data.races`, `Data.outfits`, `Data.accessories`,
  `Data.zones`, `Data.stats`, `Data.combat`, `Data.movement`, `Data.camera`, `Data.cutscenes`, `Data.form_looks`,
  `Data.dragon_hunts`, `Data.kaioken`, `Data.avatar`, `Data.rpg`, `Data.appearance`. Contents are exactly the
  JS objects after load. That means installed endgame/RPG/hunt content is included and names are already the
  game's own (`data/names.js` ran). Functions are not exported; any rule that was code in a data file moves to `rules/`.
- **Events (`Events` autoload, signal bus):** `notify(text)`, `dialogue(d: Dictionary)`,
  `quest_accepted(id, title)`, `quest_completed(id, title)`, `quest_progress(id, objective)`, `travel(zone)`,
  `enemy_defeated(d)`, `levelup(level)`, `stats()`. Rules receive an `events` object and call
  `events.emit_signal(...)` with the same payloads the JS game emits today.
- **Saves (`SaveStore` autoload, Codex writes `rules/schema.gd`, Claude the file I/O):** 3 slots in
  `user://profile.json`. A slot is the same Dictionary shape as today (schema v6). `rules/schema.gd` provides
  `new_slot(look)`, `normalize(slot)` and migration. Saves move from the current game through the existing
  **save code** (`DL1:` prefix, `save.exportCode()`/`importCode()` in `web/src/core/save.js`), which the
  Godot version must import.
- **Rules (Codex), one GDScript per JS module, same function names in snake_case:**
  - `rules/zone.gd`: port of `game/zones.js` + `game/noise.js` + `game/placement.js`. `height_at(x, z)`, `place`,
    spawn, travel point, kill height, scattered trees/rocks/bushes as data. **The views build terrain from
    `height_at`, so this must match the JS output exactly** (tests compare sample points against values
    exported from JS).
  - `rules/game.gd`: `Game.new(slot_index, slot, events)` with `player` (Dictionary, same fields as JS),
    `update(dt, intents)`, `hud()`, `add_xp`, `spend_stat_point`, `select_form`, `choose_form_path`,
    `customize_appearance`, `equip_*`, `to_save()`. Intents are a Dictionary with today's keys (`move_x`,
    `move_z`, `jump`, `dash`, `flight`, `ascend`, `descend`, `fly_pitch`, `charge`, `melee`, `block`, `ki_blast`,
    `beam`, `transform`, `lock_on`, `interact`, `kaioken`).
  - `rules/movement.gd`, `ki.gd`, `collision.gd`, `combat.gd` (enemies, hits, projectiles, avatar),
    `progression.gd`, `forms.gd`, `mastery.gd`, `kaioken.gd`, `schema.gd`.
  - `rules/story.gd`: `Story.new(game, events)` with `npcs()`, `interact()`, `interaction()`, `accept_quest`,
    `tracker()`, `waypoint()`, `pickups()`, `encounters()`, `radar()`, `travel_guide()`, `travel_options()`,
    `travel_to()`, `tasks_here()`, `next_main()`, `journal()`, `shop()`, `buy()`, `use_item()`, `update(dt, intents)`.
  - `rules/cutscene_rules.gd` (which boss scene plays when) and `rules/tutorial_rules.gd` (tutorial steps).
- **Views (Claude) only read rule state and call those functions.** They never change rule state directly.

## Graphics direction (Claude)

- Forward+ renderer, HDR with filmic/ACES tonemapping, SDFGI or baked-style ambient light, volumetric fog and
  sky per world, and cascaded sun shadows.
- Terrain: one mesh per world built from `rules/zone.gd` heights, with splat-blended ground textures (grass,
  dirt, rock, snow, sand) and normal detail. Instanced grass (MultiMesh) with wind, LOD and distance fade.
  Instanced trees and rocks. A water shader with reflections, foam and depth colour.
- Characters: **decided (user, 2026-11-02): CC0 rigged asset packs restyled into our fighters.** Primary source:
  Quaternius (CC0): a humanoid base mesh with a standard rig, plus its Universal Animation Library for walk, run,
  jump, idle, punch/kick combos, hits, flying-style poses. Kenney (CC0) is the fallback. Only CC0 or equally free
  commercial licences, each recorded in `godot/assets/LICENSES.md`, and nothing ripped from other games. Our
  look is added on top: race skin tones and features (tails, antennae, horns), gi/armour/cape outfits, our hair
  styles and every form's hair, eyes, size and aura from `Data.form_looks`. Flight and power-up poses we make
  ourselves (animation blending + procedural layers).
- Effects: GPU particles for auras, ki blasts, beams, impacts, dust and speed lines. Shader-based aura flames
  with per-form colours from `Data.form_looks`.
- Target 60 fps on the user's GTX 1650 Ti at 1080p. Quality presets as today.

## Stages (each is playable or tested before the next)

| # | Stage | Owner | Done when |
|---|---|---|---|
| 1 | Foundation: `godot/` project, autoloads, input map, clock, contract skeleton | Claude | project opens and runs. Codex can run `tools/godot_test.sh` |
| 2 | Data export + zone heights + schema/saves/progression rules | Codex | JSON for every table. `height_at` matches JS samples. Save-code import works. Tests pass |
| 3 | Movement, ki, collision, combat (+ avatar, Kaiyoken), forms, mastery rules | Codex | ports of today's movement/combat/forms/kaioken/avatar checks pass headless |
| 4 | Story rules: quests, travel pilot, radar, hunts, cutscene and tutorial rules | Codex | port of check_story (whole-story bot) and check_scenes pass headless |
| 5 | Worlds: all 23 with the new graphics | Claude | every world loads and renders at target fps |
| 6 | Characters, forms, auras, animation | Claude | all races/outfits/forms render. Walk/run/fly/fight animations |
| 7 | Play scene wiring, camera, combat VFX, cutscenes and voices, HUD and menus | Claude | the whole story is playable start to end |
| 8 | Exports for every platform, auto-update, download page | Claude | apps built and tested. The Godot version replaces the web one |

Stages 2–4 (Codex) run in parallel with 5–6 (Claude) once stage 1 lands.

## Testing

- Rules: headless GDScript tests in `godot/tests/`, run by `tools/godot_test.sh` (Godot `--headless`). Each
  existing node check gets a GDScript counterpart, and parity tests compare rule outputs against values exported
  from the JS game for the same inputs (zone heights, damage, XP curves, quest walk).
- Views: Claude runs the real game on the user's GPU and captures screenshots for every world, race and form
  (the same approach used for the current game).

## Collaboration

The normal protocol applies: claim files in COLLABORATION.md before editing, release with validation notes.
Claude integrates, commits, builds and publishes. Codex never edits `world/`, `characters/`, `fx/`, `ui/`,
`scenes/` or `core/`. Claude never edits `rules/`, `data/` or `tests/` without a claim.
