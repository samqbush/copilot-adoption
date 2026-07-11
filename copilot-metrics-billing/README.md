# Copilot Metrics & Billing — Scripts

Self-contained example scripts for pulling **usage metrics** (engagement) and
**billing metrics** (cost) out of Copilot and dropping the results into your own
data lake.

There are two ways to use them:

- **Deploy** — the [example GitHub Action](#deploy-the-github-action) collects
  the prior day automatically on a schedule and uploads the files as artifacts.
  This is the easy, unattended path.
- **Verify first** — [test each credential](#verify-each-credential) on its own
  by pulling the **last 28 days** with a single script, so you can confirm the
  setup works and eyeball last month's data before automating anything.

> **Two different things — don't confuse them:**
> - **Usage metrics** = engagement/adoption data (active users, completions, chat). No dollar amounts.
> - **Billing metrics** = consumption and cost data (AI Credits, quantities, dollar amounts).

| Script | What it gives you | Auth |
|--------|-------------------|------|
| `copilot-usage-metrics.sh` | The pre-aggregated daily usage-metrics report (enterprise or org), as JSON | Enterprise GitHub App *(or PAT with `read:enterprise`)* |
| `copilot-billing-export.sh` | The `ai_credit` billing CSV — every user, day, and model with dollar amounts | Classic PAT with `manage_billing:enterprise` |

The [`examples/copilot-metrics-collection.yml`](./examples/copilot-metrics-collection.yml)
workflow runs these two scripts on a schedule in a GitHub Action.

See [enterprise-setup.md](./enterprise-setup.md) for the one-time setup of the
Enterprise GitHub App and the billing PAT.

---

## Deploy: the GitHub Action

For unattended daily collection, copy
[`examples/copilot-metrics-collection.yml`](./examples/copilot-metrics-collection.yml)
into your own repository at `.github/workflows/`, along with this `scripts/`
folder (the workflow's `SCRIPTS_DIR` points at
`copilot-metrics-billing/scripts` by default — adjust it if you put the scripts
elsewhere).

Then set these in that repo under **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
|------|------|-------|
| Variable | `ENTERPRISE` | your enterprise slug |
| Variable | `COPILOT_APP_ID` | GitHub App ID |
| Variable | `COPILOT_INSTALLATION_ID` | App installation ID |
| Secret | `COPILOT_APP_PRIVATE_KEY` | the App's `.pem` contents |
| Secret | `GH_BILLING_TOKEN` | classic PAT with `manage_billing:enterprise` |

The workflow runs daily (and on demand via **Run workflow**), collects the prior
day's usage metrics and billing, and uploads them as a **workflow artifact** —
no extra infrastructure to see it working. Usage and billing run as separate
steps, so one credential failing still lets the other collect and upload.

> **Security:** `GH_BILLING_TOKEN` grants enterprise-wide billing access. Host
> the workflow in a dedicated private repo with a protected default branch and
> minimal write access, so no one can add a step that exfiltrates it.

> Artifacts expire — they're a zero-setup starting point, not a durable archive.
> Download them, or sync them to your data lake, for the long-term record.
> Grafana dashboards are coming soon (placeholder step in the workflow).

---

## Verify each credential

Before (or instead of) deploying, confirm each credential works on its own by
pulling the **last 28 days** and saving it to a file you can read. You don't need
to clone anything — download the one script you're testing and run it.

**Usage metrics (GitHub App):**

```bash
export ENTERPRISE=<your-enterprise> APP_ID=<id> INSTALLATION_ID=<id> PRIVATE_KEY=./app.pem
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-usage-metrics.sh" && chmod +x copilot-usage-metrics.sh

./copilot-usage-metrics.sh "$ENTERPRISE" --last-28-days \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY" \
  > usage-last-28-days.json
jq '.report' usage-last-28-days.json      # the metrics rows
```

**Billing (classic PAT):**

```bash
export ENTERPRISE=<your-enterprise> GH_BILLING_TOKEN=ghp_xxx
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-billing-export.sh" && chmod +x copilot-billing-export.sh

./copilot-billing-export.sh "$ENTERPRISE" --last-28-days --out billing-last-28-days.csv
head billing-last-28-days.csv             # or open it in a spreadsheet
```

Each script is self-contained (the usage script mints its own App token), so you
only download the one you're testing. See
[enterprise-setup.md](./enterprise-setup.md) for the full one-time credential
setup and these test steps in context.

> The two 28-day outputs aren't identical in shape: usage is a single **rolling
> aggregate report** (with its own `report_start_day`/`report_end_day`), while
> billing is **per-day detail rows**. Their end dates can differ slightly because
> of reporting lag.

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

# The last 28 complete days (handy for a manual "last month" pull)
./copilot-billing-export.sh my-enterprise --last-28-days --out last-month.csv

# A specific date range, written straight to a file
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

## Requirements

`bash`, `curl`, `jq`, and (for App auth) `openssl`. The scripts target
`api.github.com` (GitHub Enterprise Cloud). Use API version `2026-03-10` for
billing endpoints — the scripts set this header for you.
