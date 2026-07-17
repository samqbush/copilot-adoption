#!/usr/bin/env python3
"""Load collected Copilot usage/billing summaries into Postgres (Neon).

This is the "push" half of the pipeline. The collection scripts drop raw files
into a directory (usage report JSON + billing CSV per day); this script writes
several Postgres tables (e.g. free Neon serverless Postgres). Grafana then reads
those tables via its native Postgres datasource — no GitHub credential lives in
Grafana.

It writes both enterprise-level aggregates AND identifiable per-user billing
detail (see Privacy). Grafana should read the aggregate tables / restricted
views, NOT the raw table.

Usage tables written:
    - copilot_usage          — one row per (scope, slug, day) with active/engaged
                               user totals plus enriched per-day scalars (activity,
                               LOC, pull_requests, totals_by_cli, code-review users).
    - copilot_usage_ide / _feature / _model_feature / _language_model /
      _language_feature / _adoption_phase — aggregate breakdowns from the report's
                               totals_by_* arrays (NO identities; safe for Grafana),
                               one row per dimension-combo per day.

Design notes
------------
* Privacy: the billing CSV contains per-user rows (username, cost_center_name,
  quotas). This loader INTENTIONALLY stores identifiable per-user billing detail
  so a Copilot admin can identify power users and their spend:
    - copilot_billing        — enterprise aggregate per day (no identities).
                               total_cost_usd is the actual billed amount
                               (net_amount); gross_cost_usd / discount_cost_usd
                               track metered value vs. quota/discount coverage so
                               divergence (e.g. quota exhaustion) is visible.
    - copilot_billing_model  — per-model aggregate per day (no identities)
    - copilot_billing_user   — per (day, user, model) aggregate (IDENTIFIABLE)
    - copilot_billing_raw    — one row per CSV row + full raw row as JSONB
                               (IDENTIFIABLE, highest fidelity)
  This is a deliberate reversal of the original "aggregate only" stance. Treat
  copilot_billing_user / copilot_billing_raw as sensitive: serve dashboards from
  aggregates or restricted views, use a least-privilege Grafana DB role, and set
  a retention policy. Dry-run output withholds per-user/raw rows by default
  (they contain usernames / full CSV cells) unless --show-raw is passed locally.
  Quota columns are NOT summed into the aggregate tables (their semantics vary);
  inspect copilot_billing_raw.raw for quota detail.
* Idempotency: aggregate rows (copilot_usage, copilot_billing) are keyed by a
  primary key and upserted with ON CONFLICT DO UPDATE; enriched copilot_usage
  columns are added with ADD COLUMN IF NOT EXISTS (additive, safe on existing
  DBs). The billing detail tables (raw/user/model) are replaced with a
  delete-by-day-then-insert scoped ONLY to days that produced parsed rows, and
  the copilot_usage_* breakdown tables are replaced by delete-then-insert scoped
  to the exact (scope, slug, day) keys whose payload contained that container, so
  a partial/empty export cannot wipe previously loaded good data.
* Robustness: the usage report and billing CSV schemas are confirmed against a
  real payload and mapped by their known field names, but the names are not
  contractually pinned by GitHub, so extraction keeps short candidate lists and
  NULL fallbacks as defense. ADJUST the candidate lists below, or set the
  BILLING_*_COLUMN env overrides, against a real payload if a field lands NULL or
  the wrong column is picked. Multi-row days sum additive counters only; unique
  user-counts/medians are taken from the first row (see extract_usage_scalars).
* Dry run: with no --database-url / DATABASE_URL, computed aggregates are printed
  as JSON and nothing is written — handy for local testing without a database.

Usage:
  load_metrics.py --data-dir copilot-data \
      [--database-url postgresql://...]   # or set DATABASE_URL
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import glob
import hashlib
import json
import os
import sys
from decimal import Decimal, InvalidOperation

# --- Candidate field/column names (best-effort; adapt to the real schema) ----
ACTIVE_USER_KEYS = ("total_active_users", "daily_active_users", "active_users", "total_active")
ENGAGED_USER_KEYS = ("total_engaged_users", "engaged_users", "total_engaged")
# In the current Copilot metrics report there is no top-level engaged total;
# total_engaged_users lives once per adoption-phase inside this list and must be
# SUMMED (not maxed) to get the day's engaged-user total.
ENGAGED_PHASE_CONTAINER = "totals_by_ai_adoption_phase"
ENGAGED_PHASE_KEY = "total_engaged_users"
COST_COLUMN_PATTERNS = (
    "net_amount", "gross_amount", "total_amount", "amount_usd",
    "cost_usd", "amount", "cost", "total", "usd",
)
# Additional money columns tracked alongside the primary spend column so we can
# see if/when actual billed cost (net) diverges from metered value (gross) or the
# quota/discount that covers it. Aggregated per day at the enterprise level only.
GROSS_COLUMN_PATTERNS = ("gross_amount", "aic_gross_amount")
DISCOUNT_COLUMN_PATTERNS = ("discount_amount",)
USER_COLUMN_PATTERNS = ("username", "user", "login", "handle")
MODEL_COLUMN_PATTERNS = ("model", "model_name", "sku", "product")
DATE_COLUMN_PATTERNS = ("date", "day", "usage_date", "billing_date", "timestamp")
COST_CENTER_COLUMN_PATTERNS = ("cost_center_name", "cost_center", "costcenter")
QUOTA_COLUMN_PATTERNS = ("quota",)
# Columns that superficially look cost-like (they contain "cost"/"total") but
# must NEVER be chosen as the spend column. Excluded from cost matching.
COST_EXCLUDE_PATTERNS = ("cost_center", "costcenter", "quota")

# Sentinels so a missing/unmatched username or model never becomes NULL in a
# primary key (Postgres PK columns are implicitly NOT NULL). Unknowns stay
# visible in the dashboard instead of failing the whole load.
UNKNOWN_USER = "__unknown_user__"
UNKNOWN_MODEL = "__unknown_model__"

# Optional explicit column overrides. CSV headers are not contractually pinned
# and a billing export can carry several cost-like columns (billed vs estimated
# vs credits); set these env vars to force a specific header when best-effort
# matching picks the wrong one.
COLUMN_OVERRIDE_ENV = {
    "cost": "BILLING_COST_COLUMN",
    "user": "BILLING_USER_COLUMN",
    "model": "BILLING_MODEL_COLUMN",
    "date": "BILLING_DATE_COLUMN",
    "cost_center": "BILLING_COST_CENTER_COLUMN",
}

CREATE_SQL = """
CREATE TABLE IF NOT EXISTS copilot_usage (
    day                 date        NOT NULL,
    scope               text        NOT NULL,
    slug                text        NOT NULL,
    report_day          date,
    report_start_day    date,
    report_end_day      date,
    total_active_users  integer,
    total_engaged_users integer,
    report_rows         integer,
    generated_at        timestamptz,
    source_run_id       text,
    source_repository   text,
    PRIMARY KEY (scope, slug, day)
);
CREATE TABLE IF NOT EXISTS copilot_billing (
    day                 date        NOT NULL,
    enterprise          text        NOT NULL,
    report_type         text        NOT NULL,
    total_cost_usd      numeric,
    gross_cost_usd      numeric,
    discount_cost_usd   numeric,
    billing_rows        integer,
    cost_rows_counted   integer,
    user_count          integer,
    model_count         integer,
    generated_at        timestamptz,
    source_run_id       text,
    source_repository   text,
    PRIMARY KEY (enterprise, day, report_type)
);
-- Full-fidelity raw billing facts: ONE row per CSV row. Holds identifiable
-- per-user data plus the complete original row as JSONB. Do NOT expose this
-- table (especially `raw`) directly to Grafana; serve dashboards from the
-- derived aggregate tables / restricted views instead.
CREATE TABLE IF NOT EXISTS copilot_billing_raw (
    enterprise          text        NOT NULL,
    day                 date        NOT NULL,
    row_hash            text        NOT NULL,
    username            text,
    model               text,
    cost_center_name    text,
    cost_usd            numeric,
    raw                 jsonb,
    generated_at        timestamptz,
    source_run_id       text,
    source_repository   text,
    PRIMARY KEY (enterprise, day, row_hash)
);
-- Derived per-user aggregate (identifiable). username_key/model_key use
-- sentinels for missing values so unknowns stay visible and never violate the
-- primary key. Quota columns are intentionally NOT summed here (their semantics
-- vary); inspect `copilot_billing_raw.raw` for quota detail.
CREATE TABLE IF NOT EXISTS copilot_billing_user (
    enterprise          text        NOT NULL,
    day                 date        NOT NULL,
    username_key        text        NOT NULL,
    model_key           text        NOT NULL,
    cost_center_name    text,
    total_cost_usd      numeric,
    cost_rows_counted   integer,
    row_count           integer,
    generated_at        timestamptz,
    source_run_id       text,
    source_repository   text,
    PRIMARY KEY (enterprise, day, username_key, model_key)
);
-- Derived per-model aggregate (NO identities) — safe for broad dashboard use.
CREATE TABLE IF NOT EXISTS copilot_billing_model (
    enterprise          text        NOT NULL,
    day                 date        NOT NULL,
    model_key           text        NOT NULL,
    total_cost_usd      numeric,
    user_count          integer,
    row_count           integer,
    generated_at        timestamptz,
    source_run_id       text,
    source_repository   text,
    PRIMARY KEY (enterprise, day, model_key)
);
-- Identity enrichment (IDENTIFIABLE — emails are PII). Maps a billing username
-- (username_key, matching copilot_billing_user.username_key) to the member's
-- primary email from the SCIM API, so dashboards can display emails instead of
-- usernames via a LEFT JOIN with a COALESCE(email, username_key) fallback. This
-- is a full snapshot refreshed each run (no per-day history); the join keeps
-- every historical billing day labeled with the current email. Treat as
-- sensitive: expose only through restricted views / a least-privilege role.
CREATE TABLE IF NOT EXISTS copilot_enterprise_users (
    enterprise          text        NOT NULL,
    username_key        text        NOT NULL,
    email               text,
    scim_user_name      text,
    external_id         text,
    display_name        text,
    active              boolean,
    generated_at        timestamptz,
    source_run_id       text,
    source_repository   text,
    PRIMARY KEY (enterprise, username_key)
);
-- Idempotent migrations for columns added to pre-existing tables. Postgres
-- supports ADD COLUMN IF NOT EXISTS, so these are safe to run on every load.
ALTER TABLE copilot_billing ADD COLUMN IF NOT EXISTS gross_cost_usd numeric;
ALTER TABLE copilot_billing ADD COLUMN IF NOT EXISTS discount_cost_usd numeric;
"""

# UPSERT_USAGE is generated from USAGE_METRIC_DEFS further down (build_usage_sql)
# so the enriched scalar columns stay in sync across DDL, INSERT and UPDATE.

UPSERT_BILLING = """
INSERT INTO copilot_billing (
    day, enterprise, report_type, total_cost_usd, gross_cost_usd,
    discount_cost_usd, billing_rows,
    cost_rows_counted, user_count, model_count,
    generated_at, source_run_id, source_repository
) VALUES (
    %(day)s, %(enterprise)s, %(report_type)s, %(total_cost_usd)s,
    %(gross_cost_usd)s, %(discount_cost_usd)s,
    %(billing_rows)s, %(cost_rows_counted)s, %(user_count)s, %(model_count)s,
    %(generated_at)s, %(source_run_id)s, %(source_repository)s
)
ON CONFLICT (enterprise, day, report_type) DO UPDATE SET
    total_cost_usd = EXCLUDED.total_cost_usd,
    gross_cost_usd = EXCLUDED.gross_cost_usd,
    discount_cost_usd = EXCLUDED.discount_cost_usd,
    billing_rows = EXCLUDED.billing_rows,
    cost_rows_counted = EXCLUDED.cost_rows_counted,
    user_count = EXCLUDED.user_count,
    model_count = EXCLUDED.model_count,
    generated_at = EXCLUDED.generated_at,
    source_run_id = EXCLUDED.source_run_id,
    source_repository = EXCLUDED.source_repository;
"""

# New detail tables use delete-by-day-then-insert (see load_to_postgres) so a
# user/model that drops out of a re-export is removed rather than left stale.
DELETE_RAW_DAY = "DELETE FROM copilot_billing_raw WHERE enterprise = %(enterprise)s AND day = %(day)s;"
DELETE_USER_DAY = "DELETE FROM copilot_billing_user WHERE enterprise = %(enterprise)s AND day = %(day)s;"
DELETE_MODEL_DAY = "DELETE FROM copilot_billing_model WHERE enterprise = %(enterprise)s AND day = %(day)s;"

INSERT_RAW = """
INSERT INTO copilot_billing_raw (
    enterprise, day, row_hash, username, model, cost_center_name, cost_usd,
    raw, generated_at, source_run_id, source_repository
) VALUES (
    %(enterprise)s, %(day)s, %(row_hash)s, %(username)s, %(model)s,
    %(cost_center_name)s, %(cost_usd)s, %(raw)s, %(generated_at)s,
    %(source_run_id)s, %(source_repository)s
);
"""

INSERT_USER = """
INSERT INTO copilot_billing_user (
    enterprise, day, username_key, model_key, cost_center_name, total_cost_usd,
    cost_rows_counted, row_count, generated_at, source_run_id, source_repository
) VALUES (
    %(enterprise)s, %(day)s, %(username_key)s, %(model_key)s,
    %(cost_center_name)s, %(total_cost_usd)s, %(cost_rows_counted)s,
    %(row_count)s, %(generated_at)s, %(source_run_id)s, %(source_repository)s
);
"""

INSERT_MODEL = """
INSERT INTO copilot_billing_model (
    enterprise, day, model_key, total_cost_usd, user_count, row_count,
    generated_at, source_run_id, source_repository
) VALUES (
    %(enterprise)s, %(day)s, %(model_key)s, %(total_cost_usd)s, %(user_count)s,
    %(row_count)s, %(generated_at)s, %(source_run_id)s, %(source_repository)s
);
"""

# Identity enrichment: full-snapshot upsert keyed on (enterprise, username_key).
# The whole enterprise's mapping is deleted then re-inserted each run so users
# who leave SCIM stop labeling billing rows; scoped to the snapshot's enterprise
# so other enterprises' rows are untouched.
DELETE_ENTERPRISE_USERS = (
    "DELETE FROM copilot_enterprise_users WHERE enterprise = %(enterprise)s;"
)

UPSERT_ENTERPRISE_USERS = """
INSERT INTO copilot_enterprise_users (
    enterprise, username_key, email, scim_user_name, external_id,
    display_name, active, generated_at, source_run_id, source_repository
) VALUES (
    %(enterprise)s, %(username_key)s, %(email)s, %(scim_user_name)s,
    %(external_id)s, %(display_name)s, %(active)s, %(generated_at)s,
    %(source_run_id)s, %(source_repository)s
)
ON CONFLICT (enterprise, username_key) DO UPDATE SET
    email = EXCLUDED.email,
    scim_user_name = EXCLUDED.scim_user_name,
    external_id = EXCLUDED.external_id,
    display_name = EXCLUDED.display_name,
    active = EXCLUDED.active,
    generated_at = EXCLUDED.generated_at,
    source_run_id = EXCLUDED.source_run_id,
    source_repository = EXCLUDED.source_repository;
"""

# --- Enriched usage metrics --------------------------------------------------
# Confirmed against a real enterprise payload. Each report row (normally one per
# day) carries these scalar fields in addition to active/engaged users. `section`
# says where the value lives: 'top' = the report row, 'pr' = pull_requests{},
# 'cli' = totals_by_cli{}, 'cli_token' = totals_by_cli.token_usage{}. `additive`
# governs multi-row aggregation: true counters are SUMMED across report rows,
# while unique-user counts / medians / averages are NOT (see extract_usage_scalars).
# (column, json_key, section, additive, sql_type)
USAGE_METRIC_DEFS = [
    ("daily_active_users", "daily_active_users", "top", False, "bigint"),
    ("weekly_active_users", "weekly_active_users", "top", False, "bigint"),
    ("monthly_active_users", "monthly_active_users", "top", False, "bigint"),
    ("daily_active_cli_users", "daily_active_cli_users", "top", False, "bigint"),
    ("daily_active_cloud_agent_users", "daily_active_copilot_cloud_agent_users", "top", False, "bigint"),
    ("weekly_active_cloud_agent_users", "weekly_active_copilot_cloud_agent_users", "top", False, "bigint"),
    ("monthly_active_cloud_agent_users", "monthly_active_copilot_cloud_agent_users", "top", False, "bigint"),
    ("monthly_active_chat_users", "monthly_active_chat_users", "top", False, "bigint"),
    ("monthly_active_agent_users", "monthly_active_agent_users", "top", False, "bigint"),
    ("daily_active_code_review_users", "daily_active_copilot_code_review_users", "top", False, "bigint"),
    ("weekly_active_code_review_users", "weekly_active_copilot_code_review_users", "top", False, "bigint"),
    ("monthly_active_code_review_users", "monthly_active_copilot_code_review_users", "top", False, "bigint"),
    ("daily_passive_code_review_users", "daily_passive_copilot_code_review_users", "top", False, "bigint"),
    ("weekly_passive_code_review_users", "weekly_passive_copilot_code_review_users", "top", False, "bigint"),
    ("monthly_passive_code_review_users", "monthly_passive_copilot_code_review_users", "top", False, "bigint"),
    ("user_initiated_interactions", "user_initiated_interaction_count", "top", True, "bigint"),
    ("code_generation_activities", "code_generation_activity_count", "top", True, "bigint"),
    ("code_acceptance_activities", "code_acceptance_activity_count", "top", True, "bigint"),
    ("loc_suggested_added", "loc_suggested_to_add_sum", "top", True, "bigint"),
    ("loc_suggested_deleted", "loc_suggested_to_delete_sum", "top", True, "bigint"),
    ("loc_added", "loc_added_sum", "top", True, "bigint"),
    ("loc_deleted", "loc_deleted_sum", "top", True, "bigint"),
    ("pr_total_reviewed", "total_reviewed", "pr", True, "bigint"),
    ("pr_total_created", "total_created", "pr", True, "bigint"),
    ("pr_created_by_copilot", "total_created_by_copilot", "pr", True, "bigint"),
    ("pr_reviewed_by_copilot", "total_reviewed_by_copilot", "pr", True, "bigint"),
    ("pr_total_merged", "total_merged", "pr", True, "bigint"),
    ("pr_median_minutes_to_merge", "median_minutes_to_merge", "pr", False, "numeric"),
    ("cli_session_count", "session_count", "cli", True, "bigint"),
    ("cli_request_count", "request_count", "cli", True, "bigint"),
    ("cli_prompt_count", "prompt_count", "cli", True, "bigint"),
    ("cli_output_tokens_sum", "output_tokens_sum", "cli_token", True, "bigint"),
    ("cli_prompt_tokens_sum", "prompt_tokens_sum", "cli_token", True, "bigint"),
    ("cli_avg_tokens_per_request", "avg_tokens_per_request", "cli_token", False, "numeric"),
]
USAGE_EXTRA_COLUMNS = [d[0] for d in USAGE_METRIC_DEFS]

# --- Usage breakdown tables (aggregate; NO identities → safe for Grafana) -----
# Each `totals_by_*` array becomes one row per dimension-combo per day. Dimension
# keys are sentinel-normalized so a missing/empty value never violates the PK
# (real API literals like "unknown"/"others" are left as-is). Populated with
# delete-then-insert scoped to (scope, slug, day), but ONLY for days where the
# container was present in the payload (see load_to_postgres) so a partial export
# can't wipe history.
BREAKDOWN_DEFS = [
    {
        "table": "copilot_usage_ide",
        "container": "totals_by_ide",
        "dims": [("ide", "ide", "__unknown_ide__")],
        "sums": [
            ("user_initiated_interactions", "user_initiated_interaction_count"),
            ("code_generation_activities", "code_generation_activity_count"),
            ("code_acceptance_activities", "code_acceptance_activity_count"),
            ("loc_suggested_added", "loc_suggested_to_add_sum"),
            ("loc_suggested_deleted", "loc_suggested_to_delete_sum"),
            ("loc_added", "loc_added_sum"),
            ("loc_deleted", "loc_deleted_sum"),
        ],
        "attrs": [],
    },
    {
        "table": "copilot_usage_feature",
        "container": "totals_by_feature",
        "dims": [("feature", "feature", "__unknown_feature__")],
        "sums": [
            ("user_initiated_interactions", "user_initiated_interaction_count"),
            ("code_generation_activities", "code_generation_activity_count"),
            ("code_acceptance_activities", "code_acceptance_activity_count"),
            ("loc_suggested_added", "loc_suggested_to_add_sum"),
            ("loc_suggested_deleted", "loc_suggested_to_delete_sum"),
            ("loc_added", "loc_added_sum"),
            ("loc_deleted", "loc_deleted_sum"),
        ],
        "attrs": [],
    },
    {
        "table": "copilot_usage_model_feature",
        "container": "totals_by_model_feature",
        "dims": [
            ("model", "model", "__unknown_model__"),
            ("feature", "feature", "__unknown_feature__"),
        ],
        "sums": [
            ("user_initiated_interactions", "user_initiated_interaction_count"),
            ("code_generation_activities", "code_generation_activity_count"),
            ("code_acceptance_activities", "code_acceptance_activity_count"),
            ("loc_suggested_added", "loc_suggested_to_add_sum"),
            ("loc_suggested_deleted", "loc_suggested_to_delete_sum"),
            ("loc_added", "loc_added_sum"),
            ("loc_deleted", "loc_deleted_sum"),
        ],
        "attrs": [],
    },
    {
        "table": "copilot_usage_language_model",
        "container": "totals_by_language_model",
        "dims": [
            ("language", "language", "__unknown_language__"),
            ("model", "model", "__unknown_model__"),
        ],
        "sums": [
            ("code_generation_activities", "code_generation_activity_count"),
            ("code_acceptance_activities", "code_acceptance_activity_count"),
            ("loc_suggested_added", "loc_suggested_to_add_sum"),
            ("loc_suggested_deleted", "loc_suggested_to_delete_sum"),
            ("loc_added", "loc_added_sum"),
            ("loc_deleted", "loc_deleted_sum"),
        ],
        "attrs": [],
    },
    {
        "table": "copilot_usage_language_feature",
        "container": "totals_by_language_feature",
        "dims": [
            ("language", "language", "__unknown_language__"),
            ("feature", "feature", "__unknown_feature__"),
        ],
        "sums": [
            ("code_generation_activities", "code_generation_activity_count"),
            ("code_acceptance_activities", "code_acceptance_activity_count"),
            ("loc_suggested_added", "loc_suggested_to_add_sum"),
            ("loc_suggested_deleted", "loc_suggested_to_delete_sum"),
            ("loc_added", "loc_added_sum"),
            ("loc_deleted", "loc_deleted_sum"),
        ],
        "attrs": [],
    },
    {
        "table": "copilot_usage_adoption_phase",
        "container": "totals_by_ai_adoption_phase",
        "dims": [("phase", "phase", "__unknown_phase__")],
        "sums": [("total_engaged_users", "total_engaged_users")],
        "attrs": [
            ("phase_number", "phase_number", "integer"),
            ("avg_user_initiated_interactions", "avg_user_initiated_interactions", "numeric"),
            ("avg_code_generation_activities", "avg_code_generation_activities", "numeric"),
            ("avg_code_acceptance_activities", "avg_code_acceptance_activities", "numeric"),
            ("avg_loc_added", "avg_loc_added", "numeric"),
            ("avg_loc_deleted", "avg_loc_deleted", "numeric"),
            ("avg_pull_requests_reviewed", "avg_pull_requests_reviewed", "numeric"),
            ("avg_pull_requests_created", "avg_pull_requests_created", "numeric"),
            ("avg_pull_requests_merged", "avg_pull_requests_merged", "numeric"),
            ("avg_pull_requests_median_minutes_to_merge", "avg_pull_requests_median_minutes_to_merge", "numeric"),
        ],
    },
]


def _build_usage_ddl() -> str:
    """ALTER statements adding every enriched scalar column to copilot_usage.
    ADD COLUMN IF NOT EXISTS is idempotent and additive, so existing rows keep
    working (new columns are nullable and backfill on the next run)."""
    lines = []
    for column, _key, _section, _additive, sqltype in USAGE_METRIC_DEFS:
        lines.append(
            f"ALTER TABLE copilot_usage ADD COLUMN IF NOT EXISTS {column} {sqltype};")
    return "\n".join(lines)


def _build_usage_upsert() -> str:
    base = ["day", "scope", "slug", "report_day", "report_start_day",
            "report_end_day", "total_active_users", "total_engaged_users",
            "report_rows"]
    prov = ["generated_at", "source_run_id", "source_repository"]
    cols = base + USAGE_EXTRA_COLUMNS + prov
    collist = ", ".join(cols)
    values = ", ".join(f"%({c})s" for c in cols)
    updates = ",\n    ".join(
        f"{c} = EXCLUDED.{c}" for c in cols if c not in ("day", "scope", "slug"))
    return (
        f"INSERT INTO copilot_usage (\n    {collist}\n) VALUES (\n    {values}\n)\n"
        f"ON CONFLICT (scope, slug, day) DO UPDATE SET\n    {updates};")


def _build_breakdown_ddl() -> str:
    stmts = []
    for d in BREAKDOWN_DEFS:
        dim_cols = [c for c, _k, _s in d["dims"]]
        lines = [
            f"CREATE TABLE IF NOT EXISTS {d['table']} (",
            "    day                 date NOT NULL,",
            "    scope               text NOT NULL,",
            "    slug                text NOT NULL,",
        ]
        for c, _k, _s in d["dims"]:
            lines.append(f"    {c} text NOT NULL,")
        for c, _k in d["sums"]:
            lines.append(f"    {c} bigint,")
        for c, _k, sqltype in d["attrs"]:
            lines.append(f"    {c} {sqltype},")
        lines.append("    generated_at        timestamptz,")
        lines.append("    source_run_id       text,")
        lines.append("    source_repository   text,")
        pk = ", ".join(["scope", "slug", "day"] + dim_cols)
        lines.append(f"    PRIMARY KEY ({pk})")
        lines.append(");")
        stmts.append("\n".join(lines))
    return "\n".join(stmts)


def build_breakdown_sql():
    """Return {table: {"delete": sql, "insert": sql, "columns": [...]}}."""
    out = {}
    for d in BREAKDOWN_DEFS:
        dim_cols = [c for c, _k, _s in d["dims"]]
        sum_cols = [c for c, _k in d["sums"]]
        attr_cols = [c for c, _k, _s in d["attrs"]]
        cols = (["day", "scope", "slug"] + dim_cols + sum_cols + attr_cols
                + ["generated_at", "source_run_id", "source_repository"])
        collist = ", ".join(cols)
        values = ", ".join(f"%({c})s" for c in cols)
        out[d["table"]] = {
            "delete": (f"DELETE FROM {d['table']} WHERE scope = %(scope)s "
                       f"AND slug = %(slug)s AND day = %(day)s;"),
            "insert": f"INSERT INTO {d['table']} (\n    {collist}\n) VALUES (\n    {values}\n);",
            "columns": cols,
        }
    return out


# Wire the generated DDL/DML into the module-level SQL used by load_to_postgres.
CREATE_SQL = CREATE_SQL + "\n" + _build_usage_ddl() + "\n" + _build_breakdown_ddl() + "\n"
UPSERT_USAGE = _build_usage_upsert()
BREAKDOWN_SQL = build_breakdown_sql()


def log(msg: str) -> None:
    print(f"[load] {msg}", file=sys.stderr)


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def find_numbers_by_key(obj, candidates_lower) -> "list[int]":
    found = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str) and k.lower() in candidates_lower and isinstance(v, (int, float)) and not isinstance(v, bool):
                found.append(int(v))
            found.extend(find_numbers_by_key(v, candidates_lower))
    elif isinstance(obj, list):
        for item in obj:
            found.extend(find_numbers_by_key(item, candidates_lower))
    return found


def extract_total(report, candidate_keys) -> "int | None":
    cands = {c.lower() for c in candidate_keys}
    nums = find_numbers_by_key(report, cands)
    return max(nums) if nums else None


def _first_present_number(d, keys) -> "int | None":
    """First top-level key in `keys` present on dict `d` with a numeric value."""
    for k in keys:
        v = d.get(k)
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            return int(v)
    return None


def _report_rows(report) -> "list":
    if isinstance(report, list):
        return [r for r in report if isinstance(r, dict)]
    if isinstance(report, dict):
        return [report]
    return []


def extract_active_users(report) -> "int | None":
    """Top-level active-user count. This is a unique-user count, so it is NOT
    additive across report rows — take the first present value (matching the
    first-row convention in extract_usage_scalars / the module docstring)."""
    for n in (_first_present_number(r, ACTIVE_USER_KEYS)
              for r in _report_rows(report)):
        if n is not None:
            return n
    return None


def extract_engaged_users(report) -> "int | None":
    """Engaged-user total. Unique-user counts are NOT additive across report
    rows, so this reads a single row (the first one; report normally has exactly
    one). Within that row it prefers a top-level total; otherwise it SUMS the
    per-adoption-phase total_engaged_users values (the current report's shape)."""
    for r in _report_rows(report):
        top = _first_present_number(r, ENGAGED_USER_KEYS)
        if top is not None:
            return top
        phases = r.get(ENGAGED_PHASE_CONTAINER)
        if isinstance(phases, list):
            total = 0
            found = False
            for p in phases:
                if isinstance(p, dict):
                    v = p.get(ENGAGED_PHASE_KEY)
                    if isinstance(v, (int, float)) and not isinstance(v, bool):
                        total += int(v)
                        found = True
            if found:
                return total
    return None


def _num(v):
    """Return v if it is a real (non-bool) number, else None."""
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def _sources_for_section(rows, section):
    """The list of dicts a metric section lives in, across report rows."""
    if section == "top":
        return rows
    if section == "pr":
        return [r.get("pull_requests") for r in rows
                if isinstance(r.get("pull_requests"), dict)]
    if section == "cli":
        return [r.get("totals_by_cli") for r in rows
                if isinstance(r.get("totals_by_cli"), dict)]
    if section == "cli_token":
        out = []
        for r in rows:
            cli = r.get("totals_by_cli")
            if isinstance(cli, dict) and isinstance(cli.get("token_usage"), dict):
                out.append(cli["token_usage"])
        return out
    return []


def extract_usage_scalars(rows) -> dict:
    """Extract every enriched scalar in USAGE_METRIC_DEFS from the report rows.

    Additive counters are SUMMED across rows; unique-user counts, medians and
    averages are NOT summed (that would double-count) — the first present value
    is used. Report normally has exactly one row, so on the common path both are
    equivalent; the distinction only matters if GitHub ever segments a day."""
    out = {}
    for column, key, section, additive, _sqltype in USAGE_METRIC_DEFS:
        sources = _sources_for_section(rows, section)
        vals = [n for n in (_num(s.get(key)) for s in sources
                            if isinstance(s, dict)) if n is not None]
        if not vals:
            out[column] = None
        elif additive:
            out[column] = sum(vals)
        else:
            out[column] = vals[0]
    return out


def extract_usage_breakdowns(day, scope, slug, rows, run_id, repo):
    """Turn each totals_by_* array into aggregate breakdown rows.

    Returns (rows_by_table, present_containers). Rows are pre-aggregated by their
    full dimension tuple (summing additive metrics) so a repeated dimension combo
    within a day can never collide on the table's primary key. `present` records
    which containers actually appeared in the payload so the loader only replaces
    breakdown rows for containers that were present (an absent container is left
    untouched rather than wiped)."""
    generated = now_iso()
    rows_by_table = {}
    present = set()
    for d in BREAKDOWN_DEFS:
        table = d["table"]
        container = d["container"]
        groups = {}
        container_seen = False
        for r in rows:
            arr = r.get(container)
            if isinstance(arr, list):
                container_seen = True
            else:
                continue
            for item in arr:
                if not isinstance(item, dict):
                    continue
                dim_vals = tuple(
                    _dim_value(item, key, sentinel)
                    for _col, key, sentinel in d["dims"])
                g = groups.get(dim_vals)
                if g is None:
                    g = {"sums": {c: None for c, _k in d["sums"]},
                         "attrs": {c: None for c, _k, _s in d["attrs"]}}
                    groups[dim_vals] = g
                for col, key in d["sums"]:
                    n = _num(item.get(key))
                    if n is not None:
                        g["sums"][col] = (g["sums"][col] or 0) + n
                for col, key, _sqltype in d["attrs"]:
                    if g["attrs"][col] is None:
                        n = _num(item.get(key))
                        if n is not None:
                            g["attrs"][col] = n
        if container_seen:
            present.add(table)
        table_rows = []
        for dim_vals, g in groups.items():
            rec = {"day": day, "scope": scope, "slug": slug,
                   "generated_at": generated,
                   "source_run_id": run_id or None,
                   "source_repository": repo or None}
            for (col, _key, _sentinel), val in zip(d["dims"], dim_vals):
                rec[col] = val
            rec.update(g["sums"])
            rec.update(g["attrs"])
            table_rows.append(rec)
        rows_by_table[table] = table_rows
    return rows_by_table, present


def _dim_value(item, key, sentinel):
    """Sentinel-normalize a dimension key. Empty/missing → sentinel; real API
    literals like 'unknown'/'others' are preserved as-is."""
    v = item.get(key)
    if v is None:
        return sentinel
    s = str(v).strip()
    return s if s else sentinel


def merge_breakdown_rows(defn, rows):
    """Re-aggregate already-built breakdown rows by their full primary key
    (scope, slug, day, *dims). extract_usage_breakdowns aggregates within a
    single payload; this merges ACROSS payloads so two input files that resolve
    to the same (scope, slug, day) and share a dimension can never produce two
    rows with the same PK (which would abort the load on INSERT). Additive
    metrics are summed; attribute (first-seen) fields keep the first non-null."""
    dim_cols = [c for c, _k, _s in defn["dims"]]
    sum_cols = [c for c, _k in defn["sums"]]
    attr_cols = [c for c, _k, _s in defn["attrs"]]
    groups = {}
    order = []
    for r in rows:
        key = (r["scope"], r["slug"], r["day"]) + tuple(r[c] for c in dim_cols)
        g = groups.get(key)
        if g is None:
            groups[key] = dict(r)
            order.append(key)
            continue
        for c in sum_cols:
            a, b = g.get(c), r.get(c)
            g[c] = b if a is None else (a if b is None else a + b)
        for c in attr_cols:
            if g.get(c) is None and r.get(c) is not None:
                g[c] = r[c]
    return [groups[k] for k in order]


def summarize_usage(path: str, run_id: str, repo: str) -> "dict | None":
    try:
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        log(f"WARNING: cannot read usage file {path}: {exc}")
        return None

    report = doc.get("report", [])
    meta = doc.get("report_meta", {}) or {}
    day = doc.get("day") or meta.get("report_day")
    if not day:
        log(f"WARNING: no day in {path}; skipping")
        return None

    rows = _report_rows(report)
    if len(rows) > 1:
        log(f"WARNING: {path} has {len(rows)} report rows for {day}; summing "
            f"additive counters but taking unique-user counts/medians from the "
            f"first row only (they are not additive across rows).")

    active = extract_active_users(report)
    engaged = extract_engaged_users(report)
    if active is None and engaged is None:
        # Last-resort generic search for other/older report shapes.
        active = extract_total(report, ACTIVE_USER_KEYS)
        engaged = extract_total(report, ENGAGED_USER_KEYS)
    if active is None and engaged is None:
        log(f"WARNING: no active/engaged totals matched in {path}. "
            f"Adjust ACTIVE_USER_KEYS/ENGAGED_USER_KEYS to the real schema.")

    scope = doc.get("scope")
    slug = doc.get("slug")
    record = {
        "day": day,
        "scope": scope,
        "slug": slug,
        "report_day": meta.get("report_day"),
        "report_start_day": meta.get("report_start_day"),
        "report_end_day": meta.get("report_end_day"),
        "total_active_users": active,
        "total_engaged_users": engaged,
        "report_rows": len(rows),
        "generated_at": now_iso(),
        "source_run_id": run_id or None,
        "source_repository": repo or None,
    }
    record.update(extract_usage_scalars(rows))

    breakdown_rows, present = extract_usage_breakdowns(
        day, scope, slug, rows, run_id, repo)
    return {
        "usage": record,
        "breakdowns": breakdown_rows,
        "present": present,
        "key": (scope, slug, day),
    }



def pick_column(fieldnames, patterns, exclude=()) -> "str | None":
    def is_excluded(low):
        return any(x in low for x in exclude)
    lowered = {fn.lower(): fn for fn in fieldnames if fn and not is_excluded(fn.lower())}
    for pat in patterns:
        if pat in lowered:
            return lowered[pat]
    for pat in patterns:
        for low, orig in lowered.items():
            if pat in low:
                return orig
    return None


def resolve_column(kind, fieldnames, patterns, path, exclude=()) -> "str | None":
    """Resolve a CSV column for `kind`, honoring an explicit env override.

    Env overrides (see COLUMN_OVERRIDE_ENV) win over best-effort matching, which
    matters because a billing export can carry several cost-like columns. Columns
    matching `exclude` are ignored (e.g. cost_center / quota columns are never
    treated as the spend column). Warns when the override names a header that
    isn't present, and when best-effort matching finds more than one plausible
    substring match (ambiguous)."""
    env_name = COLUMN_OVERRIDE_ENV.get(kind)
    override = os.environ.get(env_name, "").strip() if env_name else ""
    if override:
        by_lower = {fn.lower(): fn for fn in fieldnames if fn}
        if override in fieldnames:
            return override
        if override.lower() in by_lower:
            return by_lower[override.lower()]
        log(f"WARNING: {env_name}='{override}' not found in headers of {path} "
            f"(headers: {fieldnames}); falling back to best-effort matching.")

    def is_excluded(low):
        return any(x in low for x in exclude)
    matches = [orig for orig in fieldnames if orig and not is_excluded(orig.lower())
               and any(pat in orig.lower() for pat in patterns)]
    unique = sorted(set(matches))
    chosen = pick_column(fieldnames, patterns, exclude=exclude)
    # An exact, highest-priority pattern match is a deliberate, unambiguous
    # choice (e.g. we prefer `net_amount` even when gross/discount also exist),
    # so only warn when we had to fall back to fuzzy substring matching.
    pattern_set = {p.lower() for p in patterns}
    exact = chosen is not None and chosen.lower() in pattern_set
    if not exact and len(unique) > 1:
        hint = (f"set {env_name} to disambiguate" if env_name
                else "no override env var exists for this column")
        log(f"WARNING: multiple candidate {kind} columns in {path}: {unique}. "
            f"Using best-effort match ({hint}).")
    return chosen


def parse_day_from_billing_filename(path: str) -> "str | None":
    base = os.path.basename(path)
    stem = base[:-4] if base.lower().endswith(".csv") else base
    parts = stem.split("-")
    if len(parts) >= 3:
        cand = "-".join(parts[-3:])
        try:
            dt.date.fromisoformat(cand)
            return cand
        except ValueError:
            return None
    return None


def normalize_day(value: str) -> "str | None":
    """Return a YYYY-MM-DD date from a CSV cell, or None if unparseable.

    Handles bare dates and ISO timestamps (e.g. '2026-07-10T00:00:00Z')."""
    if not value:
        return None
    v = value.strip()
    if not v:
        return None
    head = v[:10]
    try:
        dt.date.fromisoformat(head)
        return head
    except ValueError:
        pass
    try:
        return dt.datetime.fromisoformat(v.replace("Z", "+00:00")).date().isoformat()
    except ValueError:
        return None


def _parse_cost(raw_value):
    """Parse a cost cell into a Decimal, or None if blank/non-numeric."""
    cleaned = (raw_value or "").strip().replace("$", "").replace(",", "")
    if not cleaned:
        return None
    try:
        return Decimal(cleaned)
    except InvalidOperation:
        return "INVALID"


def summarize_billing(path: str, run_id: str, repo: str, enterprise: str) -> dict:
    """Summarize a billing CSV into four record sets keyed by day.

    Returns a dict with keys:
      * ``enterprise`` — ONE aggregate row per day (backward-compatible; feeds
        ``copilot_billing``).
      * ``user``       — one aggregate row per (day, username, model) — feeds
        ``copilot_billing_user`` (identifiable).
      * ``model``      — one aggregate row per (day, model) — feeds
        ``copilot_billing_model`` (no identities).
      * ``raw``        — one row per CSV row, with the full original row as JSON —
        feeds ``copilot_billing_raw`` (full fidelity; do not expose to Grafana).
      * ``days``       — the set of days that produced parsed rows (used by the
        loader to scope its delete-by-day replacement; a day absent here is NOT
        deleted, so a partial/empty export can't wipe good data).

    Rows are grouped by the CSV's own date column; a ranged export yields one set
    of rows per day. If there is no date column, the whole file falls back to the
    day parsed from the filename (single-day behavior)."""
    empty = {"enterprise": [], "user": [], "model": [], "raw": [], "days": set()}
    try:
        with open(path, newline="", encoding="utf-8-sig") as fh:
            reader = csv.DictReader(fh)
            rows = list(reader)
            fieldnames = reader.fieldnames or []
    except OSError as exc:
        log(f"WARNING: cannot read billing file {path}: {exc}")
        return empty

    if not rows:
        log(f"billing {os.path.basename(path)}: empty report (no billing activity).")
        return empty

    cost_col = resolve_column("cost", fieldnames, COST_COLUMN_PATTERNS, path,
                              exclude=COST_EXCLUDE_PATTERNS)
    gross_col = resolve_column("gross", fieldnames, GROSS_COLUMN_PATTERNS, path,
                               exclude=COST_EXCLUDE_PATTERNS)
    discount_col = resolve_column("discount", fieldnames, DISCOUNT_COLUMN_PATTERNS,
                                  path, exclude=COST_EXCLUDE_PATTERNS)
    user_col = resolve_column("user", fieldnames, USER_COLUMN_PATTERNS, path)
    model_col = resolve_column("model", fieldnames, MODEL_COLUMN_PATTERNS, path)
    date_col = resolve_column("date", fieldnames, DATE_COLUMN_PATTERNS, path)
    cc_col = resolve_column("cost_center", fieldnames, COST_CENTER_COLUMN_PATTERNS, path)
    fallback_day = parse_day_from_billing_filename(path)

    log(f"billing {os.path.basename(path)}: column mapping "
        f"cost={cost_col!r} gross={gross_col!r} discount={discount_col!r} "
        f"user={user_col!r} model={model_col!r} "
        f"date={date_col!r} cost_center={cc_col!r}")

    if cost_col is None:
        log(f"WARNING: no cost column matched in {path} (headers: {fieldnames}). "
            f"total_cost_usd will be NULL; set BILLING_COST_COLUMN or adjust "
            f"COST_COLUMN_PATTERNS.")
    if date_col is None and not fallback_day:
        log(f"WARNING: no date column and no day in filename for {path}; skipping.")
        return empty

    # day -> enterprise-level accumulator
    ent_groups: "dict[str, dict]" = {}
    # (day, username_key, model_key) -> per-user accumulator
    user_groups: "dict[tuple, dict]" = {}
    # (day, model_key) -> per-model accumulator
    model_groups: "dict[tuple, dict]" = {}
    raw_records: "list[dict]" = []
    day_ordinal: "dict[str, int]" = {}
    generated = now_iso()
    skipped_dates = 0

    for row in rows:
        if date_col is not None:
            day = normalize_day(row.get(date_col) or "")
            if not day:
                skipped_dates += 1
                continue
        else:
            day = fallback_day

        username = (row.get(user_col) or "").strip() if user_col else ""
        model = (row.get(model_col) or "").strip() if model_col else ""
        cost_center = (row.get(cc_col) or "").strip() if cc_col else ""
        username_key = username or UNKNOWN_USER
        model_key = model or UNKNOWN_MODEL

        cost = _parse_cost(row.get(cost_col)) if cost_col is not None else None
        if cost == "INVALID":
            log(f"WARNING: non-numeric cost '{row.get(cost_col)}' in {path}")
            cost = None
        gross = _parse_cost(row.get(gross_col)) if gross_col is not None else None
        if gross == "INVALID":
            gross = None
        discount = _parse_cost(row.get(discount_col)) if discount_col is not None else None
        if discount == "INVALID":
            discount = None

        # Enterprise aggregate (backward-compatible)
        eg = ent_groups.setdefault(day, {
            "total": Decimal("0"), "counted": 0,
            "gross": Decimal("0"), "gross_counted": 0,
            "discount": Decimal("0"), "discount_counted": 0,
            "users": set(), "models": set(), "rows": 0,
        })
        eg["rows"] += 1
        if cost is not None:
            eg["total"] += cost
            eg["counted"] += 1
        if gross is not None:
            eg["gross"] += gross
            eg["gross_counted"] += 1
        if discount is not None:
            eg["discount"] += discount
            eg["discount_counted"] += 1
        if user_col and username:
            eg["users"].add(username)
        if model_col and model:
            eg["models"].add(model)

        # Per-user aggregate
        ug = user_groups.setdefault((day, username_key, model_key), {
            "total": Decimal("0"), "counted": 0, "rows": 0, "cost_center": None,
        })
        ug["rows"] += 1
        if cost is not None:
            ug["total"] += cost
            ug["counted"] += 1
        if cost_center and not ug["cost_center"]:
            ug["cost_center"] = cost_center

        # Per-model aggregate (no identities)
        mg = model_groups.setdefault((day, model_key), {
            "total": Decimal("0"), "counted": 0, "users": set(), "rows": 0,
        })
        mg["rows"] += 1
        if cost is not None:
            mg["total"] += cost
            mg["counted"] += 1
        if user_col and username:
            mg["users"].add(username)

        # Raw fidelity: one record per CSV row. Ordinal keeps identical rows from
        # colliding on the same row_hash within a day.
        ordinal = day_ordinal.get(day, 0)
        day_ordinal[day] = ordinal + 1
        raw_json = json.dumps(row, sort_keys=True, ensure_ascii=False)
        row_hash = hashlib.sha256(
            f"{day}|{ordinal}|{raw_json}".encode("utf-8")).hexdigest()
        raw_records.append({
            "enterprise": enterprise or None,
            "day": day,
            "row_hash": row_hash,
            "username": username or None,
            "model": model or None,
            "cost_center_name": cost_center or None,
            "cost_usd": (str(cost) if cost is not None else None),
            "raw": raw_json,
            "generated_at": generated,
            "source_run_id": run_id or None,
            "source_repository": repo or None,
        })

    if skipped_dates:
        log(f"WARNING: skipped {skipped_dates} row(s) with unparseable dates in {path}.")

    enterprise_records = []
    for day in sorted(ent_groups):
        g = ent_groups[day]
        enterprise_records.append({
            "day": day,
            "enterprise": enterprise or None,
            "report_type": "ai_credit",
            "total_cost_usd": (str(g["total"]) if cost_col is not None and g["counted"] else None),
            "gross_cost_usd": (str(g["gross"]) if gross_col is not None and g["gross_counted"] else None),
            "discount_cost_usd": (str(g["discount"]) if discount_col is not None and g["discount_counted"] else None),
            "billing_rows": g["rows"],
            "cost_rows_counted": g["counted"],
            "user_count": len(g["users"]) if user_col else None,
            "model_count": len(g["models"]) if model_col else None,
            "generated_at": generated,
            "source_run_id": run_id or None,
            "source_repository": repo or None,
        })

    user_records = []
    for (day, username_key, model_key) in sorted(user_groups):
        g = user_groups[(day, username_key, model_key)]
        user_records.append({
            "enterprise": enterprise or None,
            "day": day,
            "username_key": username_key,
            "model_key": model_key,
            "cost_center_name": g["cost_center"],
            "total_cost_usd": (str(g["total"]) if cost_col is not None and g["counted"] else None),
            "cost_rows_counted": g["counted"],
            "row_count": g["rows"],
            "generated_at": generated,
            "source_run_id": run_id or None,
            "source_repository": repo or None,
        })

    model_records = []
    for (day, model_key) in sorted(model_groups):
        g = model_groups[(day, model_key)]
        model_records.append({
            "enterprise": enterprise or None,
            "day": day,
            "model_key": model_key,
            "total_cost_usd": (str(g["total"]) if cost_col is not None and g["counted"] else None),
            "user_count": len(g["users"]) if user_col else None,
            "row_count": g["rows"],
            "generated_at": generated,
            "source_run_id": run_id or None,
            "source_repository": repo or None,
        })

    return {
        "enterprise": enterprise_records,
        "user": user_records,
        "model": model_records,
        "raw": raw_records,
        "days": set(ent_groups),
    }


def _scim_username_candidates(username, email, shortcode):
    """Ordered, de-duplicated join-key candidates for a SCIM user.

    The billing CSV keys per-user rows by the GitHub *handle*
    (copilot_billing_user.username_key), while SCIM `userName` is often the IdP
    identity / email (especially for EMU, where the handle is typically
    `<idp-shortname>_<enterprise-shortcode>`). We therefore emit several
    best-effort candidates so a LEFT JOIN can line up regardless of which form the
    billing export uses. Higher-priority (more specific) candidates come first.
    Set ENTERPRISE_SHORTCODE (or SCIM_SHORTCODE) to reconstruct the EMU
    `_<shortcode>` handle from the IdP short name / email local-part."""
    cands = []

    def add(v):
        if v:
            v = v.strip()
            if v and v not in cands:
                cands.append(v)

    uname = (username or "").strip()
    local = ""
    if "@" in uname:
        local = uname.split("@", 1)[0]
    email_local = ""
    if email and "@" in email:
        email_local = email.split("@", 1)[0]

    # Most specific first: reconstructed EMU handle, then raw userName, then
    # the local-parts (which match non-suffixed handles / some export shapes).
    if shortcode:
        add(f"{local or uname}_{shortcode}")
        if email_local:
            add(f"{email_local}_{shortcode}")
    add(uname)
    add(local)
    add(email_local)
    return cands


def summarize_scim(path: str, run_id: str, repo: str, enterprise: str) -> list:
    """Parse a SCIM users snapshot JSON into copilot_enterprise_users rows.

    Emits one row per distinct `username_key` candidate (see
    _scim_username_candidates) so the dashboards' LEFT JOIN can match the billing
    username. On a candidate collision between two different SCIM users, the
    first (higher-priority / earlier) wins and a warning is logged."""
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError) as exc:
        log(f"WARNING: cannot read/parse SCIM file {path}: {exc}")
        return []

    users = data.get("users") or []
    file_enterprise = (data.get("enterprise") or "").strip()
    ent = enterprise or file_enterprise or None
    shortcode = (os.environ.get("ENTERPRISE_SHORTCODE")
                 or os.environ.get("SCIM_SHORTCODE") or "").strip()
    generated = now_iso()

    by_key: "dict[str, dict]" = {}
    with_email = 0
    for u in users:
        username = (u.get("username") or "").strip()
        email = (u.get("email") or "").strip() or None
        if email:
            with_email += 1
        base = {
            "enterprise": ent,
            "email": email,
            "scim_user_name": (u.get("scim_user_name") or username) or None,
            "external_id": (u.get("external_id") or None),
            "display_name": (u.get("display_name") or None),
            "active": u.get("active"),
            "generated_at": generated,
            "source_run_id": run_id or None,
            "source_repository": repo or None,
        }
        for key in _scim_username_candidates(username, email, shortcode):
            existing = by_key.get(key)
            if existing is None:
                by_key[key] = {**base, "username_key": key}
            elif existing.get("email") != email:
                log(f"WARNING: SCIM username_key {key!r} maps to multiple "
                    f"users/emails; keeping first ({existing.get('email')!r}, "
                    f"dropping {email!r}).")

    log(f"scim {os.path.basename(path)}: {len(users)} user(s), "
        f"{with_email} with email; {len(by_key)} username_key mapping row(s)"
        + (f" (shortcode={shortcode!r})" if shortcode else ""))
    return list(by_key.values())


def collect_rows(data_dir, run_id, repo, enterprise):
    usage = []
    # Per breakdown table: accumulated rows + the set of (scope,slug,day) keys
    # whose payload actually contained that container (so absent containers are
    # never replaced/wiped by the loader).
    usage_breakdowns = {d["table"]: {"rows": [], "present_keys": set()}
                        for d in BREAKDOWN_DEFS}
    billing = {"enterprise": [], "user": [], "model": [], "raw": [], "days": set()}
    for path in sorted(glob.glob(os.path.join(data_dir, "usage-*.json"))):
        result = summarize_usage(path, run_id, repo)
        if not result:
            continue
        rec = result["usage"]
        usage.append(rec)
        log(f"usage {rec['day']}: active={rec['total_active_users']} "
            f"engaged={rec['total_engaged_users']} rows={rec['report_rows']}")
        key = result["key"]
        for table, rows in result["breakdowns"].items():
            usage_breakdowns[table]["rows"].extend(rows)
            if table in result["present"]:
                usage_breakdowns[table]["present_keys"].add(key)
    # Merge breakdown rows across files so duplicate (scope,slug,day) inputs can
    # never collide on a breakdown primary key when inserted.
    _defn_by_table = {d["table"]: d for d in BREAKDOWN_DEFS}
    for table, bucket in usage_breakdowns.items():
        bucket["rows"] = merge_breakdown_rows(_defn_by_table[table], bucket["rows"])
    for path in sorted(glob.glob(os.path.join(data_dir, "billing-*.csv"))):
        result = summarize_billing(path, run_id, repo, enterprise)
        billing["enterprise"].extend(result["enterprise"])
        billing["user"].extend(result["user"])
        billing["model"].extend(result["model"])
        billing["raw"].extend(result["raw"])
        billing["days"].update(result["days"])
        for rec in result["enterprise"]:
            log(f"billing {rec['day']}: total_cost_usd={rec['total_cost_usd']} "
                f"gross={rec['gross_cost_usd']} discount={rec['discount_cost_usd']} "
                f"users={rec['user_count']} rows={rec['billing_rows']}")
    scim_users = []
    for path in sorted(glob.glob(os.path.join(data_dir, "scim-users-*.json"))):
        scim_users.extend(summarize_scim(path, run_id, repo, enterprise))
    return usage, usage_breakdowns, billing, scim_users


def _decimal_or_zero(value):
    try:
        return Decimal(value) if value is not None else Decimal("0")
    except (InvalidOperation, TypeError):
        return Decimal("0")


def reconcile_billing(billing) -> None:
    """Warn if the enterprise / per-user / per-model / raw cost totals for a day
    don't reconcile — a strong signal that column detection or grouping is off."""
    for rec in billing["enterprise"]:
        day = rec["day"]
        ent = _decimal_or_zero(rec["total_cost_usd"])
        user_sum = sum((_decimal_or_zero(r["total_cost_usd"])
                        for r in billing["user"] if r["day"] == day), Decimal("0"))
        model_sum = sum((_decimal_or_zero(r["total_cost_usd"])
                         for r in billing["model"] if r["day"] == day), Decimal("0"))
        raw_sum = sum((_decimal_or_zero(r["cost_usd"])
                       for r in billing["raw"] if r["day"] == day), Decimal("0"))
        if not (ent == user_sum == model_sum == raw_sum):
            log(f"WARNING: billing cost totals for {day} do not reconcile "
                f"(enterprise={ent} user={user_sum} model={model_sum} "
                f"raw={raw_sum}). Check column detection/grouping.")


def load_to_postgres(database_url, usage, usage_breakdowns, billing, scim_users):
    try:
        import psycopg
        from psycopg.types.json import Jsonb
    except ImportError:
        log("ERROR: psycopg not installed. `pip install 'psycopg[binary]'`.")
        return 1

    reconcile_billing(billing)

    # Only replace days that actually produced parsed rows. A day absent from
    # this set (e.g. a partial or empty export) is never deleted, so we can't
    # wipe previously loaded good data.
    replace_days = sorted(billing["days"])

    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(CREATE_SQL)
            # Aggregate tables: idempotent upsert.
            for rec in usage:
                cur.execute(UPSERT_USAGE, rec)
            for rec in billing["enterprise"]:
                cur.execute(UPSERT_BILLING, rec)
            # Usage breakdown tables: delete-then-insert scoped to the exact
            # (scope, slug, day) keys whose payload contained that container.
            # A container that was absent for a day is left untouched (its
            # present_keys won't include that key), so a partial payload can't
            # wipe good breakdown history.
            breakdown_replaced = 0
            breakdown_inserted = 0
            for d in BREAKDOWN_DEFS:
                table = d["table"]
                sql = BREAKDOWN_SQL[table]
                bucket = usage_breakdowns.get(table, {"rows": [], "present_keys": set()})
                for (scope, slug, day) in sorted(bucket["present_keys"]):
                    cur.execute(sql["delete"],
                                {"scope": scope, "slug": slug, "day": day})
                    breakdown_replaced += 1
                for rec in bucket["rows"]:
                    cur.execute(sql["insert"], rec)
                    breakdown_inserted += 1
            # Detail tables: delete-then-insert, scoped to validated days only,
            # inside this same transaction.
            enterprise_slug = None
            for rec in billing["raw"]:
                enterprise_slug = rec["enterprise"]
                break
            for day in replace_days:
                params = {"enterprise": enterprise_slug, "day": day}
                cur.execute(DELETE_RAW_DAY, params)
                cur.execute(DELETE_USER_DAY, params)
                cur.execute(DELETE_MODEL_DAY, params)
            for rec in billing["raw"]:
                rec = {**rec, "raw": Jsonb(json.loads(rec["raw"]))}
                cur.execute(INSERT_RAW, rec)
            for rec in billing["user"]:
                cur.execute(INSERT_USER, rec)
            for rec in billing["model"]:
                cur.execute(INSERT_MODEL, rec)
            # Identity enrichment: full snapshot upsert. Scoped to the enterprise
            # present in the snapshot so we don't touch other enterprises' rows.
            scim_enterprise = None
            for rec in scim_users:
                scim_enterprise = rec["enterprise"]
                break
            if scim_users:
                cur.execute(DELETE_ENTERPRISE_USERS, {"enterprise": scim_enterprise})
                for rec in scim_users:
                    cur.execute(UPSERT_ENTERPRISE_USERS, rec)
        conn.commit()
    log(f"Upserted {len(usage)} usage row(s) and "
        f"{len(billing['enterprise'])} enterprise billing row(s). "
        f"Replaced {breakdown_replaced} usage-breakdown day/table slice(s) "
        f"({breakdown_inserted} rows). "
        f"Replaced detail for {len(replace_days)} day(s): "
        f"{len(billing['raw'])} raw, {len(billing['user'])} per-user, "
        f"{len(billing['model'])} per-model row(s). "
        f"Refreshed {len(scim_users)} enterprise-user email mapping row(s).")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--data-dir", default="copilot-data",
                    help="Directory holding the raw collected files.")
    ap.add_argument("--database-url", default=os.environ.get("DATABASE_URL", ""),
                    help="Postgres connection string. If empty, run as a dry run.")
    ap.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID", ""))
    ap.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    ap.add_argument("--enterprise", default=os.environ.get("ENTERPRISE", ""))
    ap.add_argument("--show-raw", action="store_true",
                    help="LOCAL USE ONLY: include identifiable per-user/raw rows "
                         "in dry-run output. Never enable in CI — it would write "
                         "usernames and full CSV rows to the job log.")
    args = ap.parse_args()

    usage, usage_breakdowns, billing, scim_users = collect_rows(
        args.data_dir, args.run_id, args.repository, args.enterprise)

    if not usage and not billing["enterprise"] and not billing["raw"] \
            and not scim_users:
        log("No usage-*.json, billing-*.csv, or scim-users-*.json inputs found; "
            "nothing to load.")
        return 0

    if args.database_url and (billing["enterprise"] or billing["user"]
                              or billing["model"] or billing["raw"]) \
            and not args.enterprise.strip():
        log("ERROR: billing data is present and a database was requested, but "
            "--enterprise/ENTERPRISE is empty. The billing tables define "
            "'enterprise text NOT NULL', so the insert would fail with an opaque "
            "Postgres error. Set --enterprise (or the ENTERPRISE env var).")
        return 1

    if not args.database_url:
        log("DRY RUN (no --database-url/DATABASE_URL).")
        reconcile_billing(billing)
        # Default output is PII-safe: aggregates + counts only. The per-user and
        # raw rows contain usernames / full CSV cells and are withheld unless
        # --show-raw is passed for local inspection. Usage breakdowns are
        # aggregate (no identities), so their counts are always safe to show.
        # SCIM email-mapping rows are PII (emails), so they're withheld too.
        summary = {
            "usage": usage,
            "billing_enterprise": billing["enterprise"],
            "billing_model": billing["model"],
            "usage_breakdown_counts": {
                t: len(b["rows"]) for t, b in usage_breakdowns.items()},
            "counts": {
                "billing_user_rows": len(billing["user"]),
                "billing_raw_rows": len(billing["raw"]),
                "enterprise_user_rows": len(scim_users),
                "days": sorted(billing["days"]),
            },
        }
        if args.show_raw:
            summary["billing_user"] = billing["user"]
            summary["billing_raw"] = billing["raw"]
            summary["enterprise_users"] = scim_users
            summary["usage_breakdowns"] = {
                t: b["rows"] for t, b in usage_breakdowns.items()}
        else:
            log("Per-user, raw, and email-mapping rows withheld from output "
                "(contain usernames / emails / full CSV cells). Pass --show-raw "
                "locally to include them.")
        print(json.dumps(summary, indent=2))
        return 0

    return load_to_postgres(args.database_url, usage, usage_breakdowns, billing,
                            scim_users)


if __name__ == "__main__":
    raise SystemExit(main())
