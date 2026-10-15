#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-/Applications/ScreenMate.app}"
if [[ "$app" != /*/ScreenMate.app ]]; then
  printf 'Install destination must be an absolute path ending in /ScreenMate.app\n' >&2
  exit 2
fi
if [[ ! -f dist/ScreenMate.app/Contents/MacOS/ScreenMate ]]; then
  printf 'Build the app first: bash scripts/build-app.sh\n' >&2
  exit 1
fi
codesign --verify --deep --strict dist/ScreenMate.app
# Stop this user's running copy before replacing it. Layouts and preferences are untouched.
pkill -u "$(id -u)" -x ScreenMate 2>/dev/null || true
mkdir -p "$(dirname "$app")"
ditto dist/ScreenMate.app "$app"
codesign --verify --deep --strict "$app"
open "$app"
printf 'Installed: %s\n' "$app"
