---
layout: default
title: Using CLI-Backed Skills Instead of MCP Servers
description: A reference implementation for packaging a skill plus a command-line tool as a required plugin, using a pre-flight install check instead of running an MCP server.
toc: true
---

# Using CLI-Backed Skills Instead of MCP Servers
{:.no_toc}

*Last updated: July 16, 2026*

---

> [!NOTE]
> **Coming soon.** This guide is being written. The outline below is what it will cover.

## What this guide will cover

Not every capability needs an MCP server. When a mature command-line tool already does the job, you can wrap it in a [skill](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating) and ship it through your internal marketplace as a [required plugin](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/about-enterprise-plugin-standards) — no server process to run, host, or authenticate against.

The catch: a required plugin delivers the skill, but it does **not** install the CLI the skill depends on. So the skill has to check its own dependency before it does any work. This guide walks through that pattern end to end:

- **When to reach for a CLI-backed skill** instead of an MCP server — and when MCP is still the right call (typed tool schemas, structured responses, persistent or remote services, MCP-native auth).
- **The pre-flight contract** every CLI-backed skill should enforce before running:
  - the executable is on `PATH`
  - it meets a minimum/supported version
  - any required authentication or configuration is present
  - the platform is supported
  - clear, actionable install instructions when a check fails
  - no partial execution before every check passes
- **Packaging and distribution** — bundling the skill in a plugin and requiring it enterprise-wide via `enabledPlugins`.

The worked example will adapt the pre-flight check pattern used by a real CLI-backed skill — one that wraps an existing command-line tool and verifies it is installed before running.
