# AI Commit Attribution — Scripts

Utility scripts for measuring AI adoption and developer productivity metrics.

| Script | What it gives you | Platform |
|--------|-------------------|----------|
| `ai-leverage-daily.sh` | **AI leverage %** and rejection rate by scanning `Co-authored-by` trailers (catches all AI tools: Copilot coding agent, IDE, CLI, Claude Code) | Any (GHES or Cloud) |
| `copilot-cloud-agent-metrics.sh` | **Additional ESSP metrics**: time-to-merge, code review coverage, suggestion acceptance, daily active users | Cloud/EMU only |

`ai-leverage-daily.sh` is the primary script — it captures all AI-attributed PRs including coding agent PRs (which add trailers). `copilot-cloud-agent-metrics.sh` supplements it with velocity and quality metrics that trailers can't provide.

See [GHES vs Cloud Comparison](./ghes-vs-cloud-comparison.md) for a detailed side-by-side analysis with real data.

---

## ai-leverage-daily.sh

Calculates the percentage of merged PRs that contain AI-authored commits (Copilot CLI, VS Code Copilot, Claude Code) by scanning commit trailers across all repos in a GitHub org.

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
  "ai_rejection_rate_pct": 11.1
}
```

| Metric | Formula | ESSP Zone |
|--------|---------|-----------|
| AI Leverage | AI-merged PRs ÷ total merged PRs | Activity |
| AI Rejection Rate | AI-closed-without-merge ÷ all AI PRs | Quality |

Progress and debug info goes to stderr, so you can pipe stdout directly:
```bash
./scripts/ai-leverage-daily.sh octodemo > report.json
```

---

## copilot-cloud-agent-metrics.sh

Fetches native Copilot PR metrics from the [Copilot Metrics API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics). This is the Cloud/EMU equivalent — no trailer scanning needed. Server-side tracking means zero client configuration and 100% accuracy for Copilot coding agent PRs.

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

> **Note:** The Copilot Metrics API requires org admin or explicit "Copilot usage metrics" access. If your App returns `Resource not accessible by integration`, you need to add the `organization_copilot_seat_management: read` permission to the App or use a PAT with org admin scope.

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
| GHES customer | `ai-leverage-daily.sh` only |
| Cloud/EMU, AI leverage % only | `ai-leverage-daily.sh` only |
| Cloud/EMU, full ESSP metrics (velocity, quality, throughput) | **Both scripts** |

| Dimension | `ai-leverage-daily.sh` | `copilot-cloud-agent-metrics.sh` |
|-----------|------------------------|----------------------------------|
| **Primary metric** | AI leverage %, AI rejection rate | Time-to-merge, review coverage, active users |
| **AI tools covered** | All (Copilot coding agent + IDE + CLI + Claude) | Copilot platform features only |
| **How** | Scans `Co-authored-by` trailers | Queries Copilot Metrics API |
| **Platform** | Any (GHES or Cloud) | Cloud/EMU only |
| **Permissions** | `repo` scope | Org admin or Copilot metrics access |
| **API cost** | ~100-1000+ calls/day | 1-2 calls/day |

---

## generate-installation-token.sh

Generates a short-lived GitHub App installation token from a private key. Used internally by both scripts when `--app-id` is provided, but can also be called standalone:

```bash
./scripts/generate-installation-token.sh \
  --app-id 12345 \
  --installation-id 67890 \
  --private-key ~/.config/ai-attribution/octodemo-app.pem
```

Outputs the token to stdout. Requires only `openssl` and `curl` (no extra dependencies).

---

## GitHub App Setup

See [github-app-setup.md](./github-app-setup.md) for step-by-step instructions on creating and installing the GitHub App used for authentication.

