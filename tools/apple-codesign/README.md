# apple-codesign

Scripts for preparing and validating an Apple Developer ID Application certificate
before it goes into CI (GitHub Actions secrets) for macOS code signing / notarization.

## Scripts

### `validate-certs.sh`

Validates a local `.env` + PKCS12 file against the same checks a CI signing step
performs, so a bad password or incompatible cert format is caught before upload.

```bash
./validate-certs.sh [path/to/.env]   # defaults to .env next to the script
```

Expects these keys in `.env`:

| Key | Purpose |
|---|---|
| `APPLE_CERTIFICATE_PATH` | Path to the `.p12` or base64-wrapped `.p12.b64` file (relative to the `.env`) |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting the `.p12` |
| `KEYCHAIN_PASSWORD` | Password for the throwaway CI keychain (any value) |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_PASSWORD` | App-specific password for that Apple ID |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID |

Checks performed: required vars present, format sanity (Team ID shape, app-specific
password shape, email shape), base64 decode, `openssl pkcs12 -info` unlocks with the
configured password (reproduces CI's `security import` MAC check locally), certificate
subject is `Developer ID Application`, and expiry date.

### `reexport-legacy.sh`

Re-exports a certificate + private key as a **legacy-format** PKCS12
(`SHA1` MAC, `RC2-40-CBC`/`3DES-CBC` encryption) — the format macOS's
`security import` reliably supports. See the [macos-code-signing skill](../../skills/macos-code-signing/SKILL.md)
for why this is needed.

```bash
./reexport-legacy.sh <key.pem> <cert.pem> <output.p12> <password>
```

Requires OpenSSL 3.x's `legacy` provider (bundled by default; pass `-legacy` explicitly
when reading the result back with `openssl pkcs12 -info`).
