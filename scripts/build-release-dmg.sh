#!/bin/zsh
set -euo pipefail

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the Apple Developer Team ID.}"
: "${SIGNING_IDENTITY:?Set SIGNING_IDENTITY to the exact Developer ID Application certificate name.}"
: "${NOTARIZATION_KEY_PATH:?Set NOTARIZATION_KEY_PATH to the App Store Connect API key.}"
: "${NOTARIZATION_KEY_ID:?Set NOTARIZATION_KEY_ID to the App Store Connect API key ID.}"
: "${NOTARIZATION_ISSUER_ID:?Set NOTARIZATION_ISSUER_ID to the App Store Connect API issuer ID.}"
: "${RELEASE_TAG:?Set RELEASE_TAG, for example v1.0.0.}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="${SCHEME:-Converter}"
APP_NAME="${APP_NAME:-Convert}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR/dist}"
ARCHIVE_PATH="$OUTPUT_DIR/$SCHEME.xcarchive"
VERSION="${RELEASE_TAG#v}"
DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Converter.app"
TEMP_ROOT="${TMPDIR:-/tmp}"
STAGING_DIR="$(mktemp -d "${TEMP_ROOT%/}/convert-release.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
rm -rf "$ARCHIVE_PATH" "$DMG_PATH"

xcodebuild archive \
  -project "$PROJECT_DIR/Converter.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"

test -d "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" \
  --key "$NOTARIZATION_KEY_PATH" \
  --key-id "$NOTARIZATION_KEY_ID" \
  --issuer "$NOTARIZATION_ISSUER_ID" \
  --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature -vv "$DMG_PATH"

echo "Created notarized DMG: $DMG_PATH"
