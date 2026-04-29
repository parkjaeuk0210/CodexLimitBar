#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT/dist"
PROFILE="${CODEX_LIMIT_BAR_NOTARY_PROFILE:-codexlimitbar-notary}"
SIGN_IDENTITY="${CODEX_LIMIT_BAR_SIGN_IDENTITY:-Developer ID Application}"
NOTARY_TIMEOUT="${CODEX_LIMIT_BAR_NOTARY_TIMEOUT:-90m}"

IDENTITIES="$(security find-identity -v -p codesigning || true)"
IDENTITY_LINE="$(printf '%s\n' "$IDENTITIES" | grep -F "$SIGN_IDENTITY" | head -n 1 || true)"

if [[ -z "$IDENTITY_LINE" ]]; then
  cat >&2 <<EOF
Missing signing identity matching: $SIGN_IDENTITY

Install a Developer ID Application certificate, then retry.
Current identities:
$IDENTITIES
EOF
  exit 2
fi

if [[ "$IDENTITY_LINE" != *"Developer ID Application"* ]]; then
  cat >&2 <<EOF
The matching identity is not a Developer ID Application certificate:
$IDENTITY_LINE

Developer ID Application signing is required for public notarized distribution.
EOF
  exit 2
fi

SIGN_IDENTITY_HASH="$(printf '%s\n' "$IDENTITY_LINE" | awk '{ print $2 }')"
APP_DIR="$("$ROOT/scripts/build.sh")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
SIGNED_ZIP="$DIST_DIR/CodexLimitBar-$VERSION-notary-upload.zip"
FINAL_ZIP="$DIST_DIR/CodexLimitBar-$VERSION-notarized.zip"

mkdir -p "$DIST_DIR"
rm -f "$SIGNED_ZIP" "$FINAL_ZIP" "$FINAL_ZIP.sha256"

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY_HASH" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$SIGNED_ZIP"
xcrun notarytool submit "$SIGNED_ZIP" \
  --keychain-profile "$PROFILE" \
  --wait \
  --timeout "$NOTARY_TIMEOUT"

xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

ditto -c -k --keepParent "$APP_DIR" "$FINAL_ZIP"
shasum -a 256 "$FINAL_ZIP" > "$FINAL_ZIP.sha256"

echo "$FINAL_ZIP"
