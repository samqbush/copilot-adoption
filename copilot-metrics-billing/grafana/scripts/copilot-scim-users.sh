#!/bin/bash
# copilot-scim-users.sh
# Guide: https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-grafana.md
# Grafana add-on only: this script has no base-guide counterpart.
# Snapshot job: reads enterprise members' primary EMAIL addresses from the SCIM
# API and writes them as JSON to stdout. This is the identity-enrichment half of
# the pipeline: the billing CSV keys per-user rows by GitHub USERNAME, and this
# script provides the username -> email mapping so the Grafana dashboards can
# display emails instead of usernames.
#
# Endpoint: GET /scim/v2/enterprises/{enterprise}/Users  (paginated)
#
# Auth: an Enterprise App installation token with the "Enterprise SCIM: read"
#       permission (recommended, least-privilege, auditable), OR a classic PAT
#       with `admin:enterprise` owned by an enterprise owner. Fine-grained PATs
#       do NOT work with SCIM. This script REUSES the existing Copilot metrics
#       App (grant it Enterprise SCIM: read and install it at enterprise scope).
#
# Usage: ./copilot-scim-users.sh <enterprise> [options]
#
# Options:
#   --app-id ID            GitHub App ID (enables App auth).
#   --installation-id ID   GitHub App Installation ID.
#   --private-key PATH     Path to GitHub App private key (.pem).
#   --page-size N          SCIM page size (default: 100, GitHub max).
#   --out PATH             Write JSON to PATH instead of stdout.
#
# Auth priority:
#   1. GitHub App (if --app-id, --installation-id, --private-key all provided)
#   2. GH_TOKEN env var (classic PAT with admin:enterprise, enterprise owner)
#   3. `gh auth token` fallback
#
# Output: a single JSON object to stdout (or --out):
#   { "enterprise": "...", "generated_at": "...", "users": [
#       { "username": "...", "email": "...", "external_id": "...",
#         "display_name": "...", "active": true, "scim_user_name": "..." }, ... ] }
#   Progress/debug goes to stderr.

set -euo pipefail

API_VERSION="2026-03-10"

ENTERPRISE="${1:?Usage: $0 <enterprise> [--app-id ID --installation-id ID --private-key PATH] [--page-size N] [--out PATH]}"
shift

APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY=""
PAGE_SIZE=100
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY="$2"; shift 2 ;;
    --page-size) PAGE_SIZE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ ! "$PAGE_SIZE" =~ ^[0-9]+$ ]] || (( PAGE_SIZE < 1 )); then
  echo "ERROR: --page-size must be a positive integer." >&2
  exit 1
fi

# Mints a short-lived (1-hour) GitHub App installation token from the private
# key (RS256-signed JWT valid ~10 min, exchanged for an installation token).
# Kept in sync with copilot-usage-metrics.sh so this script is self-contained.
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
if [[ -n "$APP_ID" && -n "$INSTALLATION_ID" && -n "$PRIVATE_KEY" ]]; then
  echo "Authenticating via GitHub App (App ID: $APP_ID)..." >&2
  TOKEN=$(generate_installation_token "$APP_ID" "$INSTALLATION_ID" "$PRIVATE_KEY") || exit 1
  echo "Installation token acquired (expires in 1 hour)." >&2
elif [[ -n "${GH_TOKEN:-}" ]]; then
  TOKEN="$GH_TOKEN"
else
  TOKEN=$(gh auth token 2>/dev/null || true)
fi

if [[ -z "${TOKEN:-}" ]]; then
  echo "ERROR: No auth token. Provide App credentials (App with 'Enterprise SCIM: read'), set GH_TOKEN (classic PAT w/ admin:enterprise, enterprise owner), or run 'gh auth login'." >&2
  exit 1
fi

api() {
  curl -sS -H "Accept: application/scim+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: $API_VERSION" \
    "$@"
}

BASE="https://api.github.com/scim/v2/enterprises/$ENTERPRISE/Users"

# Paginate: SCIM uses 1-based startIndex + count. Loop until we've fetched
# totalResults (or a short/empty page defensively ends the loop).
echo "Fetching SCIM users for $ENTERPRISE (page size $PAGE_SIZE)..." >&2
START_INDEX=1
TOTAL=""
PAGES_JSON="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/scim-pages.$$.ndjson"
: > "$PAGES_JSON"
trap 'rm -f "$PAGES_JSON"' EXIT

while :; do
  RESP=$(api "$BASE?startIndex=$START_INDEX&count=$PAGE_SIZE")

  # Surface API errors clearly. SCIM errors carry a `detail`; REST-style errors a
  # `message`. A 403 almost always means the App lacks 'Enterprise SCIM: read'
  # (or a PAT owner isn't an enterprise owner / isn't admin:enterprise).
  ERR=$(echo "$RESP" | jq -r '.detail // .message // empty' 2>/dev/null || true)
  HAS_RESOURCES=$(echo "$RESP" | jq -e 'has("Resources")' >/dev/null 2>&1 && echo yes || echo no)
  if [[ "$HAS_RESOURCES" != "yes" ]]; then
    echo "ERROR: Unexpected SCIM response: ${ERR:-$RESP}" >&2
    echo "  (A 403 usually means missing 'Enterprise SCIM: read' on the App, or the token owner is not an enterprise owner with admin:enterprise. Fine-grained PATs do NOT work with SCIM.)" >&2
    exit 1
  fi

  if [[ -z "$TOTAL" ]]; then
    TOTAL=$(echo "$RESP" | jq -r '.totalResults // 0')
    echo "SCIM reports $TOTAL total user(s)." >&2
  fi

  COUNT=$(echo "$RESP" | jq -r '.Resources | length')
  # Extract the fields we care about, one flattened record per line (NDJSON).
  echo "$RESP" | jq -c '.Resources[] | {
      username: .userName,
      email: ((.emails // []) | (map(select(.primary == true)) + .) | .[0].value // null),
      external_id: (.externalId // null),
      display_name: (.displayName // (.name.formatted // null)),
      active: (.active // null),
      scim_user_name: .userName
    }' >> "$PAGES_JSON"

  FETCHED=$(( START_INDEX - 1 + COUNT ))
  echo "  fetched $FETCHED / $TOTAL" >&2

  # Stop when we've reached the total, or a page came back short/empty.
  if (( COUNT == 0 )) || (( FETCHED >= TOTAL )); then
    break
  fi
  START_INDEX=$(( START_INDEX + PAGE_SIZE ))
done

GENERATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Assemble the final object: slurp the NDJSON records into a users array.
if [[ -n "$OUT" ]]; then
  jq -n \
    --arg enterprise "$ENTERPRISE" \
    --arg generated_at "$GENERATED" \
    --slurpfile users <(cat "$PAGES_JSON") \
    '{enterprise: $enterprise, generated_at: $generated_at, users: $users}' > "$OUT"
  echo "Wrote $OUT" >&2
else
  jq -n \
    --arg enterprise "$ENTERPRISE" \
    --arg generated_at "$GENERATED" \
    --slurpfile users <(cat "$PAGES_JSON") \
    '{enterprise: $enterprise, generated_at: $generated_at, users: $users}'
fi
