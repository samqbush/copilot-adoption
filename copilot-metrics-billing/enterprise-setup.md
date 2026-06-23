# Setup: Copilot Metrics & Billing Collection

Two one-time setups, because the two data domains use two different tokens:

1. **Enterprise GitHub App** — for **usage metrics** (engagement data). Higher
   rate limit (15,000 req/hr) and short-lived tokens.
2. **Billing-manager classic PAT** — for **billing metrics** (cost data). GitHub
   Apps and fine-grained PATs cannot access billing endpoints.

---

## Prerequisites

- **Enterprise owner** access (to create the App and the billing PAT, and to
  enable the usage-metrics policy).
- `openssl`, `curl`, and `jq` installed locally (all pre-installed or easily
  available on macOS/Linux).

---

## Part 1 — Enterprise GitHub App (usage metrics)

### Step 1: Enable the usage-metrics policy

The metrics endpoints return data only when the **Copilot usage metrics** policy
is set to **Enabled everywhere** for the enterprise.

1. Go to your enterprise: **Settings → Policies → Copilot**.
2. Set **Copilot usage metrics** to **Enabled everywhere**.

See [Manage enterprise policies for Copilot](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-enterprise-policies).

### Step 2: Create the GitHub App

1. Go to: **`https://github.com/enterprises/<your-enterprise>/settings/apps/new`**
2. Fill in the form:

   | Field | Value |
   |-------|-------|
   | **GitHub App name** | `Copilot Metrics Collector` |
   | **Homepage URL** | any URL you control |

3. Under **Webhook**: **uncheck** "Active" (no webhook events needed).

4. Under **Permissions → Enterprise permissions**:
   - **View Enterprise Copilot Metrics**: Read-only

   > If you also want **org-level** reports (the `--org` flag), add
   > **Organization permissions → Organization Copilot metrics: Read-only** as well.

5. Under **Where can this GitHub App be installed?**: **Only on this account**.

6. Click **Create GitHub App**, then **note the App ID** on the next page.

### Step 3: Generate a private key

1. On the App settings page, scroll to **Private keys → Generate a private key**.
2. A `.pem` file downloads. Move it somewhere safe:

```bash
mkdir -p ~/.config/copilot-metrics
mv ~/Downloads/copilot-metrics-collector.*.pem ~/.config/copilot-metrics/app.pem
chmod 600 ~/.config/copilot-metrics/app.pem
```

### Step 4: Install the App on the enterprise

1. From the App settings, click **Install App** and install it on your enterprise.
2. **Note the Installation ID** from the URL:
   `.../settings/installations/<INSTALLATION_ID>`.

### Step 5: Store the App config

```bash
cat > ~/.config/copilot-metrics/config << 'EOF'
APP_ID=<your-app-id>
INSTALLATION_ID=<your-installation-id>
PRIVATE_KEY=~/.config/copilot-metrics/app.pem
EOF
```

Test it:

```bash
source ~/.config/copilot-metrics/config
./scripts/copilot-usage-metrics.sh <your-enterprise> \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY" \
  | jq '.report_meta'
```

> If you get `Resource not accessible by integration`, the App is missing the
> **View Enterprise Copilot Metrics** permission, or the usage-metrics policy
> isn't enabled yet. Fix it, then re-accept the updated permissions on the
> installation.

---

## Part 2 — Billing-manager PAT (billing metrics)

Billing endpoints require a **classic** personal access token with the
`manage_billing:enterprise` scope, owned by an **enterprise owner or billing
manager**. There is no GitHub App or fine-grained PAT equivalent today.

1. Go to: **`https://github.com/settings/tokens`** → **Generate new token
   (classic)**.
2. Select the **`manage_billing:enterprise`** scope.
3. Generate the token and store it as an environment variable (kept separate from
   the App token):

```bash
export GH_BILLING_TOKEN=ghp_xxxxxxxxxxxxxxxx
```

Test it:

```bash
./scripts/copilot-billing-export.sh <your-enterprise> --out /tmp/billing.csv
head -1 /tmp/billing.csv
```

> A `404` on the `/reports` endpoints means the token is missing
> `manage_billing:enterprise`. The other billing endpoints (`/usage/summary`,
> `/ai_credit/usage`) work with just the enterprise role, but the bulk CSV export
> needs this scope.

---

## Rate limits

| Auth method | Rate limit |
|-------------|-----------|
| Classic PAT | 5,000 req/hr |
| GitHub App (installation token) | 15,000 req/hr |

A full daily collection is under ten API calls, so either budget is plenty — but
the App is the better choice for usage metrics because of the short-lived tokens.

---

## Security notes

- The App private key and the billing PAT **never** go into the repository.
- Installation tokens expire after **1 hour**; billing download URLs expire in
  **~1 hour**.
- Both tokens are **read-only** with respect to your code — they cannot modify
  repositories or PRs.
- If a credential is compromised, revoke it (App settings for the key, token
  settings for the PAT) and reissue.
