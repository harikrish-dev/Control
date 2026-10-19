#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
APP_DIR="$DIR/Control.app"
BIN_DIR="$HOME/.local/bin"

echo "========================================="
echo "  🚀 Installing Control for macOS"
echo "========================================="

# 1. Build Swift release binary
echo "🔨 Compiling Swift binary..."
swift build --package-path "$DIR" -c release

# 2. Package Control.app bundle
echo "📦 Assembling Control.app..."
"$DIR/bundle_app.sh"

# 3. Copy to /Applications
echo "📁 Installing to /Applications..."
rm -rf "/Applications/Control.app"
cp -R "$APP_DIR" "/Applications/Control.app"

# 4. Install CLI tool
echo "⚡ Installing 'control' CLI command..."
mkdir -p "$BIN_DIR"
ln -sf "$DIR/bin/control" "$BIN_DIR/control"
chmod +x "$DIR/bin/control"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
    if [ -f "$HOME/.bash_profile" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    fi
    echo "" >> "$SHELL_PROFILE"
    echo '# Added by Control installer' >> "$SHELL_PROFILE"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_PROFILE"
    echo "ℹ Added $BIN_DIR to $SHELL_PROFILE"
fi

echo ""
echo "========================================="
echo "  ✓ Installation Complete!"
echo "========================================="
echo "  • App: /Applications/Control.app"
echo "  • CLI: $BIN_DIR/control"
echo ""
echo "To start, open Control from Applications or run: control list"
