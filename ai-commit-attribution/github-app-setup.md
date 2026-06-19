# GitHub App Setup: AI Commit Attribution

This guide walks through creating and installing a GitHub App for the AI attribution scripts. The App provides 15,000 API requests/hour (vs 5,000 for a PAT) and uses short-lived tokens.

The permissions you grant depend on which scripts you run. `ai-leverage-daily.sh` needs repository read access. `copilot-cloud-agent-metrics.sh` additionally needs the Copilot metrics permission. Both are covered in Step 1.

---

## Prerequisites

- **Org admin access** to `octodemo` (or your target org)
- `openssl` installed locally (pre-installed on macOS)

---

## Step 1: Create the GitHub App

1. Go to: **https://github.com/organizations/octodemo/settings/apps/new**

2. Fill in the form:

   | Field | Value |
   |-------|-------|
   | **GitHub App name** | `AI Commit Attribution` |
   | **Description** | Measures AI leverage across org repos by scanning commit trailers |
   | **Homepage URL** | `https://github.com/octodemo/octocat_supply-glorious-fishstick` |

3. Under **Webhook**:
   - **Uncheck** "Active" (we don't need webhook events)

4. Under **Permissions → Repository permissions** (required for `ai-leverage-daily.sh`):
   - **Contents**: Read-only
   - **Pull requests**: Read-only
   - **Metadata**: Read-only (auto-selected)

   Under **Permissions → Organization permissions** (only if you also run `copilot-cloud-agent-metrics.sh`):
   - **Organization Copilot metrics**: Read-only

   > For enterprise-level metrics (the `--enterprise` flag), the org permission above is not enough. The App must be installed on the enterprise and granted **View Enterprise Copilot Metrics**, and the "Copilot usage metrics" policy must be enabled for the enterprise. See [Copilot usage metrics](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-usage-metrics).

5. Under **Where can this GitHub App be installed?**:
   - Select **Only on this account**

6. Click **Create GitHub App**

7. **Note the App ID** shown on the next page (you'll need this)

---

## Step 2: Generate a Private Key

1. On the App settings page, scroll to **Private keys**
2. Click **Generate a private key**
3. A `.pem` file downloads automatically
4. Move it to a secure location:

```bash
mkdir -p ~/.config/ai-attribution
mv ~/Downloads/ai-commit-attribution.*.pem ~/.config/ai-attribution/octodemo-app.pem
chmod 600 ~/.config/ai-attribution/octodemo-app.pem
```

---

## Step 3: Install the App

1. Go to: **https://github.com/organizations/octodemo/settings/apps** (or click "Install App" in the left sidebar of your App's settings)
2. Click **Install** next to your App
3. Select **All repositories**
4. Click **Install**
5. **Note the Installation ID** from the URL: `https://github.com/organizations/octodemo/settings/installations/<INSTALLATION_ID>`

---

## Step 4: Store Configuration

Create a config file for easy invocation:

```bash
cat > ~/.config/ai-attribution/config << EOF
APP_ID=<your-app-id>
INSTALLATION_ID=<your-installation-id>
PRIVATE_KEY_PATH=~/.config/ai-attribution/octodemo-app.pem
EOF
```

---

## Step 5: Run the Script

The main script handles token generation automatically — just pass the App credentials:

```bash
./scripts/ai-leverage-daily.sh octodemo \
  --app-id <APP_ID> \
  --installation-id <INSTALLATION_ID> \
  --private-key ~/.config/ai-attribution/octodemo-app.pem
```

Or, using the config file created in Step 4:

```bash
source ~/.config/ai-attribution/config
./scripts/ai-leverage-daily.sh octodemo \
  --app-id "$APP_ID" \
  --installation-id "$INSTALLATION_ID" \
  --private-key "$PRIVATE_KEY_PATH"
```

> **Note:** You do NOT need to run `generate-installation-token.sh` separately — `ai-leverage-daily.sh` calls it internally. The standalone script exists only if you need a token for other tools (e.g., `curl`, `gh` CLI):
> ```bash
> export GH_TOKEN=$(./scripts/generate-installation-token.sh \
>   --app-id <APP_ID> --installation-id <INSTALLATION_ID> \
>   --private-key ~/.config/ai-attribution/octodemo-app.pem)
> gh api /orgs/octodemo/repos --jq '.[].name' | head
> ```

### Running the metrics script

The same App credentials work for `copilot-cloud-agent-metrics.sh`, as long as you granted the **Organization Copilot metrics** permission in Step 1 and the **Copilot usage metrics** policy is enabled for the org (or enterprise):

```bash
source ~/.config/ai-attribution/config
./scripts/copilot-cloud-agent-metrics.sh octodemo \
  --app-id "$APP_ID" \
  --installation-id "$INSTALLATION_ID" \
  --private-key "$PRIVATE_KEY_PATH"
```

If the App lacks the metrics permission, the API returns `Resource not accessible by integration`. Add the permission to the App, then re-accept the updated permissions on the installation.

---

## Rate Limits

| Auth Method | Rate Limit | Notes |
|-------------|-----------|-------|
| Personal Access Token | 5,000/hr | Shared across all your PAT usage |
| GitHub App (installation token) | 15,000/hr | Dedicated to this App |

The trailer scan finds closed PRs via the Search API rather than walking every repo, so it costs about two calls per closed PR. A busy day of ~500 closed PRs is roughly 1,000 calls, well within either budget.

---

## Security Notes

- The private key **never** goes into the repository
- Installation tokens expire after **1 hour**
- The App has **read-only** access — it cannot modify any code or PRs
- If the key is compromised, revoke it from the App settings page and generate a new one
