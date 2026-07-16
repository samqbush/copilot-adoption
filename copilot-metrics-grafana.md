---
layout: default
title: Copilot Metrics & Billing Dashboards in Grafana
description: An optional add-on to the data-lake guide — push daily Copilot usage and billing summaries into free Neon Postgres and read them from Grafana, with an importable dashboard.
toc: true
---

# Copilot Metrics & Billing Dashboards in Grafana
{:.no_toc}

*Last updated: July 16, 2026*

---

This is an **optional add-on** to
[Pulling Copilot Metrics & Billing Into Your Data Lake](copilot-metrics-billing.md).
That guide gets the raw usage JSON and billing CSV out of GitHub and into files.
This one turns those files into a live dashboard: the daily Action **pushes**
per-day summaries into a free Postgres database, and **Grafana reads** from
Postgres.

If you just want the raw data in your own warehouse, stop at the base guide —
you don't need any of this. Reach for this page when you want charts without
building your own BI layer.

---

## How it fits together

```
GitHub Actions (daily cron)
  ├─ collect job   (holds the App key + billing PAT)
  │    ├─ usage report JSON  +  billing CSV
  │    └─ upload as a 90-day artifact (backup only)
  └─ load-to-postgres job   (NO GitHub creds — only DATABASE_URL)
       └─ load_metrics.py distills one row per day → UPSERT into Postgres

Postgres (Neon)  ──SELECT──▶  Grafana dashboards
```

The Action **writes** to Postgres and Grafana only ever **reads** from it, so
**Grafana never holds a GitHub credential** — no App key, no PAT. The sensitive
GitHub credentials stay in the `collect` job; the `load-to-postgres` job sees
only the already-collected files and the database connection string.

> [!NOTE]
> The base guide's [`scripts/`](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/scripts)
> are meant for **quickly testing the APIs and your credentials** from a laptop.
> This add-on is the **durable pipeline**: it ships its own self-contained copies
> under [`grafana/scripts/`](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/grafana)
> plus the loader, the workflow, and the dashboard.

---

## Prerequisites

You need the **two credentials from the base guide** — the Enterprise GitHub App
(usage metrics) and the billing classic PAT. If you haven't created them, do
that first: [Set up the two credentials](copilot-metrics-billing.md#set-up-the-two-credentials).
This page adds one thing on top: a Postgres database.

---

## Why Postgres (and why Neon) {#why-postgres}

Grafana is only a visualization layer; it needs a datastore behind it. Two traps
to avoid:

- **Workflow artifacts** (what the base guide uploads) expire and Grafana can't
  query them — they're a backup, not a datasource.
- **Grafana Cloud's own time-series database** (Prometheus/Mimir) looks native,
  but its free tier retains only ~14 days. For adoption *trends* that's useless.

A small SQL database sidesteps both. [Neon](https://neon.tech) is fully-managed
serverless Postgres with a free tier and **no time-based expiry**, so a daily job
builds history indefinitely — nothing to host.

> [!NOTE]
> "No expiry" is not "unlimited space." The free tier has a fixed storage cap
> (currently ~0.5 GB). The daily aggregate rows are tiny, but `copilot_billing_raw`
> keeps a full copy of every billing CSV row and grows with your user count.
> Watch your database size in the Neon console; if it climbs, set a retention
> policy on the detail tables (see [Privacy](#privacy)) or skip the raw table.

---

## 1. Create a Neon database {#create-neon}

1. Sign up at [neon.tech](https://neon.tech) (free, no card) and **create a
   project** — Neon provisions a Postgres database.
2. Copy the **connection string** from the project dashboard. It looks like:

   ```
   postgresql://USER:PASSWORD@HOST/DBNAME?sslmode=require
   ```

Two Neon quirks worth knowing up front:

- **No port in the string.** Postgres uses `5432` implicitly. You still enter
  `HOST:5432` wherever a tool asks for host and port separately (Grafana, below).
- **Cold start.** Compute auto-suspends after ~5 min idle, so the first query
  after a lull takes a few seconds to wake. Neon doesn't pause the *project* on
  inactivity, so a daily job is safe.

---

## 2. Set the secrets {#secrets}

In the repo that will host the workflow: **Settings → Secrets and variables →
Actions**. The App ID / installation ID are identifiers (Variables); the key,
PAT, and connection string are sensitive (Secrets).

| Kind | Name | Value |
|------|------|-------|
| Variable | `ENTERPRISE` | your enterprise slug |
| Variable | `COPILOT_APP_ID` | the App ID |
| Variable | `COPILOT_INSTALLATION_ID` | the installation ID |
| Secret | `COPILOT_APP_PRIVATE_KEY` | the App's `.pem` contents |
| Secret | `GH_BILLING_TOKEN` | classic PAT (`manage_billing:enterprise`) |
| Secret | `DATABASE_URL` | the Neon connection string from step 1 |

```bash
gh variable set ENTERPRISE              --body "$ENTERPRISE"
gh variable set COPILOT_APP_ID          --body "$APP_ID"
gh variable set COPILOT_INSTALLATION_ID --body "$INSTALLATION_ID"
gh secret   set COPILOT_APP_PRIVATE_KEY < ./app.pem
gh secret   set GH_BILLING_TOKEN <<< "$GH_BILLING_TOKEN"
gh secret   set DATABASE_URL     <<< "$DATABASE_URL"
```

> [!IMPORTANT]
> `GH_BILLING_TOKEN` grants enterprise-wide billing access, and the **90-day
> artifact still contains the raw per-user billing CSV**. Host this workflow in a
> **dedicated private repo** with a protected default branch and minimal write
> access, and restrict who can download its artifacts.

---

## 3. Deploy the workflow and seed history {#deploy}

Copy the workflow and the three scripts into your repo so they land at these
paths (the workflow's `SCRIPTS_DIR` defaults to `scripts`):

```
.github/workflows/copilot-metrics-collection.yml   ← grafana/copilot-metrics-collection.yml
scripts/copilot-usage-metrics.sh                   ← grafana/scripts/copilot-usage-metrics.sh
scripts/copilot-billing-export.sh                  ← grafana/scripts/copilot-billing-export.sh
scripts/load_metrics.py                            ← grafana/scripts/load_metrics.py
```

Grab them from the
[`grafana/`](https://github.com/samqbush/copilot-adoption/tree/main/copilot-metrics-billing/grafana)
folder, commit, and push:

```bash
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/grafana
mkdir -p .github/workflows scripts
curl -fsSL "$base/copilot-metrics-collection.yml"     -o .github/workflows/copilot-metrics-collection.yml
curl -fsSL "$base/scripts/copilot-usage-metrics.sh"   -o scripts/copilot-usage-metrics.sh
curl -fsSL "$base/scripts/copilot-billing-export.sh"  -o scripts/copilot-billing-export.sh
curl -fsSL "$base/scripts/load_metrics.py"            -o scripts/load_metrics.py
git add .github/workflows/copilot-metrics-collection.yml scripts/
git commit -m "Add Copilot metrics + Grafana/Postgres collection workflow"
git push
```

The `load-to-postgres` job **creates the tables on first run** — the database
stays empty until then. Seed history once, then let the nightly cron take over:

```bash
# one-time: backfill the last 28 days (GitHub retains ~28 days of usage metrics)
gh workflow run copilot-metrics-collection.yml -f backfill_days=28
```

> [!NOTE]
> GitHub only shows **Run workflow** (and runs the cron) for workflows on the
> repo's **default branch**. Merge to default first, or dispatch against your
> branch with `gh workflow run … --ref <branch>`.

After the run, the nightly cron (05:17 UTC) collects yesterday and history grows.
Re-running any day just upserts — no duplicates.

---

## 4. Point Grafana at Postgres {#datasource}

Works on Grafana Cloud (free) or any Grafana. **Connections → Data sources → Add
data source → PostgreSQL**:

- **Host:** the `HOST` from the connection string with `:5432` appended
- **Database:** `DBNAME`
- **User / Password:** from the connection string (prefer the read-only role in
  [Privacy](#privacy))
- **TLS/SSL Mode:** `require`
- **Save & test.**

---

## 5. Import the dashboard {#import}

1. Grafana → **Dashboards → New → Import**.
2. Upload
   [`grafana/dashboard.json`](https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-billing/grafana/dashboard.json)
   (or paste its contents).
3. When prompted for the **`pg`** datasource variable, pick the PostgreSQL
   datasource from step 4.

The dashboard groups panels into rows — adoption KPIs, spend, power users (these
show usernames), activity, lines of code, pull requests, CLI, code-review
adoption, usage breakdowns, and a **Spend detail** row. Its `Top N`, `Model`,
`Cost center`, and `User` variables filter the power-user and per-model panels.
The time picker defaults to the last 90 days.

> [!TIP]
> **Billed (net) spend is often `$0`.** Enterprise quota and discounts usually
> cover the metered value, so `net_amount` reads `$0` on most days — expected,
> not a bug. To see *consumption*, read the **Spend detail** row (gross vs.
> discount vs. net), or set `BILLING_COST_COLUMN=gross_amount` in the workflow to
> make the canonical spend column track metered value.

---

## What lands in the database {#tables}

`load_metrics.py` creates and fills these tables (full column reference in the
loader's docstring):

| Table | Holds | Identities? |
|---|---|---|
| `copilot_usage` (+ `copilot_usage_ide` / `_feature` / `_model_feature` / `_language_model` / `_language_feature` / `_adoption_phase`) | per-day usage totals and aggregate breakdowns | no |
| `copilot_billing` | enterprise spend per day (net/gross/discount) | no |
| `copilot_billing_model` | spend per model per day | no |
| `copilot_billing_user` | spend per user/model/day | **yes (usernames)** |
| `copilot_billing_raw` | one row per billing CSV row, full row as JSONB | **yes (highest fidelity)** |

Aggregate tables are safe for broad dashboards. The last two are identifiable —
treat them as sensitive.

---

## Privacy {#privacy}

This pipeline **deliberately stores identifiable per-user billing detail** so an
admin can spot power users and their spend. That's a conscious choice — handle it
accordingly.

The bundled dashboard's power-user panels and the `User` / `Cost center`
variables **read `copilot_billing_user`**, so a Grafana role that can't see that
table will make those panels error rather than hide. Decide who should see
usernames, then grant to match. A least-privilege read-only role that powers the
full dashboard but can never touch the raw table:

```sql
-- Run AFTER the first workflow run has created the tables.
CREATE ROLE grafana_ro LOGIN PASSWORD 'choose-a-strong-password';
GRANT CONNECT ON DATABASE <dbname> TO grafana_ro;
GRANT USAGE ON SCHEMA public TO grafana_ro;

-- Everything the dashboard needs, EXCEPT copilot_billing_raw:
GRANT SELECT ON
  copilot_usage, copilot_usage_ide, copilot_usage_feature,
  copilot_usage_model_feature, copilot_usage_language_model,
  copilot_usage_language_feature, copilot_usage_adoption_phase,
  copilot_billing, copilot_billing_model, copilot_billing_user
TO grafana_ro;

-- Never expose the raw per-user JSONB, and don't auto-grant future tables:
REVOKE ALL ON copilot_billing_raw FROM grafana_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM grafana_ro;
```

Then use `grafana_ro` in the Grafana datasource (step 4) instead of the owner
credentials.

- **Don't want usernames in Grafana at all?** Omit `copilot_billing_user` from
  the `GRANT` above and delete the "Power users" dashboard row — the aggregate
  panels keep working.
- **Restrict the dashboard.** Use Grafana folder/team permissions so only the
  right people can open the power-user panels.
- **Never point Grafana at `copilot_billing_raw`.** It stores *every* CSV column
  as JSONB, so any field GitHub adds later (e.g. an email) silently widens
  exposure. Review it periodically and set a retention policy if you don't need
  unlimited per-user history.

---

## Gotchas

- **Empty billing days leave a chart gap.** A day with no billing activity
  produces an empty export, which the loader skips (no zero row). Widen the time
  range or read the usage panels if a recent day looks missing — and remember
  "latest spend" reflects the most recent day that *had* activity.
- **One billing report per enterprise at a time.** A second export while one is
  running returns `409`. The workflow serializes its own runs, but a manual
  export or another repo sharing the enterprise can still collide — retry later.
- **One enterprise per database.** The dashboard doesn't filter by enterprise
  slug, so point each enterprise at its own Neon database (or add an enterprise
  filter to every query).
- **Run against the prior complete day.** "Today" isn't fully processed; the
  workflow defaults to yesterday (UTC).
- **Usage vs. billing model names differ** (`claude-opus-4.6` vs.
  `Auto: GPT-5.3-Codex`). They're separate axes — don't join them; the `Model`
  filter is sourced from billing only.

---

## Related

- [Pulling Copilot Metrics & Billing Into Your Data Lake](copilot-metrics-billing.md)
  — the base guide this builds on (credentials, endpoints, the daily pull).
- [Managing Copilot usage-based billing](cost-management.md) — budgets, AI Credits,
  and keeping spend predictable.
