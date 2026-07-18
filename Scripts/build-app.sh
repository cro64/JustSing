#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/MinusOne.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

swift build --disable-sandbox --package-path "$ROOT_DIR" -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/.build/$CONFIGURATION/MinusOne" "$MACOS_DIR/MinusOne"
chmod +x "$MACOS_DIR/MinusOne"

echo "Built $APP_DIR"
