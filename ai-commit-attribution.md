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


> [!NOTE]
> **Note the different email addresses**: Copilot CLI uses the GitHub noreply format (`223556219+Copilot@users.noreply.github.com`) while VS Code's built-in setting uses `copilot@github.com`. Both are valid, but your query patterns need to match both.

---

## Configuration: Ensuring AI Commits Are Tagged

### VS Code Setting (IDE-Level)

The VS Code Git extension has a built-in [`git.addAICoAuthor`](https://github.com/microsoft/vscode/blob/main/extensions/git/package.json) setting with three values:

| Value | Behavior |
|---|---|
| `"off"` | Never add trailer **(default)** |
| `"chatAndAgent"` | Add trailer when code from chat or agent edits is included |
| `"all"` | Add trailer when any AI-generated code is included (inline completions, chat, and agent edits) |

Test locally by adding it to your VS Code user settings:

```json
// VS Code user settings (Cmd+Shift+P → "Preferences: Open User Settings (JSON)")
{
  "git.addAICoAuthor": "all"
}
```

**Key constraint: This is NOT an enforceable enterprise policy.** The VS Code [enterprise policy allowlist](https://code.visualstudio.com/docs/enterprise/policies) does not include `git.addAICoAuthor`. This means:

- It will **not** appear in ADMX/Group Policy templates or Intune Settings Catalog
- It **cannot** be locked — developers can override it in their user settings
- It will **not** show the "managed by your organization" lock icon in VS Code

This is the same constraint as [Copilot OpenTelemetry settings](https://code.visualstudio.com/docs/agents/guides/monitoring-agents) — you can push it as an overridable default, but you cannot enforce it. The [Copilot OpenTelemetry via Intune](./copilot-otel-intune) guide covers the full Intune deployment pattern; the MDM scripts below follow that same approach for `git.addAICoAuthor`.

#### Deploying via MDM (Intune example)

Push `git.addAICoAuthor` as a default into each developer's VS Code `settings.json` via an MDM script.

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

> [!IMPORTANT]
> **Known gap:** Cursor and Windsurf do not add AI attribution trailers and do not expose environment signals that would allow external detection. Commits from those tools will not show up in AI leverage queries unless the developer manually adds a trailer.

---

## Measuring AI Leverage: Querying PRs on GHES

Once trailers are landing on commits, you can measure what GitHub's [Engineering System Success Playbook](https://github.com/resources/insights/engineering-system-success-playbook) (ESSP) calls **AI leverage** — the percentage of merged PRs that contain at least one AI-authored commit.

See also: [Well-Architected Framework: Engineering System Metrics](https://wellarchitected.github.com/library/productivity/recommendations/engineering-system-metrics/) for a TLDR of the ESSP

The goal: **What percentage of merged PRs in a given period contained at least one AI-authored commit?**

### Trailer Patterns to Search For

Different tools use different trailer formats. Your queries need to match all variants in use:

| Tool | Trailer format |
|---|---|
| Copilot CLI | `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` |
| VS Code (`git.addAICoAuthor`) | `Co-authored-by: Copilot <copilot@github.com>` |
| Claude Code | `Co-Authored-By: Claude <noreply@anthropic.com>` |

A broad match pattern that catches both Copilot trailer variants: `Co-authored-by:.*Copilot` — this works because "Copilot" appears as the author name in both formats, before the email address.

### Approach: Daily GHES REST API Job

Run this as a daily GitHub Actions workflow or cron job. The script iterates all repos in the org, pulls closed PRs from the last 24 hours, classifies each as merged or closed-without-merge, and checks commit messages for Copilot trailers.

This gives you two signals from the [ESSP](https://github.com/resources/insights/engineering-system-success-playbook):
- **AI leverage (throughput)** — what % of merged PRs had AI involvement?
- **AI rejection rate (quality)** — what % of AI-attributed PRs were closed without merging? A high rejection rate may indicate AI-generated code that doesn't meet quality standards.

```bash
#!/bin/bash
# ai-leverage-daily.sh
# Daily job: calculates AI leverage and AI rejection rate for an org on GHES.
# Designed for cron / GitHub Actions. Processes the previous day's closed PRs.
#
# Usage: GHES_TOKEN=xxx GHES_HOSTNAME=github.example.com ./ai-leverage-daily.sh MY_ORG
#
# Output: JSON report to stdout (pipe to file, dashboard, or artifact)

set -euo pipefail

ORG="${1:?Usage: $0 <org>}"
SINCE=$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "1 day ago" +%Y-%m-%dT%H:%M:%SZ)
API="https://${GHES_HOSTNAME}/api/v3"
AUTH="Authorization: token ${GHES_TOKEN}"
ACCEPT="Accept: application/vnd.github+json"

TOTAL_MERGED=0
TOTAL_CLOSED=0
AI_MERGED=0
AI_CLOSED=0

# Paginated GET — returns all pages concatenated as a JSON array
paginate() {
  local url="$1" page=1 sep="["
  while true; do
    local body
    body=$(curl -s -H "$AUTH" -H "$ACCEPT" "${url}&page=${page}&per_page=100")
    local count
    count=$(echo "$body" | jq 'length')
    echo "$body" | jq -c '.[]' | while read -r item; do echo "${sep}${item}"; sep=","; done
    [[ "$count" -lt 100 ]] && break
    ((page++))
    sleep 0.3
  done
  echo "]"
}

# Check if any commit in a PR has a Copilot trailer
pr_has_ai() {
  local repo="$1" pr_num="$2"
  curl -s -H "$AUTH" -H "$ACCEPT" "$API/repos/$repo/pulls/$pr_num/commits?per_page=100" | \
    jq -r '[.[].commit.message] | join("\n")' | \
    grep -qi "co-authored-by:.*copilot" && return 0 || return 1
}

# Get all repos in the org
REPOS=$(curl -s -H "$AUTH" -H "$ACCEPT" "$API/orgs/$ORG/repos?type=all&per_page=100" | \
  jq -r '.[].full_name')

for REPO in $REPOS; do
  # Fetch PRs closed/merged since yesterday
  PRS_JSON=$(curl -s -H "$AUTH" -H "$ACCEPT" \
    "$API/repos/$REPO/pulls?state=closed&sort=updated&direction=desc&per_page=100")

  # Process each PR closed within our window
  echo "$PRS_JSON" | jq -c --arg since "$SINCE" \
    '.[] | select(.closed_at >= $since)' | while read -r PR; do

    PR_NUM=$(echo "$PR" | jq -r '.number')
    MERGED_AT=$(echo "$PR" | jq -r '.merged_at')

    if [[ "$MERGED_AT" != "null" ]]; then
      ((TOTAL_MERGED++)) || true
      if pr_has_ai "$REPO" "$PR_NUM"; then
        ((AI_MERGED++)) || true
      fi
    else
      ((TOTAL_CLOSED++)) || true
      if pr_has_ai "$REPO" "$PR_NUM"; then
        ((AI_CLOSED++)) || true
      fi
    fi
    sleep 0.2
  done
done

# Output report as JSON
cat <<EOF
{
  "date": "$(date -u +%Y-%m-%d)",
  "org": "$ORG",
  "total_merged_prs": $TOTAL_MERGED,
  "ai_attributed_merged": $AI_MERGED,
  "ai_leverage_pct": $(echo "scale=1; if ($TOTAL_MERGED > 0) $AI_MERGED * 100 / $TOTAL_MERGED else 0" | bc),
  "total_closed_without_merge": $TOTAL_CLOSED,
  "ai_attributed_closed": $AI_CLOSED,
  "ai_rejection_rate_pct": $(echo "scale=1; a=$AI_MERGED+$AI_CLOSED; if (a > 0) $AI_CLOSED * 100 / a else 0" | bc)
}
EOF
```

**What this measures:**

| Metric | Formula | ESSP zone |
|---|---|---|
| AI leverage | AI-attributed merged PRs ÷ total merged PRs | Business Outcomes (Activity) |
| AI rejection rate | AI-attributed closed-without-merge ÷ all AI-attributed PRs | Quality |
| PR merge rate | Total merged PRs ÷ total developers | Velocity |

A rising rejection rate for AI-attributed PRs (compared to non-AI PRs) could indicate that AI-generated code isn't passing review — worth investigating with the team before drawing conclusions.

> [!NOTE]
> **Rate limits:** GHES has rate limits [disabled by default](https://docs.github.com/en/enterprise-server@3.21/admin/configuring-settings/configuring-rate-limits/configuring-rate-limits-for-your-instance). If your instance has them enabled, or you're adapting this for GHEC (15,000 requests/hour), a daily cadence keeps volumes manageable — a 1,000-repo org with ~50 PRs closed per day uses roughly 1,000 + 50 = ~1,050 API calls per run.

---

## Limitations & Gaps

- **IDE completions are NOT tracked** — This approach only covers agent/CLI sessions where AI makes commits. A developer using Copilot inline suggestions in the editor gets no trailer. The `"all"` value for `git.addAICoAuthor` attempts to cover completions, but detection accuracy for inline completions is lower than for agent/chat edits.
- **`git.addAICoAuthor` is not enforceable** — It's a regular VS Code setting, not an [enterprise policy](https://code.visualstudio.com/docs/enterprise/policies). Developers can override it.
- **Trailers are removable** — Developers can edit commit messages before pushing. This is an honesty system.
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
| Configuration required | VS Code setting (overridable) | None — works out of the box |
| Accuracy | Depends on trailer presence (honesty system) | Server-side tracking (100% for coding agent) |

The native Cloud/EMU metrics track at the platform level. No client configuration, no trailers to manage, no opt-out risk.

---

## Recommended Implementation Order

1. **Test locally** — set `"git.addAICoAuthor": "all"` in your own VS Code settings and verify trailers appear on commits from agent mode
2. Copilot CLI already tags by default — no action needed
3. **Deploy fleet-wide via MDM** — push the setting as a managed default through Intune (see [MDM section above](#deploying-via-mdm-intune-example))
4. **Set up the daily job** — schedule the AI leverage script as a GitHub Actions workflow or cron to start collecting data
