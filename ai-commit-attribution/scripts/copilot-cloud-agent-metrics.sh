#!/bin/bash
# copilot-cloud-agent-metrics.sh
# Fetches metrics for Copilot coding agent and Copilot code review from the GHEC Metrics API.
# Use this when measuring Copilot platform features (coding agent PRs, code review).
# For IDE completions and CLI co-authorship, use ai-leverage-daily.sh instead.
#
# Usage:
#   ./scripts/copilot-cloud-agent-metrics.sh <org> [options]
#
# Options:
#   --day YYYY-MM-DD         Fetch metrics for a specific day (default: yesterday)
#   --days N                 Fetch the last N days (default: 1)
#   --28day                  Fetch the rolling 28-day report instead
#   --enterprise <slug>      Query enterprise-level instead of org-level
#   --app-id ID              GitHub App ID (enables App auth)
#   --installation-id ID     GitHub App Installation ID
#   --private-key PATH       Path to GitHub App private key (.pem)
#
# Output: JSON report to stdout with PR metrics from the Copilot Metrics API.
#
# Required permissions: org admin or "Copilot usage metrics" access
# Docs: https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ORG="${1:?Usage: $0 <org> [--day YYYY-MM-DD] [--days N] [--28day] [--enterprise slug]}"
shift

# Parse options
DAY=""
DAYS=1
USE_28DAY=false
ENTERPRISE=""
APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --day) DAY="$2"; DAYS=1; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --28day) USE_28DAY=true; shift ;;
    --enterprise) ENTERPRISE="$2"; shift 2 ;;
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Auth setup (same pattern as ai-leverage-daily.sh)
if [[ -n "$APP_ID" && -n "$INSTALLATION_ID" && -n "$PRIVATE_KEY" ]]; then
  echo "Authenticating via GitHub App (App ID: $APP_ID)..." >&2
  TOKEN=$("$SCRIPT_DIR/generate-installation-token.sh" \
    --app-id "$APP_ID" \
    --installation-id "$INSTALLATION_ID" \
    --private-key "$PRIVATE_KEY")
elif [[ -n "$APP_ID" || -n "$INSTALLATION_ID" || -n "$PRIVATE_KEY" ]]; then
  echo "ERROR: GitHub App auth requires all three: --app-id, --installation-id, --private-key" >&2
  exit 1
else
  TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}"
fi

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: No auth token available." >&2
  exit 1
fi

AUTH="Authorization: token ${TOKEN}"
ACCEPT="Accept: application/vnd.github+json"

# Determine API base path
if [[ -n "$ENTERPRISE" ]]; then
  API_BASE="https://api.github.com/enterprises/$ENTERPRISE/copilot/metrics/reports"
  ENTITY_LABEL="enterprise"
  ENTITY_NAME="$ENTERPRISE"
else
  API_BASE="https://api.github.com/orgs/$ORG/copilot/metrics/reports"
  ENTITY_LABEL="org"
  ENTITY_NAME="$ORG"
fi

# Fetch NDJSON report from a download link endpoint
fetch_ndjson() {
  local endpoint="$1"
  local response
  response=$(curl -s -H "$AUTH" -H "$ACCEPT" "$endpoint")
  local url
  url=$(echo "$response" | jq -r '.download_links[0] // empty')
  if [[ -z "$url" ]]; then
    local msg
    msg=$(echo "$response" | jq -r '.message // empty')
    echo "ERROR: No download link from $endpoint" >&2
    [[ -n "$msg" ]] && echo "  API said: $msg" >&2
    echo "  Check that Copilot usage metrics are enabled for $ENTITY_NAME" >&2
    return 1
  fi
  curl -s "$url"
}

if $USE_28DAY; then
  echo "Fetching 28-day rolling report for $ENTITY_LABEL: $ENTITY_NAME..." >&2
  if [[ -n "$ENTERPRISE" ]]; then
    ENDPOINT="$API_BASE/enterprise-28-day/latest"
  else
    ENDPOINT="$API_BASE/organization-28-day/latest"
  fi

  REPORT=$(fetch_ndjson "$ENDPOINT") || exit 1

  # Extract all days' PR metrics and compute aggregates
  echo "$REPORT" | head -1 | jq --arg entity "$ENTITY_NAME" --arg entity_type "$ENTITY_LABEL" '
    .day_totals as $days |
    {
      report_type: "28-day rolling",
      ($entity_type): $entity,
      report_start: .report_start_day,
      report_end: .report_end_day,
      days_with_data: ($days | length),

      # Aggregate PR metrics
      total_merged_prs: ($days | map(.pull_requests.total_merged // 0) | add),
      total_merged_created_by_copilot: ($days | map(.pull_requests.total_merged_created_by_copilot // 0) | add),
      total_merged_reviewed_by_copilot: ($days | map(.pull_requests.total_merged_reviewed_by_copilot // 0) | add),
      total_prs_created: ($days | map(.pull_requests.total_created // 0) | add),
      total_prs_created_by_copilot: ($days | map(.pull_requests.total_created_by_copilot // 0) | add),
      total_prs_reviewed_by_copilot: ($days | map(.pull_requests.total_reviewed_by_copilot // 0) | add),

      # AI leverage %
      ai_leverage_pct: (
        ($days | map(.pull_requests.total_merged // 0) | add) as $merged |
        ($days | map(.pull_requests.total_merged_created_by_copilot // 0) | add) as $ai_merged |
        if $merged > 0 then ($ai_merged * 100.0 / $merged | . * 10 | round / 10)
        else 0 end
      ),

      # Median time to merge (average of daily medians where available)
      median_minutes_to_merge: (
        [$days[].pull_requests | select(.median_minutes_to_merge != null) | .median_minutes_to_merge] |
        if length > 0 then (add / length | . * 100 | round / 100) else null end
      ),
      median_minutes_to_merge_copilot_authored: (
        [$days[].pull_requests | select(.median_minutes_to_merge_copilot_authored != null) | .median_minutes_to_merge_copilot_authored] |
        if length > 0 then (add / length | . * 100 | round / 100) else null end
      ),

      # Code review suggestions
      total_copilot_review_suggestions: ($days | map(.pull_requests.total_copilot_suggestions // 0) | add),
      total_copilot_applied_suggestions: ($days | map(.pull_requests.total_copilot_applied_suggestions // 0) | add),

      # Activity
      avg_daily_active_users: ($days | map(.daily_active_users // 0) | add / length | round)
    }'

else
  # Single-day or multi-day mode
  if [[ -z "$DAY" ]]; then
    DAY=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
  fi

  echo "Fetching daily report(s) for $ENTITY_LABEL: $ENTITY_NAME (starting $DAY, $DAYS day(s))..." >&2

  RESULTS="["
  SEP=""
  for ((i = 0; i < DAYS; i++)); do
    QUERY_DAY=$(date -u -v-${i}d -j -f "%Y-%m-%d" "$DAY" +%Y-%m-%d 2>/dev/null || \
                date -u -d "$DAY - $i days" +%Y-%m-%d)

    if [[ -n "$ENTERPRISE" ]]; then
      ENDPOINT="$API_BASE/enterprise-1-day?day=$QUERY_DAY"
    else
      ENDPOINT="$API_BASE/organization-1-day?day=$QUERY_DAY"
    fi

    REPORT=$(fetch_ndjson "$ENDPOINT" 2>/dev/null) || { echo "  Skipping $QUERY_DAY (no data)" >&2; continue; }

    DAY_DATA=$(echo "$REPORT" | head -1 | jq --arg day "$QUERY_DAY" '{
      day: $day,
      daily_active_users: (.daily_active_users // 0),
      pull_requests: {
        total_merged: (.pull_requests.total_merged // 0),
        total_merged_created_by_copilot: (.pull_requests.total_merged_created_by_copilot // 0),
        total_merged_reviewed_by_copilot: (.pull_requests.total_merged_reviewed_by_copilot // 0),
        total_created: (.pull_requests.total_created // 0),
        total_created_by_copilot: (.pull_requests.total_created_by_copilot // 0),
        total_reviewed_by_copilot: (.pull_requests.total_reviewed_by_copilot // 0),
        median_minutes_to_merge: (.pull_requests.median_minutes_to_merge // null),
        median_minutes_to_merge_copilot_authored: (.pull_requests.median_minutes_to_merge_copilot_authored // null),
        total_copilot_suggestions: (.pull_requests.total_copilot_suggestions // 0),
        total_copilot_applied_suggestions: (.pull_requests.total_copilot_applied_suggestions // 0),
        ai_leverage_pct: (
          if (.pull_requests.total_merged // 0) > 0
          then ((.pull_requests.total_merged_created_by_copilot // 0) * 100.0 / .pull_requests.total_merged | . * 10 | round / 10)
          else 0 end
        )
      }
    }')

    RESULTS="${RESULTS}${SEP}${DAY_DATA}"
    SEP=","
    echo "  $QUERY_DAY — fetched" >&2
  done
  RESULTS="${RESULTS}]"

  echo "$RESULTS" | jq --arg entity "$ENTITY_NAME" --arg entity_type "$ENTITY_LABEL" '{
    report_type: "daily",
    ($entity_type): $entity,
    days: .
  }'
fi
