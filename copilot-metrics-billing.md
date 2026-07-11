---
layout: default
title: Pulling Copilot Metrics & Billing Into Your Data Lake
description: How Copilot admins set up the credentials and APIs to pull usage metrics and billing data daily into their own data lake, with minimal API calls
toc: true
---

# Pulling Copilot Metrics & Billing Into Your Data Lake
{:.no_toc}

*Last updated: July 11, 2026*

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

The [example scripts](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/scripts)
do exactly this. The rest of this page explains the model and walks the setup so
you can adapt it.

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

The [setup below](#set-up-the-two-credentials) creates both.

---

## Set up the two credentials
{:#set-up-the-two-credentials}

Two one-time setups, one per data domain. You need **enterprise owner** access
(to create the App and the billing PAT and to enable the usage-metrics policy),
plus `openssl`, `curl`, and `jq` locally.

### Enterprise GitHub App (usage metrics)

1. **Enable the policy.** The metrics endpoints only return data when **Copilot
   usage metrics** is **Enabled everywhere** (**Settings → Policies → Copilot**).
   See [Manage enterprise policies for Copilot](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies).

2. **Register the App** at
   `https://github.com/enterprises/<your-enterprise>/settings/apps/new`
   ([registering a GitHub App](https://docs.github.com/en/enterprise-cloud@latest/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)).
   The choices that matter for this example:
   - **Enterprise permissions → View Enterprise Copilot Metrics: Read-only.**
     Add **Organization permissions → Organization Copilot metrics: Read-only**
     too if you'll pull org-level reports (the `--org` flag).
   - **Webhook → Active: unchecked** — no events needed.
   - **Only on this account.**

   Note the **App ID** shown after you create it.

3. **Generate a private key** (App settings → Private keys), then lock it down:

   ```bash
   mv ~/Downloads/*.pem ./app.pem && chmod 600 ./app.pem
   ```

4. **Install the App** on your enterprise and note the **installation ID** from
   the URL: `.../settings/installations/<INSTALLATION_ID>`.

The scripts mint the installation token themselves from the App ID, installation
ID, and key.

### Billing classic PAT (billing metrics)

Create a **classic** PAT with the `manage_billing:enterprise` scope, owned by an
enterprise owner or billing manager, at
[github.com/settings/tokens](https://github.com/settings/tokens)
([creating a classic PAT](https://docs.github.com/en/enterprise-cloud@latest/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic)).
There is no GitHub App or fine-grained PAT equivalent today. Keep it separate
from the App key.

---

## Verify each credential
{:#verify-each-credential}

Before automating, confirm each credential works on its own by pulling the
**last 28 days** to a file you can read. Download only the script you're testing —
no clone required.

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

> [!NOTE]
> `Resource not accessible by integration` means the App is missing the **View
> Enterprise Copilot Metrics** permission, or the usage-metrics policy isn't
> enabled yet. Fix it, then re-accept the updated permissions on the installation.

**Billing (classic PAT):**

```bash
export ENTERPRISE=<your-enterprise> GH_BILLING_TOKEN=ghp_xxx
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-billing-export.sh" && chmod +x copilot-billing-export.sh

./copilot-billing-export.sh "$ENTERPRISE" --last-28-days --out billing-last-28-days.csv
head billing-last-28-days.csv             # or open it in a spreadsheet
```

> [!NOTE]
> A `404` on the `/reports` endpoints means the token is missing
> `manage_billing:enterprise`. The other billing endpoints (`/usage/summary`,
> `/ai_credit/usage`) work with just the enterprise role, but the bulk CSV export
> needs this scope.

The two 28-day outputs aren't the same shape: usage is a single **rolling
aggregate report** (with its own `report_start_day`/`report_end_day`), while
billing is **per-day detail rows**. Their end dates can differ slightly because of
reporting lag.

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
{:#the-scripts}

The [`scripts/`](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/scripts)
folder ships example scripts that implement the above. They're a starting point:
clean stdout (JSON/CSV), progress to stderr, meant to be adapted into your
pipeline. Once your credentials are set up, [verify them](#verify-each-credential)
and then [automate the daily pull](#automate).

| Script | What it does | Key flags |
|--------|--------------|-----------|
| `copilot-usage-metrics.sh` | Pulls the enterprise (or `--org`) usage report → JSON. App or PAT auth. | `--day YYYY-MM-DD`, `--org`, `--28day` (alias `--last-28-days`), `--app-id`, `--installation-id`, `--private-key` |
| `copilot-billing-export.sh` | Creates, polls, and downloads the `ai_credit` billing CSV. Classic PAT auth. | `--start`/`--end`, `--last-28-days`, `--report-type` (default `ai_credit`), `--out`, `--poll-timeout` |

For the daily job you want the single day (`--day`, defaulting to yesterday); the
28-day flags are for an ad-hoc snapshot or an initial backfill. They need `bash`,
`curl`, `jq`, and (for App auth) `openssl`, and set the `2026-03-10` billing API
version header for you.

---

## Automate with the example Action
{:#automate}

For unattended daily collection, copy the
[example workflow](https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-billing/examples/copilot-metrics-collection.yml)
and the `scripts/` folder into your own repository (the workflow's `SCRIPTS_DIR`
defaults to `scripts`). Then set your credentials under **Settings → Secrets and
variables → Actions**:

| Kind | Name | Value |
|------|------|-------|
| Variable | `ENTERPRISE` | your enterprise slug |
| Variable | `COPILOT_APP_ID` | the App ID |
| Variable | `COPILOT_INSTALLATION_ID` | the installation ID |
| Secret | `COPILOT_APP_PRIVATE_KEY` | the App's `.pem` contents |
| Secret | `GH_BILLING_TOKEN` | the classic PAT (`manage_billing:enterprise`) |

App ID and installation ID are identifiers, not credentials, so they go in
**variables**; the private key and PAT go in **secrets**. Set all five from the
terminal with `gh` (it encrypts the secrets locally before upload):

```bash
gh variable set ENTERPRISE              --body "$ENTERPRISE"
gh variable set COPILOT_APP_ID          --body "$APP_ID"
gh variable set COPILOT_INSTALLATION_ID --body "$INSTALLATION_ID"
gh secret   set COPILOT_APP_PRIVATE_KEY < ./app.pem
gh secret   set GH_BILLING_TOKEN        --body "$GH_BILLING_TOKEN"
```

`gh` targets the repo in the current directory; add `--repo <owner>/<repo>` to
point elsewhere. If you can't use `gh`, the
[Actions secrets REST API](https://docs.github.com/en/enterprise-cloud@latest/rest/actions/secrets?apiVersion=2026-03-10#create-or-update-a-repository-secret)
does the same — you seal each value against the repo's public key yourself.

Commit the workflow and scripts (the credentials live in repo settings, not the
tree):

```bash
git add .github/workflows/copilot-metrics-collection.yml scripts/copilot-*.sh
git commit -m "Add Copilot metrics & billing collection workflow"
git push
```

The workflow runs daily (and on demand via **Run workflow**), collects the prior
day, and uploads the files as a **workflow artifact**. Usage and billing run as
separate steps, so one credential failing still lets the other collect.

---

## Running it daily and landing it in a data lake

Prefer another scheduler? A Jenkins job, a GitLab schedule, or a plain `cron`
entry run the same two scripts just as well.

Artifacts expire, so to keep a long-term history land the files in your data
lake. Point the scripts at an output directory
(`copilot-usage-metrics.sh … > dir/usage-<day>.json` and
`copilot-billing-export.sh … --out dir/billing-<day>.csv`), then sync that
directory to object storage with whatever you already use:

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

## Rate limits and security
{:#security}

| Auth method | Rate limit |
|-------------|-----------|
| Classic PAT | 5,000 req/hr |
| GitHub App (installation token) | 15,000 req/hr |

A full daily collection is under ten calls, so either budget is plenty — the App
is just the better choice for usage metrics because of its short-lived tokens.

- The App private key and the billing PAT **never** go into the repository —
  only into variables and secrets.
- Installation tokens and billing download URLs expire in **~1 hour**.
- Both tokens are **read-only** with respect to your code; they can't modify
  repositories or PRs.
- If a credential is compromised, revoke it and reissue.
- `GH_BILLING_TOKEN` grants enterprise-wide billing access. Host the workflow in
  a dedicated private repo with a protected default branch and minimal write
  access, so no one can add a step that exfiltrates it.

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
