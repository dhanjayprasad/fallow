#!/bin/bash
# build-dmg.sh
# Builds a signed and notarised DMG for distribution.
# Part of Fallow. MIT licence.
#
# Usage:
#   ./scripts/build-dmg.sh                    # Unsigned (for local testing)
#   ./scripts/build-dmg.sh --sign             # Signed with Developer ID
#   ./scripts/build-dmg.sh --sign --notarise  # Signed and notarised
#
# Prerequisites:
#   - Xcode 16+ with command line tools
#   - For --sign: Developer ID Application certificate in keychain
#   - For --notarise: APPLE_ID and APPLE_APP_SPECIFIC_PASSWORD env vars
#
# Environment variables (for signing/notarisation):
#   DEVELOPER_ID_APPLICATION  - Certificate name (default: "Developer ID Application")
#   APPLE_TEAM_ID             - Apple Developer Team ID
#   APPLE_ID                  - Apple ID email for notarisation
#   APPLE_APP_SPECIFIC_PASSWORD - App-specific password for notarisation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Fallow.xcarchive"
APP_PATH="$BUILD_DIR/Fallow.app"
DMG_PATH="$BUILD_DIR/Fallow.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

SIGN=false
NOTARISE=false

for arg in "$@"; do
    case $arg in
        --sign) SIGN=true ;;
        --notarise) NOTARISE=true; SIGN=true ;;
        --help|-h)
            head -15 "$0" | tail -13
            exit 0
            ;;
    esac
done

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building release archive"
xcodebuild archive \
    -project "$PROJECT_DIR/Fallow/Fallow.xcodeproj" \
    -scheme Fallow \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

echo "==> Exporting app from archive"
cp -R "$ARCHIVE_PATH/Products/Applications/Fallow.app" "$APP_PATH" 2>/dev/null || \
cp -R "$ARCHIVE_PATH/Products/usr/local/bin/Fallow" "$APP_PATH" 2>/dev/null || {
    echo "ERROR: Could not find built app in archive"
    echo "Archive contents:"
    find "$ARCHIVE_PATH" -type f | head -20
    exit 1
}

if $SIGN; then
    CERT_NAME="${DEVELOPER_ID_APPLICATION:-Developer ID Application}"
    TEAM_ID="${APPLE_TEAM_ID:?Set APPLE_TEAM_ID environment variable}"

    echo "==> Signing helpers (kwaainet, p2pd)"
    # Sign inner binaries first if they exist
    if [ -d "$APP_PATH/Contents/Helpers" ]; then
        for helper in "$APP_PATH/Contents/Helpers"/*; do
            codesign --force --sign "$CERT_NAME" \
                --options runtime \
                --timestamp \
                "$helper"
        done
    fi

    echo "==> Signing Fallow.app"
    codesign --force --deep --sign "$CERT_NAME" \
        --entitlements "$PROJECT_DIR/Fallow/Fallow/Fallow.entitlements" \
        --options runtime \
        --timestamp \
        "$APP_PATH"

    echo "==> Verifying signature"
    codesign --verify --deep --strict "$APP_PATH"
    spctl --assess --type execute "$APP_PATH" || echo "WARNING: spctl assessment failed (may need notarisation)"
fi

echo "==> Creating DMG"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
    -volname "Fallow" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

if $SIGN; then
    echo "==> Signing DMG"
    codesign --force --sign "$CERT_NAME" "$DMG_PATH"
fi

if $NOTARISE; then
    APPLE_ID_VAL="${APPLE_ID:?Set APPLE_ID environment variable}"
    APPLE_PASS="${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD environment variable}"

    echo "==> Submitting for notarisation"
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID_VAL" \
        --password "$APPLE_PASS" \
        --team-id "$TEAM_ID" \
        --wait

    echo "==> Stapling notarisation ticket"
    xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "==> Build complete!"
echo "    DMG: $DMG_PATH"
ls -lh "$DMG_PATH"

if ! $SIGN; then
    echo ""
    echo "    NOTE: This DMG is unsigned. For distribution, run:"
    echo "    ./scripts/build-dmg.sh --sign --notarise"
fi
