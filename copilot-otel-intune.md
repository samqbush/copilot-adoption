---
layout: default
title: Copilot OpenTelemetry via Intune
description: Centrally deploy OpenTelemetry monitoring for Copilot across Windows and macOS using Microsoft Intune
toc: true
---

# Copilot OpenTelemetry via Intune
{:.no_toc}

*Last updated: June 19, 2026*

---

## Key constraint (read first)

OTel agent monitoring is **NOT** an enforceable VS Code enterprise policy. The VS Code policy allowlist (`/docs/enterprise/policies`) does **not** include any `github.copilot.chat.otel.*` setting. So you cannot *lock* OTel on the endpoint — you can only push it as an **overridable default** via environment variables or a default `settings.json`. A determined developer can override it.

- **Fine for observability** (honest developers, fleet usage/cost dashboards) → pair with drift remediation (Part 1C).
- **Not sufficient for compliance/audit** → anchor on GitHub's server-side audit log + Copilot metrics API, gate usage with the `ChatApprovedAccountOrganizations` policy, and for hard guarantees push work into org-controlled runtimes (Codespaces/VDI). Endpoint OTel is enrichment only.

## Reference docs

- [VS Code agent OTel monitoring](https://code.visualstudio.com/docs/agents/guides/monitoring-agents)
- [VS Code enterprise policies (allowlist)](https://code.visualstudio.com/docs/enterprise/policies)
- [VS Code enterprise AI settings](https://code.visualstudio.com/docs/enterprise/ai-settings)
- [Copilot CLI command reference (OTel monitoring)](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/copilot-cli-reference/cli-command-reference#opentelemetry-monitoring)

---

## Architecture overview

- **One target endpoint:** your org's OTLP/HTTP collector, e.g. `https://otel-collector.corp.example.com:4318`.
- **Two device platforms**, each with its own Intune mechanism.
- **Two app surfaces** per device: VS Code (GUI) agent + standalone `copilot` CLI (terminal).
- **Recommended split:**
  - **Windows** → push **machine-level environment variables** (covers VS Code *and* CLI in one shot — Windows GUI apps inherit machine env vars cleanly).
  - **macOS** → push a **default `settings.json`** for the VS Code half (avoids the GUI-launchd headache) **plus** an env-var file for the CLI half.
- **Content capture stays OFF** everywhere (metadata only — no prompts/code).
- **Standardize on `otlp-http`** — the standalone CLI only supports HTTP.

### Shared OTel variables / settings

| Env var | settings.json equivalent | Value |
|---|---|---|
| `COPILOT_OTEL_ENABLED` | `github.copilot.chat.otel.enabled` | `true` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `github.copilot.chat.otel.otlpEndpoint` | collector URL |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `github.copilot.chat.otel.exporterType` (`otlp-http`) | `http/protobuf` |
| `OTEL_RESOURCE_ATTRIBUTES` | (resource attrs) | `team.id=...,department=...` |
| `COPILOT_OTEL_CAPTURE_CONTENT` | `github.copilot.chat.otel.captureContent` | `false` |

> [!IMPORTANT]
> Environment variables always take precedence over VS Code settings.

---

## Part 1 — Windows via Intune

### 1A. Machine-level env vars (Custom OMA-URI)

Windows stores machine env vars in the registry under
`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment`.

**Intune → Devices → Configuration → Create → Windows 10 and later → Templates → Custom.**
Add each as Data type **String**:

| Name | OMA-URI | Value |
|---|---|---|
| OTel Enabled | `./Device/Vendor/MSFT/Registry/HKLM/SYSTEM/CurrentControlSet/Control/Session Manager/Environment/COPILOT_OTEL_ENABLED` | `true` |
| OTel Endpoint | `./Device/Vendor/MSFT/Registry/HKLM/SYSTEM/CurrentControlSet/Control/Session Manager/Environment/OTEL_EXPORTER_OTLP_ENDPOINT` | `https://otel-collector.corp.example.com:4318` |
| OTel Protocol | `./Device/Vendor/MSFT/Registry/HKLM/SYSTEM/CurrentControlSet/Control/Session Manager/Environment/OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
| Resource Attrs | `./Device/Vendor/MSFT/Registry/HKLM/SYSTEM/CurrentControlSet/Control/Session Manager/Environment/OTEL_RESOURCE_ATTRIBUTES` | `team.id=platform,department=engineering` |

Assign to a device group. A reboot/next logon makes them live; new VS Code / `copilot` processes inherit them.

### 1B. PowerShell platform script (alternative to 1A)

**Intune → Devices → Scripts and remediations → Platform scripts → Add → Windows 10 and later.** Run in **system context**, 64-bit.

```powershell
# Set-CopilotOtelEnv.ps1
$vars = @{
  'COPILOT_OTEL_ENABLED'         = 'true'
  'OTEL_EXPORTER_OTLP_ENDPOINT'  = 'https://otel-collector.corp.example.com:4318'
  'OTEL_EXPORTER_OTLP_PROTOCOL'  = 'http/protobuf'
  'OTEL_RESOURCE_ATTRIBUTES'     = 'team.id=platform,department=engineering'
}
foreach ($k in $vars.Keys) {
  [System.Environment]::SetEnvironmentVariable($k, $vars[$k], 'Machine')
}
```

### 1C. Proactive Remediation for drift control (recommended)

**Intune → Devices → Scripts and remediations → Remediations → Create** (requires Intune Premium / qualifying license). Schedule daily.

**Detection** (exit 1 = needs fix):

```powershell
$want = 'https://otel-collector.corp.example.com:4318'
$have = [System.Environment]::GetEnvironmentVariable('OTEL_EXPORTER_OTLP_ENDPOINT','Machine')
if ($have -ne $want) { Write-Output "drift: $have"; exit 1 }
$en = [System.Environment]::GetEnvironmentVariable('COPILOT_OTEL_ENABLED','Machine')
if ($en -ne 'true') { Write-Output "disabled"; exit 1 }
exit 0
```

**Remediation** = the body of 1B.

---

## Part 2 — macOS via Intune

macOS has **no native env-var payload**, and GUI VS Code ignores shell profiles. Split the two surfaces.

### 2A. VS Code half → default `settings.json` (shell script)

**Intune → Devices → Scripts → add a shell script** (macOS). Run as **root**, e.g. daily (re-runs give drift correction).

```bash
#!/bin/bash
# deploy-vscode-otel-settings.sh
# Writes a default Copilot OTel config into each local user's VS Code settings.
# Note: this is a DEFAULT a user can still edit; that's expected.

ENDPOINT="https://otel-collector.corp.example.com:4318"

for HOME_DIR in /Users/*; do
  USER_NAME=$(basename "$HOME_DIR")
  [ "$USER_NAME" = "Shared" ] && continue
  SETTINGS_DIR="$HOME_DIR/Library/Application Support/Code/User"
  SETTINGS="$SETTINGS_DIR/settings.json"
  [ -d "$HOME_DIR/Library/Application Support/Code" ] || continue
  mkdir -p "$SETTINGS_DIR"

  if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS" ]; then
    tmp=$(mktemp)
    jq --arg ep "$ENDPOINT" '
      ."github.copilot.chat.otel.enabled" = true
      | ."github.copilot.chat.otel.exporterType" = "otlp-http"
      | ."github.copilot.chat.otel.otlpEndpoint" = $ep
      | ."github.copilot.chat.otel.captureContent" = false
    ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  else
    cat > "$SETTINGS" <<EOF
{
  "github.copilot.chat.otel.enabled": true,
  "github.copilot.chat.otel.exporterType": "otlp-http",
  "github.copilot.chat.otel.otlpEndpoint": "$ENDPOINT",
  "github.copilot.chat.otel.captureContent": false
}
EOF
  fi
  chown "$USER_NAME" "$SETTINGS"
done
```

> [!NOTE]
> The `jq` merge preserves other settings; the fallback overwrites. Deploy `jq` first if you can't guarantee it.

### 2B. CLI half → managed shell env file (shell script)

Same Intune shell-script vehicle. Writes `/etc/zshenv` (read by all zsh sessions — default shell on modern macOS):

```bash
#!/bin/bash
# deploy-cli-otel-env.sh
cat > /etc/zshenv <<'EOF'
export COPILOT_OTEL_ENABLED=true
export OTEL_EXPORTER_OTLP_ENDPOINT=https://otel-collector.corp.example.com:4318
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_RESOURCE_ATTRIBUTES=team.id=platform,department=engineering
EOF
chmod 644 /etc/zshenv
```

> [!NOTE]
> For bash users, also append the same `export` lines to `/etc/profile`. To cover GUI-launched VS Code with env vars instead of 2A's settings.json, deploy a LaunchAgent calling `launchctl setenv` — but the settings.json route in 2A is cleaner and preferred.

---

## Part 3 — Cross-platform notes

- **Protocol:** keep everything on `otlp-http` / port `4318`. The standalone CLI terminal sessions only speak HTTP; if you set gRPC for VS Code, the CLI silently falls back. Standardize on HTTP (or use a collector like Aspire that serves both on one port).
- **Service names in your backend:**
  - `copilot-chat` → VS Code foreground agent + in-editor CLI wrapper + Claude agent spans.
  - `github-copilot` → CLI SDK native spans + standalone terminal CLI sessions.
- **Content capture:** left `false` everywhere. Only enable with legal/privacy sign-off — it captures prompts, code, file contents, and tool args.
- **Auth to the collector:** if needed, add `OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <token>` the same way — but treat the token as a secret. Intune script/registry values aren't a secret store, so prefer mTLS or network-level trust over a plaintext bearer token.

---

## Part 4 — Verification

1. **Windows:** after policy sync + reboot, `cmd` → `set OTEL` lists the vars. Launch VS Code, run an agent turn → spans under `copilot-chat`. Run `copilot` in a terminal → `github-copilot` spans.
2. **macOS:** VS Code **Settings → search `copilot otel`** → values show your endpoint. Terminal: `echo $OTEL_EXPORTER_OTLP_ENDPOINT`. Generate traffic in both → both service names appear.
3. **Backend:** confirm `gen_ai.usage.input_tokens` / `output_tokens`, model names, and your `team.id` resource attribute for segmentation.
4. **Drift:** remove a var on a test box, wait for the next remediation/script cycle, confirm re-application.

---

## Before shipping

- Swap in the real collector hostname/port and your actual `team.id` / `department` tagging scheme.
- Decide the macOS VS Code path — default `settings.json` (2A) is the cleaner option; the LaunchAgent env-var alternative is the fallback.
