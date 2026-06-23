---
layout: default
title: Pulling Copilot Metrics & Billing Into Your Data Lake
description: How Copilot admins set up the credentials and APIs to pull usage metrics and billing data daily into their own data lake, with minimal API calls
toc: true
---

# Pulling Copilot Metrics & Billing Into Your Data Lake
{:.no_toc}

*Last updated: June 22, 2026*

---

## What it takes

GitHub only retains Copilot usage metrics for about 28 days, so if you want a
longer adoption history (or billing data for chargeback) you have to pull it
yourself and keep your own copy. The whole job:

1. **Set up two credentials** (they can't be shared):
   - an **Enterprise GitHub App** for **usage metrics**, and
   - a **billing-manager classic PAT** for **billing data**.
2. **Run two pulls once a day** against the prior complete day, each using the
   **pre-aggregated report** endpoints so the whole thing is under ten API calls.
3. **Drop the files into your data lake** before the 28-day window rolls off.

The [example scripts](./copilot-metrics-billing/README.md) do exactly this. The
rest of this page explains the model so you can adapt it.

> [!NOTE]
> This applies to GitHub Enterprise Cloud (including EMU). The endpoints are
> enterprise-scoped against `api.github.com`.

---

## Two domains, don't confuse them

| | **Usage metrics** | **Billing metrics** |
|---|---|---|
| What it is | Engagement/adoption — active users, completions, chat | Consumption/cost — AI Credits, quantities, dollar amounts |
| Endpoint family | `/enterprises/{ent}/copilot/metrics/reports/...` | `/enterprises/{ent}/settings/billing/reports` |
| Dollar amounts | ❌ none | ✅ yes |
| Auth | Enterprise GitHub App *(or PAT `read:enterprise`)* | Classic PAT `manage_billing:enterprise` |

Usage metrics tell you *who is using Copilot and how much*. Billing tells you
*what it costs*. They come from different APIs with different auth, so you collect
them separately and join them later in your warehouse (on `username` / `date`).

---

## Why two credentials

This trips people up, so it's worth stating plainly: **GitHub Apps and
fine-grained PATs cannot read billing endpoints.** Billing requires a **classic
PAT with `manage_billing:enterprise`**, held by an enterprise owner or billing
manager which is assigned by IDP.

Usage metrics, by contrast, work well with an **Enterprise GitHub App**. You get
a 15,000 req/hr limit and short-lived (1-hour) installation tokens instead of a
long-lived PAT.

| | Usage metrics | Billing |
|---|---|---|
| Enterprise GitHub App | ✅ *View Enterprise Copilot Metrics* | ❌ not supported |
| Fine-grained PAT | ⚠️ documented, not yet in the UI | ❌ not supported |
| Classic PAT scope | `read:enterprise` or `manage_billing:copilot` | `manage_billing:enterprise` |

See [enterprise-setup.md](./copilot-metrics-billing/enterprise-setup.md) for the
one-time setup of both.

---

## Minimizing API calls

These endpoints do the aggregation for you. Use the
**report** endpoints, not per-user or per-day loops:

- **Usage metrics:** one request returns a signed `download_links` URL to an
  NDJSON file with the whole day's aggregated metrics. Download it. **~2 calls.**
- **Billing:** the **bulk CSV export** returns *every* user, day, and model in a
  single file via create → poll → download. **~3–5 calls.** This is far cheaper
  than calling `/ai_credit/usage?user=X` once per user, and it's the *only* way
  to get per-user fields (`username`, `total_monthly_quota`, `cost_center_name`)
  without already knowing every username.

A full daily collection is **under ten API calls**. Run it once a day against the
prior complete UTC day and you'll never come close to a rate limit.

> [!IMPORTANT]
> Don't use the legacy `GET /enterprises/{ent}/copilot/metrics` endpoint. It was
> closed April 2, 2026 and returns 404. Use the
> `/copilot/metrics/reports/enterprise-1-day` report endpoint instead.

---

## The endpoints

### Usage metrics (engagement)

Call **one** report endpoint per run. Enterprise-level is the primary target; use
the org-level row only if you need per-org breakdowns or you only have org
access. Each returns `download_links` to an NDJSON report you then download.

| What you want | Endpoint to call | Docs |
|---|---|---|
| Enterprise, single day | `GET /enterprises/{ent}/copilot/metrics/reports/enterprise-1-day?day=YYYY-MM-DD` | [Enterprise, specific day](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics#get-copilot-enterprise-usage-metrics-for-a-specific-day) |
| Org, single day | `GET /orgs/{org}/copilot/metrics/reports/organization-1-day?day=YYYY-MM-DD` | [Org, specific day](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics#get-copilot-organization-usage-metrics-for-a-specific-day) |

Pull the **single-day** report each day. There are also 28-day rolling report
endpoints, but you don't need them here: once you're archiving the daily files,
you reconstruct any window (7, 28, 90 days) from your own data instead of asking
GitHub to re-roll it.

Requires the **Copilot usage metrics** policy to be **Enabled everywhere**.
GitHub only retains this data for about 28 days, so pull it daily and archive it
yourself. Reference page:
[REST API endpoints for Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics).

### Billing (cost)

Three calls, in order. The CSV export is the only way to get per-user rows
without one call per known username.

| Step | Endpoint to call | Docs |
|---|---|---|
| 1. Create the report | `POST /enterprises/{ent}/settings/billing/reports` — body `{"report_type":"ai_credit","start_date":"YYYY-MM-DD","end_date":"YYYY-MM-DD"}` (returns `202` + a report `id`) | [Create a usage report export](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage-reports?apiVersion=2026-03-10#create-a-usage-report-export) |
| 2. Poll until `status: completed` | `GET /enterprises/{ent}/settings/billing/reports/{id}` | [Get a usage report export](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage-reports?apiVersion=2026-03-10#get-a-usage-report-export) |
| 3. Download the CSV | fetch the signed `download_urls[0]` from step 2 (expires ~1h) | — |

Send header `X-GitHub-Api-Version: 2026-03-10` on all three. Billing data is
available for the past 24 months. Reference page:
[REST API endpoints for usage reports](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage-reports?apiVersion=2026-03-10).

The `ai_credit` CSV gives you per-user, per-day, per-model rows with dollar
amounts:

```
date, username, product, sku, model, quantity, unit_type,
applied_cost_per_quantity, gross_amount, discount_amount, net_amount,
total_monthly_quota, organization, repository, cost_center_name,
aic_quantity, aic_gross_amount
```

> [!TIP]
> For a fast "total Copilot spend this month" number without the export, call
> `GET /enterprises/{ent}/settings/billing/usage/summary?product=Copilot`
> ([docs](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage?apiVersion=2026-03-10#get-billing-usage-summary-for-an-enterprise)).
> One call, aggregated totals, but no per-user breakdown.

---

## The scripts

The [`copilot-metrics-billing/`](./copilot-metrics-billing/README.md) folder ships
example scripts that implement the above. They're a starting point: clean stdout
(JSON/CSV), progress to stderr, meant to be adapted into your pipeline.

| Script | What it does |
|--------|--------------|
| `copilot-usage-metrics.sh` | Pulls the enterprise (or `--org`) daily usage report → JSON. App or PAT auth. |
| `copilot-billing-export.sh` | Creates, polls, and downloads the `ai_credit` billing CSV. Classic PAT auth. |
| `collect-daily.sh` | Runs both for the prior day and writes timestamped files to an output dir. |
| `generate-installation-token.sh` | Mints the short-lived App token (used internally by the usage script). |

```bash
source ~/.config/copilot-metrics/config   # APP_ID, INSTALLATION_ID, PRIVATE_KEY
export GH_BILLING_TOKEN=ghp_xxx            # classic PAT, manage_billing:enterprise

./copilot-metrics-billing/scripts/collect-daily.sh my-enterprise \
  --out-dir ./copilot-data \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY"
```

Output:

```
copilot-data/usage-enterprise-my-enterprise-2026-06-21.json
copilot-data/billing-ai_credit-my-enterprise-2026-06-21.csv
```

See the [scripts README](./copilot-metrics-billing/README.md) for full options
and output schemas.

---

## Running it daily and landing it in a data lake

Schedule `collect-daily.sh` once a day. A GitHub Actions cron, a Jenkins job, a
GitLab schedule, or a plain `cron` entry all work. It writes timestamped files to
an output directory; from there, sync that directory to object storage with
whatever you already use:

```bash
# pick the one that matches your stack
aws s3 cp ./copilot-data s3://my-bucket/copilot/$(date -u +%F)/ --recursive   # AWS S3
az storage blob upload-batch -d copilot/$(date -u +%F) -s ./copilot-data       # Azure Blob
gcloud storage cp ./copilot-data/* gs://my-bucket/copilot/$(date -u +%F)/      # GCS
```

Once the JSON and CSV are in your lake, load them into your warehouse and join on
`username` and `date` to put adoption next to cost. The shape of that warehouse
is your call. Partition the raw files by date and your daily pull becomes an
append-only history you can rebuild dashboards from at any time.

> [!NOTE]
> Keep the raw files. GitHub only retains usage metrics for ~28 days (billing for
> 24 months), so your archived daily pulls become the long-term record. For usage
> metrics, they're the *only* record once you're past the 28-day window.

---

## Gotchas

- **One billing report at a time per enterprise.** A second `POST .../reports`
  while one is running returns `409`. The daily cadence avoids this.
- **Download URLs expire in ~1 hour.** Fetch the file immediately (the scripts
  do).
- **Single-enterprise scope.** Each call targets one enterprise, so
  multi-enterprise customers run the collection once per enterprise.
- **Usage-metrics policy must be on.** Without **Copilot usage metrics → Enabled
  everywhere**, the report endpoints return no data.
- **Run against the prior complete day.** "Today" isn't fully processed yet;
  default to yesterday (UTC).

---

## Related

- [Managing Copilot usage-based billing](./cost-management) — budgets, AI Credits,
  and keeping spend predictable.
- [Measuring AI in Pull Requests](./ai-commit-attribution) — AI leverage from
  commit trailers and the Copilot usage metrics API.
