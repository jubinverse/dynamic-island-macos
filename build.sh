#!/bin/bash
# Builds DynamicIsland.app into ./build. Pass --run to (re)launch it afterwards.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/DynamicIsland.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DynamicIsland "$APP/Contents/MacOS/"
mkdir -p "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/"
cp .build/release/libNowPlayingHelper.dylib "$APP/Contents/Resources/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# Sign with an Apple Development certificate if one exists (Xcode → Settings → Accounts).
# A stable identity means macOS keeps permissions like Full Disk Access across rebuilds;
# with ad-hoc signing ("-") you may have to re-enable them after each build.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
SIGN="${IDENTITY:--}"
codesign --force --sign "$SIGN" "$APP/Contents/Resources/libNowPlayingHelper.dylib" >/dev/null
codesign --force --sign "$SIGN" "$APP" >/dev/null
echo "Built $APP"

if [[ "${1:-}" == "--run" ]]; then
    pkill -x DynamicIsland 2>/dev/null || true
    open "$APP"
fi
