#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh --universal
version="$(tr -d '\n' < VERSION)"
archive="ScreenMate-${version}-macOS-universal.zip"
# Preserve the macOS bundle layout and permissions in a Finder-friendly ZIP.
ditto -c -k --sequesterRsrc --keepParent dist/ScreenMate.app "dist/$archive"
(cd dist && shasum -a 256 "$archive" > "$archive.sha256")
printf '\nRelease: dist/%s\nChecksum: dist/%s.sha256\n' "$archive" "$archive"
