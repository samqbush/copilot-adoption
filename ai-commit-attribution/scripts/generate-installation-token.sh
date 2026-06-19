#!/bin/bash
# generate-installation-token.sh
# Generates a GitHub App installation token from a private key.
# Uses only openssl (pre-installed on macOS/Linux) — no extra dependencies.
#
# Usage:
#   ./generate-installation-token.sh --app-id 12345 --installation-id 67890 --private-key path/to/key.pem
#
# Output: Installation token to stdout (use as GH_TOKEN)

set -euo pipefail

# Parse arguments
APP_ID=""
INSTALLATION_ID=""
PRIVATE_KEY_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-id) APP_ID="$2"; shift 2 ;;
    --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
    --private-key) PRIVATE_KEY_PATH="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; echo "Usage: $0 --app-id ID --installation-id ID --private-key PATH" >&2; exit 1 ;;
  esac
done

if [[ -z "$APP_ID" || -z "$INSTALLATION_ID" || -z "$PRIVATE_KEY_PATH" ]]; then
  echo "ERROR: --app-id, --installation-id, and --private-key are all required." >&2
  exit 1
fi

if [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
  echo "ERROR: Private key not found: $PRIVATE_KEY_PATH" >&2
  exit 1
fi

# --- Generate JWT ---
# GitHub App JWTs are RS256-signed, valid for max 10 minutes.
# We set iat to 60s ago (clock skew) and exp to 10 minutes from now.

NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))

# Base64url encode (no padding, URL-safe)
b64url() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# JWT Header
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)

# JWT Payload
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | b64url)

# Sign
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | \
  openssl dgst -sha256 -sign "$PRIVATE_KEY_PATH" -binary | b64url)

JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# --- Exchange JWT for Installation Token ---
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Failed to get installation token." >&2
  echo "Response: $RESPONSE" >&2
  exit 1
fi

echo "$TOKEN"
