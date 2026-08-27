#!/usr/bin/env bash
set -e

# Directory where script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="StaticRe.app"
OUTPUT_DIR="$SCRIPT_DIR/build"
BUNDLE_DIR="$OUTPUT_DIR/$APP_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Building StaticReApp (Release)..."
swift build -c release --product StaticReApp

echo "==> Packaging $APP_NAME..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$SCRIPT_DIR/.build/release/StaticReApp" "$MACOS_DIR/StaticReApp"
chmod +x "$MACOS_DIR/StaticReApp"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "==> Successfully created $BUNDLE_DIR"
echo "You can launch it with: open \"$BUNDLE_DIR\""
