# Codex handoff (kept current by Claude; read this first)

**Prompt to paste into Codex:**

> You are taking over "The Dragon Legend" (Godot 4.7.2, ~/dragon-ball/godot) from Claude, who ran out of tokens. Read `/home/laptop_usd/dragon-ball/CODEX_HANDOFF.md`, `AGENTS.md` and the bottom of `COLLABORATION.md`, then continue exactly from "Where Claude stopped". Do not publish, push, tag or make videos unless the user says. Finish with all tests passing, commit only your own files, and update the "Where Claude stopped" section as you go.

## Standing rules (from the user)
- Version 0.0.8 is in progress. **Publishing, pushing, GitHub release/workflow, website update, intro video and release notes are ON HOLD until the user says.** The user wants to check the update first.
- Never show canon character names in game UI/data (renamed display names only).
- The user's maxed save fighters must never ship. Before installing a build: `tasklist.exe | grep -i "the dragon legend"` (installer closes a running game), and back up `%APPDATA%\DragonLegend\profile.json` to `profile.before-<tag>-<time>.json`.
- The game must never take files/data from a player's machine: no HTTP/telemetry/exec; a co-op Join sends the fighter slot to the host only after explicit consent.
- Since 2026-11-13 Claude owned rules, data, tests, characters, world, UI, builds; Codex only steps in when Claude is out of tokens. Reference images in `art/reference/` are private (git-ignored), never copied into the game.
- Subagent workflow the user likes: Claude is "the brain" (plans, reviews, commits, installs); subagents (opus, medium, background) do the work and never commit/push.

## How to work
- Tests: `tools/godot_test.sh --check-data` (data parity + ~385 tests, 4-10 min). Wrap in `flock /tmp/dl_test.lock ...`. Data: edit `tools/godot_additions.mjs` / `tools/origins.mjs`, then `node tools/export_godot_data.mjs` (never hand-edit `godot/data/*.json`).
- GPU checks (Windows Godot): `/mnt/c/Godot/Godot_v4.7.2-stable_win64_console.exe --path "$(wslpath -w ~/dragon-ball/godot)" res://scenes/main.tscn -- --play=8 --zone=<id> --noui=1 --walk=2 --shot=C:/Users/Public/x.png --frames=400` (slot 8 only) or `res://scenes/world_preview.tscn -- --zone=<id> --focus=<landmark idx> --shot=...`. After timeouts: `taskkill.exe /F /IM Godot_v4.7.2-stable_win64_console.exe`.
- Planet terrain grids are baked in `godot/world/baked/` (keyed by a hash of the zone definition): any zone-data change makes that planet's grid stale (slow load, Earth ~25-30 min). Rebake all: `~/.cache/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot -s res://tools_bake_planets.gd` (about 1 h), then delete stale files (keep only keys of the current zones).
- Build + install: `cd godot && ~/.cache/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --export-release "Windows Desktop" "../build/windows/The Dragon Legend.exe"` then copy to `/mnt/c/Users/LAPTOP USD/AppData/Local/Programs/The Dragon Legend/The Dragon Legend.exe`.

## State at last update (2026-11-13)
- Last commit includes the building-by-building audit (30+ fixes), stand-on surfaces (`RuleZone.add_surface/surface_top/ground_at(x,z,reach_y)`, `world/landmark_collision.gd`), King Kae road painted on terrain, planets re-baked, 385 tests passing; that build is installed on the user's PC.
- Four subagents were launched on the leftovers (see below). Their results are NOT yet integrated unless a later commit says so.

## Where Claude stopped (updated 2026-11-13 evening)
Everything requested so far is committed and installed: commit 8dd371e (431 tests passing, data check OK). The user said to skip co-op.
Open items (none blocking):
- King Yemmo's dais steps: in a real game session the player stopped at the foot of the steps twice although the headless test passes (maybe a wrong start point on that road map): verify in game with `--door`/`--at` flags.
- Gyran looked waist-deep on the Tournament ring in one cutscene frame (unverified).
- In-game Earth plains runs ~41 fps with ~244 lights and 67 enemies (combat_view 10-12 ms); the world preview alone is ~105 fps. A quiet-machine profile could find savings (light count, enemy updates).
- Not playable on purpose: Cell stages, Jiren Full Power, Toppo GoD, Zarbon Monster (no Android/Pride Trooper race); SSJ Kefla, SSJ4 Gogeta (fusion only).
- Known small visuals: Ginger tower has a walk-through fence across its path; hair caps are drawn inside out (darker than locks); skirt stretches between legs in a full stride; Harbor Town roofs shaded faces are dark.
Only when the user says: 0.0.8 intro video (9:16 + landscape from in-game captures with ffmpeg, to Windows Downloads and the website), release notes, website (`tools/publish_site.sh`), GitHub release/workflow, push.
VS Code is set up for the user: `code ~/dragon-ball/dragon-legend.code-workspace`.
