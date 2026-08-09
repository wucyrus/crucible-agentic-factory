---
name: macos-code-signing
description: Apple Developer ID Application code signing for macOS CI/CD (Tauri, Electron, or any `security import`-based pipeline). Use when setting up a new macOS signing/notarization pipeline, rotating an Apple Developer ID certificate, or diagnosing "MAC verification failed", "PKCS12 import" errors, `security import` failures, or GitHub Actions secrets not matching a local certificate.
---

# macOS code signing (Apple Developer ID)

Coherent reference for taking an Apple Developer ID Application certificate from
export to a working CI signing/notarization pipeline (GitHub Actions `security
import` + `notarytool`), and for diagnosing the two failure modes that look
identical but have different causes.

Tooling referenced below lives in [`tools/apple-codesign`](../../tools/apple-codesign/README.md):
`validate-certs.sh` (pre-flight check) and `reexport-legacy.sh` (the fix for the
PKCS12-format lesson).

## The PKCS12-format lesson

`security import` on macOS (Apple's `SecKeychainItemImport`, not OpenSSL) only
reliably parses **legacy**-format PKCS12: `SHA1` MAC + `RC2-40-CBC`/`3DES-CBC`
encryption. OpenSSL 3.x's default export format is **modern**: `PBES2/PBKDF2/
AES-256-CBC` encryption with an `hmacWithSHA256` MAC.

A `.p12` exported with modern defaults:
- Decodes and unlocks fine with `openssl pkcs12 -info` (any OpenSSL version) — so local
  validation with OpenSSL alone gives a false pass.
- Fails on macOS CI with `security: SecKeychainItemImport: MAC verification failed
  during PKCS12 import (wrong password?)` — **even with the correct password**.

This is the first thing to rule out whenever that exact error appears, before
assuming the password or secret itself is wrong. Confirm which format a `.p12` is in:

```bash
openssl pkcs12 -info -in cert.p12 -passin pass:PASSWORD -noout
# modern  (broken on macOS): MAC: sha256 ... PBES2, PBKDF2, AES-256-CBC
# legacy  (works on macOS):  MAC: sha1   ... pbeWithSHA1And40BitRC2-CBC
```

If it's modern, re-export as legacy (needs the cert + matching private key):

```bash
tools/apple-codesign/reexport-legacy.sh dev-id.key developerID_application.pem \
  developerID_application_legacy.p12 "$APPLE_CERTIFICATE_PASSWORD"
```

Re-encode to base64 and re-upload as the `APPLE_CERTIFICATE` secret (see below).

## The secret-interpolation lesson

Never splice `${{ secrets.X }}` directly into a `run:` script body:

```yaml
# risky: a shell-special character (", `, $) in the secret corrupts quoting,
# silently changing the value passed to the command - and it's a script-injection vector
run: security import cert.p12 -P "${{ secrets.APPLE_CERTIFICATE_PASSWORD }}"
```

Pass secrets through `env:` and reference them as quoted shell variables instead:

```yaml
env:
  APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
run: security import cert.p12 -P "$APPLE_CERTIFICATE_PASSWORD"
```

This is immune to special characters in the secret value and doesn't splice
untrusted content into the script text.

## Required secrets

| Secret | Purpose |
|---|---|
| `APPLE_CERTIFICATE` | Base64 of the **legacy-format** `.p12` (see lesson above) |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting the `.p12` |
| `KEYCHAIN_PASSWORD` | Password for the throwaway CI keychain (any value, only used within the job) |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_PASSWORD` | App-specific password for that Apple ID (`xxxx-xxxx-xxxx-xxxx`, generated at [appleid.apple.com](https://appleid.apple.com)) |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID |

`APPLE_CERTIFICATE_PATH` (pointing at a local `.p12`/`.p12.b64`) is a local-only
convenience value for the validation script — it is never itself uploaded; only the
file's contents become `APPLE_CERTIFICATE`.

## Workflow: rotating or setting up a certificate

1. Export/obtain the Developer ID Application cert + private key (Apple Developer
   portal, or Keychain Access "Certificate Assistant").
2. Put the cert, key, and a `.env` (see table above) in one local working folder —
   never commit it to a repo.
3. Run `tools/apple-codesign/validate-certs.sh` against that folder. It reproduces
   the exact CI PKCS12/MAC check locally and flags a modern-format PKCS12 before it
   ever reaches CI.
4. If flagged, run `reexport-legacy.sh` and re-validate.
5. Upload secrets via `gh secret set NAME --repo owner/repo < file` or
   `--body "$VALUE"` (piped stdin, not PowerShell `<` redirection — that operator
   isn't implemented for external commands and silently no-ops).
6. Re-run the CI signing job.

## Diagnosing a fresh failure

1. Is the error exactly `MAC verification failed during PKCS12 import (wrong
   password?)`? Check the PKCS12 format first (see lesson above) — this is the more
   common cause than an actually-wrong password once a pipeline has worked before.
2. Confirm the CI secret actually matches the local, validated file — re-upload
   rather than assume; a stale secret from an earlier cert generation is common.
3. Only after both check out, suspect the interpolation lesson (secrets spliced
   into `run:` bodies) or an actually-changed password.
