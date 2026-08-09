#!/usr/bin/env bash
# Re-exports a certificate + private key as a legacy-format PKCS12.
#
# macOS `security import` (SecKeychainItemImport) fails with "MAC verification
# failed (wrong password?)" against PKCS12 files using OpenSSL 3.x's modern
# defaults (PBES2/AES-256-CBC + hmacWithSHA256 MAC) even with the correct
# password - it only reliably supports the legacy RC2/3DES + SHA1 format.
#
# Usage: ./reexport-legacy.sh <key.pem> <cert.pem> <output.p12> <password> [friendly-name]

set -euo pipefail

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <key.pem> <cert.pem> <output.p12> <password> [friendly-name]" >&2
  exit 1
fi

KEY_PATH="$1"
CERT_PATH="$2"
OUT_PATH="$3"
PASSWORD="$4"
FRIENDLY_NAME="${5:-Developer ID Application}"

openssl pkcs12 -export -legacy \
  -inkey "$KEY_PATH" \
  -in "$CERT_PATH" \
  -out "$OUT_PATH" \
  -name "$FRIENDLY_NAME" \
  -passout "pass:$PASSWORD"

echo "== Export OK, verifying =="
openssl pkcs12 -info -legacy -in "$OUT_PATH" -passin "pass:$PASSWORD" -noout
