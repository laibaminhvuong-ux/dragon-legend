# Godot Stage 7: Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Native, user-chosen). Steps use `- [ ]`.

**Goal:** The whole game is playable in Godot from the title menu to the end of the story: worlds, characters,
combat, NPCs and quests, travel, cutscenes with voices, music, HUD, menus, radar and the tutorial.

**Architecture:** `scenes/main.gd` switches between `menu` and `play` (like `web/src/main.js`). `scenes/play.gd`
owns one `RuleGame` + `RuleStory` (Codex), steps them at 1/60 s from `Controls` intents, and drives views that
only read rule state: `WorldView` (Stage 5), the player `Fighter` (Stage 6), `views/combat_view.gd` (enemies,
projectiles, beams, damage numbers, impacts, avatar), `views/story_view.gd` (NPCs, markers, pickups, pads,
beacon, wish dragon) and `views/follow_camera.gd` (port of `render/camera.js`). UI lives in `ui/` as Control
scenes built in code: HUD, dialogue, notifications, fighter menu (stats/forms/techniques/outfits/journal/shop),
pause (settings, save codes), slot select + creator, radar, tutorial panel, cutscene player, loading card.
Voices use the OS text-to-speech (`DisplayServer.tts_*`), a distinct voice/pitch/rate per speaker; music ports
`audio/music.js`.

**Spec:** `docs/superpowers/specs/2026-11-02-godot-port-design.md` (Stage 7)

## Global Constraints
- Views never change rule state directly; they call rule functions (`select_form`, `spend_stat_point`, `buy`, ...).
- Same behaviour as `web/src/main.js`: autosave every 60 s and on pause/quit; travel saves, then rebuilds play in
  the new world; the player model rebuilds when the look changes; cutscenes freeze play but keep idle animation.
- Fixed 1/60 s simulation; views interpolate the player between the previous and current step.
- All UI text from rule/data strings (already renamed); no franchise names.

## Review Focus
- **Travel** mid-cutscene or with a dialogue open never loses the save or leaves two worlds loaded.
- **Pause/menu/dialogue** freeze the simulation; input pressed while paused doesn't leak into the next step.
- **Look changes** (outfit, colours) rebuild the player model without leaking nodes.
- **No crashes on empty states:** no lock target, no waypoint, no NPCs, a world without water.
- **Whole story:** a scripted run through the play scene (headless) completes the first quests, travels, and
  saves/loads correctly.

### Task 1: Play scene core (rules loop, input → intents, player, camera, world, autosave, travel, pause)
### Task 2: Combat view (enemies, bars, projectiles, beams, impacts, damage numbers, avatar)
### Task 3: Story view (NPCs, markers, pickups, pads, beacon, wish dragon)
### Task 4: HUD, dialogue, notifications, lock-on reticle, radar, tutorial panel
### Task 5: Menus: slot select + creator, pause + settings + save codes, fighter menu, loading card
### Task 6: Cutscenes, voices (TTS), music
### Task 7: Whole-game run: headless play smoke + GPU screenshots of each screen and world
