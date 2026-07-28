---
layout: default
title: Using CLI-Backed Skills Instead of MCP Servers
description: A reference implementation for packaging a skill plus a command-line tool as a plugin, using a pre-flight install check instead of running an MCP server.
toc: true
---

# Using CLI-Backed Skills Instead of MCP Servers
{:.no_toc}

*Last updated: July 28, 2026*

---

Not every capability needs an MCP server. When a mature command-line tool already does the job, you can wrap it in a [skill](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/about-agent-skills) and ship it through your internal marketplace as a [required plugin](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/about-enterprise-plugin-standards), with no server process to host, run, or authenticate against.

The catch: the plugin delivers the skill, but it does not install the CLI the skill depends on. So the skill has to check its own dependency before it does any work. This guide walks through that pattern end to end, with two worked examples you can lift: a `gh` skill that replaces the GitHub MCP server, and a `playwright-cli` skill that replaces a browser-automation server.

> [!NOTE]
> "CLI-backed" describes the tool the skill wraps, not the client you run Copilot in. The pattern applies across Copilot CLI, VS Code, and the GitHub Copilot app, not just the terminal.

It is one worked example on one stack, not the only way. Adapt the waypoints to your own tooling.

---

## Pick the right shape {#pick-the-right-shape}

MCP is not the loser here. It solves problems a CLI cannot, and reaching for a skill when you need a server is how you end up rebuilding a protocol in Bash.

| Choose | When |
|---|---|
| **CLI-backed skill** | A mature, well-documented CLI already does the work. Output is text or JSON. The work is local and per-invocation. The tool already handles its own auth (`gh auth login`, a config file, a keychain). You want the agent to compose commands, pipe, and iterate. |
| **MCP server** | You need typed tool schemas and validated arguments. Responses are structured and the agent should not parse them. The service is remote, persistent, or stateful across calls. Auth is OAuth or token exchange that belongs behind a server. There is no CLI, or the CLI is a thin wrapper you would have to maintain. |

A couple of tiebreakers if the table does not settle it. If a human on your team already runs the tool by hand, a skill mostly captures what they know: you are writing down a runbook, not building an integration. And if the capability needs a credential your developers should never hold directly, that belongs behind a server, not in a skill that shells out on their laptop.

---

## Where this runs {#where-this-runs}

Plugins are not a Copilot CLI feature. The `enabledPlugins`, `extraKnownMarketplaces`, and `strictKnownMarketplaces` keys in `managed-settings.json` are supported in Copilot CLI, VS Code, and the GitHub Copilot app ([managed settings reference](https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/enterprise-managed-settings-reference#supported-keys)). Skills reach further still. Cloud agent, code review, and JetBrains agent mode all load them.

That reach is exactly why the pre-flight check matters. The skill goes everywhere the plugin does; the CLI does not.

| Surface | Gets plugins from | Where commands run |
|---|---|---|
| Copilot CLI | `managed-settings.json`, or `enabledPlugins` in `~/.copilot/settings.json` / `.github/copilot/settings.json` | The developer's machine |
| VS Code agent mode | `managed-settings.json` | The developer's machine |
| GitHub Copilot app | `managed-settings.json` | A local worktree or repo, or a [cloud sandbox](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/github-copilot-app/agent-sessions) (public preview) |
| Copilot cloud agent | `enabledPlugins` in `.github/copilot/settings.json` | An ephemeral Actions environment |

Copilot code review runs in an ephemeral environment too, and by default reuses the cloud agent's setup steps.

So "is the tool installed?" has a different answer in each place:

- **A developer's machine** has whatever that developer installed. Some have `gh`; the new hire on day one does not.
- **An ephemeral Actions environment** is a [GitHub-hosted runner image](https://github.com/actions/runner-images), so `gh` and Node.js are already there, but `playwright-cli` and its browser downloads are not. Add anything extra in [`copilot-setup-steps.yml`](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/customize-the-agent-environment).
- **A cloud sandbox** is isolated from the machine the app is running on, so a locally installed binary is not in scope.

A skill that assumes its CLI exists works on the author's laptop and fails everywhere else. Worse, it fails *halfway*, three commands into a workflow, with a half-finished branch and a confusing error.

---

## The pre-flight contract {#pre-flight-contract}

Every CLI-backed skill opens with the same block. It answers one question: can this skill actually run right now? And it answers it before touching anything.

Six checks, in order:

1. **On `PATH`.** The executable resolves.
2. **Version.** It meets the minimum the skill's commands assume.
3. **Auth and config.** Credentials the tool needs are present and valid.
4. **Platform.** The OS and any runtime dependency are supported.
5. **Actionable failure.** A failed check reports the exact install or login command, not "something went wrong."
6. **No partial execution.** Nothing runs until every check passes.

The last one carries the most weight. An agent that finds a missing tool at step four has already made changes. Fail at step zero instead.

Here is the shape, with `gh` as the subject:

```bash
set -u

MIN=2.60.0

command -v gh >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: gh is not installed. Install it from https://cli.github.com, then rerun."
  exit 1
}

have=$(gh --version | head -1 | awk '{print $3}')
if [ "$(printf '%s\n%s\n' "$MIN" "$have" | sort -V | head -1)" != "$MIN" ]; then
  echo "PRE-FLIGHT FAILED: gh $have is older than $MIN. Upgrade, then rerun."
  exit 1
fi

gh auth status >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: gh is not authenticated. Run: gh auth login"
  exit 1
}

echo "pre-flight OK (gh $have)"
```

`sort -V` does the version comparison, so you are not writing a semver parser in Bash. Every failure path prints the fix and exits non-zero.

### Why it checks instead of installs {#why-not-install}

The obvious next thought is to have the skill install the missing tool itself. Do not. A check that reports and stops is the safer design, for reasons that compound as the plugin spreads:

- **A required plugin would become a fleet-wide silent installer.** The premise of this guide is `enabledPlugins` pushing the skill to everyone automatically. A skill that self-installs turns that into an unattended `npm install -g` on every machine in the enterprise, with no one approving the package.
- **It burns time and tokens without finishing the job.** Give an agent sudo and an autopilot session, and a failed install becomes a long loop of retries, workarounds, and permission prompts that still ends without the task done. Failing at step zero costs one turn.
- **Installs need privileges the agent should not have.** Global installs want sudo or write access outside the workspace. That is not a capability to hand a skill so it can save a copy-paste.
- **It widens the prompt-injection blast radius.** A skill running with `allowed-tools: shell` that already contains an install command is a useful target. Injected content that reaches the skill can then influence what gets installed.
- **The auth check cannot be automated anyway.** `gh auth login` is interactive. You need the report-and-stop path regardless, so auto-install adds a second code path without removing the first.
- **It is the wrong layer.** The correct install differs by platform, by pinned version, and by internal registry. In an ephemeral environment it belongs in `copilot-setup-steps.yml`, where it runs before the agent starts and is reviewable in a pull request. On a laptop it belongs with your package manager or MDM, where it can be updated and audited.

A missing dependency is a configuration problem. Surface it, name the fix, and let the person or the platform that owns that configuration apply it.

Both examples below use `allowed-tools`, which pre-approves tools so the agent does not prompt on every command. [The docs warn](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/customize-copilot/add-skills#enabling-a-skill-to-run-a-script) that pre-approving `shell` removes a confirmation step protecting you from prompt injection, so only do it for skills you have read and trust. The `description` matters just as much: it is what the agent matches against when deciding whether to load the skill, so write it for retrieval. Name the tool, name the triggers.

---

## Example: replacing the GitHub MCP server {#example-gh}

`gh` is the easiest server to retire. It is already installed on every Actions runner, it handles its own auth, and it returns JSON on request.

Save as `skills/github-cli/SKILL.md`:

````markdown
---
name: github-cli
description: Work with GitHub issues, pull requests, and the REST/GraphQL API using the gh command-line tool. Use for reading or creating issues and PRs, checking workflow runs, reviewing PR comments, and any GitHub API call. Prefer this over MCP-based GitHub tools; gh authenticates reliably across environments, including private repositories.
license: MIT
allowed-tools: shell
---

# GitHub via the `gh` CLI

## Step 0: pre-flight (required)

Run this before anything else. If it fails, report the message to the user and stop.
Do not attempt any GitHub operation.

```bash
set -u
MIN=2.60.0

command -v gh >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: gh is not installed. See https://cli.github.com, then rerun."
  exit 1
}

have=$(gh --version | head -1 | awk '{print $3}')
if [ "$(printf '%s\n%s\n' "$MIN" "$have" | sort -V | head -1)" != "$MIN" ]; then
  echo "PRE-FLIGHT FAILED: gh $have is older than $MIN. Upgrade, then rerun."
  exit 1
fi

gh auth status >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: gh is not authenticated. Run: gh auth login"
  exit 1
}

echo "pre-flight OK (gh $have)"
```

In an ephemeral environment, `gh` is preinstalled but authenticates from `GH_TOKEN`.
If `gh auth status` fails there, the token is missing or lacks scope. Report that
rather than trying to log in interactively.

## Reading

Always request JSON and select only the fields you need. Full objects are large and
crowd out context.

```bash
gh issue list --repo OWNER/REPO --state open --limit 20 \
  --json number,title,labels,updatedAt

gh pr view 123 --repo OWNER/REPO \
  --json title,body,state,reviewDecision,files

gh run list --repo OWNER/REPO --workflow ci.yml --limit 5 \
  --json databaseId,status,conclusion,headBranch
```

Use `--jq` to filter in the same call rather than piping a large payload:

```bash
gh pr list --repo OWNER/REPO --state open \
  --json number,title,author --jq '.[] | select(.author.login == "octocat")'
```

## Anything the subcommands do not cover

`gh api` reaches the whole REST and GraphQL surface:

```bash
gh api repos/OWNER/REPO/branches/main/protection
gh api --paginate 'repos/OWNER/REPO/issues?state=all&per_page=100' --jq '.[].number'
gh api graphql -f query='
  query($owner:String!, $name:String!) {
    repository(owner:$owner, name:$name) { issues(states:OPEN) { totalCount } }
  }' -F owner=OWNER -F name=REPO
```

## Writing

Confirm the target repository with the user before any command that creates or
modifies state.

```bash
gh issue create --repo OWNER/REPO --title "TITLE" --body "BODY"
gh pr create --repo OWNER/REPO --base main --head BRANCH --title "TITLE" --body "BODY"
gh pr comment 123 --repo OWNER/REPO --body "COMMENT"
```

## Notes

- Private repositories work here as long as the authenticated account has access.
- Add `--repo OWNER/REPO` explicitly. Relying on the current directory's remote
  guesses wrong in multi-repo sessions.
- Rate limits surface as a non-zero exit and an explicit message. Report it; do not retry blindly.
````

---

## Example: replacing a browser-automation server {#example-playwright}

The same contract, applied to a CLI with a harder install story. [`playwright-cli`](https://www.npmjs.com/package/@playwright/cli) installs from npm and downloads browser binaries on first use, so its pre-flight has to check two things. It is also the case that genuinely needs a setup step in an ephemeral environment.

Save as `skills/playwright-cli/SKILL.md`:

````markdown
---
name: playwright-cli
description: Browser automation with the playwright-cli command-line tool. Use for browsing or scraping pages that plain HTTP fetch cannot handle: JavaScript-rendered content, login-protected pages, and sites that block bots. Also use as the fallback when a web fetch returns 403, 404, or 429 on a non-GitHub URL.
license: MIT
allowed-tools: shell
---

# Browser automation via `playwright-cli`

## Step 0: pre-flight (required)

Run this before anything else. If it fails, report the message and stop. Do not
open a browser or attempt a fetch.

```bash
set -u

command -v playwright-cli >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: playwright-cli is not installed."
  echo "Install with: npm install -g @playwright/cli@latest"
  exit 1
}

command -v node >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: playwright-cli needs Node.js on PATH."
  exit 1
}

playwright-cli --version >/dev/null 2>&1 || {
  echo "PRE-FLIGHT FAILED: playwright-cli is on PATH but not runnable."
  echo "Reinstall with: npm install -g @playwright/cli@latest"
  exit 1
}

echo "pre-flight OK (playwright-cli $(playwright-cli --version))"
```

Browsers download on first launch. If `open` fails with a missing-browser error,
report the install command rather than retrying. In a sandboxed or firewalled
environment the download may be blocked entirely, and that is a configuration
problem, not something to work around.

## The loop

Open, inspect, act, extract, close. Always close.

```bash
playwright-cli open https://example.com
playwright-cli snapshot                     # page structure with element refs
playwright-cli click e15                    # act on a ref from the snapshot
playwright-cli fill e5 "search query" --submit
playwright-cli eval "document.title"        # extract
playwright-cli close
```

## Extraction

`eval` is more reliable than parsing a snapshot. Pull everything you need in one
call rather than making a round trip per field:

```bash
playwright-cli eval "JSON.stringify({
  title: document.title,
  text: document.querySelector('article')?.innerText
     || document.querySelector('main')?.innerText
     || document.body.innerText?.slice(0, 15000)
})"
```

Use `--raw` when you want the value alone, with no page status attached:

```bash
playwright-cli --raw eval "document.title"
```

## Sessions

Named sessions keep state separate across concurrent tasks. `--persistent` keeps
cookies across runs, which also reduces bot detection:

```bash
playwright-cli -s=research close 2>/dev/null || true
playwright-cli -s=research open "https://example.com" --persistent
playwright-cli -s=research goto "https://example.com/page-2"
playwright-cli -s=research close
```

## Fetch fallback

When a plain fetch returns 403, 404, or 429 on a non-GitHub URL, retry through a
real browser. Wait after navigating; evaluating too early throws "Execution
context was destroyed":

```bash
playwright-cli open "https://blocked-site.example/article"
sleep 3
playwright-cli eval "document.title"
playwright-cli close
```

Do not use this fallback for GitHub URLs (use `gh` instead) or for 5xx responses.
The server is down and a browser will not help.

## When the browser is blocked too

A title containing "Just a moment", "Attention Required", or "Access Denied" means
you landed on a challenge page. Wait five seconds and retry once; most Cloudflare
challenges clear on their own. If it persists, close the session and tell the user
the content is inaccessible. Do not loop.
````

The playwright example does two things the `gh` one does not. Its pre-flight checks a runtime dependency (`node`) as well as the tool, and it separates "on `PATH`" from "actually runnable": a broken global npm install passes the first check and fails the second. The body also ends with an explicit stop condition. Skills that wrap network-facing tools need one, or the agent will retry a CAPTCHA until it runs out of turns.

---

## Package it {#package-it}

Both skills go in one plugin. The layout the CLI expects:

```text
my-tools/
├── plugin.json
└── skills/
    ├── github-cli/
    │   └── SKILL.md
    └── playwright-cli/
        └── SKILL.md
```

`plugin.json` needs only `name`; the `skills/` path is the default convention. Naming it explicitly costs nothing and documents intent:

```json
{
  "name": "my-tools",
  "description": "CLI-backed skills for GitHub and browser automation",
  "version": "1.0.0",
  "license": "MIT",
  "skills": "skills/"
}
```

Test it locally before it goes anywhere near a marketplace:

```bash
copilot plugin install ./my-tools
copilot plugin list
```

Then start a session and run `/skills list` to confirm both skills loaded. Components are cached at install, so rerun `copilot plugin install ./my-tools` to pick up edits.

Verify the failure path, not just the happy one. Rename the binary out of `PATH` and prompt the skill. You want the actionable install message, not a stack trace:

```bash
sudo mv "$(command -v gh)" /tmp/gh.bak   # restore when done
```

To distribute it, add a `marketplace.json` at `.github/plugin/marketplace.json` in the repository holding the plugins:

```json
{
  "name": "my-marketplace",
  "owner": { "name": "Your Organization" },
  "metadata": {
    "description": "Curated plugins for our team",
    "version": "1.0.0"
  },
  "plugins": [
    {
      "name": "my-tools",
      "description": "CLI-backed skills for GitHub and browser automation",
      "version": "1.0.0",
      "source": "./plugins/my-tools"
    }
  ]
}
```

Bump the version in both `plugin.json` and the matching `marketplace.json` entry on every change. They have to agree, and a stale version means clients keep serving the cached copy.

---

## Require it {#require-it}

A marketplace only *offers* a plugin. To make it standard, name it in `enabledPlugins`.

For Copilot CLI, VS Code, and the GitHub Copilot app, put this in `copilot/managed-settings.json` in your enterprise's `.github-private` repository:

```json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": {
        "source": "github",
        "repo": "your-org/copilot-plugins"
      }
    }
  },
  "enabledPlugins": {
    "my-tools@my-marketplace": true
  }
}
```

Once that merges to the default branch, enterprise users on a supported client version get the plugin installed the next time they authenticate. Full deployment options are in [Configuring enterprise-managed settings](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-managed-settings).

Cloud agent reads the same keys per repository, from `.github/copilot/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "my-marketplace": {
      "source": {
        "source": "github",
        "repo": "your-org/copilot-plugins"
      }
    }
  },
  "enabledPlugins": {
    "my-tools@my-marketplace": true
  }
}
```

If a skill in that plugin needs a tool the runner image lacks, install it in `copilot-setup-steps.yml` in the same repository:

```yaml
name: "Copilot Setup Steps"
on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Install playwright-cli
        run: |
          npm install -g @playwright/cli@latest
          playwright-cli --version
```

The job must be named `copilot-setup-steps`, and the file has to be on the default branch to take effect. `gh` needs nothing here; it ships with the runner image.

---

## Before shipping {#before-shipping}

- Every skill starts with a pre-flight block, and nothing runs before it passes.
- No skill installs its own dependency. It reports and stops.
- Every failure message names the exact install, upgrade, or login command.
- You tested the failure path by removing the tool, not just the happy path.
- The `description` names the tool and the trigger phrases, so the agent loads the skill when it should.
- `allowed-tools: shell` appears only on skills you have read and trust.
- Versions in `plugin.json` and `marketplace.json` match, and both were bumped.
- For repositories using cloud agent, any tool missing from the runner image is installed in `copilot-setup-steps.yml`.
