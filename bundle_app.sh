#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$DIR/Control.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$DIR/.build/debug/Control" "$MACOS_DIR/Control"
chmod +x "$MACOS_DIR/Control"

if [ -f "$DIR/tuya_helper.py" ]; then
    cp "$DIR/tuya_helper.py" "$RESOURCES_DIR/tuya_helper.py"
fi

if [ -f "$DIR/Control/Assets/splash.mp4" ]; then
    cp "$DIR/Control/Assets/splash.mp4" "$RESOURCES_DIR/splash.mp4"
fi

if [ -f "$DIR/Control/Assets/app-logo.png" ]; then
    cp "$DIR/Control/Assets/app-logo.png" "$RESOURCES_DIR/app-logo.png"
fi

if [ -f "$DIR/Control/Assets/AppIcon.icns" ]; then
    cp "$DIR/Control/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat << 'PLIST' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Control</string>
    <key>CFBundleIdentifier</key>
    <string>com.harikrish.control</string>
    <key>CFBundleName</key>
    <string>Control</string>
    <key>CFBundleDisplayName</key>
    <string>Control</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Control needs local network access to communicate with WiZ lights, Homemate plugs, Atomberg fans, and Carrier air conditioners.</string>
</dict>
</plist>
PLIST

echo "Control.app bundle created at: $APP_DIR"
