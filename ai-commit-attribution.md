---
layout: default
title: AI Commit Attribution — GHES Runbook
toc: true
---

# AI Commit Attribution — GHES Runbook
{:.no_toc}

*Last updated: June 19, 2026*

How to track which Pull Requests contain AI-authored commits on GitHub Enterprise Server, where Cloud/EMU-only PR metrics are unavailable.

---

## Why This Matters

GitHub Enterprise Cloud exposes native API metrics for AI-attributed PRs — fields like `total_merged_created_by_copilot` in the [Copilot Metrics API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics). GHES customers don't have access to these metrics.

However, the underlying mechanism is portable: AI tools add a `Co-authored-by` [trailer](https://docs.github.com/en/enterprise-cloud@latest/pull-requests/committing-changes-to-your-project/creating-and-editing-commits/creating-a-commit-with-multiple-authors) to git commit messages. This is a standard Git feature that works on any platform. If you make sure these trailers land on commits and then query for them, you get equivalent visibility on GHES.

---

## Tool Landscape: What Tags Commits Today?

| Tool | Adds trailer by default? | Trailer format | Source |
|---|---|---|---|
| **Copilot CLI** | ✅ Yes | `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` | Built into CLI system prompt |
| **VS Code Agent Mode** | ❌ No (opt-in) | `Co-authored-by: Copilot <copilot@github.com>` | Was default in [v1.118](https://code.visualstudio.com/updates/v1_118) (April 2026), [reverted in v1.119](https://github.com/microsoft/vscode/pull/310226) after community backlash (372 👎). Opt-in via `git.addAICoAuthor` setting. |
| **Claude Code** | ✅ Yes | `Co-Authored-By: Claude <noreply@anthropic.com>` | Default on; disable with `attribution.commits: false` in [Claude Code settings](https://docs.anthropic.com/en/docs/claude-code/settings) |
| **Cursor Agent** | ❌ No | — | No automatic attribution as of June 2026 |
| **Windsurf Agent** | ❌ No | — | No automatic attribution as of June 2026 |

Bottom line: Copilot CLI and Claude Code handle this automatically. VS Code agent mode — the most common agent workflow — requires you to turn it on.

> [!NOTE]
> **Note the different email addresses**: Copilot CLI uses the GitHub noreply format (`223556219+Copilot@users.noreply.github.com`) while VS Code's built-in setting uses `copilot@github.com`. Both are valid, but your query patterns need to match both.

---

## Configuration: Ensuring AI Commits Are Tagged

Two approaches. Recommend both for defense in depth.

### Option A: VS Code Setting (IDE-Level) — Recommended Starting Point

The VS Code Git extension has a built-in [`git.addAICoAuthor`](https://github.com/microsoft/vscode/blob/main/extensions/git/package.json) setting with three values:

| Value | Behavior |
|---|---|
| `"off"` | Never add trailer **(default)** |
| `"chatAndAgent"` | Add trailer when code from chat or agent edits is included |
| `"all"` | Add trailer when any AI-generated code is included (inline completions, chat, and agent edits) |

Enable it in workspace settings committed to repos:

```json
// .vscode/settings.json (committed to repo)
{
  "git.addAICoAuthor": "all"
}
```

**Key constraint: This is NOT an enforceable enterprise policy.** The VS Code [enterprise policy allowlist](https://code.visualstudio.com/docs/enterprise/policies) does not include `git.addAICoAuthor`. This means:

- It will **not** appear in ADMX/Group Policy templates or Intune Settings Catalog
- It **cannot** be locked — developers can override it in their user settings
- It will **not** show the "managed by your organization" lock icon in VS Code

This is the same constraint as [Copilot OpenTelemetry settings](https://code.visualstudio.com/docs/agents/guides/monitoring-agents) — you can push it as an overridable default, but you cannot enforce it. See the [Copilot OpenTelemetry via Intune](./copilot-otel-intune) guide for the full pattern.

#### Deploying via MDM (Intune example)

Push `git.addAICoAuthor` as a default into each developer's VS Code `settings.json` via an MDM script. Same mechanism as OTel deployment (see [Copilot OpenTelemetry via Intune — Part 2A](./copilot-otel-intune#2a-vs-code-half--default-settingsjson-shell-script) for the full pattern).

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

> [!NOTE]
> These are overridable defaults. A developer can change the setting in their VS Code preferences. For observability use cases (measuring AI adoption) this is acceptable — most developers won't bother overriding it. For compliance/audit requirements where override is unacceptable, the server-side metrics on Cloud/EMU are the only enforceable path.

### Option B: Git Hook (Repo-Level, Tool-Agnostic)

A [`prepare-commit-msg`](https://git-scm.com/docs/githooks#_prepare_commit_msg) hook catches commits from ALL agent tools — including Cursor, Windsurf, or any future tool that runs `git commit`:

```bash
#!/bin/bash
# .git/hooks/prepare-commit-msg
# Adds AI co-author trailer when an AI agent session is detected

COMMIT_MSG_FILE="$1"
COMMIT_SOURCE="$2"

# Skip merge/squash commits
[[ "$COMMIT_SOURCE" == "merge" || "$COMMIT_SOURCE" == "squash" ]] && exit 0

# Check if trailer already exists (from VS Code setting or tool default)
grep -qi "Co-authored-by:.*\(Copilot\|Claude\|AI-Agent\)" "$COMMIT_MSG_FILE" && exit 0

# Detect AI agent sessions via environment signals
AI_DETECTED=false
[[ -n "$COPILOT_SESSION" ]] && AI_DETECTED=true  # Copilot CLI
[[ -n "$CLAUDE_CODE" ]] && AI_DETECTED=true       # Claude Code

# Alternative: "always-on" approach — tag all commits unconditionally
# Uncomment the line below if you want to assume AI is always involved:
# AI_DETECTED=true

if [[ "$AI_DETECTED" == "true" ]]; then
    TRAILER="Co-authored-by: AI-Agent <ai-agent@company.com>"
    git interpret-trailers --in-place --trailer "$TRAILER" "$COMMIT_MSG_FILE"
fi
```

**Distribution options:**
- Set org-wide default hooks directory: `git config --global core.hooksPath ~/.git-hooks` ([git docs](https://git-scm.com/docs/git-config#Documentation/git-config.txt-corehooksPath))
- Use hook managers: [Husky](https://typicode.github.io/husky/) (JS), [Lefthook](https://github.com/evilmartians/lefthook) (polyglot), [pre-commit](https://pre-commit.com/) (Python)
- Bake into developer environment setup scripts or machine images

**Pros**: Works with any AI tool, tool-agnostic, catches tools that don't self-tag
**Cons**: Developers can bypass hooks with `git commit --no-verify`; requires a distribution strategy

---

## Measuring AI Leverage: Querying PRs on GHES

This section lines up with the [Engineering System Success Playbook (ESSP)](https://github.com/resources/insights/engineering-system-success-playbook) — specifically the **(Percentage) AI leverage** metric in the Business Outcomes zone. See also the [Well-Architected Framework: Engineering System Metrics](https://wellarchitected.github.com/library/productivity/recommendations/engineering-system-metrics/).

The goal: **What percentage of merged (or closed) PRs in a given period contained at least one AI-authored commit?**

### Trailer Patterns to Search For

Different tools use different trailer formats. Your queries need to match all variants in use:

| Tool | Trailer format |
|---|---|
| Copilot CLI | `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` |
| VS Code (`git.addAICoAuthor`) | `Co-authored-by: Copilot <copilot@github.com>` |
| Claude Code | `Co-Authored-By: Claude <noreply@anthropic.com>` |
| Custom hook (if deployed) | `Co-authored-by: AI-Agent <ai-agent@company.com>` |

A broad match pattern that catches all of these: `Co-authored-by:.*Copilot` and `Co-authored-by:.*Claude`

### Approach: GHES REST API

A GHES admin runs this centrally against the GHES API. No repo cloning or local git access required.

**Step 1: List merged PRs for a repo in a date range**

Use the [List pull requests](https://docs.github.com/en/enterprise-server@3.21/rest/pulls/pulls#list-pull-requests) endpoint. Filter to `state=closed`, then check `merged_at` in the response to confirm it was merged (not just closed):

```bash
curl -s -H "Authorization: token $GHES_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://GHES_HOSTNAME/api/v3/repos/{owner}/{repo}/pulls?state=closed&sort=updated&direction=desc&per_page=100"
```

Each result includes `merged_at` (non-null if merged) and `number` (the PR number).

**Step 2: For each merged PR, fetch its commits**

Use the [List commits on a pull request](https://docs.github.com/en/enterprise-server@3.21/rest/pulls/pulls#list-commits-on-a-pull-request) endpoint:

```bash
curl -s -H "Authorization: token $GHES_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://GHES_HOSTNAME/api/v3/repos/{owner}/{repo}/pulls/{pull_number}/commits?per_page=100"
```

Each commit object includes `commit.message` — check this field for AI co-author trailers.

**Step 3: Check commit messages for AI trailers**

For each commit in the PR, check if `commit.message` contains any of the trailer patterns above. If at least one commit has a match, the PR is "AI-attributed."

**Step 4: Aggregate**

```
AI Leverage (%) = (PRs with ≥1 AI commit / Total merged PRs) × 100
```

### Scaling Across the Instance

To run this across all repos in an org (or the entire GHES instance):

- **List all repos**: [`GET /orgs/{org}/repos`](https://docs.github.com/en/enterprise-server@3.21/rest/repos/repos#list-organization-repositories) or [`GET /organizations`](https://docs.github.com/en/enterprise-server@3.21/rest/orgs/orgs#list-organizations) + repos per org
- **Pagination**: All endpoints return max 100 results per page. Use `Link` header pagination to iterate.
- **Rate limiting**: GHES rate limits are [disabled by default](https://docs.github.com/en/enterprise-server@3.21/rest/search/search) but may be enabled. Check with your GHES site admin.
- **Commit search shortcut**: The [search commits](https://docs.github.com/en/enterprise-server@3.21/rest/search/search#search-commits) endpoint can find AI-attributed commits across repos in a single query:

```bash
curl -s -H "Authorization: token $GHES_TOKEN" \
  -H "Accept: application/vnd.github.cloak-preview+json" \
  "https://GHES_HOSTNAME/api/v3/search/commits?q=org:MY_ORG+author-date:>2026-05-01+Co-authored-by+Copilot"
```

> [!NOTE]
> Search returns max 1,000 results. For large orgs, use the per-repo PR + commits approach above.

### Recommended Automation

Run this as a scheduled GitHub Actions workflow on GHES (or a cron job) that:
- Queries all repos in the org for merged PRs in the last 7/30 days
- Checks each PR's commits for AI trailers
- Outputs a report: total PRs, AI-attributed PRs, AI leverage %, broken down by repo and by developer
- Stores results over time to track trending

---

## Limitations & Gaps

- **IDE completions are NOT tracked** — This approach only covers agent/CLI sessions where AI makes commits. A developer using Copilot inline suggestions in the editor gets no trailer. The `"all"` value for `git.addAICoAuthor` attempts to cover completions, but detection accuracy for inline completions is lower than for agent/chat edits.
- **`git.addAICoAuthor` is not enforceable** — It's a regular VS Code setting, not an [enterprise policy](https://code.visualstudio.com/docs/enterprise/policies). Developers can override it. Same constraint as OTel monitoring.
- **Trailers are removable** — Developers can edit commit messages or use `--no-verify` to skip hooks. This is an honesty system.
- **False positives are possible** — VS Code's `git.addAICoAuthor` [historically tagged commits even when AI wasn't actually used](https://github.com/microsoft/vscode/pull/310226) (part of why it was reverted from default-on)
- **No standard trailer yet** — Industry is split between `Co-authored-by`, `Assisted-by`, and `AI-Generated-By`. The Linux kernel is exploring `Assisted-by`. Microsoft is tracking this in [vscode#313962](https://github.com/microsoft/vscode/issues/313962).
- **Cross-tool inconsistency** — Different tools use different trailer formats and email addresses, requiring broad grep patterns

---

## What Cloud/EMU Gives You Instead

For comparison, GitHub Enterprise Cloud provides native metrics via the [Copilot Metrics API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics):

| Capability | GHES (this runbook) | Cloud/EMU (native) |
|---|---|---|
| AI PR metrics | Manual query via trailers | [`total_merged_created_by_copilot`](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics) |
| Time-to-merge comparison | DIY calculation | `median_minutes_to_merge_copilot_authored` |
| Copilot code review tracking | Not available | `total_merged_reviewed_by_copilot` |
| Per-user AI engagement | Not available | [Per-user metrics endpoints](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-usage-metrics/copilot-usage-metrics) |
| Configuration required | VS Code settings + hooks (overridable) | None — works out of the box |
| Accuracy | Depends on trailer presence (honesty system) | Server-side tracking (100% for coding agent) |

The native Cloud/EMU metrics track at the platform level. No client configuration, no trailers to manage, no opt-out risk.

---

## Recommended Implementation Order

1. Commit `.vscode/settings.json` with `"git.addAICoAuthor": "all"` to repositories (immediate, covers the most common agent workflow)
2. Copilot CLI already tags by default — no action needed
3. For orgs using Claude Code — already tags by default
4. For orgs using Cursor/Windsurf or wanting a safety net — deploy a `prepare-commit-msg` hook via `core.hooksPath` or a hook manager
5. Build a periodic query (weekly/monthly) against GHES commit search to track AI PR percentage over time
