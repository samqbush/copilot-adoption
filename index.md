---
layout: default
title: "Copilot: The Ready Room"
description: "Opinionated, runnable guides for rolling out GitHub Copilot at scale, with real config and worked examples."
---

These pages are maintained as opinionated implementation guides — worked examples you can copy and adapt, not documentation. Think of it in three tiers:

- **The aircraft manual** — [GitHub Docs](https://docs.github.com/en/enterprise-cloud@latest/): what every switch does.
- **Flight doctrine** — the [Well-Architected Framework](https://wellarchitected.github.com/): the design principles behind a good rollout — *what* to consider and *why* — but it stops short of naming specific tools.
- **A proven flight plan** — these guides: one concrete, runnable way to actually do it on a real stack.

Each guide is a working flight plan for the *how*: specific tooling, real config, and the trade-offs behind each choice. Treat it as one reference implementation. Take what works for your environment and adapt the rest.

## Copilot Adoption Official Resources

- [Rolling Out GitHub Copilot at Scale](https://docs.github.com/en/copilot/rolling-out-github-copilot-at-scale) — GitHub's official rollout guide
- [Well-Architected: Adopting Copilot at Scale](https://wellarchitected.github.com/library/productivity/recommendations/adopting-copilot-at-scale/) — GitHub's Well-Architected Framework guidance
- [Copilot Feature Matrix](https://docs.github.com/en/copilot/reference/copilot-feature-matrix) — Official feature comparison across plans and IDEs

## Top 3 Recommendations for Skilling Up Developers at Scale

The highest-impact adoption strategies focus on raising the floor across your organization — ensuring every developer has the tools and support to be productive with Copilot, not just the early adopters and power users.

1. **Implement a Champion Program** — Identify and empower internal advocates who can mentor peers and drive adoption organically. See the [Well-Architected Champion Program guide](https://wellarchitected.github.com/library/collaboration/recommendations/champion-program/).

2. **Get Users on the Copilot CLI** — The CLI shifts developers from single-agent pair programming to orchestrating multiple agents in parallel. Instead of watching code change line by line, developers can multitask between terminals — delegating work across agents while staying focused on architecture and decisions. Training: [Copilot CLI Zero to Hero](https://copilot-academy.github.io/labs/copilot-cli-zero-to-hero).

3. **Create an Internal Plugin Marketplace — and make your plugins required** — Curate and share custom plugins/skills so teams can leverage each other's work. See the [Copilot Plugins Marketplace docs](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/customize-copilot/plugins-marketplace) and the open-source [awesome-copilot](https://github.com/github/awesome-copilot) collection for inspiration. A marketplace only *offers* plugins, so pair it with [enterprise managed settings](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/administer-copilot/manage-for-enterprise/manage-agents/configure-enterprise-managed-settings) ([GA July 2026](https://github.blog/changelog/2026-07-01-enterprise-managed-settings-json-is-generally-available/)) to make your standards the default. Its `enabledPlugins` key — part of [enterprise-managed plugin standards](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/agents/about-enterprise-plugin-standards) (public preview) — auto-installs your required plugins for every enterprise user at sign-in. That is how you distribute the [skills, agents, and hooks](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating) that carry your standards, rather than relying on developers to install them.

## The Guides

Each of these is a proven flight plan — one concrete, runnable implementation on a real stack, not the only way to do it. Lift the flight plan and adapt the waypoints to your own tooling.

- [Managing Copilot Usage-Based Billing](cost-management.md) — budget sizing math, promo-window credit arbitrage, and a troubleshooting checklist for when developers get blocked.
- [Pulling Copilot Metrics & Billing Into Your Data Lake](copilot-metrics-billing.md) — the credentials, endpoints, and daily pull to keep your own history before GitHub's 28-day window rolls off.
- [Measuring AI in Pull Requests](ai-commit-attribution.md) — measure AI leverage across merged PRs with trailer scanning and the Copilot usage metrics API.
- [Copilot OpenTelemetry via Intune](copilot-otel-intune.md) — centrally deploy OTel monitoring across Windows and macOS with Microsoft Intune.
- [Using CLI-Backed Skills Instead of MCP Servers](cli-skills-over-mcp.md) *(coming soon)* — package a skill plus a CLI as a required plugin, with a pre-flight install check instead of running an MCP server.

