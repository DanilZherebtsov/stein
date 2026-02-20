#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This packaging script must be run on macOS."
  exit 1
fi

APP_NAME="Stein"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

pushd "$ROOT_DIR" >/dev/null
swift build -c release --product "$APP_NAME"

# SwiftPM bin paths can vary by toolchain/OS layout. Resolve robustly.
BIN_PATH="$(find "$ROOT_DIR/.build" -type f -name "$APP_NAME" \( -ipath "*/release/*" -o -ipath "*/products/release/*" \) | head -n 1 || true)"
popd >/dev/null

if [[ -z "$BIN_PATH" ]]; then
  echo "Build output not found under .build/*/release/$APP_NAME"
  find "$ROOT_DIR/.build" -maxdepth 4 -type f | sed 's#^#  - #' || true
  exit 1
fi

if [[ ! -s "$BIN_PATH" ]]; then
  echo "Build output is empty: $BIN_PATH"
  exit 1
fi

echo "Using binary: $BIN_PATH"
install -m 755 "$BIN_PATH" "$APP_DIR/Contents/MacOS/Stein"

if [[ ! -s "$APP_DIR/Contents/MacOS/Stein" ]]; then
  echo "Packaged app binary missing/empty after install step."
  exit 1
fi

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Stein</string>
  <key>CFBundleDisplayName</key><string>Stein</string>
  <key>CFBundleIdentifier</key><string>lab.agentfoundry.stein</string>
  <key>CFBundleVersion</key><string>0.1.0</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleExecutable</key><string>Stein</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

pushd "$DIST_DIR" >/dev/null
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${APP_NAME}-macos.zip"
popd >/dev/null

echo "Packaged: $DIST_DIR/${APP_NAME}.app"
echo "Packaged: $DIST_DIR/${APP_NAME}-macos.zip"
