#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iconset="$PWD/dist/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" assets/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" assets/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
python3 scripts/pack-icon.py "$iconset" assets/AppIcon.icns
printf 'Built: assets/AppIcon.icns\n'
