#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "verify-package-macos.sh must run on macOS"
  exit 1
fi

./scripts/package-macos.sh

APP_BIN="dist/Stein.app/Contents/MacOS/Stein"
APP_PLIST="dist/Stein.app/Contents/Info.plist"
ZIP_FILE="dist/Stein-macos.zip"

[[ -f "$APP_BIN" ]] || { echo "Missing app binary: $APP_BIN"; exit 1; }
[[ -s "$APP_BIN" ]] || { echo "App binary is empty: $APP_BIN"; exit 1; }
[[ -f "$APP_PLIST" ]] || { echo "Missing Info.plist"; exit 1; }
[[ -f "$ZIP_FILE" ]] || { echo "Missing zip artifact"; exit 1; }
[[ -s "$ZIP_FILE" ]] || { echo "Zip artifact is empty"; exit 1; }

/usr/bin/file "$APP_BIN"
/usr/bin/stat -f "%N %z bytes" "$APP_BIN"
/usr/bin/stat -f "%N %z bytes" "$ZIP_FILE"

echo "Packaging verification passed."
