#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
APP_DIR="$BUILD_DIR/CodexLimitBar.app"
BINARY="$BUILD_DIR/CodexLimitBar"
SOURCE_DIR="$ROOT/Sources/CodexLimitBar"

rm -rf "$APP_DIR"
mkdir -p "$BUILD_DIR" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

SOURCE_FILES=()
while IFS= read -r file; do
  SOURCE_FILES+=("$file")
done < <(find "$SOURCE_DIR" -name '*.swift' -type f | sort)

swiftc \
  -O \
  -target arm64-apple-macosx13.0 \
  -framework AppKit \
  -framework Foundation \
  -framework IOKit \
  "${SOURCE_FILES[@]}" \
  -o "$BINARY"

cp "$BINARY" "$APP_DIR/Contents/MacOS/CodexLimitBar"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
