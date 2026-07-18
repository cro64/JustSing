#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/MinusOne.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

swift build --disable-sandbox --package-path "$ROOT_DIR" -c "$CONFIGURATION"

# Refresh Liquid Glass catalog if missing or .icon is newer
if [[ ! -f "$ROOT_DIR/Resources/Assets.car" ]] \
  || [[ "$ROOT_DIR/Resources/MinusOne.icon/icon.json" -nt "$ROOT_DIR/Resources/Assets.car" ]]; then
  "$ROOT_DIR/Scripts/package-icon.sh"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/Assets.car" "$RESOURCES_DIR/Assets.car"
[[ -f "$ROOT_DIR/Resources/MinusOne.icns" ]] && cp "$ROOT_DIR/Resources/MinusOne.icns" "$RESOURCES_DIR/MinusOne.icns"
cp "$ROOT_DIR/.build/$CONFIGURATION/MinusOne" "$MACOS_DIR/MinusOne"
chmod +x "$MACOS_DIR/MinusOne"

echo "Built $APP_DIR"
