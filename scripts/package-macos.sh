#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This packaging script must be run on macOS."
  exit 1
fi

APP_NAME="Stein"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"

rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

pushd "$ROOT_DIR" >/dev/null
swift build -c release
popd >/dev/null

cp "$BUILD_DIR/Stein" "$APP_DIR/Contents/MacOS/Stein"
chmod +x "$APP_DIR/Contents/MacOS/Stein"

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
zip -qry "${APP_NAME}-macos.zip" "${APP_NAME}.app"
popd >/dev/null

echo "Packaged: $DIST_DIR/${APP_NAME}.app"
echo "Packaged: $DIST_DIR/${APP_NAME}-macos.zip"
