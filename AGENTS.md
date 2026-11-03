# Agent instructions (Codex)

This is **Dragon Legend**: a standalone 3D action RPG inspired by Dragon Ball, shipped as a downloadable app. It is not a Roblox game. Three AI agents (Claude Code, Codex, Freebuff) share this folder.

**Since 2026-11-03 the main game is the Godot 4.7.2 port in `godot/`** (typed GDScript). The JavaScript/Three.js game in `web/` (Electron `desktop/`, Capacitor `mobile/`) is the "classic" version: keep it as the reference for behaviour, but new work goes into `godot/`. Codex owns `godot/rules/`, `godot/data/`, `godot/tests/rules/`, `tools/export_godot_data.mjs`, `tools/check_godot_export.mjs` and `tools/godot_test.sh`. Run `tools/godot_test.sh --check-data` before every release note.

Read `COLLABORATION.md` first (the latest sections are at the bottom) and follow the THREE-AGENT PROTOCOL: claim files before editing, never edit files another agent has claimed and not released, release with a note when done, and leave committing, building installers and publishing to the integrator (Claude Code).
