---
layout: default
title: Managing Copilot usage-based billing
description: AI Credits, budget controls, and strategies for predictable spending under GitHub's Usage-Based Billing model
toc: true
---

# Managing Copilot usage-based billing
{:.no_toc}

*Last updated: July 1, 2026*

## Key resources

- **Governance framework** — layered budget design, cost center configuration, operating model, and API automation: [Managing AI credits and operating model](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) (GitHub Well-Architected Framework)
- **Billing mechanics** — how credits, metering, and charges work: [Usage-based billing for organizations and enterprises](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises)
- **Budget definitions** — how the four budget controls interact, how billing flows through them, and when usage is blocked: [Budgets for usage-based billing](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/budgets-for-usage-based-billing)
- **Budget setup** — recommended step-by-step setup for your enterprise: [Getting started with budget controls](https://docs.github.com/en/enterprise-cloud@latest/copilot/tutorials/budgets/getting-started-with-budget-controls)
- **Cost center spend controls** — scale budgets to your team structure with enterprise team attribution, cost center user-level budgets, and AI credit pool caps. Changelogs: [Assign enterprise teams to cost centers](https://github.blog/changelog/2026-06-25-assign-enterprise-teams-to-cost-centers), [Per-user AI credit budgets for cost centers](https://github.blog/changelog/2026-06-30-per-user-ai-credit-budgets-available-for-cost-centers)<!-- TODO: add AI credit pool caps changelog link when it posts (issue github/billing-product#922) -->. Setup and concept docs publish from [Control costs at scale](https://docs.github.com/en/enterprise-cloud@latest/billing/tutorials/control-costs-at-scale) as each feature reaches GA.
- **Hands-on training** — end-to-end fundamentals course: [GitHub Usage-Based Billing](https://learn.github.com/courses/gitHubusagebasedbillingmodule) (GitHub Learn)
- **Budget planning tool** — visualize the budget hierarchy, model scenarios, and push changes via the API from a single browser tab: [Copilot Budget Command Calculator](https://github.com/xrvk/copilot-budget-command-calculator) (community tool — built by a GitHub Solutions Engineer, not an official GitHub product)

This page covers budget sizing guidance and operational tips, plus a troubleshooting checklist for when developers get blocked. It complements the official documentation linked above.


> [!IMPORTANT]
> The controls act at different layers: **user-level budgets** cap each person's draw from the pool, **AI credit pool caps** bound a cost center's share of the included pool, and the **enterprise budget** caps total metered overage. This page is about how to combine them well — for exactly what each one does and how the system evaluates them, see [Budgets for usage-based billing](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/budgets-for-usage-based-billing).

---

## Promotional period (June 1 – August 31, 2026)

For the first three months of usage-based billing, existing customers get more included credits:

| Plan | Standard | Promotional |
|------|----------|-------------|
| Copilot Business | 1,900 AICs/user/month | 3,000 AICs/user/month |
| Copilot Enterprise | 3,900 AICs/user/month | 7,000 AICs/user/month |

### Why this matters for Enterprise seats

During the promo, Enterprise seats include 7,000 AICs vs. 3,000 for Business, a 2.3× difference. If you have developers who will burn through 3,000 credits/month, putting them on Enterprise seats during this window gets you more pooled credits at no extra per-credit cost.

#### Promo upgrade math (100 Business developers)

| | Business | Enterprise | Difference |
|--|----------|------------|------------|
| Pool value (100 users) | $3,000 | $7,000 | +$4,000 in credits |
| Upgrade cost (100 × $19.99) | — | $2,000 | −$2,000 |
| **Net monthly savings** | | | **$2,000** |

Over the 3-month promotional window that's **$6,000** in credits you'd otherwise pay for as metered overage. This only matters if your developers are actually consuming past the Business pool — if the pool isn't depleting, there's nothing to save.

> [!NOTE]
> Copilot Enterprise requires a GitHub Enterprise Cloud (GHEC) seat. This only works for users who already have GHEC. If they don't, you'd also need to purchase a GHEC seat, so factor that cost in before upgrading.

After August 2026 the credit-arbitrage advantage disappears. Both tiers include credits proportional to their license cost ($0.01/AIC), so upgrading from Business to Enterprise adds $20/month in cost alongside $20 in credit value. From a credit-pool perspective, there is no net gain. At that point, raising Individual User Budgets is cheaper than upgrading tiers (see [Tip #4](#4-raise-individual-user-budgets-before-upgrading-tiers-post-promotional-period)).

> [!NOTE]
> All dollar examples in the below strategies use promotional-period credit values ($30/user for Business, $70/user for Enterprise). After August, this page will be updated with new guidance based on token usage patterns observed in June/July.


---

## Budget strategies

**Acronyms used on this page** (full definitions in [Budgets for usage-based billing](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/budgets-for-usage-based-billing)):

- **UULB** — Universal User-Level Budget (default per-user cap for all users)
- **CCULB** — Cost Center User-Level Budget (per-user cap for one cost center's members)
- **IUB** — Individual User Budget (per-user override for a specific person)
- **AI credit pool cap** — bounds a cost center's draw on the shared included pool
- **Enterprise team attribution** — assigning an enterprise team to a cost center so membership follows the team
- **Enterprise Budget** — enterprise-wide cap on total metered overage

One interaction matters most for the strategies below: user-level budgets (UULB, CCULB, IUB) stay active in **both** phases — they cap each person's draw from the pool *and* authorize metered overage afterward — while the AI credit pool cap and enterprise budget only bite once included credits run low. That's why the sum of your user-level budgets is an implicit overage ceiling.

---

### The recommended setup: enterprise teams + cost centers

Set spend controls against the team structure you already manage instead of against thousands of individual users. Three controls work together:

1. **Attribute enterprise teams to cost centers.** Add an enterprise team as a resource on a cost center and every member's usage is attributed there automatically. As people join or leave the team — manually or through IdP/SCIM sync — membership updates on its own, with no per-user reassignment. When a user is attributed to more than one cost center, GitHub resolves it deterministically; see [Cost center allocation](https://docs.github.com/en/enterprise-cloud@latest/billing/reference/cost-center-allocation) for the precedence rules. *How:* in your enterprise's **Billing and licensing → Cost centers** settings, create or edit a cost center and add the enterprise team under **Resources** ([Control costs at scale](https://docs.github.com/en/enterprise-cloud@latest/billing/tutorials/control-costs-at-scale)).

2. **Set a cost center user-level budget.** One per-user cap applies to every member of the cost center — directly assigned or team-based — and follows membership as it changes. This is the control that replaces managing budgets one user at a time. It overrides the universal budget for those members, and you can still grant an individual override to a specific person who needs more. *How:* this is API-only right now — call the [Create a budget](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/budgets?apiVersion=2026-03-10#create-a-budget) endpoint with `budget_scope: multi_user_cost_center` and the cost center's name in `budget_entity_name` (see the note below for the UI timeline).

3. **Enable the cost center AI credit pool cap.** This holds a cost center to the included credits its own licenses fund, so one team can't drain the shared pool that another team's licenses paid for. The cap is calculated automatically from the licenses attributed to the cost center — there's no number to set. When a capped cost center reaches its limit, you choose: block further included usage, or let members continue as paid overage (if enterprise overages are enabled). *How:* enable it per cost center in the same **Cost centers** settings ([Control costs at scale](https://docs.github.com/en/enterprise-cloud@latest/billing/tutorials/control-costs-at-scale)).

**Which controls the most restrictive user-level budget?** When several apply to one person — individual, cost center, and universal — the most specific one wins ([precedence rules](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/budgets-for-usage-based-billing)). In practice that means a CCULB tightens the universal floor for a team, and an individual override loosens or tightens it for one person. A user can be stopped by any scope that applies to them, even when a lower-priority budget still has room. AI credit pool caps only fully contain spend when *every* licensed user sits in a cost center that has them enabled — anyone left out can still draw from the shared enterprise pool.

This setup still needs an [enterprise budget backstop](#enterprise-budget-backstop) behind it.

> [!NOTE]
> Availability as of June 30, 2026: step 1 (enterprise team attribution) and step 3 (pool caps) are in the billing UI today. Step 2 (the cost center user-level budget) is **REST API only** — UI support is coming. The [`gh-ulb`](https://github.com/colinbeales/gh-ulb) CLI extension wraps the budgets API if you'd rather not script the call yourself. Official setup docs are linked in [Key resources](#key-resources) as each feature reaches GA.


### Migrating from individual user budgets

Earlier versions of this guide set spend controls one user at a time through two paths:

- **Path A — high Universal User Budget with reactive overrides:** set a high universal cap, then grant an individual override only to the rare user who hit it.
- **Path B — low Universal User Budget with proactive overrides:** set a tight universal cap, then hand out individual overrides to power users as they surfaced.

Both worked, but neither scaled — adding and maintaining individual budgets for thousands of users is exactly the problem cost center user-level budgets now solve. If you already run Path A or Path B, you don't have to undo anything:

| If you set up… | Move to… |
|----------------|----------|
| A high universal budget (Path A) | Keep the universal budget as your floor. Group teams into cost centers and set a cost center user-level budget where a tighter, team-specific cap makes sense — steps 1–2 above show where to do each. |
| A tight universal budget plus many individual overrides (Path B) | Replace the per-user overrides with a cost center user-level budget on the team that shared that cap (steps 1–2 above). Keep individual overrides only for genuine outliers. |

Your existing individual user budgets keep working. They sit at the top of the precedence order, so they still override the cost center budget for the specific people you set them on. The goal isn't to delete them — it's to stop needing a new one every time a team's needs change.

> [!WARNING]
> User-level budgets keep working after the pool is exhausted, authorizing metered overages up to the same per-user limit. The sum of every user, cost center, and individual budget is an implicit overage ceiling that can run well past your intended spend. Always pair them with an enterprise budget backstop.


### Enterprise budget backstop

The cost center controls still need an enterprise-level budget behind them.

User-level budgets — universal, cost center, and individual — control how much each person can draw from the pool, but they also authorize metered overages after the pool is exhausted. The sum of all of them creates an implicit aggregate ceiling that may be far higher than your intended spend. An enterprise budget makes that ceiling explicit.

**How to size it:**

1. **Start with your actual usage data.** Download your [usage report](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/manage-and-track-spending/prepare-for-usage-based-billing) or upload it to the [billing preview tool](https://copilot-billing-preview.github.com/) to see your projected monthly spend. Your backstop should be based on real consumption patterns, not theoretical maximums.
2. **Set the enterprise budget above your projected spend** with "Stop usage" enabled — give yourself enough headroom for growth (e.g., 1.5–2× your highest projected month) so the backstop only fires in a truly abnormal month.
3. **Set threshold alerts at 75% and 90%** so you have time to react before the backstop fires.

| Example (100 Copilot Business users, promotional period) | Value |
|----------------------------------------------------------------------|-------|
| UULB | $1,000 |
| Developers | 100 |
| Total authorized spend (100 × $1,000) | $100,000 |
| Pool value (100 × $30 promo credits) | $3,000 |
| Theoretical max overage ($100K − $3K) | $97,000 |
| Enterprise backstop | $10,000 (what you'll actually pay) |

The backstop can be $0 if you want zero overage — users draw from the pool and stop when it's gone.

> [!WARNING]
> Without an enterprise backstop, the UULB × user count is your implicit spending ceiling. Make it explicit. Even if you trust your developers, set a backstop.

> [!TIP]
> Start the backstop low and raise it monthly as you see real overage patterns. It's easier to loosen a tight backstop than to explain an unexpected bill.

> [!IMPORTANT]
> The enterprise backstop is a safety net, not a routine cap. Set it high enough that it only fires in a truly runaway month. If it triggers regularly, your user-level budgets are too generous or your pool is undersized — fix those first.

> [!TIP]
> To size the backstop precisely, GitHub's [Optimizing your budget configuration](https://docs.github.com/en/enterprise-cloud@latest/copilot/tutorials/budgets/optimizing-your-budget-configuration#sizing-your-budgets) tutorial walks through the formula: multiply your users by their user-level budgets, subtract your pool value (the sum of your Copilot seat license costs — each seat's per-seat price × number of seats), and the difference is the maximum metered spend your enterprise budget needs to cover. It also includes common configurations by org structure.


### Build your champions program

The developers who consistently hit their budgets are your power users — whether you knew them upfront or discovered them through notifications. They're also the foundation of a good AI adoption story:

- Identify them through budget notifications and usage data
- Collect their stories: what they're shipping faster, what problems Copilot is solving for them
- Use those stories to demonstrate business value and justify continued investment

> [!NOTE]
> This turns cost management into a discovery exercise. Budget notifications become a signal for where AI is delivering real returns, not just a spending alert.

---

## Configuration tips

### 1. Always set a Universal User Budget

Here's how to set it in the enterprise billing settings:

![Setting the Universal User Budget in GitHub enterprise billing]({{ site.baseurl }}/universal-user-budget.gif)

### 2. Enable "Stop usage" on User-Level Budgets

Enable "Stop usage" on Universal, cost center, and Individual User Budgets — this is your hard cap per user. At the enterprise level, "Stop usage" should be a high backstop set well above expected spend (see [Enterprise budget backstop](#enterprise-budget-backstop)). It catches runaway months without blocking developers during normal operations. Use threshold alerts (75%, 90%, 100%) at the enterprise and cost center levels for day-to-day monitoring. The [WAF recommends](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) focusing enforcement at the user level and alerts at the enterprise level.

### 3. Budgets only track from their creation date

When you first create a budget, it applies only to metered usage from that date forward. Prior consumption isn't counted. This means you can exceed your budget in the first cycle even with "Stop usage" enabled. Create or adjust budgets at the start of a billing cycle whenever possible. If creating mid-cycle, set the limit conservatively. See [Budgets and alerts](https://docs.github.com/en/enterprise-cloud@latest/billing/concepts/budgets-and-alerts#your-first-billing-cycle-after-creating-a-budget) for details.

### 4. Raise Individual User Budgets before upgrading tiers *(post-promotional period)*

After August 2026, raising a user-level budget on a Business license lets a user borrow more from the pool at no extra cost. Upgrading from Business to Enterprise adds $20/month in licensing alongside $20 in credit value. From a credit-pool perspective, there is no net gain. If someone needs more capacity post-promo, raise their cost center or individual user budget first.

> [!NOTE]
> During the promotional period (June 1 – August 31, 2026), Enterprise seats include disproportionately more AICs (7,000 vs. 3,000), so the upgrade is worthwhile for power users who already have a GHEC seat. See the [Promotional period](#promotional-period-june-1--august-31-2026) section.

### 5. Gate budget increases on prior-month usage data

Raising a user-level budget doesn't expand the pool. It raises the per-user ceiling, which accelerates depletion for everyone. Require usage data before granting increases: if someone didn't hit their limit last month, they don't need a higher one.

### 6. Share pool depletion metrics monthly

Publish a simple end-of-month summary ("Pool was 74% consumed, no one was blocked"). When people can see the pool is healthy, they're less likely to inflate usage defensively or rush to consume credits early in the cycle.

---

## Reducing token consumption at the source

Budgets control how much each user *can* spend — but the most effective cost lever is making every credit count. Well-scoped agent sessions, deliberate model selection, and deterministic guardrails (tests, linters, security scans) all reduce retries and wasted tokens, which directly lowers credit consumption without limiting developer productivity.

Key resources for developers:
**GitHub Docs**
- **Optimize AI usage** — GitHub's official five strategies for higher-quality agents that complete tasks in fewer attempts: model selection, prompt guidance, the research-plan-implement workflow, deterministic guardrails, and concise `copilot-instructions.md` files: [Optimize AI usage](https://docs.github.com/en/enterprise-cloud@latest/copilot/tutorials/optimize-ai-usage)
**Field Maintained Information**
- **Interactive token optimization guide** — Scenarios, a cost calculator, a model-selection playbook, and copy-paste templates: [GitHub Copilot Token Optimizer](https://ashy-dune-0b4215a0f.7.azurestaticapps.net/index.html)

> [!TIP]
> Teams that invest in agent quality guardrails often see **fewer retries and lower total token spend** — even when individual steps use slightly more tokens upfront. Pair this with the budget strategy above: when power users hit their limits less often, you spend less time adjusting budgets and more time shipping. For developers who want hands-on practice, share the [Context Engineering Lab](https://copilot-academy.github.io/labs/context-engineering-lab) — a 2-hour workshop on measuring and reducing token consumption.

---


## When developers are blocked

When someone reports being blocked, work through these checks in order:

1. **Did they hit a user-level budget?**
   Check every scope that applies — their Individual override, their cost center user-level budget, and the Universal User Budget. The most restrictive one wins, so a user can be stopped by their cost center budget even when their personal headroom or the shared pool still has room. This is the cause nine times out of ten.
   - Yes: raise the budget at the scope that's binding, or grant an individual override.
   - No: keep checking.

2. **Has the cost center hit its AI credit pool cap?**
   If the cost center's included-usage cap is reached and overages aren't allowed, its members stop until the next cycle.
   - Yes: allow overage for that cost center, or raise or remove the cap.
   - No: keep checking.

3. **Is the shared pool depleted and the Enterprise Budget reached?**
   If pooled credits are gone and the Enterprise Budget has "Stop usage" enabled at its limit, it's capping total metered overage.
   - Yes: raise the Enterprise Budget.
   - No: check whether their license or feature access was removed.

> [!TIP]
> **Start with one question: does the shared pool still have credits?** It splits the diagnosis in two.
> - **Pool still has credits.** The block is almost always a user-level budget. Check the scopes most-restrictive-first — Individual (IUB), then cost center (CCULB), then Universal (UULB) — and raise the one that's binding. If none are, check whether that user's cost center hit its own [AI credit pool cap](#the-recommended-setup-enterprise-teams--cost-centers): a cost center can exhaust its included share while the enterprise pool still has room.
> - **Pool depleted.** User-level budgets still bind in the metered phase, so check them in the same order first. Past them, the [Enterprise Budget backstop](#enterprise-budget-backstop) is what caps total overage — raise it if it's the limit that fired.

