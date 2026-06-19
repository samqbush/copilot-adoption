---
layout: default
title: "GHES vs Cloud: AI Metric Comparison (Octodemo)"
toc: true
---

# GHES vs Cloud: AI Metric Comparison
{:.no_toc}

*Sample run: June 19, 2026 — octodemo org*

A side-by-side comparison of two approaches to measuring AI leverage on the same org, same day:

1. **Trailer scanning** (`ai-leverage-daily.sh`) — the GHES approach, scanning `Co-authored-by` trailers in commit messages via the REST API
2. **Copilot Metrics API** (`copilot-cloud-agent-metrics.sh`) — the Cloud/EMU approach, using native server-side PR metrics

---

## Raw Output: Same Day (June 18, 2026)

### Trailer Scanning (ai-leverage-daily.sh)

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

### Copilot Metrics API (copilot-cloud-agent-metrics.sh)

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

---

## Head-to-Head: Key Metrics

| Metric | Trailer Scanning | Copilot Metrics API | Delta |
|---|---|---|---|
| Total merged PRs | 23 | 23 | ✅ Match |
| AI-attributed merged PRs | **8** | **2** | ⚠️ 4× higher via trailers |
| AI leverage % | **34.8%** | **8.7%** | 26.1pp gap |
| Closed without merge | 46 | — | Not tracked by Metrics API |
| AI rejection rate | 11.1% | — | Not tracked by Metrics API |
| PRs created | — | 396 | Not tracked by trailer scanning |
| PRs created by Copilot | — | 18 | Not tracked by trailer scanning |
| PRs reviewed by Copilot | — | 345 | Not tracked by trailer scanning |
| Median time to merge | — | 0.53 min | Not tracked by trailer scanning |
| Median TTM (Copilot-authored) | — | 10.25 min | Not tracked by trailer scanning |
| Code review suggestions | — | 103 | Not tracked by trailer scanning |
| Daily active users | — | 812 | Not tracked by trailer scanning |

---

## Why Trailer Scanning Shows 4× More AI PRs

The trailer scanner found **8 AI-attributed merged PRs** while the Copilot Metrics API reported only **2**. This is expected:

**Trailer scanning is the superset for AI leverage:**
- Catches everything: Copilot coding agent PRs (which include trailers), IDE completions (if `git.addAICoAuthor` is on), Copilot CLI, and Claude Code
- Counts any PR where any commit has a matching `Co-authored-by` trailer
- The 8 AI PRs include the 2 coding agent PRs plus 6 others from IDE/CLI usage

**Copilot Metrics API `total_merged_created_by_copilot` is a subset:**
- Only counts PRs **created by the Copilot coding agent** — not all PRs with AI involvement
- Does not count PRs where a human created the PR but used Copilot in their editor
- Does not count Claude Code — it's a Copilot-specific metric

**Key takeaway:** Use `ai-leverage-daily.sh` for the AI leverage percentage. Use `copilot-cloud-agent-metrics.sh` for the additional ESSP metrics that trailers can't provide (velocity, review quality, throughput).

---

## ESSP Metric Coverage

The [Engineering System Success Playbook](https://github.com/resources/insights/engineering-system-success-playbook) defines metrics across four zones. Here's what each script covers:

| ESSP Zone | Metric | Trailer Scanning | Copilot Metrics API |
|---|---|---|---|
| **Activity** | AI leverage (% merged PRs with AI) | ✅ 34.8% | ✅ 8.7% (narrower definition) |
| **Activity** | Daily active Copilot users | ❌ | ✅ 812 |
| **Velocity** | Time to merge | ❌ | ✅ 0.53 min median |
| **Velocity** | Time to merge (AI-authored) | ❌ | ✅ 10.25 min median |
| **Quality** | AI rejection rate | ✅ 11.1% | ❌ |
| **Quality** | Code review (suggestions/applied) | ❌ | ✅ 103 suggestions, 2 applied |
| **Throughput** | PRs created | ❌ | ✅ 396 total, 18 by Copilot |
| **Throughput** | PRs reviewed by Copilot | ❌ | ✅ 345 |

### What GHES Customers Miss

Without the Copilot Metrics API, GHES customers cannot measure:

1. **Time-to-merge comparison** — is AI-authored code merging faster or slower? (On octodemo: Copilot-authored PRs take 10.25 min vs 0.53 min median — though this likely reflects different PR complexity rather than AI slowness)
2. **Copilot code review adoption** — 345 PRs reviewed by Copilot out of 396 created (87% review coverage)
3. **PR creation volume by Copilot** — 18 PRs created by Copilot coding agent
4. **Code review suggestion acceptance** — only 2 of 103 suggestions applied (1.9% acceptance rate)
5. **Daily active Copilot users** — 812 users active on this day

### What GHES Customers Get That Cloud Doesn't Surface

1. **AI rejection rate** — the Metrics API doesn't track closed-without-merge for AI PRs. Trailer scanning found 11.1% rejection rate (1 AI-attributed PR closed without merge out of 9 total AI PRs). This is a quality signal.
2. **Multi-tool attribution** — trailer scanning catches Claude Code, Copilot CLI, and VS Code agent mode. The Metrics API only tracks Copilot.
3. **Per-PR granularity** — the trailer script logs each PR individually, so you can see exactly which repos and PRs had AI involvement.

---

## 28-Day Rolling Metrics (Cloud Only)

The Copilot Metrics API also provides a 28-day rolling view not available via trailer scanning:

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

Over 28 days:
- **7% AI leverage** (12 of 172 merged PRs created by Copilot)
- **329 PRs created by Copilot** out of 15,039 total (2.2% of all PRs created)
- **3,871 PRs reviewed by Copilot** (25.7% of all PRs created)
- **1,097 review suggestions**, 17 applied (1.5% acceptance rate)

---

## Auth Differences

An important operational difference: the Copilot Metrics API requires **org admin or "Copilot usage metrics" read access**. The GitHub App used for the trailer script (App ID: 4097118) returned `Resource not accessible by integration` when trying the Metrics API — it lacks the required `copilot` permission scope. The data above was fetched using a personal token with org admin access.

Trailer scanning only needs `repo` scope (read access to commits and PRs), which is more commonly available.

---

## Summary

| Dimension | Trailer Scanning (GHES) | Copilot Metrics API (Cloud) |
|---|---|---|
| **Setup** | Deploy VS Code setting + daily cron | None — works out of the box |
| **Accuracy** | Depends on trailers being present (honesty system) | Server-side tracking (100% for coding agent) |
| **AI tools covered** | Copilot CLI, VS Code agent, Claude Code | Copilot only |
| **AI definition** | "Any PR with an AI co-author trailer" | "PR created by Copilot coding agent" |
| **ESSP coverage** | AI leverage + rejection rate | AI leverage + velocity + quality + throughput |
| **Permissions needed** | `repo` scope | Org admin or Copilot metrics access |
| **API cost** | ~100-1000+ calls/day (scales with PRs) | 1-2 calls/day |

For GHES customers, trailer scanning is the only option. For Cloud/EMU customers, the Copilot Metrics API provides richer data with zero configuration — but pairing it with trailer scanning gives you multi-tool visibility and the AI rejection rate metric.
