#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_PATH="${1:-${APPLE_DEVELOPER_CERT_PATH:-}}"
OUT_DIR="${CODEX_LIMIT_BAR_CERT_DIR:-$ROOT/.secrets/developer-id}"
PRIVATE_KEY="${DEVELOPER_ID_PRIVATE_KEY_PATH:-$OUT_DIR/developer-id-private-key.pem}"
CERT_PEM="$OUT_DIR/developer-id-application.pem"
P12_PATH="$OUT_DIR/developer-id-application.p12"
PASSWORD_PATH="$OUT_DIR/p12-password.txt"

if [[ -z "$CERT_PATH" ]]; then
  echo "Usage: $0 /path/to/developer_id_application.cer" >&2
  exit 2
fi

if [[ ! -f "$CERT_PATH" ]]; then
  echo "Certificate file not found: $CERT_PATH" >&2
  exit 2
fi

if [[ ! -f "$PRIVATE_KEY" ]]; then
  echo "Private key not found: $PRIVATE_KEY" >&2
  echo "Run ./scripts/create-developer-id-csr.sh first, then upload its CSR to Apple." >&2
  exit 2
fi

umask 077
mkdir -p "$OUT_DIR"

if openssl x509 -inform DER -in "$CERT_PATH" -out "$CERT_PEM" 2>/dev/null; then
  :
else
  openssl x509 -inform PEM -in "$CERT_PATH" -out "$CERT_PEM"
fi

if [[ -z "${P12_PASSWORD:-}" ]]; then
  if [[ -f "$PASSWORD_PATH" ]]; then
    P12_PASSWORD="$(cat "$PASSWORD_PATH")"
  else
    P12_PASSWORD="$(openssl rand -base64 32)"
    printf '%s' "$P12_PASSWORD" > "$PASSWORD_PATH"
  fi
fi

openssl pkcs12 \
  -export \
  -inkey "$PRIVATE_KEY" \
  -in "$CERT_PEM" \
  -out "$P12_PATH" \
  -name "Developer ID Application" \
  -passout "pass:$P12_PASSWORD"

cat <<EOF
Created:
  p12:      $P12_PATH
  password: $PASSWORD_PATH

Use these for GitHub Secrets:
  DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64 = base64 of $P12_PATH
  DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD = contents of $PASSWORD_PATH
EOF
