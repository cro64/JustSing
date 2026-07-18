#!/usr/bin/env bash
# Compile Resources/MinusOne.icon → Assets.car + MinusOne.icns (Xcode 26.6+ actool).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON="$ROOT_DIR/Resources/MinusOne.icon"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/MinusOne-icon.XXXXXX")"
cleanup() { rm -rf "$OUT"; }
trap cleanup EXIT

mkdir -p "$OUT"
xcrun actool "$ICON" \
  --compile "$OUT" \
  --platform macosx \
  --target-device mac \
  --minimum-deployment-target 26.0 \
  --app-icon MinusOne \
  --include-all-app-icons \
  --output-partial-info-plist "$OUT/partial.plist" \
  --output-format human-readable-text

[[ -f "$OUT/Assets.car" ]] || { echo "error: Assets.car not produced" >&2; exit 1; }
cp "$OUT/Assets.car" "$ROOT_DIR/Resources/Assets.car"
echo "Wrote Resources/Assets.car"
if [[ -f "$OUT/MinusOne.icns" ]]; then
  cp "$OUT/MinusOne.icns" "$ROOT_DIR/Resources/MinusOne.icns"
  echo "Wrote Resources/MinusOne.icns"
fi
