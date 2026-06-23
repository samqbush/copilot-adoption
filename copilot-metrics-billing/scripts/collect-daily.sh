#!/bin/bash
# collect-daily.sh
# Orchestrator: runs the usage-metrics and billing-export scripts for the prior
# day and drops timestamped files into an output directory — the hand-off point
# to your data lake. Sync that directory to S3 / Azure Blob / GCS with whatever
# you already use (see the one-liners at the bottom of this file).
#
# Usage: ./collect-daily.sh <enterprise> [options]
#
# Options:
#   --day YYYY-MM-DD     Day to collect (default: yesterday, UTC).
#   --out-dir DIR        Output directory (default: ./copilot-data).
#   --org SLUG           Also/instead pull org-level usage metrics for SLUG.
#                        (Omit to pull enterprise-level usage metrics.)
#   --skip-usage         Don't pull usage metrics.
#   --skip-billing       Don't pull billing data.
#   --app-id ID          GitHub App ID for usage metrics (passed through).
#   --installation-id ID GitHub App Installation ID (passed through).
#   --private-key PATH   GitHub App private key (passed through).
#
# Auth:
#   - Usage metrics: GitHub App (preferred) or GH_TOKEN (read:enterprise).
#   - Billing:       GH_BILLING_TOKEN (classic PAT w/ manage_billing:enterprise).
#
# Output files (in --out-dir):
#   usage-<scope>-<slug>-<day>.json
#   billing-ai_credit-<enterprise>-<day>.csv

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENTERPRISE="${1:?Usage: $0 <enterprise> [--day YYYY-MM-DD] [--out-dir DIR] [--org SLUG] [--skip-usage] [--skip-billing] [App flags]}"
shift

DAY=""
OUT_DIR="./copilot-data"
ORG=""
SKIP_USAGE=""
SKIP_BILLING=""
APP_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --day) DAY="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --org) ORG="$2"; shift 2 ;;
    --skip-usage) SKIP_USAGE="1"; shift ;;
    --skip-billing) SKIP_BILLING="1"; shift ;;
    --app-id) APP_ARGS+=(--app-id "$2"); shift 2 ;;
    --installation-id) APP_ARGS+=(--installation-id "$2"); shift 2 ;;
    --private-key) APP_ARGS+=(--private-key "$2"); shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$DAY" ]]; then
  DAY=$(date -u -v-1d +%Y-%m-%d 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%d)
fi

mkdir -p "$OUT_DIR"
echo "Collecting Copilot data for $DAY into $OUT_DIR" >&2

# --- Usage metrics ---
if [[ -z "$SKIP_USAGE" ]]; then
  if [[ -n "$ORG" ]]; then
    USAGE_OUT="$OUT_DIR/usage-org-$ORG-$DAY.json"
    echo "-> usage metrics (org: $ORG)" >&2
    "$SCRIPT_DIR/copilot-usage-metrics.sh" "$ORG" --org --day "$DAY" "${APP_ARGS[@]}" > "$USAGE_OUT"
  else
    USAGE_OUT="$OUT_DIR/usage-enterprise-$ENTERPRISE-$DAY.json"
    echo "-> usage metrics (enterprise: $ENTERPRISE)" >&2
    "$SCRIPT_DIR/copilot-usage-metrics.sh" "$ENTERPRISE" --day "$DAY" "${APP_ARGS[@]}" > "$USAGE_OUT"
  fi
  echo "   wrote $USAGE_OUT" >&2
fi

# --- Billing ---
if [[ -z "$SKIP_BILLING" ]]; then
  BILLING_OUT="$OUT_DIR/billing-ai_credit-$ENTERPRISE-$DAY.csv"
  echo "-> billing export (enterprise: $ENTERPRISE)" >&2
  "$SCRIPT_DIR/copilot-billing-export.sh" "$ENTERPRISE" \
    --start "$DAY" --end "$DAY" --out "$BILLING_OUT"
  echo "   wrote $BILLING_OUT" >&2
fi

echo "Done. Files ready in $OUT_DIR/" >&2

# --- Ship to your data lake (pick one, run from your scheduler) -------------
# AWS S3:     aws s3 cp "$OUT_DIR" "s3://my-bucket/copilot/$DAY/" --recursive
# Azure Blob: az storage blob upload-batch -d "copilot/$DAY" -s "$OUT_DIR"
# GCS:        gcloud storage cp "$OUT_DIR/*" "gs://my-bucket/copilot/$DAY/"
