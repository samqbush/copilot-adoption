# Copilot Metrics & Billing — Scripts

Self-contained example scripts for pulling **usage metrics** (engagement) and
**billing metrics** (cost) out of Copilot on a daily schedule and dropping the
results into your own data lake.

> **Two different things — don't confuse them:**
> - **Usage metrics** = engagement/adoption data (active users, completions, chat). No dollar amounts.
> - **Billing metrics** = consumption and cost data (AI Credits, quantities, dollar amounts).

| Script | What it gives you | Auth |
|--------|-------------------|------|
| `copilot-usage-metrics.sh` | The pre-aggregated daily usage-metrics report (enterprise or org), as JSON | Enterprise GitHub App *(or PAT with `read:enterprise`)* |
| `copilot-billing-export.sh` | The `ai_credit` billing CSV — every user, day, and model with dollar amounts | Classic PAT with `manage_billing:enterprise` |
| `collect-daily.sh` | Runs both for the prior day and writes timestamped files to an output dir | Both of the above |
| `generate-installation-token.sh` | Mints a short-lived GitHub App installation token (used internally by the usage script) | App private key |

See [enterprise-setup.md](./enterprise-setup.md) for the one-time setup of the
Enterprise GitHub App and the billing PAT.

---

## Quick local testing

To re-test the whole flow with a single command, put your credentials in an
uncommitted secrets file and run the wrapper:

```bash
cp config.example .secrets/config        # then fill in your real values
mv ~/Downloads/your-app.*.pem .secrets/app.pem && chmod 600 .secrets/app.pem
./scripts/run-test.sh                     # collects yesterday into .secrets/output
```

`.secrets/` is gitignored, so the config file and `.pem` never get committed.
`run-test.sh` loads the file, checks your credentials and tools, then runs
`collect-daily.sh` for both usage metrics and billing. Pass any
`collect-daily.sh` flag straight through:

```bash
./scripts/run-test.sh --day 2026-06-21    # a specific day
./scripts/run-test.sh --skip-billing      # usage metrics only
```

The secrets file holds `ENTERPRISE`, `APP_ID`, `INSTALLATION_ID`, `PRIVATE_KEY`,
and `GH_BILLING_TOKEN` — see [config.example](./config.example) for the format.

---

## Why two auth mechanisms?

GitHub Apps and fine-grained PATs **cannot access billing endpoints** — billing
requires a classic PAT with `manage_billing:enterprise`, held by an enterprise
owner or billing manager. Usage metrics, on the other hand, work great with an
Enterprise GitHub App (higher rate limit, short-lived tokens). So the two domains
use two tokens by design.

| | Usage metrics | Billing |
|---|---|---|
| Endpoint family | `/enterprises/{ent}/copilot/metrics/reports/...` | `/enterprises/{ent}/settings/billing/reports` |
| GitHub App | ✅ *View Enterprise Copilot Metrics* | ❌ not supported |
| Fine-grained PAT | ⚠️ permission exists in docs, not yet in UI | ❌ not supported |
| Classic PAT scope | `read:enterprise` or `manage_billing:copilot` | `manage_billing:enterprise` |

---

## Minimizing API calls

Both scripts use the **pre-aggregated report** endpoints, not per-entity loops:

- **Usage:** one report request returns a signed `download_links` URL; the script
  downloads the NDJSON. **~2 calls/run.**
- **Billing:** the bulk CSV export returns *every* user/day/model in one file via
  create → poll → download. **~3–5 calls/run** instead of one call per user.

A full daily collection is well under ten API calls — run it once a day against
the prior complete UTC day.

---

## copilot-usage-metrics.sh

Pulls the daily Copilot usage-metrics report. Enterprise-level by default; pass
`--org` for organization-level.

**APIs used** — each returns `download_links` to an NDJSON report the script then
downloads. Reference page: [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics).

For daily collection, use the **single-day** report:

| Report | Endpoint | Docs |
|--------|----------|------|
| Enterprise, single day | `GET /enterprises/{ent}/copilot/metrics/reports/enterprise-1-day?day=YYYY-MM-DD` | [link](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics#get-copilot-enterprise-usage-metrics-for-a-specific-day) |
| Org, single day | `GET /orgs/{org}/copilot/metrics/reports/organization-1-day?day=YYYY-MM-DD` | [link](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics#get-copilot-organization-usage-metrics-for-a-specific-day) |

```bash
# Enterprise, yesterday (default), GitHub App auth
source ~/.config/copilot-metrics/config
./copilot-usage-metrics.sh my-enterprise \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY"

# A specific day
./copilot-usage-metrics.sh my-enterprise --day 2026-06-21

# Org-level instead (PAT or App with org metrics access)
GH_TOKEN=$(gh auth token) ./copilot-usage-metrics.sh octodemo --org --day 2026-06-21
```

> The script also supports `--28day` (the `enterprise-28-day/latest` /
> `organization-28-day/latest` endpoints) for a quick ad-hoc rolling snapshot or
> an initial backfill. You don't need it for the daily job: once you're archiving
> the single-day files, you rebuild any window from your own data.

Requires the **Copilot usage metrics** policy to be **Enabled everywhere** for
the enterprise. Output is JSON: request metadata plus a `report` array of the
NDJSON rows. Progress goes to stderr, so `> file.json` captures clean output.

---

## copilot-billing-export.sh

Exports AI Credit billing data via the bulk CSV report — the only way to get
per-user data (with `username`, `total_monthly_quota`, `cost_center_name`)
without one API call per known user.

**Flow (3 API calls):**

| Step | Endpoint | Docs |
|------|----------|------|
| 1. Create the report | `POST /enterprises/{ent}/settings/billing/reports` | [Create a usage report export](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage-reports?apiVersion=2026-03-10#create-a-usage-report-export) |
| 2. Poll until `completed` | `GET /enterprises/{ent}/settings/billing/reports/{id}` | [Get a usage report export](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage-reports?apiVersion=2026-03-10#get-a-usage-report-export) |
| 3. Download CSV | signed `download_urls[0]` (expires ~1h) | — |

Reference page: [REST API endpoints for usage reports](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage-reports?apiVersion=2026-03-10).

```bash
# Yesterday's ai_credit export → CSV on stdout
export GH_BILLING_TOKEN=ghp_xxx   # classic PAT, manage_billing:enterprise
./copilot-billing-export.sh my-enterprise > billing.csv

# A date range, written straight to a file
./copilot-billing-export.sh my-enterprise \
  --start 2026-06-01 --end 2026-06-21 --out june-billing.csv
```

**CSV columns (`ai_credit`):** `date`, `username`, `product`, `sku`, `model`,
`quantity`, `unit_type`, `applied_cost_per_quantity`, `gross_amount`,
`discount_amount`, `net_amount`, `total_monthly_quota`, `organization`,
`repository`, `cost_center_name`, `aic_quantity`, `aic_gross_amount`.

Only one report runs at a time per enterprise — a `409` means another export is
still in progress. Download URLs expire in ~1 hour, so fetch immediately (the
script does).

---

## collect-daily.sh

Runs both scripts for the prior day and writes timestamped files to an output
directory — the hand-off point to your data lake.

```bash
source ~/.config/copilot-metrics/config
export GH_BILLING_TOKEN=ghp_xxx

./collect-daily.sh my-enterprise \
  --out-dir ./copilot-data \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY"
```

Produces:

```
copilot-data/usage-enterprise-my-enterprise-2026-06-21.json
copilot-data/billing-ai_credit-my-enterprise-2026-06-21.csv
```

Sync that directory to object storage with whatever you already use (the script
prints these as commented examples):

```bash
aws s3 cp ./copilot-data s3://my-bucket/copilot/2026-06-21/ --recursive   # AWS
az storage blob upload-batch -d copilot/2026-06-21 -s ./copilot-data       # Azure
gcloud storage cp ./copilot-data/* gs://my-bucket/copilot/2026-06-21/      # GCS
```

---

## generate-installation-token.sh

Mints a short-lived (1-hour) GitHub App installation token from a private key.
Called internally by `copilot-usage-metrics.sh` when `--app-id` is provided; can
also be run standalone.

```bash
./generate-installation-token.sh \
  --app-id 12345 --installation-id 67890 \
  --private-key ~/.config/copilot-metrics/app.pem
```

**API used:** `POST /app/installations/{installation_id}/access_tokens`. Requires
`openssl`, `curl`, and `jq`.

---

## Requirements

`bash`, `curl`, `jq`, and (for App auth) `openssl`. The scripts target
`api.github.com` (GitHub Enterprise Cloud). Use API version `2026-03-10` for
billing endpoints — the scripts set this header for you.
