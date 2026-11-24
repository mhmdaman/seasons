#!/bin/zsh
set -e

# build.sh
# Compiles SeasonsIsComing.swift with -O, creates build/SeasonsIsComing.app,
# sets up Info.plist, resources, signs ad-hoc, and prints usage instructions.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/SeasonsIsComing.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Cleaning old build..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Generate AppIcon.icns if needed
if [[ ! -f "AppIcon.icns" ]]; then
    if [[ -x "./make_icon.sh" ]]; then
        ./make_icon.sh
    fi
fi

echo "==> Compiling SeasonsIsComing with swiftc -O..."
mkdir -p /tmp/swift-cache
swiftc -O \
    -module-cache-path /tmp/swift-cache \
    -Xcc -fmodules-cache-path=/tmp/swift-cache \
    SeasonsIsComing.swift \
    -o "$MACOS_DIR/SeasonsIsComing"

echo "==> Creating Info.plist..."
cat << 'EOF' > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>SeasonsIsComing</string>
    <key>CFBundleDisplayName</key>
    <string>SeasonsIsComing</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.SeasonsIsComing</string>
    <key>CFBundleExecutable</key>
    <string>SeasonsIsComing</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

if [[ -f "AppIcon.icns" ]]; then
    echo "==> Copying AppIcon.icns..."
    cp "AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [[ -d "leaves" ]]; then
    echo "==> Copying leaves to Resources..."
    mkdir -p "$RESOURCES_DIR/leaves"
    cp leaves/*.png "$RESOURCES_DIR/leaves/" 2>/dev/null || true
fi

if [[ -d "spring_leaves" ]]; then
    echo "==> Copying spring_leaves to Resources..."
    mkdir -p "$RESOURCES_DIR/spring_leaves"
    cp spring_leaves/*.png "$RESOURCES_DIR/spring_leaves/" 2>/dev/null || true
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "=========================================================="
echo "  Build successful! Created: $APP_BUNDLE"
echo "=========================================================="
echo ""
echo "To run the app:"
echo "  open build/SeasonsIsComing.app"
echo ""
echo "To install for all users:"
echo "  cp -R build/SeasonsIsComing.app /Applications"
echo ""
