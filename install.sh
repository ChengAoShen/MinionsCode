#!/bin/bash
set -e

APP_NAME="MinionsCode"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

echo "Building $APP_NAME (release)..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp .build/release/MinionsCode "$APP_BUNDLE/Contents/MacOS/"

if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MinionsCode</string>
    <key>CFBundleIdentifier</key>
    <string>com.minions.code</string>
    <key>CFBundleName</key>
    <string>MinionsCode</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
</dict>
</plist>
PLIST

echo "Installed to $APP_BUNDLE"

# Kill any running instance so the next launch picks up the fresh binary —
# easy to forget "did I restart MinionsCode after rebuilding?" otherwise.
if pgrep -x MinionsCode >/dev/null 2>&1; then
    echo "Stopping running MinionsCode instance..."
    pkill -x MinionsCode 2>/dev/null || true
    sleep 1
    pkill -9 -x MinionsCode 2>/dev/null || true
    sleep 1
fi

if [ "$1" = "--launch" ] || [ "$1" = "-r" ]; then
    echo "Launching..."
    open "$APP_BUNDLE"
else
    echo "Run: open $APP_BUNDLE  (or: bash install.sh --launch)"
fi
