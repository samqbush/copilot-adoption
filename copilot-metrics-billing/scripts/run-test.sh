#!/bin/bash
# run-test.sh
# Local credential check for the Copilot metrics + billing collection. Confirms
# your two credentials work INDEPENDENTLY and, in the same run, pulls the last
# 28 days of data so you can eyeball last month's numbers by hand:
#
#   - Usage metrics  -> tests your Enterprise GitHub App (App ID + installation
#                       ID + private key) against the 28-day rolling report.
#   - Billing        -> tests your classic PAT (manage_billing:enterprise)
#                       against the last 28 days of ai_credit data.
#
# This is the "verify locally" path. For unattended daily collection into your
# own data lake, use the example GitHub Action in ../examples/ instead.
#
# Quick start:
#   cp config.example .secrets/config       # then fill in real values
#   mv ~/Downloads/your-app.*.pem .secrets/app.pem && chmod 600 .secrets/app.pem
#   ./scripts/run-test.sh                    # tests BOTH creds, writes .secrets/output
#
# Usage: ./scripts/run-test.sh [options]
#
# Options:
#   --usage-only    Only test the GitHub App / usage-metrics credential.
#   --billing-only  Only test the classic PAT / billing credential.
#   --config PATH   Secrets file to load (default: .secrets/config, or
#                   $COPILOT_METRICS_CONFIG).
#   --out-dir DIR   Output directory (default: .secrets/output).
#   -h, --help      Show this help.
#
# With no --usage-only/--billing-only flag, BOTH are tested. Each domain only
# validates the tools and credentials it actually needs, so --billing-only does
# not require the GitHub App and --usage-only does not require the billing PAT.
#
# The secrets file (.secrets/config) defines:
#   ENTERPRISE, APP_ID, INSTALLATION_ID, PRIVATE_KEY, GH_BILLING_TOKEN
# See config.example for the format.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG="${COPILOT_METRICS_CONFIG:-$ROOT_DIR/.secrets/config}"
OUT_DIR=""
DO_USAGE=""
DO_BILLING=""

die() { echo "ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --usage-only) DO_USAGE="1"; shift ;;
    --billing-only) DO_BILLING="1"; shift ;;
    --config) [[ $# -ge 2 ]] || die "--config requires a value"; CONFIG="$2"; shift 2 ;;
    --out-dir) [[ $# -ge 2 ]] || die "--out-dir requires a value"; OUT_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,44p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

if [[ -n "$DO_USAGE" && -n "$DO_BILLING" ]]; then
  die "--usage-only and --billing-only are mutually exclusive (omit both to test both)."
fi
# Default: test both domains.
if [[ -z "$DO_USAGE" && -z "$DO_BILLING" ]]; then
  DO_USAGE="1"; DO_BILLING="1"
fi

# --- Load secrets ----------------------------------------------------------
if [[ ! -f "$CONFIG" ]]; then
  die "Secrets file not found: $CONFIG
  Create it from the template:
    cp \"$ROOT_DIR/config.example\" \"$ROOT_DIR/.secrets/config\"
  then fill in your real values."
fi

# shellcheck disable=SC1090
set -a; source "$CONFIG"; set +a

: "${ENTERPRISE:?ENTERPRISE is not set in $CONFIG}"

OUT_DIR="${OUT_DIR:-$ROOT_DIR/.secrets/output}"
mkdir -p "$OUT_DIR"
TODAY=$(date -u +%Y-%m-%d)

echo "Testing Copilot collection for enterprise '$ENTERPRISE'" >&2
echo "  config:  $CONFIG" >&2
echo "  out-dir: $OUT_DIR" >&2

FAILED=""

# --- Usage metrics (GitHub App) -------------------------------------------
if [[ -n "$DO_USAGE" ]]; then
  echo >&2
  echo "== Usage metrics — GitHub App credential ==" >&2

  for tool in curl jq openssl; do
    command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool (needed for GitHub App auth)"
  done
  : "${APP_ID:?APP_ID is not set in $CONFIG (needed for the usage-metrics test)}"
  : "${INSTALLATION_ID:?INSTALLATION_ID is not set in $CONFIG}"
  : "${PRIVATE_KEY:?PRIVATE_KEY is not set in $CONFIG}"

  # Resolve PRIVATE_KEY relative to the copilot-metrics-billing/ dir if needed.
  case "$PRIVATE_KEY" in
    /*) ;;                                   # absolute, leave as-is
    ~*) PRIVATE_KEY="${PRIVATE_KEY/#\~/$HOME}" ;;
    *)  PRIVATE_KEY="$ROOT_DIR/$PRIVATE_KEY" ;;
  esac
  [[ -f "$PRIVATE_KEY" ]] || die "Private key not found: $PRIVATE_KEY
  Place your GitHub App .pem there (e.g. $ROOT_DIR/.secrets/app.pem)."

  USAGE_OUT="$OUT_DIR/usage-enterprise-$ENTERPRISE-28day-$TODAY.json"
  if "$SCRIPT_DIR/copilot-usage-metrics.sh" "$ENTERPRISE" --last-28-days \
      --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY" \
      > "$USAGE_OUT"; then
    COVERAGE=$(jq -r '.report_meta | "\(.report_start_day // "?") -> \(.report_end_day // "?")"' "$USAGE_OUT" 2>/dev/null || echo "?")
    ROWS=$(jq -r '.report | length' "$USAGE_OUT" 2>/dev/null || echo "?")
    echo "✓ GitHub App OK — wrote $USAGE_OUT (coverage: $COVERAGE, $ROWS report rows)" >&2
  else
    echo "✗ GitHub App test FAILED — check App permissions, installation, and the usage-metrics policy." >&2
    FAILED="1"
  fi
fi

# --- Billing (classic PAT) -------------------------------------------------
if [[ -n "$DO_BILLING" ]]; then
  echo >&2
  echo "== Billing — classic PAT credential ==" >&2

  for tool in curl jq; do
    command -v "$tool" >/dev/null 2>&1 || die "Required tool not found: $tool (needed for billing)"
  done
  : "${GH_BILLING_TOKEN:?GH_BILLING_TOKEN is not set in $CONFIG (needed for the billing test)}"
  export GH_BILLING_TOKEN

  BILLING_OUT="$OUT_DIR/billing-ai_credit-$ENTERPRISE-last28days-$TODAY.csv"
  if "$SCRIPT_DIR/copilot-billing-export.sh" "$ENTERPRISE" --last-28-days --out "$BILLING_OUT"; then
    LINES=$(wc -l < "$BILLING_OUT")
    ROWS=$(( LINES > 0 ? LINES - 1 : 0 ))   # minus header
    echo "✓ Billing PAT OK — wrote $BILLING_OUT ($ROWS data rows over the last 28 days)" >&2
  else
    echo "✗ Billing test FAILED — the PAT needs the manage_billing:enterprise scope." >&2
    FAILED="1"
  fi
fi

echo >&2
if [[ -n "$FAILED" ]]; then
  die "One or more credential checks failed (see above)."
fi
echo "All requested credential checks passed. Files in $OUT_DIR/" >&2
