#!/bin/bash
# ai-leverage-daily.sh
# Daily job: calculates AI leverage and AI rejection rate for an org on GHEC.
# Adapted from the GHES runbook for use with api.github.com.
#
# Usage: ./ai-leverage-daily.sh <org> [options]
#
# Options:
#   --since ISO8601          Only check PRs closed after this timestamp (default: 24h ago)
#   --app-id ID              GitHub App ID (enables App auth)
#   --installation-id ID     GitHub App Installation ID
#   --private-key PATH       Path to GitHub App private key (.pem)
#
# Auth priority:
#   1. GitHub App (if --app-id, --installation-id, --private-key all provided)
#   2. GH_TOKEN env var
#   3. `gh auth token` fallback
#
# Output: JSON report to stdout. Progress/debug to stderr.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ORG="${1:?Usage: $0 <org> [--since ISO8601] [--app-id ID --installation-id ID --private-key PATH]}"
shift

# Parse optional flags
SINCE=""
APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Default: last 24 hours
if [[ -z "$SINCE" ]]; then
  SINCE=$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%dT%H:%M:%SZ)
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
elif [[ -n "$APP_ID" || -n "$INSTALLATION_ID" || -n "$PRIVATE_KEY" ]]; then
  echo "ERROR: GitHub App auth requires all three: --app-id, --installation-id, --private-key" >&2
  exit 1
else
  TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}"
  if [[ -z "$TOKEN" ]]; then
    echo "ERROR: No GH_TOKEN env var and 'gh auth token' failed." >&2
    echo "  Provide --app-id, --installation-id, --private-key for GitHub App auth," >&2
    echo "  or set GH_TOKEN, or authenticate with 'gh auth login'." >&2
    exit 1
  fi
fi

API="https://api.github.com"
AUTH="Authorization: token ${TOKEN}"
ACCEPT="Accept: application/vnd.github+json"

# Counters (NOT in subshells — we use process substitution to avoid pipe+while bug)
TOTAL_MERGED=0
TOTAL_CLOSED=0
AI_MERGED=0
AI_CLOSED=0

echo "Scanning org: $ORG (PRs closed since $SINCE)" >&2

# Check if any commit in a PR has an AI co-author trailer
pr_has_ai() {
  local repo="$1" pr_num="$2"
  local messages
  messages=$(curl -s -H "$AUTH" -H "$ACCEPT" \
    "$API/repos/$repo/pulls/$pr_num/commits?per_page=100" | \
    jq -r '[.[].commit.message] | join("\n")' 2>/dev/null)
  # Match Copilot CLI, VS Code Copilot, and Claude Code trailers
  echo "$messages" | grep -qiE "co-authored-by:.*(copilot|claude)" && return 0 || return 1
}

# Use Search API to find closed PRs directly (instead of iterating all repos).
# This reduces ~4,100 API calls to ~10-20 for a typical daily scan.
# Search API rate limit: 30 req/min, max 1,000 results per query.
SINCE_DATE=$(echo "$SINCE" | cut -dT -f1)

search_closed_prs() {
  local page=1
  while true; do
    local body
    body=$(curl -s -H "$AUTH" -H "$ACCEPT" \
      "$API/search/issues?q=org:${ORG}+is:pr+is:closed+closed:>=${SINCE_DATE}&per_page=100&page=${page}")
    local items
    items=$(echo "$body" | jq -c '.items[]?' 2>/dev/null)
    if [[ -z "$items" ]]; then
      break
    fi
    echo "$items"
    local count
    count=$(echo "$body" | jq '.items | length' 2>/dev/null)
    if [[ "$count" -lt 100 ]]; then
      break
    fi
    ((page++))
    sleep 2  # Search API: 30 req/min
  done
}

echo "Searching for closed PRs via Search API..." >&2
SEARCH_RESULTS=$(search_closed_prs)
PR_COUNT=$(echo "$SEARCH_RESULTS" | grep -c '^' 2>/dev/null || echo "0")
echo "Found $PR_COUNT closed PRs since $SINCE_DATE." >&2

PR_IDX=0
while IFS= read -r ITEM; do
  [[ -z "$ITEM" ]] && continue
  ((PR_IDX++))

  PR_URL=$(echo "$ITEM" | jq -r '.pull_request.url // empty')
  [[ -z "$PR_URL" ]] && continue

  # Extract repo and PR number from the API URL
  REPO=$(echo "$PR_URL" | sed 's|.*/repos/\(.*\)/pulls/.*|\1|')
  PR_NUM=$(echo "$PR_URL" | sed 's|.*/pulls/||')

  # Fetch full PR details to check merged_at (search results don't include it)
  PR_DETAIL=$(curl -s -H "$AUTH" -H "$ACCEPT" "$PR_URL")
  MERGED_AT=$(echo "$PR_DETAIL" | jq -r '.merged_at // "null"')
  CLOSED_AT=$(echo "$PR_DETAIL" | jq -r '.closed_at // "null"')

  # Skip if closed before our exact timestamp (search uses date granularity, not timestamp)
  if [[ "$CLOSED_AT" < "$SINCE" ]]; then
    continue
  fi

  if [[ "$MERGED_AT" != "null" ]]; then
    ((TOTAL_MERGED++)) || true
    if pr_has_ai "$REPO" "$PR_NUM"; then
      ((AI_MERGED++)) || true
      echo "  [$PR_IDX/$PR_COUNT] ✓ $REPO#$PR_NUM — AI-attributed MERGE" >&2
    else
      echo "  [$PR_IDX/$PR_COUNT]   $REPO#$PR_NUM — merged" >&2
    fi
  else
    ((TOTAL_CLOSED++)) || true
    if pr_has_ai "$REPO" "$PR_NUM"; then
      ((AI_CLOSED++)) || true
      echo "  [$PR_IDX/$PR_COUNT] ✗ $REPO#$PR_NUM — AI-attributed CLOSE" >&2
    else
      echo "  [$PR_IDX/$PR_COUNT]   $REPO#$PR_NUM — closed (no merge)" >&2
    fi
  fi
  sleep 0.2
done <<< "$SEARCH_RESULTS"

echo "" >&2
echo "Scan complete." >&2
echo "  Merged PRs: $TOTAL_MERGED (AI: $AI_MERGED)" >&2
echo "  Closed (no merge): $TOTAL_CLOSED (AI: $AI_CLOSED)" >&2

# Calculate percentages (using awk to avoid bc dependency)
AI_LEVERAGE=$(awk "BEGIN { if ($TOTAL_MERGED > 0) printf \"%.1f\", $AI_MERGED * 100.0 / $TOTAL_MERGED; else print \"0.0\" }")
AI_TOTAL=$((AI_MERGED + AI_CLOSED))
AI_REJECTION=$(awk "BEGIN { if ($AI_TOTAL > 0) printf \"%.1f\", $AI_CLOSED * 100.0 / $AI_TOTAL; else print \"0.0\" }")

# Output JSON report to stdout
cat <<EOF
{
  "date": "$(date -u +%Y-%m-%d)",
  "org": "$ORG",
  "since": "$SINCE",
  "prs_checked": $PR_COUNT,
  "total_merged_prs": $TOTAL_MERGED,
  "ai_attributed_merged": $AI_MERGED,
  "ai_leverage_pct": $AI_LEVERAGE,
  "total_closed_without_merge": $TOTAL_CLOSED,
  "ai_attributed_closed": $AI_CLOSED,
  "ai_rejection_rate_pct": $AI_REJECTION
}
EOF
