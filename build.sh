#!/bin/bash
set -euo pipefail

# Always work from the repository root: BUILD_DIR is relative and gets deleted below.
cd "$(dirname "$0")"

APP_NAME="ROG Gaming Center"
# Single source for the app version (make-dmg.sh reads it back from Info.plist).
VERSION="2.0.1"
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "=========================================================="
echo "  Building $APP_NAME for macOS & Hackintosh (Native Swift) "
echo "=========================================================="

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# 1. Compile app + CLI with SwiftPM
echo "-> Compiling $APP_NAME and rogauracore (swift build -c release)..."
swift build -c release --product ROGGamingCenter
swift build -c release --product rogauracore
BIN_DIR="$(swift build -c release --show-bin-path)"
cp "$BIN_DIR/ROGGamingCenter" "$MACOS/ROGGamingCenter"
cp "$BIN_DIR/rogauracore" "$BUILD_DIR/rogauracore"
chmod +x "$BUILD_DIR/rogauracore"

# 2. Copy Resources into App Bundle
echo "-> Packaging bundle assets..."
if [ -f "./Resources/emblem.png" ]; then
    cp ./Resources/emblem.png "$RESOURCES/emblem.png"
fi
if [ -f "./Resources/menubar_icon.png" ]; then
    cp ./Resources/menubar_icon.png "$RESOURCES/menubar_icon.png"
fi
if [ -f "./Resources/menubar_icon@2x.png" ]; then
    cp ./Resources/menubar_icon@2x.png "$RESOURCES/menubar_icon@2x.png"
fi
if [ -f "./Resources/AppIcon.icns" ]; then
    cp ./Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"
fi
if [ -f "./Resources/app_icon.png" ]; then
    cp ./Resources/app_icon.png "$RESOURCES/app_icon.png"
fi
if [ -f "./Resources/app_icon_dark.png" ]; then
    cp ./Resources/app_icon_dark.png "$RESOURCES/app_icon_dark.png"
fi
if [ -f "$BUILD_DIR/rogauracore" ]; then
    cp "$BUILD_DIR/rogauracore" "$RESOURCES/rogauracore"
    chmod +x "$RESOURCES/rogauracore"
fi

# 3. Generate Info.plist
cat << EOF > "$CONTENTS/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ROG Gaming Center</string>
    <key>CFBundleDisplayName</key>
    <string>ROG Gaming Center</string>
    <key>CFBundleIdentifier</key>
    <string>com.asus.roggamingcenter</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>ROGGamingCenter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <false/>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026. Open Source under MIT License.</string>
</dict>
</plist>
EOF

# 4. Code-sign with a STABLE identity
#
# WHY THIS STEP EXISTS (read this if RGB works in Terminal but not in the app):
# swiftc alone produces an UNSIGNED binary. macOS gates HID access (Input
# Monitoring, in System Settings > Privacy & Security) behind a per-app TCC
# grant keyed to the app's code-signing identity. `rogauracore` run from
# Terminal piggybacks on Terminal.app's own already-granted permission, so it
# "just works" — but the bundled .app has never been signed with a consistent
# identity, so macOS either never prompts for permission or silently drops
# any grant on the next rebuild (the binary hash changes every time).
#
# Set SIGNING_IDENTITY below to a certificate from `security find-identity -v
# -p codesigning` (a free self-signed "Apple Development" cert or a local
# Keychain cert both work) for a grant that survives rebuilds. Falls back to
# an auto-detected "Apple Development" identity, then to ad-hoc signing ("-"),
# where the grant has to be given again after every build.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
if [ -z "$SIGNING_IDENTITY" ]; then
    DETECTED_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" | head -1 | awk -F '"' '{print $2}' || true)
    if [ -n "$DETECTED_IDENTITY" ]; then
        SIGNING_IDENTITY="$DETECTED_IDENTITY"
        echo "-> Auto-detected code-signing identity: $SIGNING_IDENTITY"
    else
        SIGNING_IDENTITY="-"
    fi
fi

echo "-> Code-signing app bundle (identity: $SIGNING_IDENTITY)..."
# NOTE: deliberately NOT using --options runtime (hardened runtime) and NOT
# using the app-sandbox entitlement. Either would put this process behind
# additional kernel-level restrictions on raw IOHIDDeviceSetReport calls to a
# vendor HID interface, on top of the Input Monitoring check. The
# entitlements file below is intentionally near-empty — it exists so you can
# add specific entitlements later (e.g. if you sandbox the app) without
# restructuring the signing step.
codesign --force --deep \
    --identifier "com.asus.roggamingcenter" \
    --entitlements "./ROGGamingCenter.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_BUNDLE"

codesign --force \
    --identifier "com.asus.rogauracore" \
    --sign "$SIGNING_IDENTITY" \
    "$BUILD_DIR/rogauracore"

echo "✓ Successfully built:"
echo "   - App Bundle: $APP_BUNDLE"
echo "   - CLI Tool:   $BUILD_DIR/rogauracore"

if [ "${1:-}" == "--install" ]; then
    echo "=============================================="
    echo "  Installing to System...                     "
    echo "=============================================="
    
    # Terminate running instances if any
    killall ROGGamingCenter 2>/dev/null || true
    
    # Every reinstall of an ad-hoc-signed build looks like a "new app" to TCC.
    # Clear the stale Input Monitoring record so macOS prompts fresh instead of
    # silently denying against a record for a previous binary hash. With a real
    # signing identity the existing grant stays valid, so it is left alone.
    if [ "$SIGNING_IDENTITY" == "-" ]; then
        tccutil reset ListenEvent com.asus.roggamingcenter 2>/dev/null || true
    fi

    echo "-> Installing application to /Applications/$APP_NAME.app..."
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/$APP_NAME.app"
    touch "/Applications/$APP_NAME.app"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$APP_NAME.app" 2>/dev/null || true
    
    if [ -w "/usr/local/bin" ]; then
        echo "-> Installing CLI binary to /usr/local/bin/rogauracore..."
        cp "$BUILD_DIR/rogauracore" "/usr/local/bin/rogauracore"
    fi
    
    echo "-> Launching $APP_NAME..."
    open "/Applications/$APP_NAME.app"
    echo "✓ Successfully installed and launched!"
    echo ""
    echo "⚠️  First launch after a fresh install/identity change will trigger a"
    echo "   macOS 'would like to receive keystrokes' prompt (or none at all —"
    echo "   go straight to System Settings > Privacy & Security > Input"
    echo "   Monitoring and enable/re-check 'ROG Gaming Center' if it's already"
    echo "   listed but toggled off). The app will now show an in-app banner"
    echo "   if this permission is the problem."
fi
