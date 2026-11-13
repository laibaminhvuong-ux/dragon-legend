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

## Where Claude stopped
Remaining work ("do everything left"), in order:
1. **Privacy / co-op consent**: consent dialog before co-op Join (what is sent: fighter name, look, stats, items, zeni; to the host), send minimum data, UPnP "map router" warning and off by default, tests, re-grep for OS.execute/HTTP/file access outside user://.
2. **Story data**: Tournament Island bout fighters (Giran, Jackie Chung, Chaozo, Cyborg Tau, Namu) stand at (+-24,0) beside the 40 m ring centred (0,20): move NPC + quest coordinates onto the ring; Papaya Island dragon orb (70,70) is 4.4 m under water; new forms (look.formLooks display only, not in forms data, bosses never transform); re-run quests-real/story-play after the map changes; re-measure fps (Amber City ~35, earth_plains ~39 baseline).
3. **Characters**: Brolo dark chest arc, hair floating on hairless races, Piccor giant forms, dress outfits for Bulma/Chi-Chi etc., approximate animal heads, check big/seated NPCs (King Yemmo, Zeno...).
4. **World**: stairs for stand-on platforms taller than 1.35 m (West City, Future Earth, Nameless Planet), Beerus tower door (4 m tier), Capsule house entrances, dome window slabs, thin lines on King Kae dome, GPU checks of Earth towns/hamlets (grids are baked now).
5. Then: full tests, commit own files, export + install (backup save first), report to the user in Vietnamese.
6. **Only when the user says**: version 0.0.8 intro video (vertical 9:16 + landscape from in-game captures with ffmpeg, to Windows Downloads for Instagram and to the website), release notes, `tools/publish_site.sh`, `gh release`/workflow, push.
