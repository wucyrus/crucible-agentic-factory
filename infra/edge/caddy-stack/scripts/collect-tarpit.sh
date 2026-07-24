#!/usr/bin/env bash
set -euo pipefail

SINCE="${1:-6h}"
RAW_OUTPUT="${2:-tarpit-raw.log}"
CSV_OUTPUT="${3:-tarpit-events.csv}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker command not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq command not found. Install jq first." >&2
  exit 1
fi

echo "Exporting tarpit logs since ${SINCE} ..."
docker logs --since "${SINCE}" xray-tarpit > "${RAW_OUTPUT}" 2>&1

# Build CSV header.
printf 'ts,client_ip,host,method,path,user_agent,hold_seconds,chunks_sent,disconnected_early\n' > "${CSV_OUTPUT}"

# Parse line-delimited logs safely. Non-JSON lines (startup, warnings) are ignored.
jq -Rr '
  fromjson?
  | select(.event == "tarpit_request")
  | [
      .ts,
      .client_ip,
      .host,
      .method,
      .path,
      .user_agent,
      (.hold_seconds|tostring),
      (.chunks_sent|tostring),
      (.disconnected_early|tostring)
    ]
  | @csv
' "${RAW_OUTPUT}" >> "${CSV_OUTPUT}" || true

echo "Saved: ${RAW_OUTPUT}"
echo "Saved: ${CSV_OUTPUT}"

if [[ $(wc -l < "${CSV_OUTPUT}") -le 1 ]]; then
  echo "No tarpit_request events found in selected window."
  exit 0
fi

echo "Top scanner IPs:"
jq -Rr 'fromjson? | select(.event == "tarpit_request") | .client_ip' "${RAW_OUTPUT}" \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 10
