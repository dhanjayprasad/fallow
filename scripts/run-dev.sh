#!/bin/bash
# run-dev.sh
# Builds and launches Fallow in a minimal app bundle for development.
# Usage: ./scripts/run-dev.sh
# Part of Fallow. MIT licence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="/tmp/Fallow.app/Contents"

# Kill existing instance
pkill -x Fallow 2>/dev/null && sleep 1 || true

# Build
echo "==> Building..."
cd "$PROJECT_DIR/Fallow"
swift build 2>&1

# Create app bundle
echo "==> Creating app bundle..."
mkdir -p "$APP_DIR/MacOS"
cp .build/debug/Fallow "$APP_DIR/MacOS/Fallow"

cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Fallow</string>
	<key>CFBundleIdentifier</key>
	<string>com.fallow.app</string>
	<key>CFBundleName</key>
	<string>Fallow</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
</dict>
</plist>
PLIST

# Launch
echo "==> Launching Fallow..."
open /tmp/Fallow.app
echo "==> Fallow is running. Look for the leaf icon in the menu bar."
echo "    Click the leaf to open the popover."
echo "    To stop: pkill -x Fallow"
