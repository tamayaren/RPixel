#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building RPixel (Release)..."
cd "$ROOT_DIR"
swift build -c release

BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/RPixel.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Packaging $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executables
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/RPixelApp" "$MACOS_DIR/RPixelApp"
cp "$BIN_DIR/RPixel" "$MACOS_DIR/RPixel"
chmod +x "$MACOS_DIR/RPixelApp" "$MACOS_DIR/RPixel"

# Generate AppIcon.icns from Icons/ and Icon.png
echo "==> Generating AppIcon.icns from Icons..."
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

if [ -d "$ROOT_DIR/Icons" ]; then
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-16@1x.png" "$ICONSET_DIR/icon_16x16.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-16@2x.png" "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-32@1x.png" "$ICONSET_DIR/icon_32x32.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-32@2x.png" "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-128@1x.png" "$ICONSET_DIR/icon_128x128.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-128@2x.png" "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-256@1x.png" "$ICONSET_DIR/icon_256x256.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-256@2x.png" "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-512@1x.png" "$ICONSET_DIR/icon_512x512.png" 2>/dev/null || true
    cp "$ROOT_DIR/Icons/Icon-iOS-Default-1024@1x.png" "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null || true
fi

# Fallback or fill missing icons from Icon.png
if [ -f "$ROOT_DIR/Icon.png" ]; then
    [ ! -f "$ICONSET_DIR/icon_16x16.png" ] && sips -z 16 16 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_16x16@2x.png" ] && sips -z 32 32 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_32x32.png" ] && sips -z 32 32 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_32x32@2x.png" ] && sips -z 64 64 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_128x128.png" ] && sips -z 128 128 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_128x128@2x.png" ] && sips -z 256 256 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_256x256.png" ] && sips -z 256 256 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_256x256@2x.png" ] && sips -z 512 512 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_512x512.png" ] && sips -z 512 512 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1 || true
    [ ! -f "$ICONSET_DIR/icon_512x512@2x.png" ] && sips -z 1024 1024 "$ROOT_DIR/Icon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1 || true
fi

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
rm -rf "$ICONSET_DIR"

# Copy Icon.png and Icons directory to app Resources
if [ -f "$ROOT_DIR/Icon.png" ]; then
    cp "$ROOT_DIR/Icon.png" "$RESOURCES_DIR/Icon.png"
fi
if [ -d "$ROOT_DIR/Icons" ]; then
    cp -R "$ROOT_DIR/Icons" "$RESOURCES_DIR/Icons"
fi

# Generate Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>RPixelApp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.rpixel.macos</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>RPixel</string>
    <key>CFBundleDisplayName</key>
    <string>RPixel</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>PNG Image</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.png</string>
            </array>
        </dict>
    </array>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Fix Alpha with RPixel</string>
            </dict>
            <key>NSMessage</key>
            <string>fixAlphaService</string>
            <key>NSPortName</key>
            <string>RPixel</string>
            <key>NSRequiredContext</key>
            <dict>
                <key>NSApplicationIdentifier</key>
                <string>com.apple.finder</string>
            </dict>
            <key>NSSendFileTypes</key>
            <array>
                <string>public.png</string>
                <string>public.image</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "==> Ad-hoc signing $APP_BUNDLE..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "✓ Successfully built RPixel.app at: $APP_BUNDLE"
