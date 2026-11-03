#!/usr/bin/env bash
# Runs the Godot headless tests: tools/godot_test.sh [filter]
# GODOT = Godot 4.7.2 binary. Default: a Linux build in ~/.cache/godot (WSL-native), else the Windows console exe.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX="$HOME/.cache/godot/Godot_v4.7.2-stable_linux.x86_64"
WIN="/mnt/c/Godot/Godot_v4.7.2-stable_win64_console.exe"
GODOT="${GODOT:-$([ -x "$LINUX" ] && echo "$LINUX" || echo "$WIN")}"
PROJ="$ROOT/godot"
case "$GODOT" in *.exe) PROJ="$(wslpath -w "$PROJ")" ;; esac
# refresh the class cache (class_name scripts) before running
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1
"$GODOT" --headless --path "$PROJ" -s res://tests/run_all.gd -- "$@" 2>&1 | tr -d '\r' | grep -v "^Godot Engine\|^$"
exit "${PIPESTATUS[0]}"
