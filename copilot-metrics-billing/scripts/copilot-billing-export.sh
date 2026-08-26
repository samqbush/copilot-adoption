#!/bin/bash
# copilot-billing-export.sh
# Guide: https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-billing.md
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
# Auth: Enterprise GitHub App installation token with "Enterprise billing: read"
#       (recommended), or a classic PAT with `manage_billing:enterprise`.
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
#   --app-id ID          GitHub App ID (enables App auth).
#   --installation-id ID GitHub App installation ID.
#   --private-key PATH   Path to GitHub App private key (.pem).
#
# Auth priority:
#   1. GitHub App (if --app-id, --installation-id, --private-key all provided)
#   2. GH_BILLING_TOKEN env var (classic PAT compatibility)
#   3. GH_TOKEN env var
#   4. `gh auth token` fallback
#
# Output: CSV to stdout (or --out). Progress/debug to stderr.

set -euo pipefail

API_VERSION="2026-03-10"

ENTERPRISE="${1:?Usage: $0 <enterprise> [--start YYYY-MM-DD] [--end YYYY-MM-DD] [--last-28-days] [--report-type ai_credit] [--out PATH] [--poll-timeout SECS] [--app-id ID --installation-id ID --private-key PATH]}"
shift

START=""
END=""
LAST_28=""
REPORT_TYPE="ai_credit"
OUT=""
POLL_TIMEOUT=300
APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start) START="$2"; shift 2 ;;
    --end) END="$2"; shift 2 ;;
    --last-28-days) LAST_28="1"; shift ;;
    --report-type) REPORT_TYPE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --poll-timeout) POLL_TIMEOUT="$2"; shift 2 ;;
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

APP_ARG_COUNT=0
[[ -n "$APP_ID" ]] && APP_ARG_COUNT=$((APP_ARG_COUNT + 1))
[[ -n "$INSTALLATION_ID" ]] && APP_ARG_COUNT=$((APP_ARG_COUNT + 1))
[[ -n "$PRIVATE_KEY" ]] && APP_ARG_COUNT=$((APP_ARG_COUNT + 1))
if (( APP_ARG_COUNT > 0 && APP_ARG_COUNT < 3 )); then
  echo "ERROR: App auth requires --app-id, --installation-id, and --private-key together." >&2
  exit 1
fi

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

# Mints a short-lived (1-hour) GitHub App installation token from the private
# key. The function is inlined so this script remains a self-contained download.
generate_installation_token() {
  local app_id="$1" installation_id="$2" key_path="$3"
  if [[ ! -f "$key_path" ]]; then
    echo "ERROR: Private key not found: $key_path" >&2
    return 1
  fi

  local now iat exp header payload signature jwt response token
  now=$(date +%s); iat=$((now - 60)); exp=$((now + 600))

  b64url() { openssl base64 -e -A | tr '+/' '-_' | tr -d '='; }

  header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$app_id" | b64url)
  signature=$(printf '%s.%s' "$header" "$payload" \
    | openssl dgst -sha256 -sign "$key_path" -binary | b64url)
  jwt="${header}.${payload}.${signature}"

  response=$(curl -sS -X POST \
    -H "Authorization: Bearer $jwt" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/$installation_id/access_tokens")
  token=$(echo "$response" | jq -r '.token // empty')
  if [[ -z "$token" ]]; then
    echo "ERROR: Failed to get installation token. Response: $response" >&2
    return 1
  fi
  printf '%s' "$token"
}

if (( APP_ARG_COUNT == 3 )); then
  echo "Authenticating via GitHub App (App ID: $APP_ID)..." >&2
  TOKEN=$(generate_installation_token "$APP_ID" "$INSTALLATION_ID" "$PRIVATE_KEY") || exit 1
  echo "Installation token acquired (expires in 1 hour)." >&2
elif [[ -n "${GH_BILLING_TOKEN:-}" ]]; then
  TOKEN="$GH_BILLING_TOKEN"
elif [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="$GH_TOKEN"
else
  TOKEN=$(gh auth token 2>/dev/null || true)
fi

if [[ -z "${TOKEN:-}" ]]; then
  echo "ERROR: No auth token. Pass App credentials, set GH_BILLING_TOKEN/GH_TOKEN, or run 'gh auth login'." >&2
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
  echo "  (A 409 means another export is already running. An App needs 'Enterprise billing: read' and approval of the updated installation; a classic PAT needs manage_billing:enterprise.)" >&2
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
