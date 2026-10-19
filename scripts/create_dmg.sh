#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
BUILD_DIR="$DIR/.build/release"
APP_DIR="$DIR/Control.app"
STAGING_DIR="$DIR/.dmg_staging"
DMG_OUTPUT="$DIR/Control.dmg"

echo "🔨 Building Control in Release mode..."
swift build --package-path "$DIR" -c release

# Ensure app bundle is fresh
echo "📦 Packaging Control.app..."
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BUILD_DIR/Control" "$MACOS_DIR/Control"
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

# Prepare DMG staging directory
echo "📂 Preparing DMG disk layout..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 1. Copy App
cp -R "$APP_DIR" "$STAGING_DIR/Control.app"

# 2. Symlink Applications folder (for drag-and-drop install)
ln -s /Applications "$STAGING_DIR/Applications"

# 3. Double-clickable CLI installer helper
cat << 'EOF' > "$STAGING_DIR/Install CLI.command"
#!/bin/bash
TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CLI_SRC="$SCRIPT_DIR/Control.app/Contents/MacOS/Control"

# Install control CLI script
cp "$SCRIPT_DIR/control" "$TARGET_DIR/control"
chmod +x "$TARGET_DIR/control"

echo ""
echo "========================================="
echo "  ✓ Control CLI installed to $TARGET_DIR/control"
echo "========================================="
echo ""
echo "You can now run 'control list', 'control fan on', 'control names' from your terminal."
echo "Press any key to close this window..."
read -n 1
EOF
chmod +x "$STAGING_DIR/Install CLI.command"

# 4. Copy CLI script
cp "$DIR/bin/control" "$STAGING_DIR/control"
chmod +x "$STAGING_DIR/control"

# 5. Quick instructions
cat << 'EOF' > "$STAGING_DIR/Quick Start.txt"
========================================================
             Welcome to Control for macOS
========================================================

1. Drag "Control.app" into "Applications".
2. Open Control from Applications (it runs in your menu bar).
3. Optional: Double-click "Install CLI.command" to enable
   the "control" terminal command in your shell.

Enjoy!
========================================================
EOF

# 6. Generate compressed DMG with hdiutil
echo "💿 Generating Control.dmg using hdiutil..."
rm -f "$DMG_OUTPUT"
hdiutil create \
    -volname "Control" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "========================================================"
echo "  ✓ Success! DMG created at:"
echo "    $DMG_OUTPUT"
echo "========================================================"
echo "You can now AirDrop, email, or copy 'Control.dmg' directly to your other MacBook."
