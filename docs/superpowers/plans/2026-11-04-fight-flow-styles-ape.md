# Fight Flow, Fighting Styles and New Great Ape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace stiff, snapping fight animation with flowing code-authored move clips per fighting style (Turtle, Brawler, Speedster, Crane), add a style picker, and replace the Great Ape with a rigged, animated giant.

**Architecture:** Moves are Godot `Animation` resources generated at load from compact key-pose tables (`MoveClips` builds them; `FightStyles` holds the per-style tables), added to each fighter's AnimationPlayer as library `moves` and played through the existing AnimationTree one-shot with crossfades. Visual-only extras (lunge root motion, hit-stop, reactions) are applied by Fighter/AnimController from presentation fields. The ape is a generated skinned mesh on its own Skeleton3D with its own generated clips.

**Tech Stack:** Godot 4.7.2, typed GDScript, existing test runner `tools/godot_test.sh`, Windows Godot for GPU sheets/recordings.

**Spec:** `docs/superpowers/specs/2026-11-04-fight-flow-styles-ape-design.md`

## Global Constraints
- Typed GDScript (no Variant inference); Claude edits only `godot/characters/**`, `godot/ui/**`, `godot/scenes/play/**`, their tests, `godot/tools_lineup.gd`.
- Style ids exactly `turtle`, `brawler`, `speedster`, `crane`; default `turtle`.
- Presentation never changes damage timing; hit-stop is visual (fighter animation dt only, never the simulation).
- Crossfades 0.08–0.2 s; lunges 0.2–1.2 m; hit-stop 40–90 ms (finisher at the top end).
- Every existing anim contract key keeps working (attackKind, skill poses, kick/strike kinds) when no `style`/`move` is given.
- No canon names in any UI text.

## Review Focus
- A `move` id the clip library doesn't know (Codex adds one later) → falls back to the style's generic strike, never a T-pose or error.
- Attack serial arriving mid-follow-through repeatedly (button mashing) → each new clip blends in from the current pose; no pops.
- Fighter scaled (NPC scale 0.5–4.2) or sculpted → lunge distance scales with the fighter; clips stay on the same skeleton.
- Style changed while a clip is playing → the current clip finishes; the next attack uses the new style.
- Ape transform in and out mid-combat → the ape node is created/freed cleanly; no leaked nodes or stuck human pose.

---

### Task 1: MoveClips — key poses to Animation

**Files:**
- Create: `godot/characters/move_clips.gd`
- Test: `godot/tests/characters/test_move_clips.gd`

**Interfaces:**
- Produces: `class_name MoveClips`; `static func build(skeleton: Skeleton3D, base: Dictionary, keys: Array, length: float, loop := false) -> Animation` where `base` = bone name → local rest-pose Quaternion (from `base_pose(player, "Idle")`), `keys` = Array of `{"t": float, "ease": String ("in"|"out"|"inout"|"linear"), <bone>: Vector3 euler offset, "lunge": float}`; bones addressed by short names `hips, spine, chest, neck, head, armL, armR, foreL, foreR, handL, handR, thighL, thighR, shinL, shinR, footL, footR` (map to DEF-* in `BONES`). `static func base_pose(player: AnimationPlayer, skeleton: Skeleton3D, clip: String) -> Dictionary`. The clip stores lunge in metadata `lunge_curve` (PackedVector2Array of (t, metres)).
- [ ] Test `test_clip_has_tracks_and_length`: build a 3-key clip on the real mannequin; assert length, a rotation track per keyed bone, last key at `length`.
- [ ] Test `test_keys_without_bone_keep_base`: a bone missing from a key interpolates from neighbours (no snap to identity).
- [ ] Test `test_unknown_bone_name_is_ignored`: key with `"tail": Vector3.ONE` builds without error.
- [ ] Implement; offsets applied in bone-local space: `rot = base[bone] * Quaternion.from_euler(offset)`; easing baked by inserting intermediate keys (4 per segment).
- [ ] Run `tools/godot_test.sh --check-data` → all pass. Commit.

### Task 2: FightStyles — four style move tables

**Files:**
- Create: `godot/characters/fight_styles.gd`
- Test: `godot/tests/characters/test_fight_styles.gd`

**Interfaces:**
- Consumes: `MoveClips.build`.
- Produces: `class_name FightStyles`; `const IDS := ["turtle","brawler","speedster","crane"]`; `static func moves(style: String) -> Dictionary` (move id → `{"length": float, "keys": Array, "contact": float}`), each style with `stance` (looping), `combo1..combo4`, `dash`, `finisher`; move ids `"<style>_<name>"` mirroring the spec table plus generic `"<style>_combo<n>"` aliases; `static func move_for(style: String, move: String, combo_step: int) -> String` (fallback chain: exact move → `<style>_combo<step>` → `turtle_combo1`); `static func library(f: Fighter) -> AnimationLibrary` (cached per skeleton rest + style set).
- [ ] Test `test_every_style_has_full_set`: for each id, stance/combo1-4/dash/finisher exist, lengths 0.3–1.2 s (stance 1.5–3 s), contact inside wind-up..length.
- [ ] Test `test_move_for_fallbacks`: unknown move → combo clip; unknown style → turtle.
- [ ] Test `test_styles_differ`: the four combo1 clips differ in length or keyed pose (no two identical).
- [ ] Implement the tables per spec §2 (Turtle: jab, cross, front kick, straight + double-palm finisher; Brawler: wide hook, hammer fist, shoulder charge, uppercut + overhead slam; Speedster: jab flurry, side-step knee, spin kick, back-fist + blur rush; Crane: palm strike, high kick, knife-hand, crane kick + one-finger). Each move: anticipation key (counter-movement), contact key, overshoot follow-through, settle; hips lead chest by ~0.04 s.
- [ ] GPU check: `tools_lineup.gd -- --styles` sheet (each style's moves at contact frame). Commit.

### Task 3: Flow engine in AnimController + Fighter

**Files:**
- Modify: `godot/characters/anim_controller.gd`, `godot/characters/fighter.gd`
- Test: `godot/tests/characters/test_fight_flow.gd`

**Interfaces:**
- Consumes: `FightStyles.library`, `FightStyles.move_for`.
- Produces: anim keys `style: String`, `move: String`, `comboStep: int`, `inCombat: bool`, `lunge: float`, `hitstop: float`, `reaction: String ("stagger"|"knockback"|"launch")`; `AnimController.current_move: String`; `Fighter.root_offset: Vector3` (visual lunge, local +Z).
- [ ] Test `test_attack_plays_style_clip`: attackSerial + style brawler + move brawler_hammer_fist → `current_move == "brawler_hammer_fist"`.
- [ ] Test `test_chain_blends_without_pop`: fire combo1 then combo2 mid follow-through; max per-frame rotation change of `DEF-upper_arm.R` < 0.6 rad.
- [ ] Test `test_stance_when_in_combat`: inCombat true + idle → stance clip active; false → normal idle.
- [ ] Test `test_hitstop_freezes_animation_only`: hitstop 0.08 → skeleton pose unchanged across 2 frames of 1/60, resumes after.
- [ ] Test `test_lunge_scales_with_fighter`: fighter scale 2 → root_offset peak ≈ 2 × lunge.
- [ ] Test `test_legacy_attackKind_still_works`: no style → existing punch/kick behaviour.
- [ ] Implement: register library `moves` on the player; one-shot uses `AnimationNodeAnimation` set per play with xfade 0.12 (fade-in) / 0.18 (fade-out); stance via a blend into `mode` ground state when `inCombat`; hit-stop scales `tree.advance` dt to 0 while active; reactions as short generated clips (stagger/knockback/launch) in the same library.
- [ ] Commit.

### Task 4: Combat integration + style picker UI

**Files:**
- Modify: `godot/scenes/play/combat_view.gd`, `godot/scenes/play/play.gd`
- Create: `godot/ui/style_picker.gd`
- Test: `godot/tests/ui/test_style_picker.gd`, `godot/tests/scenes/test_play.gd` (extend)

**Interfaces:**
- Consumes: Codex event fields (`style`, `move`, `combo_step`, `chain_window`, `lunge`, damage `knockback`/`launch`/`stagger`/`hitstop`), Codex `set_style` command and `slot.style` (until they land: read `look.style`/default `turtle`, picker writes through a stub that the Codex API replaces).
- Produces: `_presentation()` passes the Task 3 keys; `inCombat` = target locked or enemy within 15 m.
- [ ] Test picker lists the 4 styles in order with display names "Turtle School", "Brawler", "Speedster", "Crane"; choosing one issues set_style; current marked.
- [ ] Test play view: an attack event with style/move reaches the fighter (`current_move`); a damage event with hitstop/knockback reaches the victim.
- [ ] Implement; key binding Y opens the picker (Controls), HUD hint updated.
- [ ] Commit.

### Task 5: New Great Ape body and clips

**Files:**
- Create: `godot/characters/ape_body.gd` (skeleton + skinned mesh generation), `godot/characters/ape_clips.gd`
- Modify (rewrite): `godot/characters/great_ape.gd` (keeps `static func create(golden: bool) -> GreatApe` and `update(dt: float, anim: Dictionary)`)
- Test: `godot/tests/characters/test_great_ape.gd`

**Interfaces:**
- Produces: `ApeBody.build(golden: bool) -> Dictionary {"skeleton": Skeleton3D, "mesh": MeshInstance3D}` with bones `hips, spine1, spine2, chest, neck, head, jaw, shoulder.L/R, arm.L/R, forearm.L/R, hand.L/R, thigh.L/R, shin.L/R, foot.L/R, tail1..tail4`; `ApeClips.library() -> AnimationLibrary` with `idle, walk, roar, chest_pound, stomp, swipe, grab_slam, mouth_blast, hurt, transform_in`; GreatApe emits `Events` shake via `footfall(pos, strength)` signal.
- [ ] Test builds both forms; single MeshInstance3D with skin; every vertex weighted (sum ≈ 1); every clip plays without errors; golden fur colour differs.
- [ ] Test anim mapping: speed > 0.5 → walk; attackSerial → swipe/stomp/mouth_blast by attackKind; charging → roar.
- [ ] Implement mesh as merged skinned primitives (capsules/ellipsoids with fur clump displacement), weights by nearest bone segments with smooth falloff.
- [ ] GPU: `tools_lineup.gd -- --ape` sheet (both forms, 4 clips). Commit.

### Task 6: GPU review, recordings, ship
- [ ] Record per-style combo videos and ape clips with `--write-movie` (dev fight screen + `--style=`), convert to MP4, save to the user's Downloads, show the user.
- [ ] Full suite + story-play; install locally (tasklist check, profile backup); integrate Codex's release; update COLLABORATION; release only when the user asks.
