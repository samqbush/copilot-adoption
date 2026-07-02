---
layout: default
title: Measuring AI in Pull Requests (Not Lines of Code)
description: Measure AI's contribution to merged PRs with trailer scanning and the Copilot usage metrics API
toc: true
---

# Measuring AI in Pull Requests (Not Lines of Code)
{:.no_toc}

*Last updated: July 2, 2026*

---

## The mission

Measure **AI leverage** — the share of your merged Pull Requests that involved AI — on your own stack, using two signals: `Co-authored-by` commit trailers (any GitHub edition) and the Copilot usage metrics API (Cloud/EMU). This guide hands you one reference implementation: two example scripts, the exact APIs behind them, and the MDM and plugin plumbing to make IDE usage show up in the number. It's one worked example, not the only way — adapt the waypoints to your stack.

Why the PR and not lines of code, in two sentences: counting lines suggested or accepted rewards verbose generated code and can't be tied to shipped work, so it produces a number you can't defend. The PR is the unit of shipped work, so "what share of merged PRs involved AI?" is a number you *can* list, audit, and defend — the full argument is in [Why the PR is the unit](#why-the-pr-is-the-unit).

---

## Why the PR is the unit {#why-the-pr-is-the-unit}

The reflex is to answer "how much are we using AI?" with a lines-suggested or lines-accepted number off the Copilot dashboard. Lines of code is the wrong unit for it:

- **Accepted suggestions are not kept code.** A developer can accept an inline completion, then rewrite or delete it before committing — the dashboard still counts the acceptance.
- **Lines are not value.** A 200-line generated boilerplate file and a 5-line fix that saved the weekend are not comparable, but LoC treats the big file as 40x more "AI."
- **It rewards the wrong behavior, and it is not auditable.** Optimizing for "lines written by AI" pushes teams toward verbose generated code, and there is no way to point at a commit and prove which lines were AI.

The PR is the unit of shipped work — reviewed, merged, in production. Ask "what share of our merged PRs involved AI?" and you get a number you can defend: you can list the exact PRs behind it, and it does not lurch when someone generates one big file. It tracks AI's reach into real output instead of keystrokes.

> [!NOTE]
> **Heads-up on the term "AI leverage."** GitHub's [Engineering System Success Playbook](https://github.com/resources/insights/engineering-system-success-playbook) (ESSP) and [Well-Architected Framework](https://wellarchitected.github.com/library/productivity/recommendations/engineering-system-metrics/) use *"AI leverage"* to mean something different: an estimated time-savings cost model — roughly *time saved × salary × headcount ÷ AI cost* — whose headline input (time saved) comes from developer surveys, not an API. The telemetry GitHub does define (the Copilot Metrics API's [suggestion and acceptance rate](https://wellarchitected.github.com/library/productivity/scenarios/measuring-genai-impact/)) measures *adoption*, and carries the same problems as counting lines. Neither framework measures AI's reach into merged PRs. So when "AI leverage" appears on this page, it means the share of merged PRs that involved AI — a PR-level, telemetry-backed metric, related to but distinct from the business-outcome metric of the same name in ESSP/WAF. Use ESSP and WAF for the four-zone model and the general point that raw output counts are weak signals.

---

## How AI Shows Up in a PR

There are two ways to detect AI involvement in a PR, and you need both because they cover different Copilot features.

**1. Co-authored-by trailers (any platform).**
AI tools can add a `Co-authored-by` [trailer](https://docs.github.com/en/enterprise-cloud@latest/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors) to commit messages. This is a standard Git feature. If the trailer lands on a commit, you can scan for it later. This catches IDE (VS Code) and Copilot CLI usage, and the Copilot coding agent too, since the agent tags its own commits.

**2. The Copilot usage metrics API (Cloud/EMU only).**
GitHub tracks the Copilot coding agent and Copilot code review server-side and exposes the counts through the [Copilot usage metrics API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics). No trailers, no client configuration. The coding agent already shows up in the trailer scan, but the API gives you its exact count separately, plus review coverage and suggestion acceptance that the trailer scan cannot derive.

Which detection method you need depends on which Copilot features are in play. That is what the two scripts below are for.

---

## The Two Scripts

This guide ships two example scripts. Run one or both depending on which Copilot features your developers use.

| Script | What it measures | When you need it |
|---|---|---|
| `ai-leverage-daily.sh` | AI leverage %, AI rejection rate, and median time-to-merge by scanning `Co-authored-by` trailers (Copilot CLI, VS Code, Claude Code) | **Always.** This is the only way to see IDE and CLI AI usage. |
| `copilot-cloud-agent-metrics.sh` | Coding agent PRs, code review coverage, suggestion acceptance, daily active users | **Add it if you are on Cloud/EMU** and use the Copilot coding agent or Copilot code review. |

`ai-leverage-daily.sh` is the baseline. Trailers are the only signal that captures a developer using Copilot in their editor or in the CLI, and that usage is invisible to the metrics API. It also computes median time-to-merge straight from each PR's `created_at` and `merged_at` timestamps, so you get PR velocity on any GitHub edition. Start here regardless of platform.

`copilot-cloud-agent-metrics.sh` adds two things. First, it isolates the Copilot coding agent subset of your PRs, which you can subtract from the trailer total to see how much leverage comes from IDE and CLI usage. Second, it reports metrics the trailer scan cannot derive: code review coverage, suggestion acceptance, daily active users, and a server-side time-to-merge pre-scoped to coding-agent PRs. It only works on Cloud/EMU because the usage metrics API is Cloud-only.

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
| Get a PR's merge status and timestamps (`created_at`, `merged_at`, `closed_at`) | `GET /repos/{owner}/{repo}/pulls/{pull_number}` | [Get a pull request](https://docs.github.com/en/enterprise-cloud@latest/rest/pulls/pulls#get-a-pull-request) |
| List a PR's commits to scan trailers | `GET /repos/{owner}/{repo}/pulls/{pull_number}/commits` | [List commits on a pull request](https://docs.github.com/en/enterprise-cloud@latest/rest/pulls/pulls#list-commits-on-a-pull-request) |

The same PR response carries `created_at` and `merged_at`, so the script computes median time-to-merge locally — no Cloud-only API required.

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
| **VS Code agent mode** | No — see [known gap](#agent-mode-gap) | `Co-authored-by: Copilot <copilot@github.com>` |
| **Claude Code** | Yes | `Co-Authored-By: Claude <noreply@anthropic.com>` |
| **Cursor agent** | Yes | `Made with Cursor` (not `Co-authored-by` format) |
| **Windsurf agent** | No | none |

VS Code shipped the setting default-on for a few weeks in spring 2026 ([PR 310226](https://github.com/microsoft/vscode/pull/310226) flipped the default to `all`), then walked it back to `off` ([PR 313931](https://github.com/microsoft/vscode/pull/313931)) after a debate over what `Co-authored-by` should mean for an AI. It is opt-in again today. Note the two different Copilot emails: the CLI uses the GitHub noreply address, while the VS Code setting uses `copilot@github.com`. Your scan pattern has to match both. The script uses `co-authored-by:.*(copilot|claude)`, which catches all of them.

**Cursor is a special case.** Cursor's Agent does tag commits by default — its CLI config field [`attribution.attributeCommitsToAgent`](https://cursor.com/docs/cli/reference/configuration) defaults to `true` and adds a `Made with Cursor` trailer (with a matching `Made with Cursor` footer on PRs via `attributePRsToAgent`). The catch is the format: it is a `Made with Cursor` line, not a `Co-authored-by` trailer, so the default scan pattern above does **not** catch it. If your developers use Cursor, extend the scan to also match `made with cursor`. Cursor users can disable the trailer in Settings → Agents → Attribution, or by setting `attributeCommitsToAgent` to `false` in `~/.cursor/cli-config.json`.

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

Make a commit after using inline completions or NES and confirm the trailer appears.

#### Agent mode gap {#agent-mode-gap}

> [!WARNING]
> `git.addAICoAuthor` does **not** work for VS Code Agent Mode — even if you click the Commit button in the Source Control panel after the agent edits files. Agent Mode writes files directly to disk, so VS Code's AI contribution tracker classifies those edits as external filesystem changes rather than AI-generated code. The trailer is only added for inline completions (NES) and chat/apply edits that go through the editor API.
>
> This is tracked in [vscode#316317](https://github.com/microsoft/vscode/issues/316317) and [vscode#297415](https://github.com/microsoft/vscode/issues/297415). Until the VS Code team fixes this, use the [enterprise plugin approach](#agent-mode-trailer-plugin) instead to get trailers on agent mode commits.

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
> Cursor's Agent tags commits with a `Made with Cursor` trailer by default, but it is not in `Co-authored-by` format, so the default scan pattern misses it unless you extend the pattern to also match `made with cursor`. Windsurf does not add any AI attribution trailer and exposes no externally detectable signal, so its commits will not show up in your AI leverage number unless the developer adds a trailer by hand.

---

## Enforcing Trailers via Enterprise Plugin {#agent-mode-trailer-plugin}

`git.addAICoAuthor` only works for inline completions and NES. For VS Code Agent Mode, you need a different approach. (Copilot CLI and the Copilot coding agent already add the trailer by default.)

There is no way to push a `.github/copilot-instructions.md` file to every repo in an organization at once, so the scalable solution is [enterprise plugin standards](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/about-enterprise-plugin-standards). Create a plugin with a `SessionStart` hook that injects the trailer context into every agent session, publish it to an internal marketplace, and deploy it enterprise-wide via `managed-settings.json`.

> [!NOTE]
> Enterprise plugin standards are in **public preview** and apply to Copilot CLI and VS Code (1.122+). JetBrains is not yet supported. See [About enterprise-managed plugin standards](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/about-enterprise-plugin-standards).

### 1. Plugin structure

```text
ai-commit-trailer/
├── plugin.json
├── hooks.json
└── scripts/
    └── inject-trailer.sh
```

**`plugin.json`**

```json
{
  "name": "ai-commit-trailer",
  "description": "Adds Co-authored-by trailer to every agent session via SessionStart hook",
  "version": "1.0.0",
  "author": {
    "name": "Your Org"
  },
  "hooks": "hooks.json"
}
```

**`hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "./scripts/inject-trailer.sh"
      }
    ]
  }
}
```

**`scripts/inject-trailer.sh`**

```bash
#!/bin/bash
# Outputs additionalContext telling the agent to always include the
# Co-authored-by trailer. Stdin (SessionStart event JSON) is ignored.
cat > /dev/null
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "When creating git commits, always include the following trailer at the end of the commit message, separated by a blank line:\n\nCo-authored-by: Copilot <copilot@github.com>"
  }
}
EOF
```

### 2. Marketplace

Host the plugin in a GitHub repository with a `.github/plugin/marketplace.json`:

```json
{
  "name": "your-org-plugins",
  "owner": {
    "name": "Your Organization"
  },
  "metadata": {
    "description": "Internal Copilot plugins",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "ai-commit-trailer",
      "description": "Adds Co-authored-by trailer to agent commits",
      "version": "1.0.0",
      "source": "./plugins/ai-commit-trailer"
    }
  ]
}
```

### 3. Enterprise deployment

In your enterprise's `.github-private` repository, create `copilot/managed-settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "your-org-plugins": {
      "source": {
        "source": "github",
        "repo": "your-org/copilot-plugins"
      }
    }
  },
  "enabledPlugins": {
    "ai-commit-trailer@your-org-plugins": true
  }
}
```

Once merged to the default branch, every enterprise user on the Copilot plan gets the plugin auto-installed on next authentication. The hook fires at session start and injects the trailer context.

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
  "ai_rejection_rate_pct": 11.1,
  "median_time_to_merge_min": 142.5,
  "median_ai_time_to_merge_min": 98.3
}
```

| Metric | Formula | ESSP zone |
|---|---|---|
| AI leverage | AI-attributed merged PRs ÷ total merged PRs | Activity |
| AI rejection rate | AI-attributed closed-without-merge ÷ all AI-attributed PRs | Quality |
| Median time to merge | Median of `merged_at − created_at` across merged PRs | Velocity |
| AI vs human velocity | `median_ai_time_to_merge_min` vs `median_time_to_merge_min` | Velocity |

Time-to-merge comes from each PR's own `created_at` and `merged_at`, which the standard pulls API returns on any GitHub edition, so the baseline script reports velocity without the Cloud-only metrics API. Both medians are `null` when nothing merged in the window.

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

The coding agent adds a `Co-authored-by: Copilot` trailer too, so its PRs already count toward the trailer scan's total. What this script adds is the breakdown. The coding-agent-only count (`total_merged_created_by_copilot`) lets you subtract that subset from the trailer total to see how much of your AI leverage comes from IDE, CLI, and Claude instead. It also reports things the trailer scan cannot derive: code review coverage (`total_reviewed_by_copilot`), suggestion acceptance, daily active users, and a server-side time-to-merge pre-scoped to coding-agent PRs. (Overall and AI-attributed time-to-merge for all PRs already comes from the baseline scan.) See the [scripts README](./ai-commit-attribution/README.md) for the full output schema and ESSP mapping.

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
| Median time to merge | 142.5 min | 0.53 min |
| Median TTM (AI-attributed) | 98.3 min | 10.25 min |
| Daily active Copilot users | — | 812 |

The trailer scan found 8 AI PRs; the metrics API found 2. Both are right, and the gap is the useful part. The coding agent tags its commits, so its 2 PRs are already inside the trailer scan's 8. Subtract the agent count and you learn that 6 of the 8 came from developers using Copilot in their editor or the CLI. That split is exactly why you run the trailer scan everywhere and add the metrics API when you have coding agent or review activity to break out. The two time-to-merge columns differ because they measure different sets: the baseline median covers every merged PR (and its AI-attributed subset), while the metrics API median is scoped to coding-agent-authored PRs only.

See [ghes-vs-cloud-comparison.md](./ai-commit-attribution/ghes-vs-cloud-comparison.md) for the full side-by-side with real data.

---

## Limitations

- **Inline completions need the `all` setting.** `git.addAICoAuthor` only tags inline completions at the `all` level. The `chatAndAgent` value tags chat and agent edits but skips completions by design, so a fleet on `chatAndAgent` undercounts editor usage.
- **`git.addAICoAuthor` does not work for Agent Mode.** VS Code Agent Mode writes files directly to disk, so the AI contribution tracker never registers those edits. The trailer is not added even if you click the Commit button after agent edits. Use the [enterprise plugin approach](#agent-mode-trailer-plugin) instead. Tracked in [vscode#316317](https://github.com/microsoft/vscode/issues/316317).
- **`git.addAICoAuthor` is not enforceable.** It is a regular VS Code setting, not an [enterprise policy](https://code.visualstudio.com/docs/enterprise/policies). Developers can turn it off.
- **Manual terminal commits bypass both mechanisms.** `git.addAICoAuthor` only fires when committing through VS Code's Source Control panel, and the enterprise plugin hook only injects context into the agent's session. If a developer uses Copilot to write code then runs `git commit` from the terminal or any Git client outside VS Code, neither mechanism adds the trailer. There is no Git-level hook that detects whether staged changes were AI-assisted.
- **Trailers are removable.** A developer can edit a commit message before pushing. This is an honesty system, not an audit trail.
- **No standard trailer yet.** The industry is split between `Co-authored-by`, `Assisted-by`, and `AI-Generated-By`. The Linux kernel is looking at `Assisted-by`; Microsoft is tracking it in [vscode#313962](https://github.com/microsoft/vscode/issues/313962).
- **Cursor uses a non-standard trailer.** Cursor's Agent tags commits with `Made with Cursor` by default ([`attributeCommitsToAgent`](https://cursor.com/docs/cli/reference/configuration) defaults to `true`), but it is not a `Co-authored-by` trailer, so the default scan pattern misses it. Extend the pattern to match `made with cursor` if you have Cursor users, and note developers can disable it.
- **Windsurf is invisible.** It neither tags commits nor exposes a detectable signal.

None of this makes the number useless. It makes it a directional adoption metric rather than a compliance audit. If you need an enforceable, server-side count, that is what the Copilot usage metrics API gives you on Cloud/EMU, within its narrower coding-agent definition.
