#!/bin/bash
set -euo pipefail

# One-command setup for i18n Agent for Xcode
# Usage: curl -fsSL https://raw.githubusercontent.com/i18n-agent/xcode-sync/main/scripts/setup.sh | bash

echo ""
echo "  🌐 i18n Agent for Xcode — Setup"
echo "  ================================"
echo ""

# ── Step 1: Check for Node.js ──────────────────────────────────────────────────

if ! command -v node &>/dev/null; then
    echo "  Node.js is required but not installed."
    echo ""
    if command -v brew &>/dev/null; then
        echo "  Installing Node.js via Homebrew..."
        brew install node
    else
        echo "  Install Node.js from https://nodejs.org/ and run this script again."
        exit 1
    fi
fi

NODE_VERSION=$(node -v)
echo "  ✓ Node.js $NODE_VERSION"

# ── Step 2: Install i18nagent CLI ──────────────────────────────────────────────

if command -v i18nagent &>/dev/null; then
    CLI_VERSION=$(i18nagent --version 2>/dev/null || echo "installed")
    echo "  ✓ i18nagent CLI $CLI_VERSION (already installed)"
else
    echo "  Installing i18nagent CLI..."
    npm install -g i18nagent
    echo "  ✓ i18nagent CLI installed"
fi

# ── Step 3: Check API key ─────────────────────────────────────────────────────

CONFIG_FILE="$HOME/.config/i18nagent/config.json"

if [ -f "$CONFIG_FILE" ] && grep -q "apiKey" "$CONFIG_FILE" 2>/dev/null; then
    echo "  ✓ API key configured"
else
    echo ""
    echo "  You need an API key to use i18n Agent."
    echo "  Get one at: https://app.i18nagent.ai"
    echo ""
    # Restore interactive input from terminal (curl | bash steals stdin)
    if [ -t 0 ]; then
        # Already interactive — just run login
        i18nagent login
    else
        # stdin is piped — read from /dev/tty instead
        echo "  Paste your API key (starts with i18n_):"
        printf "  > "
        read -r API_KEY < /dev/tty
        if [ -n "$API_KEY" ]; then
            i18nagent login --key "$API_KEY"
        fi
    fi
    echo ""
    if [ -f "$CONFIG_FILE" ] && grep -q "apiKey" "$CONFIG_FILE" 2>/dev/null; then
        echo "  ✓ API key configured"
    else
        echo "  ⚠ API key not set. Run 'i18nagent login' later to configure it."
    fi
fi

# ── Step 4: Install the app ───────────────────────────────────────────────────

echo ""

# Check if DMG download is available
LATEST_DMG_URL="https://github.com/i18n-agent/xcode-sync/releases/latest/download/i18n-Agent.dmg"
HTTP_STATUS=$(curl -sI -o /dev/null -w "%{http_code}" -L "$LATEST_DMG_URL" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "  Downloading i18n Agent..."
    DMG_PATH="/tmp/i18n-Agent.dmg"
    curl -fsSL -o "$DMG_PATH" "$LATEST_DMG_URL"

    echo "  Installing to /Applications..."
    MOUNT_DIR=$(hdiutil attach "$DMG_PATH" -nobrowse -quiet 2>/dev/null | tail -1 | awk -F'\t' '{print $NF}')

    if [ -d "$MOUNT_DIR/i18n Agent.app" ]; then
        rm -rf "/Applications/i18n Agent.app" 2>/dev/null || true
        cp -R "$MOUNT_DIR/i18n Agent.app" "/Applications/"
        hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
        rm -f "$DMG_PATH"
        echo "  ✓ i18n Agent installed to /Applications"
    else
        hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
        echo "  ⚠ Could not find app in DMG. Building from source instead..."
        BUILD_FROM_SOURCE=true
    fi
else
    echo "  No release build available yet. Building from source..."
    BUILD_FROM_SOURCE=true
fi

if [ "${BUILD_FROM_SOURCE:-false}" = "true" ]; then
    # Check for Xcode
    if ! command -v xcodebuild &>/dev/null; then
        echo "  ✗ Xcode is required to build from source."
        echo "    Install Xcode from the App Store, then run this script again."
        exit 1
    fi

    # Check for xcodegen
    if ! command -v xcodegen &>/dev/null; then
        if command -v brew &>/dev/null; then
            echo "  Installing XcodeGen..."
            brew install xcodegen
        else
            echo "  ✗ XcodeGen is required. Install it with: brew install xcodegen"
            exit 1
        fi
    fi

    # Clone and build
    CLONE_DIR="/tmp/xcode-sync-build"
    rm -rf "$CLONE_DIR"
    echo "  Cloning repository..."
    git clone --depth 1 https://github.com/i18n-agent/xcode-sync.git "$CLONE_DIR" 2>/dev/null

    cd "$CLONE_DIR"
    echo "  Generating Xcode project..."
    xcodegen generate >/dev/null 2>&1

    echo "  Building (this may take a moment)..."
    xcodebuild -scheme i18nAgent -configuration Release build -quiet 2>/dev/null

    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/i18nAgent-*/Build/Products/Release -name "i18n Agent.app" -maxdepth 1 2>/dev/null | head -1)

    if [ -n "$APP_PATH" ] && [ -d "$APP_PATH" ]; then
        rm -rf "/Applications/i18n Agent.app" 2>/dev/null || true
        cp -R "$APP_PATH" "/Applications/"
        echo "  ✓ i18n Agent built and installed to /Applications"
    else
        echo "  ✗ Build failed. Open the project manually:"
        echo "    cd $CLONE_DIR && open i18nAgent.xcodeproj"
        exit 1
    fi

    rm -rf "$CLONE_DIR"
fi

# ── Done ───────────────────────────────────────────────────────────────────────

echo ""
echo "  ✓ Setup complete!"
echo ""
echo "  Launch 'i18n Agent' from Applications or Spotlight."
echo "  The globe icon will appear in your menu bar."
echo ""
echo "  Quick start:"
echo "    1. Open your Xcode project"
echo "    2. Click the globe icon in the menu bar"
echo "    3. Click 'Pull Translations' to translate your app"
echo ""
