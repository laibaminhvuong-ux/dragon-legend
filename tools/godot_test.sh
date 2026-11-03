#!/usr/bin/env bash
# Run exported-data parity and headless GDScript tests. Never launch the game's visible scene.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${GODOT_PROJECT_PATH:-$PROJECT_ROOT/godot}"
TEST_SCRIPT="${GODOT_TEST_SCRIPT:-res://tests/run_all.gd}"
CHECK_DATA=0
FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --script) TEST_SCRIPT="$2"; shift 2 ;;
    --check-data) CHECK_DATA=1; shift ;;
    --help) echo 'Usage: tools/godot_test.sh [filter] [--project DIR] [--script res://tests/run_all.gd] [--check-data]'; echo 'Set GODOT_BIN or GODOT for a native Godot binary or Windows console executable under WSL.'; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) FILTER="$1"; shift ;;
  esac
done
if [[ ! -f "$PROJECT_PATH/project.godot" ]]; then echo "Godot foundation is not ready: $PROJECT_PATH/project.godot is missing." >&2; exit 2; fi
GODOT_BIN="${GODOT_BIN:-${GODOT:-}}"
if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot >/dev/null 2>&1; then GODOT_BIN="$(command -v godot)"
  elif command -v godot4 >/dev/null 2>&1; then GODOT_BIN="$(command -v godot4)"
  elif [[ -x "$HOME/.cache/godot/Godot_v4.7.2-stable_linux.x86_64" ]]; then GODOT_BIN="$HOME/.cache/godot/Godot_v4.7.2-stable_linux.x86_64"
  elif [[ -f /mnt/c/Godot/Godot_v4.7.2-stable_win64_console.exe ]]; then GODOT_BIN=/mnt/c/Godot/Godot_v4.7.2-stable_win64_console.exe
  else echo 'Godot not found. Set GODOT_BIN to the standard Godot 4 executable.' >&2; exit 2; fi
fi
if [[ "$CHECK_DATA" == 1 ]]; then node "$PROJECT_ROOT/tools/export_godot_data.mjs" --out "$PROJECT_PATH/data" --check; fi
if [[ "$TEST_SCRIPT" == res://* && ! -f "$PROJECT_PATH/${TEST_SCRIPT#res://}" ]]; then echo "Headless test entry point is not ready: $TEST_SCRIPT" >&2; exit 2; fi
ENGINE_PATH="$PROJECT_PATH"
if [[ "${GODOT_BIN,,}" == *.exe ]]; then
  if ! command -v wslpath >/dev/null 2>&1; then echo 'Windows Godot requires wslpath when called from Bash. Use a native Godot binary instead.' >&2; exit 2; fi
  ENGINE_PATH="$(wslpath -w "$PROJECT_PATH")"
  if [[ "$TEST_SCRIPT" == /* ]]; then TEST_SCRIPT="$(wslpath -w "$TEST_SCRIPT")"; fi
fi
# An editor import registers class_name declarations before the script suite loads them.
"$GODOT_BIN" --headless --path "$ENGINE_PATH" --editor --import --quit
"$GODOT_BIN" --headless --path "$ENGINE_PATH" --script "$TEST_SCRIPT" -- "$FILTER"
