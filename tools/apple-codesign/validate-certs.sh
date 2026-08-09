#!/usr/bin/env bash
# Validates an Apple Developer ID signing .env + certificate before it's uploaded
# to CI secrets. Reproduces the checks a macOS `security import` signing step
# performs, including the exact PKCS12 password/MAC check.
#
# Usage: ./validate-certs.sh [path/to/.env]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-$SCRIPT_DIR/.env}"

FAILURES=0
WARNINGS=0

pass() { echo -e "  \033[32m[PASS]\033[0m $1"; }
fail() { echo -e "  \033[31m[FAIL]\033[0m $1"; FAILURES=$((FAILURES + 1)); }
warn() { echo -e "  \033[33m[WARN]\033[0m $1"; WARNINGS=$((WARNINGS + 1)); }
section() { echo -e "\n\033[36m== $1 ==\033[0m"; }

section "Environment"
if ! command -v openssl >/dev/null 2>&1; then
  fail "openssl not found on PATH"
  echo -e "\n$FAILURES failure(s), $WARNINGS warning(s)."
  exit 1
fi
pass "openssl found: $(command -v openssl)"

if [ ! -f "$ENV_FILE" ]; then
  fail ".env not found at $ENV_FILE"
  echo -e "\n$FAILURES failure(s), $WARNINGS warning(s)."
  exit 1
fi

section "Parsing .env"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
pass "Loaded $ENV_FILE"

ENV_DIR="$(cd "$(dirname "$ENV_FILE")" && pwd)"

REQUIRED_VARS=(APPLE_CERTIFICATE_PATH APPLE_CERTIFICATE_PASSWORD KEYCHAIN_PASSWORD APPLE_ID APPLE_PASSWORD APPLE_TEAM_ID)
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    fail "$var is missing or empty"
  else
    pass "$var is present"
  fi
done

section "Format checks"
if [ -n "${APPLE_TEAM_ID:-}" ] && ! [[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  warn "APPLE_TEAM_ID '$APPLE_TEAM_ID' doesn't look like a 10-character Apple Team ID"
fi
if [ -n "${APPLE_PASSWORD:-}" ] && ! [[ "$APPLE_PASSWORD" =~ ^[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}$ ]]; then
  warn "APPLE_PASSWORD doesn't look like an app-specific password (expected xxxx-xxxx-xxxx-xxxx)"
fi
if [ -n "${APPLE_ID:-}" ] && ! [[ "$APPLE_ID" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
  warn "APPLE_ID '$APPLE_ID' doesn't look like an email address"
fi

if [ -z "${APPLE_CERTIFICATE_PATH:-}" ]; then
  echo -e "\n$FAILURES failure(s), $WARNINGS warning(s)."
  [ "$FAILURES" -gt 0 ] && exit 1 || exit 0
fi

section "Certificate file"
CERT_PATH="$APPLE_CERTIFICATE_PATH"
[[ "$CERT_PATH" = /* ]] || CERT_PATH="$ENV_DIR/$CERT_PATH"
if [ ! -f "$CERT_PATH" ]; then
  fail "Certificate file not found: $CERT_PATH"
  echo -e "\n$FAILURES failure(s), $WARNINGS warning(s)."
  exit 1
fi
pass "Found certificate file: $CERT_PATH"

TMP_P12="$(mktemp -t apple-cert-validate.XXXXXX.p12)"
TMP_PEM="$(mktemp -t apple-cert-validate.XXXXXX.pem)"
cleanup() { rm -f "$TMP_P12" "$TMP_PEM"; }
trap cleanup EXIT

if [[ "$CERT_PATH" == *.b64 ]]; then
  # same decode path a CI step typically uses: printf '%s' "$SECRET" | base64 --decode
  if ! tr -d '\r\n' < "$CERT_PATH" | (base64 --decode 2>/dev/null || base64 -D) > "$TMP_P12"; then
    fail "Failed to base64-decode $CERT_PATH"
    exit 1
  fi
  pass "Decoded base64 certificate ($(wc -c < "$TMP_P12" | tr -d ' ') bytes)"
else
  cp "$CERT_PATH" "$TMP_P12"
fi

section "PKCS12 password / MAC check"
PKCS_OK=0
PKCS_OUTPUT=""
for extra_args in "" "-legacy"; do
  # shellcheck disable=SC2086
  if PKCS_OUTPUT=$(openssl pkcs12 -info -noout -passin "pass:$APPLE_CERTIFICATE_PASSWORD" -in "$TMP_P12" $extra_args 2>&1); then
    PKCS_OK=1
    break
  fi
done

if [ "$PKCS_OK" -eq 1 ]; then
  pass "APPLE_CERTIFICATE_PASSWORD successfully unlocks the .p12 (matches macOS 'security import')"
else
  fail "APPLE_CERTIFICATE_PASSWORD failed to unlock the .p12 - reproduces the 'MAC verification failed' error"
  echo "$PKCS_OUTPUT" | sed 's/^/    /'
fi

if [ "$PKCS_OK" -eq 1 ]; then
  section "Certificate identity"
  if ! openssl pkcs12 -passin "pass:$APPLE_CERTIFICATE_PASSWORD" -clcerts -nokeys -in "$TMP_P12" -legacy > "$TMP_PEM" 2>/dev/null; then
    openssl pkcs12 -passin "pass:$APPLE_CERTIFICATE_PASSWORD" -clcerts -nokeys -in "$TMP_P12" > "$TMP_PEM" 2>/dev/null
  fi

  SUBJECT=$(openssl x509 -noout -subject -in "$TMP_PEM" 2>&1)
  ENDDATE=$(openssl x509 -noout -enddate -in "$TMP_PEM" 2>&1)

  if [[ "$SUBJECT" == *"Developer ID Application"* ]]; then
    pass "Certificate subject is a 'Developer ID Application' cert: $SUBJECT"
  else
    fail "Certificate subject is NOT 'Developer ID Application': $SUBJECT"
  fi

  if [ -n "${APPLE_TEAM_ID:-}" ] && [[ "$SUBJECT" != *"$APPLE_TEAM_ID"* ]]; then
    warn "APPLE_TEAM_ID '$APPLE_TEAM_ID' not found in certificate subject: $SUBJECT"
  fi

  END_EPOCH=$(date -d "${ENDDATE#notAfter=}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${ENDDATE#notAfter=}" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  if [ -n "$END_EPOCH" ]; then
    if [ "$END_EPOCH" -lt "$NOW_EPOCH" ]; then
      fail "Certificate expired (${ENDDATE#notAfter=})"
    else
      pass "Certificate valid until ${ENDDATE#notAfter=}"
    fi
  else
    warn "Could not parse certificate expiry: $ENDDATE"
  fi

  section "PKCS12 algorithm (macOS Keychain compatibility)"
  ALGO_INFO=$(openssl pkcs12 -info -noout -passin "pass:$APPLE_CERTIFICATE_PASSWORD" -in "$TMP_P12" -legacy 2>&1 || openssl pkcs12 -info -noout -passin "pass:$APPLE_CERTIFICATE_PASSWORD" -in "$TMP_P12" 2>&1)
  if echo "$ALGO_INFO" | grep -qi "PBES2\|hmacWithSHA256\|sha256"; then
    warn "PKCS12 uses modern PBES2/AES/SHA256 - macOS 'security import' may fail with 'MAC verification failed' even with the correct password. Re-export with reexport-legacy.sh."
  else
    pass "PKCS12 uses legacy RC2/3DES + SHA1 MAC - compatible with macOS 'security import'"
  fi
fi

section "Summary"
echo "$FAILURES failure(s), $WARNINGS warning(s)."
[ "$FAILURES" -gt 0 ] && exit 1 || exit 0
