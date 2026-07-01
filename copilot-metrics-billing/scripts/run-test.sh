#!/bin/bash
# run-test.sh
# One-command, repeatable local test of the Copilot metrics + billing collection.
# Loads credentials from an uncommitted secrets file (.secrets/config) and runs
# collect-daily.sh for both usage metrics (GitHub App) and billing (classic PAT).
#
# Quick start:
#   cp config.example .secrets/config       # then fill in real values
#   mv ~/Downloads/your-app.*.pem .secrets/app.pem && chmod 600 .secrets/app.pem
#   ./scripts/run-test.sh                    # collects yesterday into .secrets/output
#
# Usage: ./scripts/run-test.sh [options] [-- collect-daily passthrough flags]
#
# Options:
#   --config PATH   Secrets file to load (default: .secrets/config, or
#                   $COPILOT_METRICS_CONFIG).
#   --out-dir DIR   Output directory (default: .secrets/output).
#   -h, --help      Show this help.
#
# Any other flags are passed straight through to collect-daily.sh, e.g.:
#   ./scripts/run-test.sh --day 2026-06-21
#   ./scripts/run-test.sh --skip-billing
#   ./scripts/run-test.sh --org octodemo --skip-billing
#
# The secrets file (.secrets/config) defines:
#   ENTERPRISE, APP_ID, INSTALLATION_ID, PRIVATE_KEY, GH_BILLING_TOKEN
# See config.example for the format.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="${COPILOT_METRICS_CONFIG:-$ROOT_DIR/.secrets/config}"
OUT_DIR=""
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; PASSTHROUGH+=("$@"); break ;;
    *) PASSTHROUGH+=("$1"); shift ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }

# --- Load secrets ----------------------------------------------------------
if [[ ! -f "$CONFIG" ]]; then
  die "Secrets file not found: $CONFIG
  Create it from the template:
    cp \"$ROOT_DIR/config.example\" \"$ROOT_DIR/.secrets/config\"
  then fill in your real values."
fi

# shellcheck disable=SC1090
set -a; source "$CONFIG"; set +a

# --- Validate tools --------------------------------------------------------
for tool in curl jq openssl; do
  command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool"
done

# --- Validate required values ---------------------------------------------
: "${ENTERPRISE:?ENTERPRISE is not set in $CONFIG}"
: "${APP_ID:?APP_ID is not set in $CONFIG}"
: "${INSTALLATION_ID:?INSTALLATION_ID is not set in $CONFIG}"
: "${PRIVATE_KEY:?PRIVATE_KEY is not set in $CONFIG}"
: "${GH_BILLING_TOKEN:?GH_BILLING_TOKEN is not set in $CONFIG}"
export GH_BILLING_TOKEN

# Resolve PRIVATE_KEY relative to the copilot-metrics-billing/ dir if needed.
case "$PRIVATE_KEY" in
  /*) ;;                                   # absolute, leave as-is
  ~*) PRIVATE_KEY="${PRIVATE_KEY/#\~/$HOME}" ;;
  *)  PRIVATE_KEY="$ROOT_DIR/$PRIVATE_KEY" ;;
esac
[[ -f "$PRIVATE_KEY" ]] || die "Private key not found: $PRIVATE_KEY
  Place your GitHub App .pem there (e.g. $ROOT_DIR/.secrets/app.pem)."

OUT_DIR="${OUT_DIR:-$ROOT_DIR/.secrets/output}"
mkdir -p "$OUT_DIR"

echo "Testing Copilot collection for enterprise '$ENTERPRISE'" >&2
echo "  config:  $CONFIG" >&2
echo "  out-dir: $OUT_DIR" >&2

exec "$SCRIPT_DIR/collect-daily.sh" "$ENTERPRISE" \
  --out-dir "$OUT_DIR" \
  --app-id "$APP_ID" \
  --installation-id "$INSTALLATION_ID" \
  --private-key "$PRIVATE_KEY" \
  ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
