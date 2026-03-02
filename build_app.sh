#!/bin/bash
set -e

APP_NAME="SpotifyLyrics"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Sources/SpotifyLyrics/Info.plist" "$APP_BUNDLE/Contents/"
cp "Sources/SpotifyLyrics/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "Done! App bundle created at: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
