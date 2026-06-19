# GitHub App Setup: AI Commit Attribution

This guide walks through creating and installing a GitHub App for the `ai-leverage-daily.sh` script. The App provides 15,000 API requests/hour (vs 5,000 for a PAT) and uses short-lived tokens.

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

4. Under **Permissions → Repository permissions**:
   - **Contents**: Read-only
   - **Pull requests**: Read-only
   - **Metadata**: Read-only (auto-selected)

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

---

## Rate Limits

| Auth Method | Rate Limit | Notes |
|-------------|-----------|-------|
| Personal Access Token | 5,000/hr | Shared across all your PAT usage |
| GitHub App (installation token) | 15,000/hr | Dedicated to this App |

A full octodemo scan (~4,100 API calls) uses **27%** of the App's hourly budget vs **82%** of a PAT's.

---

## Security Notes

- The private key **never** goes into the repository
- Installation tokens expire after **1 hour**
- The App has **read-only** access — it cannot modify any code or PRs
- If the key is compromised, revoke it from the App settings page and generate a new one
