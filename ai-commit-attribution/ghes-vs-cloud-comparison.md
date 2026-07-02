---
layout: default
title: "Trailer Scanning vs Copilot usage metrics API (Octodemo)"
toc: true
---

# Trailer Scanning vs Copilot usage metrics API
{:.no_toc}

*Sample run: June 19, 2026 — octodemo org*

Two ways to measure AI in Pull Requests, run against the same org on the same day:

1. **Trailer scanning** (`ai-leverage-daily.sh`) — scans `Co-authored-by` trailers in commit messages via the REST API. Catches IDE and CLI usage on any platform.
2. **Copilot usage metrics API** (`copilot-cloud-agent-metrics.sh`) — reads server-side PR metrics for the coding agent and code review. Cloud/EMU only.

They count different things, so the numbers differ. That difference is the useful part.

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

### Copilot usage metrics API (copilot-cloud-agent-metrics.sh)

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

| Metric | Trailer Scanning | Copilot usage metrics API | Delta |
|---|---|---|---|
| Total merged PRs | 23 | 23 | ✅ Match |
| AI-attributed merged PRs | **8** | **2** | ⚠️ 4× higher via trailers |
| AI leverage % | **34.8%** | **8.7%** | 26.1pp gap |
| Closed without merge | 46 | — | Not tracked by Metrics API |
| AI rejection rate | 11.1% | — | Not tracked by Metrics API |
| PRs created (total volume) | — | 396 | Trailer script reports closed PRs only, not creation volume |
| PRs created/authored by Copilot | 2 (in merged set, via trailers) | 18 (created, any state) | ⚠️ Trailers **do** attribute coding-agent PRs — but only within the closed/merged set the script scans; the API counts bot-created PRs in any state, server-side |
| PRs reviewed by Copilot | — | 345 | Not tracked by trailer scanning |
| Merged PRs by AI adoption phase | — | per-phase totals | Cloud/EMU only — `totals_by_ai_adoption_phase.total_pull_requests_merged` |
| Median time to merge | 142.5 min | 0.53 min | Different scopes: all merged PRs vs coding-agent PRs |
| Median TTM (AI-attributed) | 98.3 min | 10.25 min | Trailer scan: any AI co-author; API: coding-agent-authored |
| Code review suggestions | — | 103 | Not tracked by trailer scanning |
| Daily active users | — | 812 | Not tracked by trailer scanning |

---

## Why Trailer Scanning Shows 4× More AI PRs

The trailer scanner found **8 AI-attributed merged PRs** while the Copilot usage metrics API reported only **2**. This is expected:

**Trailer scanning is the superset for AI leverage:**
- Catches everything: Copilot coding agent PRs (which include trailers), IDE completions (if `git.addAICoAuthor` is on), Copilot CLI, and Claude Code
- Counts any PR where any commit has a matching `Co-authored-by` trailer
- The 8 AI PRs include the 2 coding agent PRs plus 6 others from IDE/CLI usage

**Copilot usage metrics API `total_merged_created_by_copilot` is a subset:**
- Only counts PRs **created by the Copilot coding agent** — not all PRs with AI involvement
- Does not count PRs where a human created the PR but used Copilot in their editor
- Does not count Claude Code — it's a Copilot-specific metric

**Key takeaway:** Use `ai-leverage-daily.sh` for the AI leverage percentage and PR velocity (time-to-merge, computed from PR timestamps on any platform). Use `copilot-cloud-agent-metrics.sh` for the additional ESSP metrics trailers can't provide (review quality, throughput, coding-agent-scoped velocity).

---

## ESSP Metric Coverage

The [Engineering System Success Playbook](https://github.com/resources/insights/engineering-system-success-playbook) defines metrics across four zones. Here's what each script covers:

| ESSP Zone | Metric | Trailer Scanning | Copilot usage metrics API |
|---|---|---|---|
| **Activity** | AI leverage (% merged PRs with AI) | ✅ 34.8% | ✅ 8.7% (narrower definition) |
| **Activity** | Daily active Copilot users | ❌ | ✅ 812 |
| **Velocity** | Time to merge | ✅ 142.5 min median | ✅ 0.53 min (coding-agent PRs) |
| **Velocity** | Time to merge (AI-attributed) | ✅ 98.3 min median | ✅ 10.25 min (coding-agent PRs) |
| **Quality** | AI rejection rate | ✅ 11.1% | ❌ |
| **Quality** | Code review (suggestions/applied) | ❌ | ✅ 103 suggestions, 2 applied |
| **Throughput** | PRs created | ❌ raw volume | ✅ 396 total, 18 by Copilot |
| **Throughput** | PRs authored by Copilot | ⚠️ via trailers (closed set) | ✅ 18 (server-side, any state) |
| **Throughput** | Merged PRs by AI adoption phase | ❌ | ✅ Cloud/EMU only |
| **Throughput** | PRs reviewed by Copilot | ❌ | ✅ 345 |

### What the trailer scan can't tell you

Trailer scanning has no view into these. You need the usage metrics API (Cloud/EMU):

1. **Copilot code review adoption** — 345 PRs reviewed by Copilot out of 396 created (87% review coverage)
2. **PR creation volume by Copilot** — 18 PRs created by Copilot coding agent
3. **Code review suggestion acceptance** — only 2 of 103 suggestions applied (1.9% acceptance rate)
4. **Daily active Copilot users** — 812 users active on this day
5. **Merged PRs by AI adoption phase** — see below

The trailer scan *does* compute overall and AI-attributed time-to-merge from each PR's `created_at`/`merged_at`, so velocity is not Cloud-only. The metrics API adds a time-to-merge value pre-scoped to coding-agent-authored PRs, useful when you want that subset broken out without filtering trailers yourself.

### Merged PRs by AI adoption phase (Cloud/EMU only)

As of June 26, 2026, the aggregated org/enterprise usage metrics reports include `total_pull_requests_merged` inside each `totals_by_ai_adoption_phase` entry — the raw count of PRs merged that day by users in each adoption cohort (`No Cohort`, `Phase 1`, `Phase 2`, `Phase 3`). This lets you see each phase's share of merged PRs, not just the per-user averages that shipped earlier.

This is a Cloud/EMU-only data point — it comes from the same usage metrics API a GHES customer can't call. One important caveat for how you read it: the adoption phase is a property of the **user**, not the PR. `total_pull_requests_merged` counts *every* PR merged by users in that cohort, whether or not AI touched that specific PR. It is a **cohort-throughput correlation** ("do heavier Copilot users merge more?"), **not** AI attribution. Don't conflate it with the AI leverage % above — that one (trailers / `*_by_copilot`) is the metric that tells you AI was actually involved in a PR.

### What the metrics API can't tell you

The usage metrics API has no view into these. You need the trailer scan:

1. **AI rejection rate** — the Metrics API doesn't track closed-without-merge for AI PRs. Trailer scanning found 11.1% rejection rate (1 AI-attributed PR closed without merge out of 9 total AI PRs). This is a quality signal.
2. **Multi-tool attribution** — trailer scanning catches Claude Code, Copilot CLI, and VS Code agent mode. The Metrics API only tracks Copilot.
3. **Per-PR granularity** — the trailer script logs each PR individually, so you can see exactly which repos and PRs had AI involvement.

---

## 28-Day Rolling Metrics (Cloud Only)

The Copilot usage metrics API also provides a 28-day rolling view not available via trailer scanning:

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

## Auth differences

The two methods need different access. The usage metrics API requires **org admin, billing manager, or "View Copilot Metrics" access**. The GitHub App used for the trailer script (App ID: 4097118) returned `Resource not accessible by integration` against the metrics API because it lacks the `copilot` permission scope, so the metrics data above was fetched with a personal token that has org admin access.

The trailer scan only needs read access to commits and PRs (`repo` scope), which is easier to get.

---

## Summary

| Dimension | Trailer scanning | Copilot usage metrics API |
|---|---|---|
| **Setup** | Deploy VS Code setting + daily job | None — works out of the box |
| **Accuracy** | Depends on trailers being present (honesty system) | Server-side tracking (100% for coding agent) |
| **AI tools covered** | Copilot CLI, VS Code agent, Claude Code | Copilot only |
| **AI definition** | "Any PR with an AI co-author trailer" | "PR created by Copilot coding agent" |
| **ESSP coverage** | AI leverage + rejection rate + velocity | AI leverage + velocity + quality + throughput + adoption-phase cohorts |
| **Permissions needed** | `repo` scope | Org admin or Copilot metrics access |
| **Platform** | Any (GHES or Cloud/EMU) | Cloud/EMU only |
| **API cost** | ~2 calls per closed PR (via Search API) | 1-2 calls/day |

Run the trailer scan everywhere — it is the only way to see IDE and CLI usage, and it works on any platform. It gives you the broad AI leverage number, the rejection rate, and PR velocity (time-to-merge from PR timestamps). On Cloud/EMU, add the usage metrics API when you have coding agent or code review activity to account for; it adds review quality, throughput, and a coding-agent-scoped velocity number.
