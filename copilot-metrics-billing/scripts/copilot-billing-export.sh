#!/bin/bash
# copilot-billing-export.sh
# Daily job: exports Copilot BILLING data (AI Credit consumption — per user, per
# day, per model, with dollar amounts) for an enterprise via the bulk CSV export.
#
# Why the CSV export instead of /ai_credit/usage?
#   - One export returns EVERY user / day / model in a single file (3 API calls:
#     create -> poll -> download), including fields the JSON API can't give you
#     per-user without one call per known username (e.g. `username`,
#     `total_monthly_quota`, `cost_center_name`).
#
# Auth: classic PAT with the `manage_billing:enterprise` scope, held by an
#       enterprise owner or billing manager. GitHub Apps and fine-grained PATs
#       CANNOT access billing endpoints — that's why billing uses a separate PAT.
#
# Usage: ./copilot-billing-export.sh <enterprise> [options]
#
# Options:
#   --start YYYY-MM-DD   Start date (default: yesterday, UTC).
#   --end YYYY-MM-DD     End date   (default: yesterday, UTC).
#   --report-type TYPE   ai_credit (default) | premium_request | detailed | summarized
#   --out PATH           Write the CSV to PATH instead of stdout.
#   --poll-timeout SECS  Max seconds to wait for the report (default: 300).
#
# Auth priority:
#   1. GH_BILLING_TOKEN env var (preferred — keep the billing PAT separate)
#   2. GH_TOKEN env var
#   3. `gh auth token` fallback
#
# Output: CSV to stdout (or --out). Progress/debug to stderr.

set -euo pipefail

API_VERSION="2026-03-10"

ENTERPRISE="${1:?Usage: $0 <enterprise> [--start YYYY-MM-DD] [--end YYYY-MM-DD] [--report-type ai_credit] [--out PATH] [--poll-timeout SECS]}"
shift

START=""
END=""
REPORT_TYPE="ai_credit"
OUT=""
POLL_TIMEOUT=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START="$2"; shift 2 ;;
    --end) END="$2"; shift 2 ;;
    --report-type) REPORT_TYPE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --poll-timeout) POLL_TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

YESTERDAY=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
START="${START:-$YESTERDAY}"
END="${END:-$YESTERDAY}"

# Auth: prefer a dedicated billing token so it never gets mixed up with the
# GitHub App / metrics token.
if [[ -n "${GH_BILLING_TOKEN:-}" ]]; then
  TOKEN="$GH_BILLING_TOKEN"
elif [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="$GH_TOKEN"
else
  TOKEN=$(gh auth token 2>/dev/null || true)
fi

if [[ -z "${TOKEN:-}" ]]; then
  echo "ERROR: No auth token. Set GH_BILLING_TOKEN (classic PAT w/ manage_billing:enterprise)." >&2
  exit 1
fi

api() {
  curl -sS -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: $API_VERSION" \
    "$@"
}

BASE="https://api.github.com/enterprises/$ENTERPRISE/settings/billing/reports"

# 1. Create the report (returns 202 + an id). Only one report runs at a time per
#    enterprise — a 409 means another export is still in progress.
echo "Creating $REPORT_TYPE billing report for $ENTERPRISE ($START -> $END)..." >&2
CREATE=$(api -X POST "$BASE" \
  -d "{\"report_type\":\"$REPORT_TYPE\",\"start_date\":\"$START\",\"end_date\":\"$END\"}")

REPORT_ID=$(echo "$CREATE" | jq -r '.id // empty')
if [[ -z "$REPORT_ID" ]]; then
  echo "ERROR: Could not create report: $CREATE" >&2
  echo "  (A 409 means another export is already running. The PAT needs manage_billing:enterprise.)" >&2
  exit 1
fi
echo "Report queued (id: $REPORT_ID). Polling..." >&2

# 2. Poll until status == completed (typically ~90s).
DEADLINE=$(( $(date +%s) + POLL_TIMEOUT ))
DOWNLOAD_URL=""
while :; do
  STATUS_JSON=$(api "$BASE/$REPORT_ID")
  STATUS=$(echo "$STATUS_JSON" | jq -r '.status // empty')
  case "$STATUS" in
    completed)
      DOWNLOAD_URL=$(echo "$STATUS_JSON" | jq -r '.download_urls[0] // empty')
      break ;;
    failed)
      echo "ERROR: Report generation failed: $STATUS_JSON" >&2
      exit 1 ;;
    "")
      echo "ERROR: Unexpected poll response: $STATUS_JSON" >&2
      exit 1 ;;
  esac
  if [[ $(date +%s) -ge $DEADLINE ]]; then
    echo "ERROR: Timed out after ${POLL_TIMEOUT}s waiting for report $REPORT_ID (status: $STATUS)." >&2
    exit 1
  fi
  sleep 10
done

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "ERROR: Report completed but no download_urls were returned." >&2
  exit 1
fi

# 3. Download the CSV (signed URL, expires in ~1 hour — fetch immediately).
echo "Downloading CSV..." >&2
if [[ -n "$OUT" ]]; then
  curl -sS -o "$OUT" "$DOWNLOAD_URL"
  echo "Wrote $OUT" >&2
else
  curl -sS "$DOWNLOAD_URL"
fi
