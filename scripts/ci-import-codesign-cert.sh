#!/usr/bin/env bash
set -euo pipefail

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 2
  fi
}

require_var DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
require_var DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
require_var KEYCHAIN_PASSWORD

CERTIFICATE_PATH="${RUNNER_TEMP:-/tmp}/developer-id-application.p12"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/codexlimitbar-signing.keychain-db"

printf '%s' "$DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" \
  -P "$DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security set-key-partition-list \
  -S apple-tool:,apple: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH"
security find-identity -v -p codesigning "$KEYCHAIN_PATH"
