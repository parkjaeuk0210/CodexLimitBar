#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${GITHUB_REPOSITORY_NAME:-parkjaeuk0210/CodexLimitBar}"
CERT_DIR="${CODEX_LIMIT_BAR_CERT_DIR:-$ROOT/.secrets/developer-id}"
P12_PATH="${DEVELOPER_ID_APPLICATION_P12_PATH:-$CERT_DIR/developer-id-application.p12}"
P12_PASSWORD_PATH="${DEVELOPER_ID_APPLICATION_P12_PASSWORD_PATH:-$CERT_DIR/p12-password.txt}"
ASC_KEY_PATH="${ASC_API_KEY_PATH:-}"

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -f "$path" ]]; then
    echo "$label not found: $path" >&2
    exit 2
  fi
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 2
  fi
}

require_file "$P12_PATH" "Developer ID p12"
require_file "$P12_PASSWORD_PATH" "Developer ID p12 password"

if [[ -z "$ASC_KEY_PATH" ]]; then
  echo "Missing required environment variable: ASC_API_KEY_PATH" >&2
  exit 2
fi

require_file "$ASC_KEY_PATH" "App Store Connect API key"
require_var ASC_KEY_ID
require_var ASC_ISSUER_ID

base64 -i "$P12_PATH" | gh secret set DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64 --repo "$REPO"
gh secret set DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD --repo "$REPO" --body "$(cat "$P12_PASSWORD_PATH")"
base64 -i "$ASC_KEY_PATH" | gh secret set ASC_API_KEY_BASE64 --repo "$REPO"
gh secret set ASC_KEY_ID --repo "$REPO" --body "$ASC_KEY_ID"
gh secret set ASC_ISSUER_ID --repo "$REPO" --body "$ASC_ISSUER_ID"
gh secret set KEYCHAIN_PASSWORD --repo "$REPO" --body "$(openssl rand -hex 32)"

gh secret list --repo "$REPO"
