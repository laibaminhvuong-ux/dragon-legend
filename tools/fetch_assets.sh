#!/usr/bin/env bash
# Downloads the CC0 assets the Godot worlds use into godot/assets/ and records their licences.
# Re-runnable; skips files already present. Source: Poly Haven (https://polyhaven.com, CC0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/assets/textures"
mkdir -p "$OUT"
# kind -> Poly Haven texture id
declare -A TEX=( [grass]=aerial_grass_rock [forest]=brown_mud_leaves_01 [dirt]=dry_ground_01
                 [rock]=rocky_terrain_02 [sand]=coast_sand_01 [snow]=snow_02 )
LIC="$ROOT/godot/assets/LICENSES.md"
printf '# Asset licences\n\nEvery asset here is CC0 (public domain): free for any use, no attribution required.\n\n| Asset | Used for | Source | Licence |\n|---|---|---|---|\n' > "$LIC"
for kind in "${!TEX[@]}"; do
  id=${TEX[$kind]}; mkdir -p "$OUT/$kind"
  json=$(curl -sf "https://api.polyhaven.com/files/$id")
  for map in Diffuse:albedo nor_gl:normal Rough:rough; do
    key=${map%%:*}; name=${map##*:}
    url=$(echo "$json" | python3 -c "import json,sys;print(json.load(sys.stdin)['$key']['1k']['jpg']['url'])")
    [ -s "$OUT/$kind/$name.jpg" ] || curl -sfL -o "$OUT/$kind/$name.jpg" "$url"
  done
  echo "| $id | $kind ground | https://polyhaven.com/a/$id | CC0 |" >> "$LIC"
done
echo "assets in $OUT"; ls "$OUT"/*/ | head -40
