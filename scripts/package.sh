#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_OUTPUT="$("$ROOT/scripts/check.sh")"
APP_DIR="$(printf '%s\n' "$BUILD_OUTPUT" | awk -F'OK: ' '/^OK: / { print $2 }')"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
DIST_DIR="$ROOT/dist"
ZIP_PATH="$DIST_DIR/CodexLimitBar-$VERSION-unsigned.zip"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

echo "$ZIP_PATH"
