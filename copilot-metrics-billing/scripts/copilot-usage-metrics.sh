#!/bin/bash
# copilot-usage-metrics.sh
# Daily job: pulls the pre-aggregated Copilot USAGE metrics report (engagement
# data — active users, completions, chat, etc.) for an enterprise or org and
# writes it as JSON to stdout. Usage metrics contain NO billing amounts.
#
# It calls the "report" endpoint, which returns short-lived download_links to an
# NDJSON file, then downloads and emits that file. ~2 API calls per run.
#
# Usage: ./copilot-usage-metrics.sh <enterprise> [options]
#        ./copilot-usage-metrics.sh <org> --org [options]
#
# Options:
#   --org                    Treat the slug as an ORG (organization-1-day) instead
#                            of an enterprise (enterprise-1-day, the default).
#   --day YYYY-MM-DD         Day to pull (default: yesterday, UTC).
#   --28day                  Pull the 28-day rolling report instead of a single day.
#                            NOT needed for the daily archive job: once you're
#                            storing the single-day files you can rebuild any
#                            window yourself. Use it only for an ad-hoc rolling
#                            snapshot or an initial backfill.
#   --app-id ID              GitHub App ID (enables App auth — enterprise App with
#                            the "View Enterprise Copilot Metrics" permission).
#   --installation-id ID     GitHub App Installation ID.
#   --private-key PATH       Path to GitHub App private key (.pem).
#
# Auth priority:
#   1. GitHub App (if --app-id, --installation-id, --private-key all provided)
#   2. GH_TOKEN env var (classic PAT needs manage_billing:copilot or read:enterprise)
#   3. `gh auth token` fallback
#
# Output: JSON (the downloaded report, wrapped with request metadata) to stdout.
#         Progress/debug to stderr.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_VERSION="2026-03-10"

SLUG="${1:?Usage: $0 <enterprise|org> [--org] [--day YYYY-MM-DD] [--28day] [--app-id ID --installation-id ID --private-key PATH]}"
shift

# Parse optional flags
SCOPE="enterprise"
DAY=""
ROLLING=""
APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) SCOPE="org"; shift ;;
    --day) DAY="$2"; shift 2 ;;
    --28day) ROLLING="1"; shift ;;
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Default day: yesterday (UTC) — the most recent complete day.
if [[ -z "$DAY" ]]; then
  DAY=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
fi

# Auth setup
if [[ -n "$APP_ID" && -n "$INSTALLATION_ID" && -n "$PRIVATE_KEY" ]]; then
  echo "Authenticating via GitHub App (App ID: $APP_ID)..." >&2
  TOKEN=$("$SCRIPT_DIR/generate-installation-token.sh" \
    --app-id "$APP_ID" \
    --installation-id "$INSTALLATION_ID" \
    --private-key "$PRIVATE_KEY")
  if [[ -z "$TOKEN" ]]; then
    echo "ERROR: Failed to generate installation token." >&2
    exit 1
  fi
  echo "Installation token acquired (expires in 1 hour)." >&2
elif [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="$GH_TOKEN"
else
  TOKEN=$(gh auth token 2>/dev/null || true)
fi

if [[ -z "${TOKEN:-}" ]]; then
  echo "ERROR: No auth token. Set GH_TOKEN, run 'gh auth login', or pass App credentials." >&2
  exit 1
fi

# Build the report endpoint URL
if [[ "$SCOPE" == "org" ]]; then
  if [[ -n "$ROLLING" ]]; then
    REPORT_PATH="/orgs/$SLUG/copilot/metrics/reports/organization-28-day/latest"
  else
    REPORT_PATH="/orgs/$SLUG/copilot/metrics/reports/organization-1-day?day=$DAY"
  fi
else
  if [[ -n "$ROLLING" ]]; then
    REPORT_PATH="/enterprises/$SLUG/copilot/metrics/reports/enterprise-28-day/latest"
  else
    REPORT_PATH="/enterprises/$SLUG/copilot/metrics/reports/enterprise-1-day?day=$DAY"
  fi
fi

echo "Requesting usage metrics report: $REPORT_PATH" >&2

api() {
  curl -sS -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: $API_VERSION" \
    "$@"
}

RESPONSE=$(api "https://api.github.com${REPORT_PATH}")

# Surface API errors clearly
if echo "$RESPONSE" | jq -e '.message? // empty' >/dev/null 2>&1; then
  echo "ERROR: API returned: $(echo "$RESPONSE" | jq -r '.message')" >&2
  echo "  (Check the 'Copilot usage metrics' policy is enabled and the token has the right permission.)" >&2
  exit 1
fi

# Pull the first download link (signed, short-lived) and fetch the NDJSON report.
LINK=$(echo "$RESPONSE" | jq -r '.download_links[0] // empty')
if [[ -z "$LINK" ]]; then
  echo "ERROR: No download_links in response: $RESPONSE" >&2
  exit 1
fi

echo "Downloading and assembling report file..." >&2

# Emit a single JSON object: request metadata + the report rows as an array.
# We stream the download straight into jq (no intermediate shell variable) so
# large reports aren't held in memory twice and the raw bytes aren't reinterpreted
# by echo. NDJSON rows are slurped into .report; empty lines are ignored.
jq -n \
  --arg scope "$SCOPE" \
  --arg slug "$SLUG" \
  --arg day "$DAY" \
  --argjson rolling "$([[ -n "$ROLLING" ]] && echo true || echo false)" \
  --argjson meta "$(echo "$RESPONSE" | jq '{report_day, report_start_day, report_end_day}')" \
  --slurpfile rows <(curl -sS "$LINK" | jq -c 'select(length>0)') \
  '{scope: $scope, slug: $slug, day: $day, rolling: $rolling, report_meta: $meta, report: $rows}'
