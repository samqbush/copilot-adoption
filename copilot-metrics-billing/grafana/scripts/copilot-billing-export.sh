#!/bin/bash
# copilot-billing-export.sh
# Guide: https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-grafana.md
# SYNCHRONIZED COPY: scripts/ and grafana/scripts/ hold identical copies of this
# file except the Guide line above. Update both together.
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
#   --last-28-days       Shortcut for the last 28 complete days (start = today-28,
#                        end = yesterday, UTC). Handy for a manual "view last
#                        month" pull / credential check. Mutually exclusive with
#                        --start/--end.
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

ENTERPRISE="${1:?Usage: $0 <enterprise> [--start YYYY-MM-DD] [--end YYYY-MM-DD] [--last-28-days] [--report-type ai_credit] [--out PATH] [--poll-timeout SECS]}"
shift

START=""
END=""
LAST_28=""
REPORT_TYPE="ai_credit"
OUT=""
POLL_TIMEOUT=300

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START="$2"; shift 2 ;;
    --end) END="$2"; shift 2 ;;
    --last-28-days) LAST_28="1"; shift ;;
    --report-type) REPORT_TYPE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --poll-timeout) POLL_TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -n "$LAST_28" && ( -n "$START" || -n "$END" ) ]]; then
  echo "ERROR: --last-28-days cannot be combined with --start/--end." >&2
  exit 1
fi

if [[ -n "$LAST_28" ]]; then
  START=$(date -u -v-28d +%Y-%m-%d 2>/dev/null || date -u -d "28 days ago" +%Y-%m-%d)
  END=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
else
  YESTERDAY=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
  START="${START:-$YESTERDAY}"
  END="${END:-$YESTERDAY}"
fi

# Validate date format and ordering.
for d in "$START" "$END"; do
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "ERROR: invalid date '$d' (expected YYYY-MM-DD)." >&2; exit 1; }
done
if [[ "$START" > "$END" ]]; then
  echo "ERROR: start date ($START) is after end date ($END)." >&2
  exit 1
fi

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
#    The payload is built with jq so quotes/odd characters in the inputs can't
#    break the JSON or inject extra fields.
echo "Creating $REPORT_TYPE billing report for $ENTERPRISE ($START -> $END)..." >&2
PAYLOAD=$(jq -n \
  --arg report_type "$REPORT_TYPE" \
  --arg start_date "$START" \
  --arg end_date "$END" \
  '{report_type: $report_type, start_date: $start_date, end_date: $end_date}')
CREATE=$(api -X POST "$BASE" -H "Content-Type: application/json" -d "$PAYLOAD")

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
  # A completed report with no download URL means there was no billing activity
  # in the range — a valid empty result, not an error. Emit an empty file/output
  # and exit 0 so callers (e.g. a backfill) don't treat "no data" as a failure.
  echo "Report completed with no data (no billing activity in $START -> $END)." >&2
  if [[ -n "$OUT" ]]; then
    : > "$OUT"
    echo "Wrote empty $OUT" >&2
  fi
  exit 0
fi

# 3. Download the CSV (signed URL, expires in ~1 hour — fetch immediately).
echo "Downloading CSV..." >&2
if [[ -n "$OUT" ]]; then
  curl -sS -o "$OUT" "$DOWNLOAD_URL"
  echo "Wrote $OUT" >&2
else
  curl -sS "$DOWNLOAD_URL"
fi
