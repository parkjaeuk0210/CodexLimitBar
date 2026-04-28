#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$("$ROOT/scripts/build.sh")"

codesign -vv "$APP_DIR"
test -x "$APP_DIR/Contents/MacOS/CodexLimitBar"
plutil -lint "$APP_DIR/Contents/Info.plist"

echo "OK: $APP_DIR"
