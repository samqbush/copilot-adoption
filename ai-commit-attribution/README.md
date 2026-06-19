# AI Commit Attribution — Scripts

Utility scripts for measuring AI adoption and developer productivity metrics.

| Script | What it gives you | When you need it |
|--------|-------------------|----------|
| `ai-leverage-daily.sh` | **AI leverage %** and rejection rate by scanning `Co-authored-by` trailers (detects tools that emit trailers: Copilot coding agent, IDE, CLI, Claude Code) | Always — the only way to see IDE and CLI usage, any platform |
| `copilot-cloud-agent-metrics.sh` | **Coding agent + code review metrics**: time-to-merge, review coverage, suggestion acceptance, daily active users | Add it on Cloud/EMU when using the coding agent or Copilot code review |

`ai-leverage-daily.sh` is the baseline. Trailers are the only signal that captures a developer using Copilot in their editor or the CLI, so run it regardless of platform. `copilot-cloud-agent-metrics.sh` adds the velocity and quality metrics that trailers can't provide, using server-side data that only exists on Cloud/EMU.

See [Trailer Scanning vs Copilot usage metrics API](./ghes-vs-cloud-comparison.md) for a side-by-side with real octodemo data.

---

## ai-leverage-daily.sh

Calculates the percentage of merged PRs that contain AI-authored commits (Copilot CLI, VS Code Copilot, Claude Code) by scanning commit trailers across a GitHub org. It finds closed PRs through the Search API rather than iterating every repo, so cost scales with the number of closed PRs.

**APIs used:**

| Step | Endpoint | Docs |
|------|----------|------|
| Find closed PRs | `GET /search/issues` | [Search issues and pull requests](https://docs.github.com/en/enterprise-cloud@latest/rest/search/search#search-issues-and-pull-requests) |
| Get PR merge status | `GET /repos/{owner}/{repo}/pulls/{pull_number}` | [Get a pull request](https://docs.github.com/en/enterprise-cloud@latest/rest/pulls/pulls#get-a-pull-request) |
| List PR commits | `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits` | [List commits on a pull request](https://docs.github.com/en/enterprise-cloud@latest/rest/pulls/pulls#list-commits-on-a-pull-request) |

### Quick Start (PAT auth)

```bash
# Uses your existing gh CLI auth or GH_TOKEN env var
./scripts/ai-leverage-daily.sh octodemo

# Scan a specific time window
./scripts/ai-leverage-daily.sh octodemo --since 2026-06-18T00:00:00Z
```

### GitHub App Auth (recommended for large orgs)

GitHub App installation tokens provide 15,000 req/hr (vs 5,000 for PATs). See [github-app-setup.md](./github-app-setup.md) for one-time setup.

```bash
# Using the config file created during setup
source ~/.config/ai-attribution/config

./scripts/ai-leverage-daily.sh octodemo \
  --app-id "$APP_ID" \
  --installation-id "$INSTALLATION_ID" \
  --private-key "$PRIVATE_KEY_PATH"
```

### Output

JSON report to stdout:
```json
{
  "date": "2026-06-19",
  "org": "octodemo",
  "since": "2026-06-18T19:30:04Z",
  "prs_checked": 116,
  "total_merged_prs": 23,
  "ai_attributed_merged": 8,
  "ai_leverage_pct": 34.8,
  "total_closed_without_merge": 46,
  "ai_attributed_closed": 1,
  "ai_rejection_rate_pct": 11.1,
  "median_time_to_merge_min": 142.5,
  "median_ai_time_to_merge_min": 98.3
}
```

| Metric | Formula | ESSP Zone |
|--------|---------|-----------|
| AI Leverage | AI-merged PRs ÷ total merged PRs | Activity |
| AI Rejection Rate | AI-closed-without-merge ÷ all AI PRs | Quality |
| PR Velocity (time-to-merge) | Median of `merged_at − created_at` across merged PRs | Velocity |
| AI vs Human velocity delta | Compare `median_ai_time_to_merge_min` vs `median_time_to_merge_min` | Velocity |

Time-to-merge is computed client-side from the PR's own `created_at` and `merged_at` timestamps, which the standard pulls API returns on **any** GitHub edition (GHES, GHEC, GHEC+EMU). It does not require the Cloud-only usage metrics API. Values are `null` when no PRs merged in the window.

Progress and debug info goes to stderr, so you can pipe stdout directly:
```bash
./scripts/ai-leverage-daily.sh octodemo > report.json
```

---

## copilot-cloud-agent-metrics.sh

Fetches native Copilot PR metrics from the [Copilot usage metrics API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics). Server-side tracking means zero client configuration and accurate counts for Copilot coding agent PRs. Cloud/EMU only.

**APIs used:** each endpoint returns `download_links` to an NDJSON report that the script downloads and parses. All are documented under [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics).

| Report | Endpoint |
|--------|----------|
| Org, single day | `GET /orgs/{org}/copilot/metrics/reports/organization-1-day?day=YYYY-MM-DD` |
| Org, 28-day rolling | `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest` |
| Enterprise, single day | `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-1-day?day=YYYY-MM-DD` |
| Enterprise, 28-day rolling | `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-28-day/latest` |

### Quick Start

```bash
# Yesterday's metrics (default)
./scripts/copilot-cloud-agent-metrics.sh octodemo

# Specific day
./scripts/copilot-cloud-agent-metrics.sh octodemo --day 2026-06-18

# Last 7 days
./scripts/copilot-cloud-agent-metrics.sh octodemo --days 7

# 28-day rolling report
./scripts/copilot-cloud-agent-metrics.sh octodemo --28day

# Enterprise-level instead of org-level
./scripts/copilot-cloud-agent-metrics.sh octodemo --enterprise my-enterprise --28day
```

### GitHub App Auth

Same pattern as `ai-leverage-daily.sh`, but the App needs the **Copilot Metrics** permission (org admin access):

```bash
source ~/.config/ai-attribution/config

./scripts/copilot-cloud-agent-metrics.sh octodemo \
  --app-id "$APP_ID" \
  --installation-id "$INSTALLATION_ID" \
  --private-key "$PRIVATE_KEY_PATH"
```

> **Note:** The Copilot usage metrics API requires the **Copilot usage metrics** policy to be enabled, plus org admin, billing manager, or the fine-grained **Organization Copilot metrics** (read) permission. If your App returns `Resource not accessible by integration`, grant it the **Organization Copilot metrics** permission (or use a PAT with org admin scope). See [github-app-setup.md](./github-app-setup.md).

### Output (daily)

```json
{
  "report_type": "daily",
  "org": "octodemo",
  "days": [
    {
      "day": "2026-06-18",
      "daily_active_users": 812,
      "pull_requests": {
        "total_merged": 23,
        "total_merged_created_by_copilot": 2,
        "total_merged_reviewed_by_copilot": 0,
        "total_created": 396,
        "total_created_by_copilot": 18,
        "total_reviewed_by_copilot": 345,
        "median_minutes_to_merge": 0.53,
        "median_minutes_to_merge_copilot_authored": 10.25,
        "total_copilot_suggestions": 103,
        "total_copilot_applied_suggestions": 2,
        "ai_leverage_pct": 8.7
      }
    }
  ]
}
```

### Output (28-day rolling)

```json
{
  "report_type": "28-day rolling",
  "org": "octodemo",
  "report_start": "2026-05-22",
  "report_end": "2026-06-18",
  "days_with_data": 28,
  "total_merged_prs": 172,
  "total_merged_created_by_copilot": 12,
  "total_merged_reviewed_by_copilot": 0,
  "total_prs_created": 15039,
  "total_prs_created_by_copilot": 329,
  "total_prs_reviewed_by_copilot": 3871,
  "ai_leverage_pct": 7,
  "median_minutes_to_merge": 183.66,
  "median_minutes_to_merge_copilot_authored": 232.96,
  "total_copilot_review_suggestions": 1097,
  "total_copilot_applied_suggestions": 17,
  "avg_daily_active_users": 580
}
```

### ESSP Metrics Covered

| Metric | ESSP Zone | Field |
|--------|-----------|-------|
| AI Leverage | Activity | `ai_leverage_pct` |
| PR Velocity (time-to-merge) | Velocity | `median_minutes_to_merge` |
| AI vs Human velocity delta | Velocity | Compare `median_minutes_to_merge_copilot_authored` vs `median_minutes_to_merge` |
| Code review coverage | Quality | `total_reviewed_by_copilot` ÷ `total_created` |
| Review suggestion acceptance | Quality | `total_copilot_applied_suggestions` ÷ `total_copilot_suggestions` |
| Copilot adoption breadth | Activity | `daily_active_users` |

---

## When You Need Which Script

See [ghes-vs-cloud-comparison.md](./ghes-vs-cloud-comparison.md) for detailed analysis with real octodemo data.

| Scenario | Scripts needed |
|----------|---------------|
| GHES, or IDE/CLI usage only | `ai-leverage-daily.sh` only |
| Cloud/EMU, AI leverage % only | `ai-leverage-daily.sh` only |
| Cloud/EMU, using coding agent and/or Copilot code review | **Both scripts** |

| Dimension | `ai-leverage-daily.sh` | `copilot-cloud-agent-metrics.sh` |
|-----------|------------------------|----------------------------------|
| **Primary metric** | AI leverage %, AI rejection rate | Time-to-merge, review coverage, active users |
| **AI tools covered** | Trailer-emitting tools (Copilot coding agent + IDE + CLI + Claude) | Copilot platform features only |
| **How** | Scans `Co-authored-by` trailers | Queries Copilot usage metrics API |
| **Platform** | Any (GHES or Cloud) | Cloud/EMU only |
| **Permissions** | `repo` scope | Org admin or Copilot metrics access |
| **API cost** | ~2 calls per closed PR | 1-2 calls/day |

---

## generate-installation-token.sh

Generates a short-lived GitHub App installation token from a private key. Used internally by both scripts when `--app-id` is provided, but can also be called standalone:

```bash
./scripts/generate-installation-token.sh \
  --app-id 12345 \
  --installation-id 67890 \
  --private-key ~/.config/ai-attribution/octodemo-app.pem
```

Outputs the token to stdout. Requires `openssl`, `curl`, and `jq`.

**API used:** `POST /app/installations/{installation_id}/access_tokens` — see [Create an installation access token for an app](https://docs.github.com/en/enterprise-cloud@latest/rest/apps/apps#create-an-installation-access-token-for-an-app).

---

## GitHub App Setup

See [github-app-setup.md](./github-app-setup.md) for step-by-step instructions on creating and installing the GitHub App used for authentication.

