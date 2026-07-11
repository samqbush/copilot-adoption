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
   | **GitHub App name** | `<enterprise-slug> Copilot Metrics Collector` |
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
2. A `.pem` file downloads. Move it into the directory you'll test from and lock
   down its permissions:

```bash
mv ~/Downloads/copilot-metrics-collector.*.pem ./app.pem
chmod 600 ./app.pem
```

> This keeps everything in one working directory for the test. For the scheduled
> [GitHub Action](#part-3--wire-it-into-the-github-action-optional) you store the
> key as a repository secret instead — it never touches disk.

### Step 4: Install the App on the enterprise

1. From the App settings, click **Install App** and install it on your enterprise.
2. **Note the Installation ID** from the URL:
   `.../settings/installations/<INSTALLATION_ID>`.

### Step 5: Set the App values and test it

Export your enterprise slug and the three App values in your shell (no config
file to bury — this is just a test):

```bash
export ENTERPRISE=<your-enterprise>
export APP_ID=<your-app-id>
export INSTALLATION_ID=<your-installation-id>
export PRIVATE_KEY=./app.pem
```

Grab the usage-metrics script (it's self-contained — it mints its own App token),
then run a last-28-days pull and **save it to a file** so you can actually read
the report:

```bash
base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-usage-metrics.sh"

bash copilot-usage-metrics.sh "$ENTERPRISE" --last-28-days \
  --app-id "$APP_ID" --installation-id "$INSTALLATION_ID" --private-key "$PRIVATE_KEY" \
  > usage-last-28-days.json
```

Progress goes to stderr, so `usage-last-28-days.json` holds only the clean JSON:
request metadata plus a `report` array of the daily rows. Look at it:

```bash
jq '.report_meta' usage-last-28-days.json   # the window it covers
jq '.report' usage-last-28-days.json         # the actual metrics — this is the report
```

> Piping straight to `jq '.report_meta'` (instead of saving the file) only prints
> that little metadata block and throws the report away — handy as a quick "did
> it connect?" check, but not what you want when you're reviewing the data.

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

Test it (pulls the last 28 days so you can confirm the PAT works and eyeball the
data). Grab the billing script into your working directory and run it:

```bash
export ENTERPRISE=<your-enterprise>   # if not already exported in Part 1
export GH_BILLING_TOKEN=ghp_xxxxxxxxxxxxxxxx

base=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing/scripts
curl -fsSLO "$base/copilot-billing-export.sh"

bash copilot-billing-export.sh "$ENTERPRISE" --last-28-days --out ./billing-last-28-days.csv

head ./billing-last-28-days.csv          # header + first rows
# or open billing-last-28-days.csv in a spreadsheet for the full per-user view
```

> A `404` on the `/reports` endpoints means the token is missing
> `manage_billing:enterprise`. The other billing endpoints (`/usage/summary`,
> `/ai_credit/usage`) work with just the enterprise role, but the bulk CSV export
> needs this scope.

---

## Part 3 — Wire it into the GitHub Action (optional)

To run the collection automatically, grab the
[example workflow](https://github.com/samqbush/copilot-adoption/blob/main/copilot-metrics-billing/examples/copilot-metrics-collection.yml)
and the two collector scripts into your own repository. From the root of that
repo:

```bash
raw=https://raw.githubusercontent.com/samqbush/copilot-adoption/main/copilot-metrics-billing
mkdir -p .github/workflows scripts

# the scheduled workflow
curl -fsSL "$raw/examples/copilot-metrics-collection.yml" \
  -o .github/workflows/copilot-metrics-collection.yml

# the collector scripts — this path matches SCRIPTS_DIR in the workflow.
# The workflow runs them with `bash`, so no executable bit is needed.
curl -fsSL "$raw/scripts/copilot-usage-metrics.sh"  -o scripts/copilot-usage-metrics.sh
curl -fsSL "$raw/scripts/copilot-billing-export.sh" -o scripts/copilot-billing-export.sh
```

> The workflow defaults to `SCRIPTS_DIR: scripts`. If you put the scripts
> somewhere else, edit that value in the workflow to match.

Then add the credentials above under **Settings → Secrets and variables →
Actions**:

| Kind | Name | Maps to |
|------|------|---------|
| Variable | `ENTERPRISE` | your enterprise slug |
| Variable | `COPILOT_APP_ID` | the App ID from Part 1 |
| Variable | `COPILOT_INSTALLATION_ID` | the installation ID from Part 1 |
| Secret | `COPILOT_APP_PRIVATE_KEY` | the contents of `app.pem` from Part 1 |
| Secret | `GH_BILLING_TOKEN` | the classic PAT from Part 2 |

App ID and installation ID are identifiers, not credentials, so they go in
**variables**; the private key and PAT go in **secrets**. Because
`GH_BILLING_TOKEN` grants enterprise-wide billing access, host the workflow in a
dedicated private repo with a protected default branch and minimal write access.

### Set the variables and secrets from the CLI

Instead of clicking through the Settings UI, set all five from the terminal.
Both approaches assume the values from Parts 1–2 are still exported
(`ENTERPRISE`, `APP_ID`, `INSTALLATION_ID`, `GH_BILLING_TOKEN`) and that you're
inside the target repo, with the App private key on disk at `./app.pem`.

**With `gh` (recommended):** it encrypts the secrets for you.

```bash
gh variable set ENTERPRISE              --body "$ENTERPRISE"
gh variable set COPILOT_APP_ID          --body "$APP_ID"
gh variable set COPILOT_INSTALLATION_ID --body "$INSTALLATION_ID"
gh secret   set COPILOT_APP_PRIVATE_KEY < ./app.pem
gh secret   set GH_BILLING_TOKEN        --body "$GH_BILLING_TOKEN"
```

`gh` targets the repo in the current directory; add `--repo <owner>/<repo>` to
point somewhere else. The private-key line reads `./app.pem` straight off disk,
so point it at wherever your key actually lives.

If the key isn't saved to disk, paste it into `gh` with a quoted heredoc:

```bash
gh secret set COPILOT_APP_PRIVATE_KEY <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
...paste the full key here...
-----END RSA PRIVATE KEY-----
EOF
```

The quoted `'EOF'` stops the shell from touching the contents and preserves the
newlines. The value is encrypted locally before it leaves your machine.

**With `curl`:** variables are plain text, so they upload directly.

```bash
export GH_REPO_TOKEN=ghp_xxxx           # token with Actions write on the repo
owner_repo=<owner>/<repo>
api=https://api.github.com/repos/$owner_repo/actions/variables

for kv in "ENTERPRISE=$ENTERPRISE" \
          "COPILOT_APP_ID=$APP_ID" \
          "COPILOT_INSTALLATION_ID=$INSTALLATION_ID"; do
  curl -fsSL -X POST "$api" \
    -H "Authorization: Bearer $GH_REPO_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg n "${kv%%=*}" --arg v "${kv#*=}" '{name:$n, value:$v}')"
done
```

Secrets are the catch: GitHub requires each value be encrypted against the
repo's public key (a libsodium sealed box) before upload, which is exactly what
`gh secret set` does under the hood. Over pure `curl` you fetch the key and seal
each value yourself (needs `python3` with `pynacl`, i.e. `pip install pynacl`):

```bash
pk=$(curl -fsSL "https://api.github.com/repos/$owner_repo/actions/secrets/public-key" \
  -H "Authorization: Bearer $GH_REPO_TOKEN" -H "Accept: application/vnd.github+json")
key_id=$(jq -r .key_id <<<"$pk"); pub=$(jq -r .key <<<"$pk")

seal() {   # usage: seal <secret-name> <plaintext>
  enc=$(python3 - "$pub" "$2" <<'PY'
import base64, sys
from nacl import public, encoding
box = public.SealedBox(public.PublicKey(sys.argv[1].encode(), encoder=encoding.Base64Encoder))
print(base64.b64encode(box.encrypt(sys.argv[2].encode())).decode())
PY
)
  curl -fsSL -X PUT "https://api.github.com/repos/$owner_repo/actions/secrets/$1" \
    -H "Authorization: Bearer $GH_REPO_TOKEN" -H "Accept: application/vnd.github+json" \
    -d "$(jq -n --arg v "$enc" --arg k "$key_id" '{encrypted_value:$v, key_id:$k}')"
}

seal COPILOT_APP_PRIVATE_KEY "$(cat ./app.pem)"
seal GH_BILLING_TOKEN        "$GH_BILLING_TOKEN"
```

### Commit and push the workflow

The credentials live in repo settings, not the tree, so all you commit is the
workflow and the two scripts you pulled down above:

```bash
git add .github/workflows/copilot-metrics-collection.yml scripts/copilot-*.sh
git commit -m "Add Copilot metrics & billing collection workflow"
git push
```

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
