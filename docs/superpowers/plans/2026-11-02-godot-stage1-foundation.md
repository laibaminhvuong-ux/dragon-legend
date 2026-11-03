# Godot Stage 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `godot/` project that opens and runs, with the shared autoloads (Data, Events, SaveStore, Clock), the input map and a headless test runner that Codex builds Stages 2–4 on.

**Architecture:** Four autoload singletons in `godot/core/` form the contract between Codex's pure rules (`godot/rules/`) and Claude's views. Data is generated JSON loaded once. Events is a signal bus with the JS game's event names. SaveStore owns `user://profile.json`. Clock runs the fixed 1/60 s simulation step. A minimal GDScript test runner runs headless from WSL.

**Tech Stack:** Godot 4.7.2 standard (GDScript), Forward+ renderer; WSL bash for the test script.

**Spec:** `docs/superpowers/specs/2026-11-02-godot-port-design.md`

## Global Constraints

- Godot 4.7.2 standard edition, GDScript only. Editor `C:\Godot\Godot_v4.7.2-stable_win64.exe`, headless runs via `C:\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- Everything new lives in `godot/`. `web/`, `desktop/` and `mobile/` are untouched.
- Coordinates and units are identical to the JS game: metres, seconds, forward = `(sin yaw, 0, cos yaw)`, models face +Z, `rotation.y = yaw`.
- Simulation runs at a fixed **1/60 s** step, at most **5 steps** per frame (drop time after a hitch), the same as `web/src/core/loop.js`.
- Saves: 3 slots in `user://profile.json`. A slot is the same Dictionary shape as the JS schema v6.
- Typed GDScript everywhere (the project treats untyped-variant inference as an error).
- Codex owns `godot/{rules,data,tests}` after this stage. Claude owns `godot/{core,world,characters,fx,ui,scenes}`.

## Review Focus

- **A missing or malformed `data/*.json` file:** the game still starts. `Data` logs which file failed and leaves that table empty instead of crashing. Pinned in Task 2.
- **A corrupt `profile.json`** (half-written, or hand-edited badly): SaveStore keeps the bad file as `profile.json.bad`, starts with 3 empty slots and never overwrites the corrupt bytes silently. Pinned in Task 4.
- **Slot index out of range** (-1, 3): `load_slot`/`save_slot`/`delete_slot` refuse and return null/false, never crash or grow the array. Pinned in Task 4.
- **A long hitch** (alt-tab, slow first frame of 2 s): Clock runs at most 5 steps and drops the rest, so the game doesn't fast-forward. Pinned in Task 5.
- **The test runner on a failing test:** it exits non-zero with the test name and message, so a broken rule can't pass CI by accident. Pinned in Task 1.

---

### Task 1: Project skeleton and headless test runner

**Files:**
- Create: `godot/project.godot`, `godot/icon.png` (copy of `web/icons/icon-512.png`), `godot/scenes/main.tscn`, `godot/scenes/main.gd`
- Create: `godot/tests/run_all.gd`, `godot/tests/test_case.gd`, `godot/tests/test_runner_selftest.gd`
- Create: `tools/godot_test.sh`
- Modify: `.gitignore` (add `godot/.godot/`, `godot/.import/`)

**Interfaces:**
- Produces: test files are `godot/tests/**/test_*.gd` extending `TestCase` (class_name in `test_case.gd`), and every method named `test_*` runs. `TestCase` has `eq(actual, expected, msg := "")`, `ok(cond: bool, msg := "")` and `near(a: float, b: float, eps := 1e-6, msg := "")`. Each records a failure instead of throwing.
- Produces: `tools/godot_test.sh [filter]` runs `--headless --path godot -s res://tests/run_all.gd -- [filter]` with `$GODOT` (default: the console exe above via `wslpath -w`). It prints `ok <file>::<test>` / `FAIL <file>::<test>: <msg>` and a summary `N passed, M failed`. Exit code 0 only if M == 0.

- [ ] **Step 1:** Write `test_runner_selftest.gd` with `test_passes()` (eq 1,1) and, behind the filter `selftest_fail`, `test_fails_on_purpose()` (eq 1,2).
- [ ] **Step 2:** Run `tools/godot_test.sh`. Expected: fails, because the runner doesn't exist yet.
- [ ] **Step 3:** Implement `run_all.gd` (extends SceneTree: walk `res://tests`, instantiate each script, call `test_*`, collect failures, `quit(1 if failures else 0)`), `test_case.gd`, `project.godot` (name "Dragon Legend", main scene `res://scenes/main.tscn`, Forward+, 1600×900, `debug/gdscript/warnings/inference_on_variant=2`) and an empty `main.tscn`/`main.gd`.
- [ ] **Step 4:** Run `tools/godot_test.sh`. Expected: `1 passed, 0 failed`, exit 0. Then `tools/godot_test.sh selftest_fail`: expected `FAIL test_runner_selftest.gd::test_fails_on_purpose`, exit 1.
- [ ] **Step 5:** Commit `godot: project skeleton and headless test runner`.

### Task 2: Data autoload

**Files:**
- Create: `godot/core/data.gd` (autoload `Data`), `godot/tests/core/test_data.gd`, `godot/tests/fixtures/data/{quests,forms,broken}.json`
- Modify: `godot/project.godot` (register autoload)

**Interfaces:**
- Produces: `Data.load_dir(path: String) -> void` (called with `res://data` at `_ready`). Each `<name>.json` becomes a property: `quests`, `npcs`, `characters`, `links`, `forms`, `mastery_evolutions`, `moves`, `races`, `outfits`, `accessories`, `zones`, `stats`, `combat`, `movement`, `camera`, `cutscenes`, `form_looks`, `dragon_hunts`, `kaioken`, `avatar`, `rpg`, `appearance`. A table is an empty Dictionary (or Array for `quests`/`npcs`) until loaded. `Data.errors: Array[String]` lists files that failed. `Data.table(name: String) -> Variant` reads any table by name (unknown name → `null` plus a warning).

- [ ] **Step 1:** Write `test_data.gd`: `test_loads_tables()` (load the fixtures dir; `Data.quests.size() == 2`, `Data.forms["SSJ"]["name"] == "Super Saiyar"`); `test_broken_file_is_reported_not_fatal()` (`broken.json` contains `{"a":` → `Data.errors` mentions `broken.json`, other tables still loaded); `test_missing_table_is_empty()` (`Data.moves.is_empty()`); `test_unknown_table_name()` (`Data.table("nope") == null`).
- [ ] **Step 2:** Run `tools/godot_test.sh test_data`. Expected: FAIL.
- [ ] **Step 3:** Implement `data.gd` with `JSON.parse_string` per file. A parse error is appended to `errors` with `push_warning`, and the table stays empty.
- [ ] **Step 4:** Run `tools/godot_test.sh test_data`. Expected: 4 passed.
- [ ] **Step 5:** Commit `godot: Data autoload`.

### Task 3: Events autoload

**Files:**
- Create: `godot/core/events.gd` (autoload `Events`), `godot/tests/core/test_events.gd`

**Interfaces:**
- Produces signals with today's payloads: `notify(text: String)`, `dialogue(d: Dictionary)`, `quest_accepted(id: String, title: String)`, `quest_completed(id: String, title: String)`, `quest_progress(id: String, objective: String)`, `travel(zone: String)`, `enemy_defeated(d: Dictionary)`, `levelup(level: int)`, `stats()`. Also `emit_named(name: String, payload: Variant) -> void`, which maps a JS event name (`"questAccepted"`, `"enemyDefeated"`...) and its object payload onto the matching signal, so ported rules can keep `emit("questAccepted", {id, title})` one-liners.

- [ ] **Step 1:** Write `test_events.gd`: `test_notify()` (connect, emit, receive the text); `test_emit_named_maps_js_names()` (`emit_named("questAccepted", {"id":"m01","title":"A"})` → `quest_accepted("m01","A")`); `test_unknown_name_warns()` (`emit_named("nope", {})` does nothing and doesn't crash).
- [ ] **Step 2:** Run `tools/godot_test.sh test_events`. Expected: FAIL.
- [ ] **Step 3:** Implement `events.gd`.
- [ ] **Step 4:** Run. Expected: 3 passed.
- [ ] **Step 5:** Commit `godot: Events autoload`.

### Task 4: SaveStore autoload

**Files:**
- Create: `godot/core/save_store.gd` (autoload `SaveStore`), `godot/tests/core/test_save_store.gd`

**Interfaces:**
- Consumes: `rules/schema.gd` if present (Codex, Stage 2): `normalize(slot: Dictionary) -> Dictionary` and `new_slot(look: Dictionary) -> Dictionary`. Until it exists, SaveStore stores slots as given and `create_slot` returns `{ "appearance": look }`.
- Produces: `SaveStore.path: String` (default `user://profile.json`; tests set a temp path), `list_slots() -> Array` (3 entries: summary Dictionary or null), `load_slot(i: int) -> Variant` (Dictionary or null), `save_slot(i: int, slot: Dictionary) -> bool`, `create_slot(i: int, look: Dictionary) -> bool`, `delete_slot(i: int) -> bool`. The file format is `{ "version": 1, "slots": [slot|null, slot|null, slot|null] }`, written atomically (write `profile.json.tmp`, then rename).

- [ ] **Step 1:** Write `test_save_store.gd` with a temp path: `test_round_trip()` (save slot 1, reload a new SaveStore instance, same Dictionary); `test_three_slots_only()` (`save_slot(3, {})` false, `load_slot(-1)` null, the file still has 3 entries); `test_corrupt_file_kept_as_bad()` (write `{"slots": [` to the path → `list_slots()` is 3 nulls, `profile.json.bad` exists with the original bytes, the original isn't overwritten until the next successful save); `test_delete()`.
- [ ] **Step 2:** Run `tools/godot_test.sh test_save_store`. Expected: FAIL.
- [ ] **Step 3:** Implement `save_store.gd` (FileAccess + DirAccess.rename_absolute for the atomic write; uses `schema.gd` via `ResourceLoader.exists("res://rules/schema.gd")`).
- [ ] **Step 4:** Run. Expected: 4 passed.
- [ ] **Step 5:** Commit `godot: SaveStore autoload`.

### Task 5: Clock and input map; Stage 1 release

**Files:**
- Create: `godot/core/clock.gd` (autoload `Clock`), `godot/tests/core/test_clock.gd`
- Modify: `godot/project.godot` (input map), `godot/scenes/main.gd` (shows a "Dragon Legend: foundation" label, quits after N frames with `-- --smoke`)
- Modify: `COLLABORATION.md` (Stage 1 release note for Codex)

**Interfaces:**
- Produces: `Clock.STEP := 1.0 / 60.0`, `Clock.MAX_STEPS := 5`, `Clock.advance(frame_dt: float) -> int` (adds to the accumulator and returns how many fixed steps to run now, max 5, dropping leftover time beyond that), and `Clock.alpha: float` (interpolation 0..1 for views).
- Produces input actions named after `web/src/core/input.js` `DEFAULT_BINDINGS` (snake_case): `move_forward/back/left/right` (WASD + arrows), `jump` (Space), `melee` (LMB), `block` (RMB), `dash` (Q), `flight` (F), `ascend` (Space), `descend` (Ctrl), `charge` (C), `ki_blast` (E), `beam` (R), `transform` (T), `lock_on` (Tab), `interact` (G), `menu` (M), `radar` (V), `base` (B), `kaioken` (K), `pause` (Esc).

- [ ] **Step 1:** Write `test_clock.gd`: `test_one_step_per_sixtieth()` (`advance(1/60)` → 1); `test_accumulates()` (three `advance(1/180)` calls → 0, 0, 1); `test_hitch_capped_and_dropped()` (`advance(2.0)` → 5, then `advance(0.0)` → 0); `test_alpha_range()`.
- [ ] **Step 2:** Run `tools/godot_test.sh test_clock`. Expected: FAIL.
- [ ] **Step 3:** Implement `clock.gd`, the input map in `project.godot`, and `main.gd`.
- [ ] **Step 4:** Run `tools/godot_test.sh` (everything). Expected: all passed, exit 0. Then run the game for real: `Godot_v4.7.2-stable_win64_console.exe --path godot -- --smoke`. Expected: exits 0 with no `SCRIPT ERROR` lines.
- [ ] **Step 5:** Append the release note to COLLABORATION.md: autoload names and signatures as above, how to run tests, and that Codex now owns `rules/`, `data/` and `tests/` (and `tools/godot_test.sh`). Commit `godot: Clock, input map; Stage 1 released`.
