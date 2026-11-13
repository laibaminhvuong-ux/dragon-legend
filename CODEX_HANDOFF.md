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

## Where Claude stopped (updated 2026-11-13 ~15:00 ET)
Committed and installed: commit e5718a6 (412 tests passing): privacy/consent (co-op and updater), story data fixes, world leftovers, character leftovers. The user said to skip co-op from now on.
In flight (4 subagents launched on the remaining items; results NOT yet integrated, working tree may be dirty):
- A. Story boss phase system (rules/combat.gd, data `phases`, combat_view) for Frieza/Cell/Broly/Buu/Jiren etc.
- B. New player forms in forms data (SSJRose, SSJKefla, Frieza forms, ...) with unlock paths.
- C. Visual leftovers: King Kae dome shading line, Meros/Chelai hair, skirt slit at stride, Harbor Town roof shadow acne, New Nameck dome footing.
- D. In-game verification (doors/interiors/stairs, updater first-run prompt screenshot, fps in 6 heavy zones, full session smoke, exe --smoke).
Next steps: wait for the four reports (resume any that stop on a rate limit with SendMessage), run `flock /tmp/dl_test.lock tools/godot_test.sh --check-data` until 0 failures, commit own files (`git add -A godot tools web COLLABORATION.md CODEX_HANDOFF.md`), back up the save, check tasklist, export + install, and report to the user in Vietnamese (done / not done / not verified).
Only when the user says: 0.0.8 intro video (9:16 + landscape), release notes, website (`tools/publish_site.sh`), GitHub release/workflow, push.
VS Code is set up for the user: `code ~/dragon-ball/dragon-legend.code-workspace`.
