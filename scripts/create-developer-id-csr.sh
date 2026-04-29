#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${CODEX_LIMIT_BAR_CERT_DIR:-$ROOT/.secrets/developer-id}"
COMMON_NAME="${CSR_COMMON_NAME:-CodexLimitBar Developer ID}"
EMAIL="${CSR_EMAIL:-}"

PRIVATE_KEY="$OUT_DIR/developer-id-private-key.pem"
CSR_PATH="$OUT_DIR/CodexLimitBar-DeveloperID.csr"

umask 077
mkdir -p "$OUT_DIR"

if [[ -e "$PRIVATE_KEY" || -e "$CSR_PATH" ]]; then
  cat >&2 <<EOF
Refusing to overwrite existing certificate request files:
  $PRIVATE_KEY
  $CSR_PATH

Move or delete them first if you want to regenerate the request.
EOF
  exit 2
fi

subject="/CN=$COMMON_NAME"
if [[ -n "$EMAIL" ]]; then
  subject="$subject/emailAddress=$EMAIL"
fi

openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -keyout "$PRIVATE_KEY" \
  -out "$CSR_PATH" \
  -subj "$subject"

openssl req -in "$CSR_PATH" -noout -subject

cat <<EOF

Created:
  CSR:         $CSR_PATH
  Private key: $PRIVATE_KEY

Upload the CSR to Apple Developer Certificates and request a
"Developer ID Application" certificate. Keep the private key local and secret.
EOF
