#!/bin/bash
# Builds Orbit in Release and copies it to /Applications.
# Run from the project root: bash scripts/install.sh
set -e

SCHEME="Orbit"
BUILD_DIR="/tmp/orbit-release"
APP="$BUILD_DIR/Build/Products/Release/Orbit.app"
DEST="/Applications/Orbit.app"

echo "🔨 Building $SCHEME (Release)…"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | grep -v "^ *warning:"

echo "📦 Installing to $DEST…"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "✅ Orbit installed — open from Launchpad or Spotlight"
open "$DEST"
