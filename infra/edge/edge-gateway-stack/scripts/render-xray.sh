#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v envsubst >/dev/null 2>&1; then
  echo "Error: envsubst not found. Install gettext (or gettext-base) and retry." >&2
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "Error: .env not found in $ROOT_DIR" >&2
  echo "Tip: cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

mkdir -p xray/output

envsubst < xray/server-config.json > xray/output/server-config.json
envsubst < xray/client-config.json > xray/output/client-config.json

if grep -R '\${' xray/output >/dev/null 2>&1; then
  echo "Warning: unresolved placeholders remain in xray/output files." >&2
  exit 2
fi

echo "Rendered files:"
echo "- xray/output/server-config.json"
echo "- xray/output/client-config.json"
