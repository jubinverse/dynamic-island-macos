#!/bin/bash
# Builds the app and packages it as build/DynamicIsland-<version>.dmg.
# The disk image contains the app and an Applications shortcut, so users
# install it by dragging one onto the other.
set -euo pipefail
cd "$(dirname "$0")/.."

./build.sh

APP="build/DynamicIsland.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG="build/DynamicIsland-${VERSION}.dmg"
VOLUME="Dynamic Island"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
STAGING="$WORK/staging"
mkdir -p "$STAGING"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
cp Resources/AppIcon.icns "$STAGING/.VolumeIcon.icns"

# Read/write image first so the custom volume icon can be switched on.
RW="$WORK/rw.dmg"
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW"
MOUNT=$(hdiutil attach -nobrowse -noautoopen "$RW" | awk -F'\t' '/\/Volumes\// {print $NF}')
SetFile -a C "$MOUNT" 2>/dev/null || true # show .VolumeIcon.icns (needs Xcode tools; optional)
hdiutil detach -quiet "$MOUNT"

# Compressed, read-only final image.
rm -f "$DMG"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG"

# Sign the image with the same identity as the app, if one exists.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
if [[ -n "${IDENTITY:-}" ]]; then
    codesign --force --sign "$IDENTITY" "$DMG" >/dev/null
fi

# Give the .dmg file itself the app icon in Finder. This is stored as file metadata,
# so it shows on this Mac and in zips made by Finder, but downloads from the web
# (e.g. GitHub Releases) usually drop it. The mounted disk keeps its icon either way.
osascript -l JavaScript -e '
  ObjC.import("AppKit");
  function run(argv) {
    const image = $.NSImage.alloc.initWithContentsOfFile(argv[0]);
    return $.NSWorkspace.sharedWorkspace.setIconForFileOptions(image, argv[1], 0);
  }' "$PWD/Resources/AppIcon.icns" "$PWD/$DMG" >/dev/null

echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
