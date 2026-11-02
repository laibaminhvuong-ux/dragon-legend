#!/usr/bin/env bash
# Builds the public Windows downloads (installer + portable zip) from dist/site.
# Runs electron-builder on the Windows side (through WSL) so the .exe gets its icon and version info.
#   tools/build_installer.sh  -> out/installer/Dragon-Legend-Setup.exe, Dragon-Legend-portable.zip, latest.yml
# Publish: gh release create v<version> out/installer/* (latest.yml is what installed apps read to update).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WINTMP="$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")/dragonlegend-build"
mkdir -p "$WINTMP"
rm -rf "$WINTMP/site" "$WINTMP/release"
cp "$ROOT/desktop/main.js" "$ROOT/desktop/package.json" "$WINTMP/"
cp -r "$ROOT/dist/site" "$WINTMP/site"
WIN="$(wslpath -w "$WINTMP")"
powershell.exe -NoProfile -Command "Set-Location '$WIN'; npm.cmd install --no-audit --no-fund; if (\$LASTEXITCODE) { exit 1 }; npx.cmd electron-builder --win --x64 --publish never"
rm -rf "$ROOT/out/installer"; mkdir -p "$ROOT/out/installer"
cp "$WINTMP"/release/Dragon-Legend-* "$WINTMP"/release/latest*.yml "$ROOT/out/installer/"
ls -la "$ROOT/out/installer"
