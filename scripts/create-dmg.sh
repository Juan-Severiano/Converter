#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${DERIVED_DATA_DIR:-/Users/juansev/Library/Developer/Xcode/DerivedData/Converter-bdiqyruuxithxwfyyhcrupacxwnz}"
DIST="$PROJECT_DIR/dist"
STAGING="$(mktemp -d "$PROJECT_DIR/dist-staging.XXXXXX")"
VOLUME="Convert"
DMG_PATH="${1:-$DIST/Convert-1.0.dmg}"
APP="$DERIVED/Build/Products/Release/Converter.app"
BACKGROUND="$STAGING/.background.png"

test -d "$APP"
mkdir -p "$DIST" "$STAGING/.background"
swift "$PROJECT_DIR/scripts/create-dmg-background.swift" "$BACKGROUND"
cp -R "$APP" "$STAGING/Convert.app"
ln -s /Applications "$STAGING/Applications"
mv "$BACKGROUND" "$STAGING/.background/Convert.png"

RAW_DMG="$STAGING/Convert-rw.dmg"
hdiutil create -volname "$VOLUME" -srcfolder "$STAGING" -ov -format UDRW "$RAW_DMG" >/dev/null
ATTACH_OUTPUT="$(hdiutil attach "$RAW_DMG" -nobrowse)"
MOUNT="$(printf '%s\n' "$ATTACH_OUTPUT" | sed -n 's#.*\(/Volumes/.*\)$#\1#p' | head -1)"
test -d "$MOUNT"

osascript <<OSA
tell application "Finder"
    tell disk "$VOLUME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {180, 120, 1140, 680}
        set icon size of icon view options of container window to 128
        set arrangement of icon view options of container window to not arranged
        set background picture of icon view options of container window to file ".background:Convert.png"
        set position of item "Convert.app" to {250, 280}
        set position of item "Applications" to {710, 280}
        update without registering applications
        close
        open
        delay 1
        close
    end tell
end tell
OSA

hdiutil detach "$MOUNT" -quiet
hdiutil convert "$RAW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH" >/dev/null
codesign --verify --deep --strict "$STAGING/Convert.app"
echo "Created $DMG_PATH"
