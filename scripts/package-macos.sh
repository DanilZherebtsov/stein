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
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
popd >/dev/null

if [[ ! -f "$BIN_PATH" ]]; then
  echo "Build output not found: $BIN_PATH"
  exit 1
fi

if [[ ! -s "$BIN_PATH" ]]; then
  echo "Build output is empty: $BIN_PATH"
  exit 1
fi

install -m 755 "$BIN_PATH" "$APP_DIR/Contents/MacOS/Stein"

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
