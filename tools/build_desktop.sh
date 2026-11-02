#!/usr/bin/env bash
# Builds the Windows desktop app folder from dist/site (run tools/build_site.py first).
#   tools/build_desktop.sh [output folder]     (default: out/desktop)
# Needs Linux node + npm on PATH (Windows npm in WSL's PATH won't work here).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/out/desktop}"
cd "$ROOT/desktop"
npm install --no-audit --no-fund
rm -rf site
cp -r "$ROOT/dist/site" site
npx @electron/packager . "Dragon Ball" --platform=win32 --arch=x64 --out "$OUT" --overwrite --asar \
  --app-copyright="Dragon Ball" --ignore='^/node_modules' --ignore='^/package-lock.json'
echo "Built: $OUT/Dragon Ball-win32-x64/Dragon Ball.exe"
