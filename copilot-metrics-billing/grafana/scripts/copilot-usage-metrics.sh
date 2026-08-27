#!/bin/bash
# copilot-usage-metrics.sh
# Guide: https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-grafana.md
# SYNCHRONIZED COPY: scripts/ and grafana/scripts/ hold identical copies of this
# file except the Guide line above. Update both together.
# Daily job: pulls the pre-aggregated Copilot USAGE metrics report (engagement
# data — active users, completions, chat, etc.) for an enterprise or org and
# writes it as JSON to stdout. Usage metrics contain NO billing amounts.
#
# It calls one report endpoint, which returns short-lived download_links to one
# or more NDJSON files, then downloads and combines every part.
#
# Usage: ./copilot-usage-metrics.sh <enterprise> [options]
#        ./copilot-usage-metrics.sh <org> --org [options]
#
# Options:
#   --org                    Treat the slug as an organization.
#   --report-type TYPE       Aggregate report (default), users, user-teams, or repos.
#   --day YYYY-MM-DD         Day to pull (default: yesterday, UTC).
#   --28day                  Pull the 28-day rolling report instead of a single day.
#                            (Alias: --last-28-days.)
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

API_VERSION="2026-03-10"

SLUG="${1:?Usage: $0 <enterprise|org> [--org] [--report-type TYPE] [--day YYYY-MM-DD] [--28day] [--app-id ID --installation-id ID --private-key PATH]}"
shift

# Parse optional flags
SCOPE="enterprise"
REPORT_TYPE="aggregate"
DAY=""
ROLLING=""
APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) SCOPE="org"; shift ;;
    --report-type) REPORT_TYPE="$2"; shift 2 ;;
    --day) DAY="$2"; shift 2 ;;
    --28day|--last-28-days) ROLLING="1"; shift ;;
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

case "$REPORT_TYPE" in
  aggregate|users|user-teams|repos) ;;
  *) echo "ERROR: --report-type must be aggregate, users, user-teams, or repos." >&2; exit 1 ;;
esac

APP_ARG_COUNT=0
[[ -n "$APP_ID" ]] && APP_ARG_COUNT=$((APP_ARG_COUNT + 1))
[[ -n "$INSTALLATION_ID" ]] && APP_ARG_COUNT=$((APP_ARG_COUNT + 1))
[[ -n "$PRIVATE_KEY" ]] && APP_ARG_COUNT=$((APP_ARG_COUNT + 1))
if (( APP_ARG_COUNT > 0 && APP_ARG_COUNT < 3 )); then
  echo "ERROR: App auth requires --app-id, --installation-id, and --private-key together." >&2
  exit 1
fi

# Default day: yesterday (UTC) — the most recent complete day.
if [[ -z "$DAY" ]]; then
  DAY=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
fi

# Mints a short-lived (1-hour) GitHub App installation token from the private
# key, inlined here so this script is self-contained — nothing else to download.
# Builds an RS256-signed JWT (valid ~10 min), then exchanges it for the token.
# Requires openssl, curl, jq.
generate_installation_token() {
  local app_id="$1" installation_id="$2" key_path="$3"
  if [[ ! -f "$key_path" ]]; then
    echo "ERROR: Private key not found: $key_path" >&2
    return 1
  fi

  local now iat exp header payload signature jwt response token
  now=$(date +%s); iat=$((now - 60)); exp=$((now + 600))

  # base64url: URL-safe alphabet, no padding.
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

# Auth setup
if (( APP_ARG_COUNT == 3 )); then
  echo "Authenticating via GitHub App (App ID: $APP_ID)..." >&2
  TOKEN=$(generate_installation_token "$APP_ID" "$INSTALLATION_ID" "$PRIVATE_KEY") || exit 1
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

# Build the report endpoint URL. Daily collection fetches every non-overlapping
# report family; the 28-day option remains limited to reports GitHub publishes.
if [[ -n "$ROLLING" ]]; then
  if [[ "$REPORT_TYPE" == "aggregate" ]]; then
    TYPE_SUFFIX=$([[ "$SCOPE" == "org" ]] && echo "organization-28-day" || echo "enterprise-28-day")
  elif [[ "$REPORT_TYPE" == "users" ]]; then
    TYPE_SUFFIX="users-28-day"
  else
    echo "ERROR: --28day is only available for aggregate and users reports." >&2
    exit 1
  fi
  BASE_PATH=$([[ "$SCOPE" == "org" ]] && echo "/orgs/$SLUG" || echo "/enterprises/$SLUG")
  REPORT_PATH="$BASE_PATH/copilot/metrics/reports/$TYPE_SUFFIX/latest"
else
  if [[ "$REPORT_TYPE" == "aggregate" ]]; then
    TYPE_SUFFIX=$([[ "$SCOPE" == "org" ]] && echo "organization-1-day" || echo "enterprise-1-day")
  else
    TYPE_SUFFIX="$REPORT_TYPE-1-day"
  fi
  BASE_PATH=$([[ "$SCOPE" == "org" ]] && echo "/orgs/$SLUG" || echo "/enterprises/$SLUG")
  REPORT_PATH="$BASE_PATH/copilot/metrics/reports/$TYPE_SUFFIX?day=$DAY"
fi

echo "Requesting usage metrics report: $REPORT_PATH" >&2

api() {
  curl -sS -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: $API_VERSION" \
    "$@"
}

RESPONSE_FILE=$(mktemp)
LINKS_FILE=$(mktemp)
REPORT_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE" "$LINKS_FILE" "$REPORT_FILE"' EXIT
HTTP_STATUS=$(api -o "$RESPONSE_FILE" -w '%{http_code}' \
  "https://api.github.com${REPORT_PATH}")
RESPONSE=$(cat "$RESPONSE_FILE")

# Some report families return 204 when there was no activity. Preserve that
# successful empty observation so downstream systems can distinguish it from a
# failed or missing collection.
if [[ "$HTTP_STATUS" == "204" ]]; then
  jq -n \
    --arg scope "$SCOPE" \
    --arg slug "$SLUG" \
    --arg report_type "$TYPE_SUFFIX" \
    --arg day "$DAY" \
    --argjson rolling "$([[ -n "$ROLLING" ]] && echo true || echo false)" \
    '{scope: $scope, slug: $slug, report_type: $report_type, day: $day, rolling: $rolling, report_meta: {http_status: 204}, report: []}'
  exit 0
fi

# Surface API errors clearly
if echo "$RESPONSE" | jq -e '.message? // empty' >/dev/null 2>&1; then
  echo "ERROR: API returned: $(echo "$RESPONSE" | jq -r '.message')" >&2
  echo "  (Check the 'Copilot usage metrics' policy is enabled and the token has the right permission.)" >&2
  exit 1
fi
if [[ ! "$HTTP_STATUS" =~ ^2[0-9][0-9]$ ]]; then
  echo "ERROR: API returned HTTP $HTTP_STATUS: $RESPONSE" >&2
  exit 1
fi

# Extract every signed download link. Large reports can be split across parts.
if ! echo "$RESPONSE" | jq -er \
    '.download_links | select(type == "array" and length > 0)[]' \
    > "$LINKS_FILE"; then
  echo "ERROR: No download_links in response: $RESPONSE" >&2
  exit 1
fi

echo "Downloading and assembling report file..." >&2

# Download first so a network/HTTP failure or malformed report cannot be hidden
# by process-substitution exit semantics.
: > "$REPORT_FILE"
PART_COUNT=0
while IFS= read -r LINK; do
  [[ -n "$LINK" ]] || continue
  curl -fLsS "$LINK" >> "$REPORT_FILE"
  printf '\n' >> "$REPORT_FILE"
  PART_COUNT=$((PART_COUNT + 1))
done < "$LINKS_FILE"

if (( PART_COUNT == 0 )) || [[ ! -s "$REPORT_FILE" ]] \
    || ! jq -e -s 'length > 0' "$REPORT_FILE" >/dev/null; then
  echo "ERROR: Downloaded usage report is not valid NDJSON." >&2
  exit 1
fi

# Emit a single JSON object: request metadata + the report rows as an array.
jq -n \
  --arg scope "$SCOPE" \
  --arg slug "$SLUG" \
  --arg report_type "$TYPE_SUFFIX" \
  --arg day "$DAY" \
  --argjson rolling "$([[ -n "$ROLLING" ]] && echo true || echo false)" \
  --argjson meta "$(echo "$RESPONSE" | jq 'del(.download_links)')" \
  --slurpfile rows "$REPORT_FILE" \
  '{scope: $scope, slug: $slug, report_type: $report_type, day: $day, rolling: $rolling, report_meta: $meta, report: $rows}'
