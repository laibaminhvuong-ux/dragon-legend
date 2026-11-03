#!/usr/bin/env bash
# Downloads the CC0 assets the Godot worlds use into godot/assets/ and records their licences.
# Re-runnable; skips files already present. Source: Poly Haven (https://polyhaven.com, CC0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/godot/assets/textures"
mkdir -p "$OUT"
# kind -> Poly Haven texture id
declare -A TEX=( [grass]=leafy_grass [forest]=forest_floor [dirt]=dry_ground_01
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

# CC0 models (glTF, 1k textures): rocks, a shrub and a dead tree. Light enough for the game; Godot makes LODs.
MOD="$ROOT/godot/assets/models"
mkdir -p "$MOD"
for id in boulder_01 namaqualand_boulder_04 rock_moss_set_01 shrub_03 dead_tree_trunk; do
  mkdir -p "$MOD/$id"
  json=$(curl -sf "https://api.polyhaven.com/files/$id")
  echo "$json" | python3 -c "
import json,sys
d=json.load(sys.stdin)['gltf']['1k']['gltf']
print(d['url'])
for path,v in d.get('include',{}).items(): print(path+' '+v['url'])
" | while read -r a b; do
    if [ -z "$b" ]; then f="$MOD/$id/$id.gltf"; url=$a; else f="$MOD/$id/$a"; url=$b; fi
    mkdir -p "$(dirname "$f")"; [ -s "$f" ] || curl -sfL -o "$f" "$url"
  done
  echo "| $id | model | https://polyhaven.com/a/$id | CC0 |" >> "$LIC"
done
du -sh "$MOD"
