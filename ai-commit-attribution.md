---
layout: default
title: Measuring AI in Pull Requests (Not Lines of Code)
toc: true
---

# Measuring AI in Pull Requests (Not Lines of Code)
{:.no_toc}

*Last updated: June 19, 2026*


A practical way to answer "how much are we using AI?" by measuring AI's contribution to Pull Requests instead of counting lines of code.

---

## The Problem: The Wrong Question

A leader reads that "47% of our code is written by AI" and asks the Copilot admin to prove it. The admin opens the Copilot dashboard, finds a lines-suggested or lines-accepted number, and tries to turn it into a percentage of the codebase.

That number does not mean what people think it means. Lines of code is a bad unit for this question:

- **Accepted suggestions are not kept code.** A developer can accept an inline completion, then rewrite or delete it before committing. The dashboard still counts the acceptance.
- **Lines are not value.** A 200-line generated boilerplate file and a 5-line bug fix that saves the weekend are not comparable, but LoC treats the big file as 40x more "AI."
- **It rewards the wrong behavior.** Optimizing for "lines written by AI" pushes teams toward verbose, generated code, which is the opposite of what you want.
- **It is not auditable.** There is no way to point at a specific commit and say "this line was AI and that one was not."

So when a leader asks "how much are we using AI?", counting lines sends you down a path that produces a number you cannot defend.

## The Better Question: AI Leverage

GitHub's [Engineering System Success Playbook](https://github.com/resources/insights/engineering-system-success-playbook) (ESSP) frames the useful metric as **AI leverage**: the share of merged Pull Requests that involved AI. The [Well-Architected Framework](https://wellarchitected.github.com/library/productivity/recommendations/engineering-system-metrics/) summarizes the same idea.

The PR is the right unit because it is the unit of shipped work. A PR got reviewed, merged, and went to production. Ask "what percentage of our merged PRs had AI involved?" and you get a number you can actually defend: you can list the exact PRs behind it, and it does not lurch around just because someone generated one big boilerplate file. It tracks AI's reach into real output instead of counting keystrokes.

This guide shows how to measure AI leverage across the Copilot features your developers actually use.

---

## How AI Shows Up in a PR

There are two ways to detect AI involvement in a PR, and you need both because they cover different Copilot features.

**1. Co-authored-by trailers (any platform).**
AI tools can add a `Co-authored-by` [trailer](https://docs.github.com/en/enterprise-cloud@latest/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors) to commit messages. This is a standard Git feature. If the trailer lands on a commit, you can scan for it later. This catches IDE (VS Code) and Copilot CLI usage, and the Copilot coding agent too, since the agent tags its own commits.

**2. The Copilot usage metrics API (Cloud/EMU only).**
GitHub tracks the Copilot coding agent and Copilot code review server-side and exposes the counts through the [Copilot usage metrics API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics). No trailers, no client configuration. The coding agent already shows up in the trailer scan, but the API gives you its exact count separately, plus review coverage and time-to-merge that trailers cannot provide.

Which detection method you need depends on which Copilot features are in play. That is what the two scripts below are for.

---

## The Two Scripts

This guide ships two example scripts. Run one or both depending on which Copilot features your developers use.

| Script | What it measures | When you need it |
|---|---|---|
| `ai-leverage-daily.sh` | AI leverage % and AI rejection rate by scanning `Co-authored-by` trailers (Copilot CLI, VS Code, Claude Code) | **Always.** This is the only way to see IDE and CLI AI usage. |
| `copilot-cloud-agent-metrics.sh` | Coding agent PRs, code review coverage, suggestion acceptance, time-to-merge, daily active users | **Add it if you are on Cloud/EMU** and use the Copilot coding agent or Copilot code review. |

`ai-leverage-daily.sh` is the baseline. Trailers are the only signal that captures a developer using Copilot in their editor or in the CLI, and that usage is invisible to the metrics API. Start here regardless of platform.

`copilot-cloud-agent-metrics.sh` adds two things. First, it isolates the Copilot coding agent subset of your PRs, which you can subtract from the trailer total to see how much leverage comes from IDE and CLI usage. Second, it reports metrics trailers cannot provide at all: code review coverage, suggestion acceptance, and velocity numbers like time-to-merge. It only works on Cloud/EMU because the usage metrics API is Cloud-only.

> [!NOTE]
> The scripts are example implementations meant for manual testing and as a starting point you can adapt. For ongoing measurement, run them on a daily schedule in whatever pipeline you already use. See [Running it on a schedule](#running-it-on-a-schedule).

### Picking your scripts

| Your setup | Scripts to run |
|---|---|
| GHES, or developers only use IDE/CLI | `ai-leverage-daily.sh` |
| Cloud/EMU, want AI leverage % only | `ai-leverage-daily.sh` |
| Cloud/EMU, using coding agent and/or Copilot code review | both |

---

## Underlying APIs

The scripts are examples. If you want to build your own tooling, here are the exact endpoints each one calls so you do not have to read the source. All links point to the GitHub REST API reference.

### ai-leverage-daily.sh

This script finds recently closed PRs, then checks each one's commits for an AI co-author trailer.

| Step | Endpoint | Docs |
|---|---|---|
| Find closed PRs in the org and time window | `GET /search/issues` | [Search issues and pull requests](https://docs.github.com/en/enterprise-cloud@latest/rest/search/search#search-issues-and-pull-requests) |
| Get a PR's merge status (`merged_at` vs `closed_at`) | `GET /repos/{owner}/{repo}/pulls/{pull_number}` | [Get a pull request](https://docs.github.com/en/enterprise-cloud@latest/rest/pulls/pulls#get-a-pull-request) |
| List a PR's commits to scan trailers | `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits` | [List commits on a pull request](https://docs.github.com/en/enterprise-cloud@latest/rest/pulls/pulls#list-commits-on-a-pull-request) |

It needs read access to repository contents and pull requests (`repo` scope on a PAT, or Contents + Pull requests read on a GitHub App).

### copilot-cloud-agent-metrics.sh

This script pulls pre-aggregated PR metrics from the Copilot usage metrics reports. Each endpoint returns `download_links` to an NDJSON report that the script then downloads and parses.

| Report | Endpoint | Docs |
|---|---|---|
| Org, single day | `GET /orgs/{org}/copilot/metrics/reports/organization-1-day?day=YYYY-MM-DD` | [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics) |
| Org, 28-day rolling | `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest` | [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics) |
| Enterprise, single day | `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-1-day?day=YYYY-MM-DD` | [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics) |
| Enterprise, 28-day rolling | `GET /enterprises/{enterprise}/copilot/metrics/reports/enterprise-28-day/latest` | [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics) |

It needs the **Copilot usage metrics** policy enabled, plus org admin, billing manager, or the "View Copilot Metrics" permission. A PAT needs `manage_billing:copilot` or `read:enterprise`.

### GitHub App auth (used by both scripts)

If you authenticate as a GitHub App for the higher rate limit, both scripts call one more endpoint to mint a token from your App's private key.

| Step | Endpoint | Docs |
|---|---|---|
| Create an installation access token | `POST /app/installations/{installation_id}/access_tokens` | [Create an installation access token](https://docs.github.com/en/enterprise-cloud@latest/rest/apps/apps#create-an-installation-access-token-for-an-app) |

See [github-app-setup.md](./ai-commit-attribution/github-app-setup.md) for the one-time App creation steps.

---

## Making IDE Usage Measurable

Trailer scanning only finds what is tagged. Copilot CLI tags commits by default, but VS Code does not. If you want IDE Copilot usage to show up in your AI leverage number, you have to turn the trailer on and push it to your developers.

### Which tools tag commits today

| Tool | Adds trailer by default? | Trailer format |
|---|---|---|
| **Copilot CLI** | Yes | `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` |
| **VS Code agent mode** | No (opt-in) | `Co-authored-by: Copilot <copilot@github.com>` |
| **Claude Code** | Yes | `Co-Authored-By: Claude <noreply@anthropic.com>` |
| **Cursor agent** | No | none |
| **Windsurf agent** | No | none |

VS Code shipped the setting default-on for a few weeks in spring 2026 ([PR 310226](https://github.com/microsoft/vscode/pull/310226) flipped the default to `all`), then walked it back to `off` ([PR 313931](https://github.com/microsoft/vscode/pull/313931)) after a debate over what `Co-authored-by` should mean for an AI. It is opt-in again today. Note the two different Copilot emails: the CLI uses the GitHub noreply address, while the VS Code setting uses `copilot@github.com`. Your scan pattern has to match both. The script uses `co-authored-by:.*(copilot|claude)`, which catches all of them.

### The VS Code setting

VS Code's Git extension has a [`git.addAICoAuthor`](https://github.com/microsoft/vscode/blob/main/extensions/git/package.json) setting:

| Value | Behavior |
|---|---|
| `"off"` | Never add the trailer (default) |
| `"chatAndAgent"` | Add the trailer when code from chat or agent edits is included |
| `"all"` | Add the trailer when any AI-generated code is included, including inline completions |

Test it locally first:

```json
// VS Code user settings (Cmd+Shift+P → "Preferences: Open User Settings (JSON)")
{
  "git.addAICoAuthor": "all"
}
```

Make a commit from agent mode and confirm the trailer appears.

### Deploying it fleet-wide via MDM

`git.addAICoAuthor` is a regular VS Code setting, not an enterprise policy. It is not on the VS Code [policy allowlist](https://code.visualstudio.com/docs/enterprise/policies), so it will not appear in ADMX/Group Policy or the Intune Settings Catalog, and you cannot lock it. You can still push it as a default through an MDM script, the same approach the [Copilot OpenTelemetry via Intune](./copilot-otel-intune) guide uses. Developers can override it, but most will not bother, which is fine for an adoption-measurement use case.

**macOS** — Intune → Devices → Scripts → shell script, run as root:

```bash
#!/bin/bash
# deploy-vscode-ai-coauthor.sh
# Merges git.addAICoAuthor into each user's VS Code settings.
# This is a DEFAULT — users can still override it.

for HOME_DIR in /Users/*; do
  USER_NAME=$(basename "$HOME_DIR")
  [ "$USER_NAME" = "Shared" ] && continue
  SETTINGS_DIR="$HOME_DIR/Library/Application Support/Code/User"
  SETTINGS="$SETTINGS_DIR/settings.json"
  [ -d "$HOME_DIR/Library/Application Support/Code" ] || continue
  mkdir -p "$SETTINGS_DIR"

  if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS" ]; then
    tmp=$(mktemp)
    jq '."git.addAICoAuthor" = "all"' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  else
    cat > "$SETTINGS" <<'EOF'
{
  "git.addAICoAuthor": "all"
}
EOF
  fi
  chown "$USER_NAME" "$SETTINGS"
done
```

**Windows** — Intune → Devices → Scripts and remediations → Platform scripts, run in user context:

```powershell
# Set-AICoAuthor.ps1
$settingsPath = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $settingsPath) {
    $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $json | Add-Member -NotePropertyName 'git.addAICoAuthor' -NotePropertyValue 'all' -Force
    $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath
} else {
    $dir = Split-Path $settingsPath
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
    '{ "git.addAICoAuthor": "all" }' | Set-Content $settingsPath
}
```

> [!IMPORTANT]
> Cursor and Windsurf do not add AI attribution trailers and do not expose a signal you can detect externally. Commits from those tools will not show up in your AI leverage number unless the developer adds a trailer by hand.

---

## Running the Scripts

### ai-leverage-daily.sh

Scans every repo's recently closed PRs and reports the share that had an AI co-author trailer.

```bash
# Uses your gh CLI auth or GH_TOKEN
./ai-commit-attribution/scripts/ai-leverage-daily.sh octodemo

# Scan a specific window
./ai-commit-attribution/scripts/ai-leverage-daily.sh octodemo --since 2026-06-18T00:00:00Z
```

Output (stdout is clean JSON; progress goes to stderr):

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

| Metric | Formula | ESSP zone |
|---|---|---|
| AI leverage | AI-attributed merged PRs ÷ total merged PRs | Activity |
| AI rejection rate | AI-attributed closed-without-merge ÷ all AI-attributed PRs | Quality |

A rising rejection rate for AI PRs, compared to non-AI PRs, can mean AI-generated code is not passing review. Treat it as a prompt to talk to the team, not a conclusion.

### copilot-cloud-agent-metrics.sh

Pulls Copilot coding agent and code review metrics from the usage metrics API.

```bash
# Yesterday (default)
./ai-commit-attribution/scripts/copilot-cloud-agent-metrics.sh octodemo

# A specific day, the last N days, or the 28-day rolling report
./ai-commit-attribution/scripts/copilot-cloud-agent-metrics.sh octodemo --day 2026-06-18
./ai-commit-attribution/scripts/copilot-cloud-agent-metrics.sh octodemo --days 7
./ai-commit-attribution/scripts/copilot-cloud-agent-metrics.sh octodemo --28day

# Enterprise level
./ai-commit-attribution/scripts/copilot-cloud-agent-metrics.sh octodemo --enterprise my-enterprise --28day
```

The coding agent adds a `Co-authored-by: Copilot` trailer too, so its PRs already count toward the trailer scan's total. What this script adds is the breakdown. The coding-agent-only count (`total_merged_created_by_copilot`) lets you subtract that subset from the trailer total to see how much of your AI leverage comes from IDE, CLI, and Claude instead. It also reports things trailers cannot show at all: code review coverage (`total_reviewed_by_copilot`), suggestion acceptance, median time-to-merge, and daily active users. See the [scripts README](./ai-commit-attribution/README.md) for the full output schema and ESSP mapping.

### Running it on a schedule

The scripts are for manual testing and as a starting point. For ongoing measurement, run `ai-leverage-daily.sh` (and `copilot-cloud-agent-metrics.sh` if you need it) once a day in whatever pipeline you already operate. A scheduled GitHub Actions workflow, a Jenkins job, a GitLab CI schedule, or a plain cron entry all work. Pipe the JSON output to a dashboard, a database, or a build artifact.

For anything beyond a small org, authenticate as a GitHub App rather than a PAT. App installation tokens get 15,000 requests/hour versus 5,000 for a PAT, and they expire after an hour. See [github-app-setup.md](./ai-commit-attribution/github-app-setup.md).

> [!NOTE]
> The trailer scan finds closed PRs through the Search API instead of walking every repo, so its cost scales with the number of closed PRs, not the number of repos. Each closed PR costs about two calls (one for merge status, one for its commits), so a day with 50 closed PRs is roughly 100 calls. The metrics API script uses one or two calls per run.

---

## Two Signals, One Picture

On Cloud/EMU the two scripts answer different questions, and the gap between them is the point.

Trailer scanning counts **any** PR with an AI co-author, so it is the superset for AI leverage: coding agent PRs (which add trailers), plus IDE and CLI usage, plus Claude Code. The usage metrics API counts a narrower thing, `total_merged_created_by_copilot`, which is only PRs the coding agent fully created. Running both on octodemo for the same day:

| Metric | `ai-leverage-daily.sh` | `copilot-cloud-agent-metrics.sh` |
|---|---|---|
| Total merged PRs | 23 | 23 |
| AI-attributed merged | 8 (34.8%) | 2 (8.7%) |
| AI rejection rate | 11.1% | — |
| PRs reviewed by Copilot | — | 345 |
| Median time to merge | — | 0.53 min |
| Median TTM (Copilot-authored) | — | 10.25 min |
| Daily active Copilot users | — | 812 |

The trailer scan found 8 AI PRs; the metrics API found 2. Both are right, and the gap is the useful part. The coding agent tags its commits, so its 2 PRs are already inside the trailer scan's 8. Subtract the agent count and you learn that 6 of the 8 came from developers using Copilot in their editor or the CLI. That split is exactly why you run the trailer scan everywhere and add the metrics API when you have coding agent or review activity to break out.

See [ghes-vs-cloud-comparison.md](./ai-commit-attribution/ghes-vs-cloud-comparison.md) for the full side-by-side with real data.

---

## Limitations

- **Inline completions need the `all` setting.** `git.addAICoAuthor` only tags inline completions at the `all` level. The `chatAndAgent` value tags chat and agent edits but skips completions by design, so a fleet on `chatAndAgent` undercounts editor usage.
- **`git.addAICoAuthor` is not enforceable.** It is a regular VS Code setting, not an [enterprise policy](https://code.visualstudio.com/docs/enterprise/policies). Developers can turn it off.
- **Trailers are removable.** A developer can edit a commit message before pushing. This is an honesty system, not an audit trail.
- **No standard trailer yet.** The industry is split between `Co-authored-by`, `Assisted-by`, and `AI-Generated-By`. The Linux kernel is looking at `Assisted-by`; Microsoft is tracking it in [vscode#313962](https://github.com/microsoft/vscode/issues/313962).
- **Cursor and Windsurf are invisible.** Neither tags commits nor exposes a detectable signal.

None of this makes the number useless. It makes it a directional adoption metric rather than a compliance audit. If you need an enforceable, server-side count, that is what the Copilot usage metrics API gives you on Cloud/EMU, within its narrower coding-agent definition.
