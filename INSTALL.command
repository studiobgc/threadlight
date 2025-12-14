#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
#  DIALOGUE EDITOR METAL - ONE-CLICK INSTALLER
#  Double-click this file to build & install to /Applications
# ═══════════════════════════════════════════════════════════════════

cd "$(dirname "$0")"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎨 Dialogue Editor Metal - One-Click Install                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if Xcode is available
if [ ! -d "/Applications/Xcode.app" ]; then
    echo "❌ Xcode.app not found in /Applications"
    echo "   Please install Xcode from the App Store"
    read -p "Press Enter to exit..."
    exit 1
fi

# Switch to Xcode developer directory if needed
CURRENT_DEV=$(xcode-select -p 2>/dev/null)
if [[ "$CURRENT_DEV" != *"Xcode.app"* ]]; then
    echo "🔧 Switching to Xcode (requires password)..."
    osascript -e 'do shell script "xcode-select -s /Applications/Xcode.app/Contents/Developer" with administrator privileges'
fi

# Clean build directory
rm -rf build
mkdir -p build

# Step 1: Generate procedural icon
echo ""
echo "🎨 Generating procedural dock icon with Metal shaders..."
mkdir -p build/Icons
swift Tools/IconGenerator.swift build/Icons 2>/dev/null

if [ -f "build/Icons/AppIcon.icns" ]; then
    echo "   ✅ Unique procedural icon generated!"
else
    echo "   ⚠️  Icon generation skipped (will use default)"
fi

# Step 2: Build with xcodebuild
echo ""
echo "🔨 Building app..."
xcodebuild -project DialogueEditorMetal.xcodeproj \
    -scheme DialogueEditorMetal \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    ONLY_ACTIVE_ARCH=NO \
    build 2>&1 | grep -E "(\*\* BUILD|error:)" | head -5

# Find built app
BUILT_APP=$(find build/DerivedData -name "DialogueEditorMetal.app" -type d 2>/dev/null | head -1)

if [ -z "$BUILT_APP" ]; then
    echo ""
    echo "❌ Build failed. Opening Xcode for manual build..."
    open DialogueEditorMetal.xcodeproj
    read -p "Press Enter to exit..."
    exit 1
fi

echo "   ✅ Build complete!"

# Step 3: Copy procedural icon into app
if [ -f "build/Icons/AppIcon.icns" ]; then
    cp "build/Icons/AppIcon.icns" "$BUILT_APP/Contents/Resources/"
    echo "   ✅ Procedural icon installed!"
fi

# Step 4: Install to Applications
echo ""
echo "📦 Installing to /Applications..."

# Remove old version
rm -rf "/Applications/Dialogue Editor.app"

# Copy new version
cp -R "$BUILT_APP" "/Applications/Dialogue Editor.app"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ INSTALLED TO /Applications/Dialogue Editor.app           ║"
echo "║                                                              ║"
echo "║  🎨 Your dock icon was procedurally generated with Metal    ║"
echo "║     shaders - it's unique to this build!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Launch the app
echo "🚀 Launching..."
open "/Applications/Dialogue Editor.app"

echo ""
read -p "Press Enter to close this window..."
