---
layout: default
title: Deploying Copilot Settings via MDM
description: Enforce Copilot client settings with enterprise-managed settings, and push overridable defaults across VS Code and the CLI with Microsoft Intune
toc: true
redirect_from:
  - /copilot-otel-intune/
---

# Deploying Copilot Settings via MDM
{:.no_toc}

*Last updated: July 16, 2026*

---

> [!IMPORTANT]
> **Looking for "Copilot OpenTelemetry via Intune"?** You are in the right place — that guide moved here. OpenTelemetry export is now an **enterprise-managed setting**, so you no longer push it as environment variables through Intune. Configure the `telemetry` block in `managed-settings.json` instead, where a managed value wins over environment variables and user settings. See [OpenTelemetry export is now managed](#otel-managed) below for the migration.

This guide covers two jobs an admin faces when standardizing Copilot across a fleet:

1. **Enforce** a setting that Copilot supports as a managed key — the enforceable path is `managed-settings.json`.
2. **Default** a setting that has no managed key and is not on the VS Code policy allowlist — the only path is an *overridable* default pushed by MDM, shown here with Microsoft Intune.

It is one worked example on a Windows + macOS Intune stack, not the only way. Adapt the waypoints to your device-management tooling.

---

## OpenTelemetry export is now managed {#otel-managed}

As of the [July 8, 2026 changelog](https://github.blog/changelog/2026-07-08-enterprise-managed-opentelemetry-export-for-vs-code-and-cli/), OTel export is configured through the `telemetry` block in `managed-settings.json` and applies to **both** the Copilot Chat extension in VS Code and the agent host process that powers Copilot CLI. A managed value always wins, taking precedence over environment variables and user settings — so the old env-var-via-Intune approach is no longer needed for OTel.

```json
{
  "telemetry": {
    "enabled": true,
    "endpoint": "https://otel-collector.corp.example.com",
    "protocol": "http/protobuf",
    "captureContent": false,
    "lockCaptureContent": true,
    "serviceName": "copilot",
    "resourceAttributes": {
      "team.id": "platform",
      "department": "engineering"
    },
    "headers": {
      "Authorization": "Bearer REDACTED"
    }
  }
}
```

Keep `captureContent` at `false` (metadata only — no prompts, code, or tool args) unless you have legal and privacy sign-off, and set `lockCaptureContent: true` to stop a developer turning capture on locally. `protocol` accepts `http/protobuf` or `http/json`.

> [!IMPORTANT]
> Managed `headers` (such as a collector auth token) are applied only to the VS Code Chat extension's OTLP exporter. They are **never** passed to the Copilot CLI agent host or its subprocesses, so a token cannot leak into spawned tools. If your CLI sessions must authenticate to the collector, terminate that auth at a network layer (mTLS or a trusted egress proxy) rather than a header.

### Deploy it

Deliver the same JSON through whichever channel matches how you manage devices. Full deployment steps are in [Configure enterprise-managed settings](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-managed-settings); the short version:

- **Server-managed** (default for most enterprises) — commit `copilot/managed-settings.json` to your enterprise `.github-private` repository. Settings travel with the signed-in account, so they follow the developer across devices.
- **Native MDM** (Intune) — deliver the same keys through the Windows registry key `HKLM\SOFTWARE\Policies\GitHubCopilot` or the macOS `com.github.copilot` managed-preference domain.
- **File-based** — place `managed-settings.json` at the OS well-known path (`/Library/Application Support/GitHubCopilot/managed-settings.json` on macOS, `%ProgramFiles%\GitHubCopilot\managed-settings.json` on Windows, `/etc/github-copilot/managed-settings.json` on Linux).

> [!IMPORTANT]
> **Channels do not merge.** Starting in VS Code 1.128, the highest-precedence channel that supplies *any* managed setting wins outright and the others are ignored — the order is native MDM → server-managed → file-based. If your Intune payload carries one telemetry key, it suppresses every server-managed key too. Define a complete payload in the single channel you use rather than splitting keys across channels. See the [VS Code precedence explanation](https://code.visualstudio.com/docs/enterprise/ai-settings#_precedence-across-channels).

### Migrating off the old env-var approach

Environment variables still resolve for any telemetry field the managed payload does **not** set, so a half-migrated fleet ends up with a mixed configuration. After the managed payload validates, clean up the artifacts the previous approach left behind:

- Remove the machine-level `OTEL_*` and `COPILOT_OTEL_*` environment variables (Windows registry env values, macOS `/etc/zshenv` exports) that the old guide pushed.
- Remove any `github.copilot.chat.otel.*` values from default `settings.json` deployments.

### Verify

In VS Code, run **Developer: Policy Diagnostics** to see the enforced values and which channel is active. Then generate an agent turn and a `copilot` CLI turn and confirm spans land on your collector under the `serviceName` you set, tagged with your `resourceAttributes`.

---

## Can you lock it, or only default it?

Before writing any Intune script, check which bucket a setting falls into — it determines whether you can *enforce* it or merely *default* it.

| The setting is… | Enforceable? | How to deploy |
|---|---|---|
| A [managed-settings key](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/enterprise-managed-settings-reference) (`telemetry`, `permissions`, `enabledPlugins`, marketplaces) | Yes — with key-specific behavior | `managed-settings.json` (above) |
| On the [VS Code policy allowlist](https://code.visualstudio.com/docs/enterprise/policies) | Yes | ADMX / Group Policy or the Intune Settings Catalog |
| Neither — e.g. `git.addAICoAuthor` | No, default only | The MDM push below |

Managed-settings keys do not all behave the same way. `telemetry.lockCaptureContent` exists precisely because content capture has its own override behavior, and `permissions.model` sets the default model for new conversations rather than freezing a developer's per-conversation choice. Check the [reference](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/enterprise-managed-settings-reference) for each key's exact behavior before you assume "managed" means "locked."

The rest of this guide is the third row: pushing an **overridable default** for a setting that has no managed key. The worked example is `git.addAICoAuthor`, the VS Code setting behind [Measuring AI in Pull Requests](ai-commit-attribution.md#deploying-it-fleet-wide-via-mdm).

---

## Pushing an overridable default across a fleet

`git.addAICoAuthor` is a regular VS Code setting, not on the policy allowlist and not a managed key, so you cannot lock it — you can only ship it as a default a developer could later change. Most never bother, which is fine for an adoption-measurement use case.

Push it as a value in each user's `settings.json`. Run the script on a schedule so re-runs correct drift.

### macOS — Intune shell script (run as root)

```bash
#!/bin/bash
# deploy-vscode-ai-coauthor.sh
# Merges git.addAICoAuthor into each user's VS Code settings as a DEFAULT.

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

> [!WARNING]
> The `jq` branch merges the key and preserves everything else, but the fallback **overwrites** the whole file. Deploy `jq` first so the merge path always runs. `jq` also does not parse comments or trailing commas (JSONC), so a user who hand-edited their `settings.json` with comments will fall through to the destructive branch — another reason to guarantee `jq` and a valid file.

### Windows — Intune platform script (run in user context)

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
> `ConvertFrom-Json` rejects JSONC comments too. If your fleet's settings files may contain comments, gate the script on a clean parse and skip (rather than overwrite) files that fail.

### Environment variables, for CLI-read or cross-agent settings

`git.addAICoAuthor` lives only in VS Code's `settings.json`. When you instead need to push a setting the standalone `copilot` CLI reads, or one value that must reach both surfaces at once, use environment variables — the CLI does not read VS Code's `settings.json`.

- **Windows** — set machine-level variables under `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment` (Intune Custom OMA-URI, or a PowerShell platform script calling `[System.Environment]::SetEnvironmentVariable($k, $v, 'Machine')`). Windows GUI apps and terminals both inherit them, covering VS Code and the CLI in one shot.
- **macOS** — GUI VS Code ignores shell profiles, so write CLI variables to `/etc/zshenv` (read by every zsh session):

```bash
#!/bin/bash
# deploy-cli-env.sh — writes managed exports for the CLI.
cat > /etc/zshenv <<'EOF'
export EXAMPLE_SETTING=value
EOF
chmod 644 /etc/zshenv
```

> [!WARNING]
> This overwrites `/etc/zshenv`. If your image already uses it, append a marked block instead of replacing the file. For bash users, mirror the exports into `/etc/profile`.

> [!IMPORTANT]
> Environment variables are the weakest source. If the same setting is also delivered through `managed-settings.json`, the managed value wins and your env-var default is silently ignored. Use env vars only for settings that have no managed key.

### Control drift (recommended)

For settings you care about staying put, add an **Intune → Devices → Scripts and remediations → Remediations** pair (requires a qualifying license), scheduled daily. Detection returns non-zero when the value is missing or wrong; remediation re-applies the push script above.

```powershell
# Detection.ps1 — exit 1 means "needs remediation"
$settingsPath = "$env:APPDATA\Code\User\settings.json"
if (!(Test-Path $settingsPath)) { Write-Output "missing"; exit 1 }
$json = Get-Content $settingsPath -Raw | ConvertFrom-Json
if ($json.'git.addAICoAuthor' -ne 'all') { Write-Output "drift"; exit 1 }
exit 0
```

### Verify

On a test device, after the policy syncs: open VS Code **Settings**, search `addAICoAuthor`, and confirm the value shows `all`. Make a Copilot-assisted commit through the Source Control panel and check for the `Co-authored-by` trailer. Then delete the value, wait for the next remediation cycle, and confirm it re-applies.

---

## Before shipping

- Swap in your real collector endpoint, `serviceName`, and resource-attribute scheme for the telemetry block.
- Decide the single managed-settings channel you will use, and keep the whole payload in it.
- Guarantee `jq` (macOS) and a clean JSON parse (Windows) before the default-push scripts run, so they never hit the destructive fallback.
- Pilot on a small device group before fleet-wide rollout.
