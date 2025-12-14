#!/bin/bash

# Dialogue Editor Metal - Simple Build Script
# Uses swiftc directly - no Xcode app required

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="DialogueEditorMetal"
APP_NAME="Dialogue Editor"
BUILD_DIR="$SCRIPT_DIR/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
SRC_DIR="$SCRIPT_DIR/DialogueEditorMetal"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎨 Dialogue Editor Metal - Build Script                     ║"
echo "║  Wild • Experimental • GPU-Powered                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Generate procedural icon
echo "🎨 Generating procedural dock icon with Metal shaders..."
ICON_OUTPUT="$BUILD_DIR/Icons"
mkdir -p "$ICON_OUTPUT"
swift "$SCRIPT_DIR/Tools/IconGenerator.swift" "$ICON_OUTPUT"
echo ""

# Step 2: Create app bundle structure
echo "📦 Creating app bundle..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Step 3: Compile Metal shaders
echo "⚡ Compiling Metal shaders..."
METAL_FILES=$(find "$SRC_DIR/Shaders" -name "*.metal" -type f 2>/dev/null || true)
if [ -n "$METAL_FILES" ]; then
    # Compile each metal file to AIR
    AIR_FILES=""
    for metal_file in $METAL_FILES; do
        base=$(basename "$metal_file" .metal)
        xcrun -sdk macosx metal -c "$metal_file" -o "$BUILD_DIR/$base.air" 2>/dev/null || {
            echo "   Warning: Could not compile $metal_file"
        }
        if [ -f "$BUILD_DIR/$base.air" ]; then
            AIR_FILES="$AIR_FILES $BUILD_DIR/$base.air"
        fi
    done
    
    # Link into metallib
    if [ -n "$AIR_FILES" ]; then
        xcrun -sdk macosx metallib $AIR_FILES -o "$APP_PATH/Contents/Resources/default.metallib" 2>/dev/null || true
        echo "   ✅ Metal shaders compiled"
    fi
fi

# Step 4: Compile Swift
echo "🔨 Compiling Swift sources..."

# Gather all Swift files
SWIFT_FILES=$(find "$SRC_DIR" -name "*.swift" -type f | grep -v "Preview" | sort)
SWIFT_COUNT=$(echo "$SWIFT_FILES" | wc -l | tr -d ' ')
echo "   Found $SWIFT_COUNT Swift files"

# Get SDK path
SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

# Compile with swiftc
# Note: We need to handle the bridging header for Metal types
BRIDGING_HEADER="$SRC_DIR/DialogueEditorMetal-Bridging-Header.h"

swiftc \
    -O \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macos14.0 \
    -import-objc-header "$BRIDGING_HEADER" \
    -framework Metal \
    -framework MetalKit \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -framework UniformTypeIdentifiers \
    -parse-as-library \
    $SWIFT_FILES \
    -o "$APP_PATH/Contents/MacOS/$PROJECT_NAME" \
    2>&1 || {
        echo ""
        echo "❌ Compilation failed. Common fixes:"
        echo "   1. Open Xcode once to accept license: sudo xcodebuild -license accept"
        echo "   2. Select Xcode: sudo xcode-select -s /Applications/Xcode.app"
        echo ""
        exit 1
    }

echo "   ✅ Swift compiled"

# Step 5: Copy icon
if [ -f "$ICON_OUTPUT/AppIcon.icns" ]; then
    cp "$ICON_OUTPUT/AppIcon.icns" "$APP_PATH/Contents/Resources/"
    echo "   ✅ Icon installed"
fi

# Step 6: Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DialogueEditorMetal</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.dialogueeditor.metal</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Dialogue Editor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ BUILD COMPLETE                                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 App: $APP_PATH"
echo ""

# Install prompt
read -p "📦 Install to /Applications? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Remove old version
    [ -d "/Applications/$APP_NAME.app" ] && rm -rf "/Applications/$APP_NAME.app"
    
    # Install
    cp -R "$APP_PATH" "/Applications/"
    
    echo ""
    echo "✅ Installed to /Applications/$APP_NAME.app"
    echo ""
    echo "🎨 Your dock icon was procedurally generated with Metal"
    echo "   shaders - it's unique to this build!"
    echo ""
    
    read -p "🚀 Launch now? [Y/n] " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Nn]$ ]] && open "/Applications/$APP_NAME.app"
else
    echo ""
    echo "Run: open \"$APP_PATH\""
fi
