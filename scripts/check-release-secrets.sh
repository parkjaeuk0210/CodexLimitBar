#!/usr/bin/env bash
set -euo pipefail

REPO="${GITHUB_REPOSITORY_NAME:-parkjaeuk0210/CodexLimitBar}"
required=(
  DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64
  DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD
  KEYCHAIN_PASSWORD
  ASC_API_KEY_BASE64
  ASC_KEY_ID
  ASC_ISSUER_ID
)

existing="$(gh secret list --repo "$REPO" | awk '{ print $1 }')"
missing=()

for name in "${required[@]}"; do
  if ! printf '%s\n' "$existing" | grep -qx "$name"; then
    missing+=("$name")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Missing release secrets for $REPO:"
  printf '  %s\n' "${missing[@]}"
  exit 2
fi

echo "All release secrets are configured for $REPO."
