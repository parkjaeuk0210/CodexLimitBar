#!/usr/bin/env bash
set -euo pipefail

PROFILE="${CODEX_LIMIT_BAR_NOTARY_PROFILE:-codexlimitbar-notary}"

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 2
  fi
}

if [[ -n "${ASC_KEY_PATH:-}${ASC_KEY_ID:-}${ASC_ISSUER_ID:-}" ]]; then
  require_var ASC_KEY_PATH
  require_var ASC_KEY_ID

  args=(
    store-credentials "$PROFILE"
    --key "$ASC_KEY_PATH"
    --key-id "$ASC_KEY_ID"
  )

  if [[ -n "${ASC_ISSUER_ID:-}" ]]; then
    args+=(--issuer "$ASC_ISSUER_ID")
  fi
else
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    cat >&2 <<EOF
Usage:
  APPLE_ID=you@example.com APPLE_TEAM_ID=TEAMID ./scripts/configure-notary.sh

Optional:
  APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
  CODEX_LIMIT_BAR_NOTARY_PROFILE=codexlimitbar-notary

App Store Connect API key mode:
  ASC_KEY_PATH=/path/AuthKey_ABC123.p8 ASC_KEY_ID=ABC123 ASC_ISSUER_ID=UUID ./scripts/configure-notary.sh
EOF
    exit 2
  fi

  args=(
    store-credentials "$PROFILE"
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
  )

  if [[ -n "${APPLE_APP_PASSWORD:-}" ]]; then
    args+=(--password "$APPLE_APP_PASSWORD")
  fi
fi

xcrun notarytool "${args[@]}"
echo "Stored notarization credentials in keychain profile: $PROFILE"
