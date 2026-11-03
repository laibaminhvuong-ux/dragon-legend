#!/usr/bin/env bash
# Renders every world on the real GPU (Windows Godot) from its spawn and collects screenshots + fps.
#   tools/world_shots.sh [quality] [out_dir]      default: medium, out/world_shots
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
Q="${1:-medium}"; OUT="${2:-$ROOT/out/world_shots}"
mkdir -p "$OUT"
WIN_GODOT="/mnt/c/Godot/Godot_v4.7.2-stable_win64_console.exe"
WINTMP="$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")/dl_world_shots"; mkdir -p "$WINTMP"
GP="$(wslpath -w "$ROOT/godot")"
"$WIN_GODOT" --headless --path "$GP" --import >/dev/null 2>&1
zones=$(python3 -c "import json;print(' '.join(json.load(open('$ROOT/godot/data/zone_order.json'))))" 2>/dev/null || python3 -c "import json;print(' '.join(json.load(open('$ROOT/godot/data/zones.json')).keys()))")
: > "$OUT/fps.txt"
for z in $zones; do
  [ "$z" = "test" ] && continue
  line=$(timeout 400 "$WIN_GODOT" --path "$GP" res://scenes/world_preview.tscn -- --zone=$z --quality=$Q "--shot=$(wslpath -w "$WINTMP")\\$z.png" 2>&1 | tr -d '\r' | grep -E "^fps|SCRIPT ERROR" | head -2 | tr '\n' ' ')
  echo "$z $line" | tee -a "$OUT/fps.txt"
  cp "$WINTMP/$z.png" "$OUT/" 2>/dev/null
done
