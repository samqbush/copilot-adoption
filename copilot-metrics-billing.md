---
layout: default
title: Pulling Copilot Metrics & Billing Into Your Data Lake
description: How Copilot admins set up the credentials and APIs to pull usage metrics and billing data daily into their own data lake, with minimal API calls
toc: true
---

# Pulling Copilot Metrics & Billing Into Your Data Lake
{:.no_toc}

*Last updated: August 27, 2026*

---

## What it takes

GitHub only retains Copilot usage metrics for about 28 days, so if you want a
longer adoption history (or billing data for chargeback) you have to pull it
yourself and keep your own copy. The whole job:

1. **Set up one Enterprise GitHub App** with read access to both **Copilot
   metrics** and **enterprise billing**.
2. **Pull four usage report families plus one billing export each day** against
   the prior complete day. This preserves aggregate, user, team, repository, and
   cost data in roughly a dozen data requests.
3. **Drop the files into your data lake** before the 28-day window rolls off.

The [example scripts](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/scripts)
do exactly this. The rest of this page explains the model and walks the setup so
you can adapt it.

> [!NOTE]
> This applies to GitHub Enterprise Cloud (including EMU). The endpoints are
> enterprise-scoped against `api.github.com`.
>
> GitHub App access to enterprise billing became available on August 26, 2026.
> Older implementations used a billing-manager PAT because Apps could not call
> these endpoints. See
> [GitHub Apps can now access enterprise billing data](https://github.blog/changelog/2026-08-26-github-apps-can-now-access-enterprise-billing-data).

---

## Two domains, don't confuse them

| | **Usage metrics** | **Billing metrics** |
|---|---|---|
| What it is | Engagement/adoption — active users, completions, chat | Consumption/cost — AI Credits, quantities, dollar amounts |
| Endpoint family | `/enterprises/{ent}/copilot/metrics/reports/...` | `/enterprises/{ent}/settings/billing/reports` |
| Dollar amounts | ❌ none | ✅ yes |
| Auth | Enterprise GitHub App: **Enterprise Copilot metrics (read)** | Same App: **Enterprise billing (read)** |

Usage metrics tell you *how Copilot is being used*. The aggregate report has no
user identity; the separate user report includes `user_id` and `user_login`.
Billing tells you *what it costs*. Collect both API families separately, then
join usage `user_login` to billing `username` for the same date. One App
installation token can authorize every call when the App has both permissions.

---

## One App, two permissions

The App needs one read permission for each API family:

| App permission | Used for |
|---|---|
| **Enterprise Copilot metrics: Read-only** | Adoption and engagement reports |
| **Enterprise billing: Read-only** | Usage summaries and billing report exports |

The billing export starts with a `POST`, but it only requests creation of a
read-only report. GitHub's
[App permission matrix](https://docs.github.com/en/enterprise-cloud@latest/rest/authentication/permissions-required-for-github-apps?apiVersion=2026-03-10#enterprise-permissions-for-enterprise-billing)
classifies the create, poll, and list report endpoints as **read**. Do not grant
write access to a collection App; write is for changing budgets and cost
centers.

The scripts still accept a classic PAT for compatibility, but the App is the
recommended unattended credential: installation tokens expire after one hour,
aren't tied to an employee, and receive the higher App rate limit.

---

## Set up the Enterprise GitHub App {#set-up-the-two-credentials}

You need **enterprise owner** access to create and install the App and enable the
usage-metrics policy, plus `openssl`, `curl`, and `jq` locally.

1. **Enable the policy.** The metrics endpoints only return data when **Copilot
   usage metrics** is **Enabled everywhere** (**Settings → Policies → Copilot**).
   See [Manage enterprise policies for Copilot](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies).

2. **Register the App** at
   `https://github.com/enterprises/<your-enterprise>/settings/apps/new`
   ([registering a GitHub App](https://docs.github.com/en/enterprise-cloud@latest/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)).
   The choices that matter for this example:
   - **Enterprise permissions → View Enterprise Copilot Metrics: Read-only.**
   - **Enterprise permissions → Enterprise billing: Read-only.**
   - **Organization permissions → Organization Copilot metrics: Read-only**
     (optional) if you'll pull org-level reports with `--org`.
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

### Migrating an existing App

If you followed an older version of this guide, add **Enterprise billing:
Read-only** to the existing App. Then review the enterprise installation and
approve the updated permission if GitHub prompts you. For enterprise-owned Apps,
some permission updates are accepted automatically; confirm the installation
shows billing read access before removing `GH_BILLING_TOKEN`.

The installation continues using its old permissions until the update is
accepted. That is the first thing to check if the App can read Copilot metrics
but billing returns an authorization error. See
[Approving updated permissions for a GitHub App](https://docs.github.com/en/enterprise-cloud@latest/apps/using-github-apps/approving-updated-permissions-for-a-github-app).

---

## Verify both permissions {#verify-each-credential}

Before automating, confirm both App permissions work by pulling the **last 28
days** to files you can read. Download only the script you're testing — no clone
required.

**Usage metrics (GitHub App):**

```bash
export ENTERPRISE=<your-enterprise> APP_ID=<id> INSTALLATION_ID=<id> PRIVATE_KEY=./app.pem
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-usage-metrics.sh" && chmod +x copilot-usage-metrics.sh

day=$(date -u -v-1d +%F 2>/dev/null || date -u -d '1 day ago' +%F)
for report in aggregate users user-teams repos; do
  ./copilot-usage-metrics.sh "$ENTERPRISE" --day "$day" --report-type "$report" \
    --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY" \
    > "usage-$report-$day.json"
done
jq '.report | length' usage-*-"$day".json
```

> [!NOTE]
> `Resource not accessible by integration` means the App is missing the **View
> Enterprise Copilot Metrics** permission, or the usage-metrics policy isn't
> enabled yet. Fix it, then re-accept the updated permissions on the installation.

**Billing (same GitHub App):**

```bash
export ENTERPRISE=<your-enterprise> APP_ID=<id> INSTALLATION_ID=<id> PRIVATE_KEY=./app.pem
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-billing-export.sh" && chmod +x copilot-billing-export.sh

./copilot-billing-export.sh "$ENTERPRISE" --last-28-days \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY" \
  --out billing-last-28-days.csv
head billing-last-28-days.csv             # or open it in a spreadsheet
```

> [!NOTE]
> A `403` or `404` on the `/reports` endpoints usually means the App is missing
> **Enterprise billing: Read-only**, or the updated installation has not been
> accepted. Fix the permission and confirm the installation, then try again.

The usage files are not interchangeable: each report family covers a different
slice of the same day. Billing is per-day detail and can lag usage slightly.

---

## Minimizing API calls

These endpoints package each dataset for you. Use the **report** endpoints, not
one API request per user or repository:

- **Usage metrics:** each of the four report requests returns signed
  `download_links` to NDJSON. Request and download every family. **~8 calls.**
- **Billing:** the **bulk CSV export** returns *every* user, day, and model in a
  single file via create → poll → download. **~3–5 calls.** This is far cheaper
  than calling `/ai_credit/usage?user=X` once per user, and it's the *only* way
  to get per-user fields (`username`, `total_monthly_quota`, `cost_center_name`)
  without already knowing every username.

A full daily collection is typically **11–13 data requests**, plus the App token
exchange. Run it once a day against the prior complete UTC day and it remains
well below the App rate limit.

> [!IMPORTANT]
> Don't use the legacy `GET /enterprises/{ent}/copilot/metrics` endpoint. It was
> closed April 2, 2026 and returns 404. Use the
> `/copilot/metrics/reports/enterprise-1-day` report endpoint instead.

---

## The endpoints

### Usage metrics (engagement)

Pull all four single-day report families. The aggregate report does not contain
the rows from the other three.

| Report | Enterprise endpoint | What it preserves |
|---|---|---|
| Aggregate | `GET /enterprises/{ent}/copilot/metrics/reports/enterprise-1-day?day=YYYY-MM-DD` | Daily totals and aggregate breakdowns |
| Users | `GET /enterprises/{ent}/copilot/metrics/reports/users-1-day?day=YYYY-MM-DD` | Per-user usage |
| User teams | `GET /enterprises/{ent}/copilot/metrics/reports/user-teams-1-day?day=YYYY-MM-DD` | Daily user-to-team membership used to attribute user usage |
| Repositories | `GET /enterprises/{ent}/copilot/metrics/reports/repos-1-day?day=YYYY-MM-DD` | Repository usage detail |

The script's `--org` flag switches to organization scope. GitHub also publishes
28-day rolling reports for aggregate and user data, but not for user-team or
repository data. The daily archive is the recommended path because you can
rebuild longer windows from it.

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
aic_quantity, aic_gross_amount, input, output, cache_read, cache_write
```

The last four are the token counts behind each model's credit consumption. They
show where the volume goes: on an agent-heavy day a single user can log 10.6M
`cache_read` tokens against 37K `output` tokens, which the credit total alone
won't tell you. Field definitions are in the
[billing reports reference](https://docs.github.com/en/enterprise-cloud@latest/billing/reference/billing-reports#ai-usage-report).

> [!TIP]
> For a fast "total Copilot spend this month" number without the export, call
> `GET /enterprises/{ent}/settings/billing/usage/summary?product=Copilot`
> ([docs](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/usage?apiVersion=2026-03-10#get-billing-usage-summary-for-an-enterprise)).
> One call, aggregated totals, but no per-user breakdown.

---

## The scripts {#the-scripts}

The [`scripts/`](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/scripts)
folder ships example scripts that implement the above. They're a starting point:
clean stdout (JSON/CSV), progress to stderr, meant to be adapted into your
pipeline. Once your credentials are set up, [verify them](#verify-each-credential)
and then [automate the daily pull](#automate).

> [!NOTE]
> These scripts are built for **quickly testing the APIs and your credentials**,
> and for a simple daily pull into files. If you want dashboards instead of raw
> files, the [Grafana add-on](copilot-metrics-grafana.md) reuses the same two
> collectors and pushes daily summaries into Postgres for Grafana to read.

| Script | What it does | Key flags |
|--------|--------------|-----------|
| `copilot-usage-metrics.sh` | Pulls one enterprise (or `--org`) usage report family → JSON. The workflow calls it four times daily. | `--report-type aggregate\|users\|user-teams\|repos`, `--day YYYY-MM-DD`, `--org`, `--28day`, `--app-id`, `--installation-id`, `--private-key` |
| `copilot-billing-export.sh` | Creates, polls, and downloads the `ai_credit` billing CSV. App auth recommended; PAT fallback supported. | `--start`/`--end`, `--last-28-days`, `--report-type` (default `ai_credit`), `--out`, `--poll-timeout`, `--app-id`, `--installation-id`, `--private-key` |

For the daily job, request all four report types for one day (`--day`, defaulting
to yesterday). The 28-day flag is only for ad-hoc aggregate or user snapshots.
The scripts need `bash`, `curl`, `jq`, and (for App auth) `openssl`, and set the
`2026-03-10` API version header for you.

---

## Automate with the example Action {#automate}

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

App ID and installation ID are identifiers, not credentials, so they go in
**variables**; the private key goes in **secrets**. Set all four from the
terminal with `gh` (it encrypts the secret locally before upload):

```bash
gh variable set ENTERPRISE              --body "$ENTERPRISE"
gh variable set COPILOT_APP_ID          --body "$APP_ID"
gh variable set COPILOT_INSTALLATION_ID --body "$INSTALLATION_ID"
gh secret   set COPILOT_APP_PRIVATE_KEY < ./app.pem
```

`gh` targets the repo in the current directory; add `--repo <owner>/<repo>` to
point elsewhere. The key is read from stdin rather than an argument, so it never
lands in your shell history or the process list. If you can't use `gh`, the
[Actions secrets REST API](https://docs.github.com/en/enterprise-cloud@latest/rest/actions/secrets?apiVersion=2026-03-10#create-or-update-a-repository-secret)
does the same — you seal each value against the repo's public key yourself.

Commit the workflow and scripts (the credentials live in repo settings, not the
tree):

```bash
git add .github/workflows/copilot-metrics-collection.yml scripts/copilot-*.sh
git commit -m "Add Copilot metrics & billing collection workflow"
git push
```

The workflow runs daily (and on demand via **Run workflow**), collects all four
usage reports plus billing for the prior day, and uploads the files as a
**workflow artifact**. Each report has its own filename. A failed usage report
is surfaced without deleting successful files, and billing still runs.

---

## Running it daily and landing it in a data lake

Prefer another scheduler? A Jenkins job, a GitLab schedule, or a plain `cron`
entry run the same two scripts just as well.

Artifacts expire, so to keep a long-term history land the files in your data
lake. Point the scripts at an output directory
(`copilot-usage-metrics.sh … > dir/usage-<report>-<day>.json` and
`copilot-billing-export.sh … --out dir/billing-<day>.csv`), then sync that
directory to object storage with whatever you already use:

```bash
# pick the one that matches your stack
aws s3 cp ./copilot-data s3://my-bucket/copilot/$(date -u +%F)/ --recursive   # AWS S3
az storage blob upload-batch -d copilot/$(date -u +%F) -s ./copilot-data       # Azure Blob
gcloud storage cp ./copilot-data/* gs://my-bucket/copilot/$(date -u +%F)/      # GCS
```

Once the JSON and CSV are in your lake, load them into your warehouse. Join the
user report's `user_login` to billing `username` for the same date; do not expect
identity fields in the aggregate report. Join the daily user report to the daily
user-team report on `user_id` before rolling up team metrics. Partition raw files
by date and report family so the daily pull becomes append-only history.

> [!NOTE]
> Keep the raw files. GitHub only retains usage metrics for ~28 days (billing for
> 24 months), so your archived daily pulls become the long-term record. For usage
> metrics, they're the *only* record once you're past the 28-day window.

---

## Rate limits and security {#security}

| Auth method | Rate limit |
|-------------|-----------|
| GitHub App (installation token) | 15,000 req/hr |
| Classic PAT fallback | 5,000 req/hr |

A full daily collection is roughly a dozen data requests, so either budget is
plenty. The App is the better unattended choice because its tokens are
short-lived and not tied to a person.

- The App private key **never** goes into the repository — only into an Actions
  secret.
- Installation tokens and billing download URLs expire in **~1 hour**.
- The App has read-only enterprise permissions and no repository write
  permission; it can't modify repositories, budgets, or cost centers.
- If a credential is compromised, revoke it and reissue.
- The App key can mint tokens that read enterprise-wide usage and billing data.
  Host the workflow in a dedicated private repo with a protected default branch
  and minimal write access, so no one can add a step that exfiltrates it.

---

## Gotchas

- **One billing report at a time per enterprise.** A second `POST .../reports`
  while one is running returns `409`. The daily cadence avoids this.
- **Download URLs expire in ~1 hour.** Fetch the file immediately (the scripts
  do).
- **Usage reports can be multipart.** Download every URL in `download_links`;
  the script combines all parts.
- **User and user-team reports are identifiable.** Protect their raw files and
  artifacts like other enterprise usage records.
- **Small teams are omitted.** Teams with fewer than five seated Copilot users
  do not appear in the user-team report. Their members' activity remains in the
  user report, so team totals can be lower than enterprise totals. See
  [Team-level Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-usage-metrics/team-level-metrics).
- **Single-enterprise scope.** Each call targets one enterprise, so
  multi-enterprise customers run the collection once per enterprise.
- **Usage-metrics policy must be on.** Without **Copilot usage metrics → Enabled
  everywhere**, the report endpoints return no data.
- **Updated App permissions may need approval.** After adding enterprise billing
  read access to an existing App, confirm the enterprise installation accepted
  it before deleting the old PAT secret.
- **Run against the prior complete day.** "Today" isn't fully processed yet;
  default to yesterday (UTC).

---

## Related

- [Copilot Metrics & Billing Dashboards in Grafana](copilot-metrics-grafana.md) —
  optional add-on that pushes these daily summaries into Postgres and reads them
  from Grafana, with an importable dashboard.
- [Managing Copilot usage-based billing](cost-management.md) — budgets, AI Credits,
  and keeping spend predictable.
- [Measuring AI in Pull Requests](ai-commit-attribution.md) — AI leverage from
  commit trailers and the Copilot usage metrics API.
