#!/usr/bin/env bash
set -euo pipefail

# Build a drag-to-Applications DMG for MinusOne.
# Usage: Scripts/package-dmg.sh [path/to/MinusOne.app]
# Defaults to build/MinusOne.app (run Scripts/build-app.sh release first if missing).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="${1:-$BUILD_DIR/MinusOne.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH"
  echo "Run: Scripts/build-app.sh release"
  exit 1
fi

VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null \
    || echo "0.0.0"
)"
VOL_NAME="MinusOne"
DMG_NAME="MinusOne-v${VERSION}-macos.dmg"
STAGE="$BUILD_DIR/dmg-stage"
RW_DMG="$BUILD_DIR/${DMG_NAME%.dmg}-rw.dmg"
FINAL_DMG="$BUILD_DIR/$DMG_NAME"
VOLUME="/Volumes/$VOL_NAME"

rm -rf "$STAGE" "$RW_DMG" "$FINAL_DMG"
# Detach a leftover volume from a previous failed run.
if [[ -d "$VOLUME" ]]; then
  hdiutil detach "$VOLUME" -quiet -force 2>/dev/null || true
fi

mkdir -p "$STAGE"
ditto "$APP_PATH" "$STAGE/MinusOne.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG" >/dev/null

cleanup() {
  if [[ -d "$VOLUME" ]]; then
    hdiutil detach "$VOLUME" -quiet -force 2>/dev/null || true
  fi
  rm -rf "$STAGE" "$RW_DMG"
}
trap cleanup EXIT

hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" >/dev/null

# Wait for Finder to see the volume.
for _ in $(seq 1 20); do
  if [[ -d "$VOLUME/MinusOne.app" ]]; then
    break
  fi
  sleep 0.25
done

# Classic Finder window: app on the left, Applications on the right.
osascript <<EOF
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 760, 460}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "MinusOne.app" of container window to {140, 160}
    set position of item "Applications" of container window to {420, 160}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

sync
hdiutil detach "$VOLUME" -quiet

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
hdiutil internet-enable -quiet -yes "$FINAL_DMG" 2>/dev/null || true

trap - EXIT
rm -rf "$STAGE" "$RW_DMG"

echo "Built $FINAL_DMG"
ls -lh "$FINAL_DMG"
