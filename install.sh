#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "          RPixel for macOS Setup          "
echo "=========================================="
echo ""

# 1. Build application bundle
echo "==> [1/4] Building RPixel.app..."
./Scripts/build_app.sh

APP_SRC="$SCRIPT_DIR/build/RPixel.app"

# 2. Determine install destination for RPixel.app
echo "==> [2/4] Installing RPixel.app..."
APP_DEST="/Applications/RPixel.app"
if [ ! -w "/Applications" ]; then
    APP_DEST="$HOME/Applications/RPixel.app"
    mkdir -p "$HOME/Applications"
fi

rm -rf "$APP_DEST"
cp -R "$APP_SRC" "$APP_DEST"
echo "✓ Installed RPixel.app to: $APP_DEST"

# 3. Install Finder Quick Action / Service
echo "==> [3/4] Installing Finder Quick Action..."
"$APP_DEST/Contents/MacOS/RPixel" --install >/dev/null 2>&1 || true

SERVICES_DIR="$HOME/Library/Services"
WORKFLOW_NAME="Fix Alpha with RPixel.workflow"
if [ -d "$SERVICES_DIR/$WORKFLOW_NAME" ]; then
    echo "✓ Finder Quick Action installed in: $SERVICES_DIR/$WORKFLOW_NAME"
else
    echo "⚠ Quick Action setup had an issue, please open RPixel.app to install."
fi

# 4. CLI Symlink
echo "==> [4/4] Setting up CLI tool..."
CLI_SRC="$APP_DEST/Contents/MacOS/RPixel"
CLI_DEST=""

if [ -w "/usr/local/bin" ] || [ ! -e "/usr/local/bin" -a -w "/usr/local" ]; then
    mkdir -p "/usr/local/bin"
    ln -sf "$CLI_SRC" "/usr/local/bin/RPixel"
    ln -sf "$CLI_SRC" "/usr/local/bin/rpixel"
    CLI_DEST="/usr/local/bin/RPixel"
elif [ -d "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin"; then
    ln -sf "$CLI_SRC" "$HOME/.local/bin/RPixel"
    ln -sf "$CLI_SRC" "$HOME/.local/bin/rpixel"
    CLI_DEST="$HOME/.local/bin/RPixel"
fi

if [ -n "$CLI_DEST" ]; then
    echo "✓ CLI tool available at: $CLI_DEST (and rpixel)"
fi

echo ""
echo "=========================================="
echo "         Installation Complete!           "
echo "=========================================="
echo ""
echo "How to use:"
echo "1. Right-click ANY PNG image in Finder:"
echo "   Select 'Quick Actions' -> 'Fix Alpha with RPixel'"
echo "   (or right-click -> Services -> Fix Alpha with RPixel)"
echo ""
echo "2. Open RPixel.app from Applications to drag & drop images or view options."
echo ""
echo "3. Run from Terminal: RPixel <image.png> [-d] [-r]"
echo "   (or: rpixel <image.png> [-d] [-r])"
echo ""
