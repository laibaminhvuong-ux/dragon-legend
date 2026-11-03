#!/usr/bin/env bash
# Publishes the game's website (website/) to https://thedragonlegend.github.io/game-for-free/
# (GitHub repo thedragonlegend/game-for-free, Pages from main /). Usage: tools/publish_site.sh ["message"]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/dragon-legend-site"
MSG="${1:-Update website}"
rm -rf "$WORK"
git clone -q https://github.com/thedragonlegend/game-for-free.git "$WORK"
find "$WORK" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$ROOT/website/." "$WORK/"
touch "$WORK/.nojekyll"   # serve the files as they are
cd "$WORK"
git add -A
if git diff --cached --quiet; then echo "website: nothing to publish"; exit 0; fi
git -c user.name="$(git -C "$ROOT" config user.name)" -c user.email="$(git -C "$ROOT" config user.email)" commit -q -m "$MSG"
git push -q origin HEAD:main
echo "website published: https://thedragonlegend.github.io/game-for-free/"
