#!/bin/bash
# Regenerates Resources/AppIcon.icns from Scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
swift Scripts/make-icon.swift "$TMP/icon.png" >/dev/null
SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
for z in 16 32 128 256 512; do
    sips -z $z $z "$TMP/icon.png" --out "$SET/icon_${z}x${z}.png" >/dev/null
    sips -z $((z * 2)) $((z * 2)) "$TMP/icon.png" --out "$SET/icon_${z}x${z}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -rf "$TMP"
echo "Wrote Resources/AppIcon.icns"
