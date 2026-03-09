#!/bin/bash
set -euo pipefail

# Build, sign, notarize, and package i18n Agent as a .dmg
#
# Prerequisites:
#   - Xcode CLI tools
#   - xcodegen (brew install xcodegen)
#   - Apple Developer certificate installed in Keychain
#   - create-dmg (brew install create-dmg) — optional, falls back to hdiutil
#
# Environment variables (required for notarization):
#   DEVELOPER_ID_APPLICATION  — e.g., "Developer ID Application: Your Name (TEAM_ID)"
#   APPLE_ID                  — your Apple ID email
#   APPLE_TEAM_ID             — your Apple Developer Team ID
#   NOTARIZE_PASSWORD         — app-specific password (store in keychain recommended)
#
# Usage:
#   ./scripts/build-release.sh                  # build only (no signing/notarization)
#   ./scripts/build-release.sh --sign           # build + sign
#   ./scripts/build-release.sh --notarize       # build + sign + notarize
#   ./scripts/build-release.sh --notarize --dmg # build + sign + notarize + create .dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="i18n Agent"
ARCHIVE_PATH="$BUILD_DIR/i18nAgent.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/i18n-Agent.dmg"
SCHEME="i18nAgent"

SIGN=false
NOTARIZE=false
CREATE_DMG=false

for arg in "$@"; do
    case $arg in
        --sign) SIGN=true ;;
        --notarize) NOTARIZE=true; SIGN=true ;;
        --dmg) CREATE_DMG=true ;;
        --help|-h)
            echo "Usage: $0 [--sign] [--notarize] [--dmg]"
            echo ""
            echo "  --sign       Code sign with Developer ID"
            echo "  --notarize   Sign + notarize with Apple"
            echo "  --dmg        Create .dmg installer"
            exit 0
            ;;
    esac
done

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> Building archive..."
if $SIGN; then
    if [ -z "${DEVELOPER_ID_APPLICATION:-}" ]; then
        echo "ERROR: DEVELOPER_ID_APPLICATION env var required for signing"
        echo "  export DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAM_ID)\""
        exit 1
    fi

    xcodebuild archive \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
        OTHER_CODE_SIGN_FLAGS="--timestamp" \
        | xcpretty || xcodebuild archive \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
            CODE_SIGN_STYLE=Manual \
            DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
            OTHER_CODE_SIGN_FLAGS="--timestamp"
else
    xcodebuild archive \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGN_STYLE=Manual \
        | xcpretty || xcodebuild archive \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGN_STYLE=Manual
fi

echo "==> Exporting app from archive..."
APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: App not found at $APP_PATH"
    echo "Archive contents:"
    find "$ARCHIVE_PATH" -name "*.app" 2>/dev/null
    exit 1
fi

mkdir -p "$EXPORT_PATH"
cp -R "$APP_PATH" "$EXPORT_PATH/"

# Notarize
if $NOTARIZE; then
    echo "==> Notarizing..."

    if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ] || [ -z "${NOTARIZE_PASSWORD:-}" ]; then
        echo "ERROR: Notarization requires APPLE_ID, APPLE_TEAM_ID, and NOTARIZE_PASSWORD"
        exit 1
    fi

    # Create a zip for notarization
    NOTARIZE_ZIP="$BUILD_DIR/i18nAgent-notarize.zip"
    ditto -c -k --keepParent "$EXPORT_PATH/$APP_NAME.app" "$NOTARIZE_ZIP"

    echo "  Submitting to Apple notary service..."
    xcrun notarytool submit "$NOTARIZE_ZIP" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$NOTARIZE_PASSWORD" \
        --wait

    echo "  Stapling notarization ticket..."
    xcrun stapler staple "$EXPORT_PATH/$APP_NAME.app"

    rm -f "$NOTARIZE_ZIP"
fi

# Create DMG
if $CREATE_DMG; then
    echo "==> Creating DMG..."

    if command -v create-dmg &>/dev/null; then
        create-dmg \
            --volname "$APP_NAME" \
            --volicon "$EXPORT_PATH/$APP_NAME.app/Contents/Resources/AppIcon.icns" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "$APP_NAME.app" 175 190 \
            --hide-extension "$APP_NAME.app" \
            --app-drop-link 425 190 \
            "$DMG_PATH" \
            "$EXPORT_PATH/" \
            2>/dev/null || true

        # create-dmg returns non-zero even on success sometimes
        if [ ! -f "$DMG_PATH" ]; then
            echo "  create-dmg failed, falling back to hdiutil..."
            hdiutil create -volname "$APP_NAME" \
                -srcfolder "$EXPORT_PATH" \
                -ov -format UDZO \
                "$DMG_PATH"
        fi
    else
        hdiutil create -volname "$APP_NAME" \
            -srcfolder "$EXPORT_PATH" \
            -ov -format UDZO \
            "$DMG_PATH"
    fi

    if $NOTARIZE; then
        echo "  Notarizing DMG..."
        xcrun notarytool submit "$DMG_PATH" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$NOTARIZE_PASSWORD" \
            --wait
        xcrun stapler staple "$DMG_PATH"
    fi

    echo ""
    echo "==> DMG created: $DMG_PATH"
    echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
fi

echo ""
echo "==> Build complete!"
echo "    App: $EXPORT_PATH/$APP_NAME.app"
if $SIGN; then
    echo "    Signed: yes"
    codesign -dvv "$EXPORT_PATH/$APP_NAME.app" 2>&1 | grep -E "(Authority|TeamIdentifier)" || true
fi
if $NOTARIZE; then
    echo "    Notarized: yes"
fi
