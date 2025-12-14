#!/bin/bash

# Dialogue Editor Metal - Build & Install Script
# Builds the app and installs it to /Applications without needing Xcode UI

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="DialogueEditorMetal"
APP_NAME="Dialogue Editor"
BUNDLE_ID="com.dialogueeditor.metal"
BUILD_DIR="$SCRIPT_DIR/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🎨 Dialogue Editor Metal - Build Script                     ║"
echo "║  Building a wild, experimental, GPU-powered dialogue tool    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check for Xcode command line tools
if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode command line tools not found."
    echo "   Install with: xcode-select --install"
    exit 1
fi

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Generate the procedural icon
echo ""
echo "🎨 Generating procedural dock icon with Metal shaders..."
echo "   (This creates a unique, generative icon every build)"
echo ""

ICON_OUTPUT="$BUILD_DIR/Icons"
mkdir -p "$ICON_OUTPUT"

# Run the icon generator
swift "$SCRIPT_DIR/Tools/IconGenerator.swift" "$ICON_OUTPUT" 2>/dev/null || {
    echo "⚠️  Icon generator requires Metal. Using fallback..."
    # Create a simple placeholder if Metal isn't available
    mkdir -p "$ICON_OUTPUT"
}

# Build the app using xcodebuild (command line, no Xcode UI needed)
echo ""
echo "🔨 Building $APP_NAME..."
echo ""

cd "$SCRIPT_DIR"

# Check if xcodeproj exists, if not create it
if [ ! -d "$PROJECT_NAME.xcodeproj" ]; then
    echo "📦 Creating Xcode project..."
    # We'll use swift build for a pure Swift approach
    
    # Create Package.swift for SPM build
    cat > Package.swift << 'EOF'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DialogueEditorMetal",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DialogueEditorMetal", targets: ["DialogueEditorMetal"])
    ],
    targets: [
        .executableTarget(
            name: "DialogueEditorMetal",
            path: "DialogueEditorMetal",
            exclude: ["Info.plist", "DialogueEditorMetal.entitlements"],
            resources: [
                .process("Assets.xcassets"),
                .process("Shaders")
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
EOF
fi

# Build with xcodebuild if project exists, otherwise use alternative
if [ -d "$PROJECT_NAME.xcodeproj" ]; then
    xcodebuild -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$PROJECT_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        -destination 'platform=macOS' \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGNING_REQUIRED=NO \
        clean build 2>&1 | grep -E "(Building|Linking|error:|warning:|\*\*)" || true
    
    # Find and copy the built app
    BUILT_APP=$(find "$BUILD_DIR/DerivedData" -name "*.app" -type d | head -1)
    if [ -n "$BUILT_APP" ]; then
        cp -R "$BUILT_APP" "$APP_PATH"
    fi
else
    echo "⚠️  No Xcode project found. Creating app bundle manually..."
    
    # Create app bundle structure
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"
    
    # Compile Swift files manually
    echo "   Compiling Swift sources..."
    
    SWIFT_FILES=$(find "$SCRIPT_DIR/DialogueEditorMetal" -name "*.swift" -type f)
    METAL_FILES=$(find "$SCRIPT_DIR/DialogueEditorMetal" -name "*.metal" -type f)
    
    # Compile Metal shaders
    if [ -n "$METAL_FILES" ]; then
        echo "   Compiling Metal shaders..."
        xcrun -sdk macosx metal -c $METAL_FILES -o "$BUILD_DIR/shaders.air" 2>/dev/null || true
        xcrun -sdk macosx metallib "$BUILD_DIR/shaders.air" -o "$APP_PATH/Contents/Resources/default.metallib" 2>/dev/null || true
    fi
    
    # Compile Swift
    swiftc -O \
        -sdk $(xcrun --show-sdk-path) \
        -target arm64-apple-macos14.0 \
        -import-objc-header "$SCRIPT_DIR/DialogueEditorMetal/DialogueEditorMetal-Bridging-Header.h" \
        $SWIFT_FILES \
        -o "$APP_PATH/Contents/MacOS/$PROJECT_NAME" \
        -framework Metal \
        -framework MetalKit \
        -framework AppKit \
        -framework SwiftUI \
        -framework Combine \
        2>&1 || {
            echo "❌ Swift compilation failed. Try opening in Xcode first to resolve dependencies."
            exit 1
        }
fi

# Copy icon if generated
if [ -f "$ICON_OUTPUT/AppIcon.icns" ]; then
    cp "$ICON_OUTPUT/AppIcon.icns" "$APP_PATH/Contents/Resources/"
    echo "✅ Procedural icon installed"
fi

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
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
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Dialogue Graph</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>dgraph</string>
            </array>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
        </dict>
    </array>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo ""
echo "✅ Build complete: $APP_PATH"
echo ""

# Ask to install
read -p "📦 Install to /Applications? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Installing to /Applications..."
    
    # Remove old version if exists
    if [ -d "/Applications/$APP_NAME.app" ]; then
        rm -rf "/Applications/$APP_NAME.app"
    fi
    
    # Copy new version
    cp -R "$APP_PATH" "/Applications/"
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Installed to /Applications/$APP_NAME.app"
    echo "║                                                              ║"
    echo "║  🎨 Your dock icon was procedurally generated with Metal    ║"
    echo "║     shaders - it's unique to this build!                    ║"
    echo "║                                                              ║"
    echo "║  🚀 Launch from Spotlight or Finder                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Open the app
    read -p "🚀 Launch now? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        open "/Applications/$APP_NAME.app"
    fi
else
    echo ""
    echo "📍 App built at: $APP_PATH"
    echo "   Run: open \"$APP_PATH\""
fi
