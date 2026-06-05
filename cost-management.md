---
layout: default
title: Managing Copilot usage-based billing
---

# Managing Copilot usage-based billing

*Last updated: June 5, 2026*

GitHub Copilot usage-based billing (UBB) uses a shared pool of AI Credits (AICs) where all licensed users draw from a central enterprise pool. When the pool runs out, metered billing kicks in, and layered budgets control what happens next.

Key resources:

- **Governance framework** — layered budget design, cost center configuration, operating model, and API automation: [Managing AI credits and operating model](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) (GitHub Well-Architected Framework)
- **Billing mechanics** — how credits, metering, and charges work: [Usage-based billing for organizations and enterprises](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises)
- **Budget definitions** — how the four budget controls interact, how billing flows through them, and when usage is blocked: [Budgets for usage-based billing](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/budgets-for-usage-based-billing)
- **Budget setup** — recommended step-by-step setup for your enterprise: [Getting started with budget controls](https://docs.github.com/en/enterprise-cloud@latest/copilot/tutorials/budgets/getting-started-with-budget-controls)
- **Hands-on training** — end-to-end fundamentals course: [GitHub Usage-Based Billing](https://learn.github.com/courses/gitHubusagebasedbillingmodule) (GitHub Learn)

This page covers budget sizing guidance and operational tips, plus a troubleshooting checklist for when developers get blocked. It complements the official documentation linked above.


> [!IMPORTANT]
> Enterprise and Cost Center budgets only cap spending *after* included credits run out. Universal and Individual User Budgets are always active and limit how much of the pool each person can draw, even while the pool still has capacity.

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

After August 2026 the credit-arbitrage advantage disappears. Both tiers include credits proportional to their license cost ($0.01/AIC), so upgrading from Business to Enterprise adds $20/month in cost alongside $20 in credit value. From a credit-pool perspective, there is no net gain. At that point, raising Individual User Budgets is cheaper than upgrading tiers (see Tip #4).

> [!NOTE]
> All dollar examples in the below strategies use promotional-period credit values ($30/user for Business, $70/user for Enterprise). After August, this page will be updated with new guidance based on token usage patterns observed in June/July.


---

## Budget strategies

**Terminology used on this page:**

- **Universal User-Level Budget (UULB)** — the default per-user spending cap applied to all users
- **Individual User Budget (IUB)** — a per-user override that replaces the UULB for a specific person
- **Enterprise Budget** — an enterprise-wide cap on total metered overage

**How the layers work:**

1. Licenses create a shared credit pool (all users draw from one balance).
2. User-level budgets (UULB and IUB) limit how much each person can draw from the pool.
3. After the pool is exhausted, those same user-level budgets authorize metered overage up to the same per-user limit.
4. Enterprise and Cost Center budgets cap total metered overage — they have no effect while pooled credits remain.

---

How you configure User-Level Budgets depends on three questions:

1. **Do you know who your power users are?** Can you name the developers who will burn through their per-seat entitlement?
2. **Do you have a large idle population?** Were you removing licenses under the old premium-request system because developers weren't using them? Do you know a significant chunk of your pool will go unconsumed?
3. **Are you comfortable giving the whole population extra headroom?** Would you rather set a high ceiling and let power users self-serve, or keep it tight and manage overrides individually?

Use your answers to pick a path:

| If you… | Then use… |
|---------|-----------|
| Know your power users, have a large idle population, and are comfortable with extra headroom | [Path A: High UULB, reactive overrides](#path-a-high-uulb-reactive-overrides) |
| Don't know who's heavy, most developers are using at least a little, and you want fair distribution | [Path B: Low UULB, proactive overrides](#path-b-low-uulb-proactive-overrides) |

Both paths require an [enterprise budget backstop](#enterprise-budget-backstop).


### Path A: High UULB, reactive overrides

**When to use**: You know power users exist, you know many developers aren't touching their credits, and you don't want power users knocking on your door every month asking for more budget.

**The idea**: Each user contributes $30 (Business) or $70 (Enterprise) worth of credits to the pool. If you set the UULB to $90/month, your power users hit that ceiling immediately and you're fielding budget requests constantly. Instead, set it high enough that most power users never hit it — they just consume from the excess pool capacity that light users aren't touching. The idle population's unused credits fund the power users' work.

#### Set the Universal User Budget at $200–$1,000

Size the UULB as **the largest amount you're willing to let any single developer spend from the pool before they need to ask for more budget**. This controls both pool draw-down *and* per-user overage after pool depletion.

$200–$1,000 is typical. Most power users will never hit this ceiling because the pool will deplete first. The ones who do hit it are the extreme outliers — and those are the only ones who need to come ask for more.

#### Example: 100 Business developers, UULB at $500

| | Value |
|--|-------|
| Pool (100 × $30 promo) | $3,000 |
| UULB per user | $500 |
| Total authorized spend (100 × $500) | $50,000 |
| Theoretical max overage ($50K − $3K) | $47,000 |

In practice, most developers use $10–$50/month. If 80 developers average $20, they consume $1,600 — leaving $1,400 in the pool for 20 power users ($70 each). The $500 ceiling only kicks in after the pool is gone, and your enterprise backstop caps actual spend long before 100 people hit $500.

#### Grant Individual User Budgets only for extreme outliers with approved projects

For the developer who hit their $500–$1,000 ceiling, find out what they're working on and whether it justifies granting an Individual (override) User-Level Budget. Size it based on **how much of the overage pool you'd want that specific person to be able to exhaust**.

With this path, Individual ULBs should be rare — the high UULB handles 95%+ of your population without intervention.


### Path B: Low UULB, proactive overrides

**When to use**: You don't yet know who your heavy users are, most developers are using Copilot at least a little, and you want to ensure fair distribution across the population while you identify power users.

**The idea**: Start with a tight Universal User Budget so no single person can monopolize the pool. Then proactively grant Individual User Budgets to power users as they surface through budget notifications.

#### Set the Universal User Budget at 1–2× entitled credits

Give every user a UULB of 1–2× their per-seat entitlement:

During the promotional period:
- Business users: $30–$60
- Enterprise users: $70–$140

This lets heavier users borrow from lighter users' unused portions without anyone monopolizing the pool. If credits are left over at month end, raise it. You want near-zero remaining credits with nobody blocked mid-month.

#### Example: 100 Business developers, UULB at $60

| | Value |
|--|-------|
| Pool (100 × $30 promo) | $3,000 |
| UULB per user | $60 (2× entitlement) |
| Total authorized spend (100 × $60) | $6,000 |
| Theoretical max overage ($6K − $3K) | $3,000 |

At 2× entitlement, even if every developer consumes their full $60, the pool covers the first $3,000 and overage tops out at $3,000. Your enterprise backstop handles that. Realistically, light users won't hit $60, so heavy users borrow their slack from the pool before overage even starts.

> [!TIP]
> Capping at exactly 1× the per-license value defeats the purpose of pooling. Heavy users get blocked while light users waste credits. 1.5–2× is the sweet spot — just make sure you have an enterprise backstop so the generosity has a ceiling.

#### Grant Individual User Budgets for power users ($200–$1,000)

When a developer hits their Universal User Budget, don't just raise the UULB for everyone. Instead:

1. **Grant them an Individual User Budget** with a cap of $200–$1,000. This is the only way to give a specific user more headroom within the pool (see [When developers are blocked](#when-developers-are-blocked) for why Cost Center budgets don't help here).
2. **Find out what project they're working on.** This context is how you build the case for AI investment and discover your champions (see [Build your champions program](#build-your-champions-program)).

With this path, Individual User Budgets are a core part of the operating model, not an exception. In orgs with broad Copilot adoption, you may need individual overrides for a large share of your population — potentially 50–70% depending on usage patterns.

> [!WARNING]
> User-level budgets control how much of the pool each person can draw — **and they keep working after the pool is exhausted**, authorizing metered overages up to the same limit. If you set every user's budget at 2× their entitlement, the total authorized overage across all users is up to 1× the pool value. For 100 Business users ($3000 pool), that's up to $3000/month in metered overages on top of what you've already paid for. **Always pair user budgets with an enterprise budget backstop.**


### Enterprise budget backstop

Both paths require an enterprise-level budget.

User-level budgets (Universal and Individual) control how much each person can draw from the pool — but they also authorize metered overages after the pool is exhausted. The sum of all user budgets creates an implicit aggregate ceiling that may be far higher than your intended spend. An enterprise budget makes that ceiling explicit.

**How to size it:**

1. **Start with your actual usage data.** Download your [usage report](https://docs.github.com/en/enterprise-cloud@latest/copilot/how-tos/manage-and-track-spending/prepare-for-usage-based-billing) or upload it to the [billing preview tool](https://copilot-billing-preview.github.com/) to see your projected monthly spend. Your backstop should be based on real consumption patterns, not theoretical maximums.
2. **Set the enterprise budget above your projected spend** with "Stop usage" enabled — give yourself enough headroom for growth (e.g., 1.5–2× your highest projected month) so the backstop only fires in a truly abnormal month.
3. **Set threshold alerts at 75% and 90%** so you have time to react before the backstop fires.

| Example (Path A — 100 Copilot Business users, promotional period) | Value |
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


### Managing Individual User Budgets at scale

> [!TIP]
> Managing Individual User Budgets through the UI is tedious at scale. Two options:
> - **REST API** — [Create a budget](https://docs.github.com/en/enterprise-cloud@latest/rest/billing/budgets?apiVersion=2026-03-10#create-a-budget) endpoint lets you script bulk budget assignments
> - **gh CLI extension** — [`gh-ulb`](https://github.com/colinbeales/gh-ulb) wraps the API if you don't want to write the scripts yourself


### Build your champions program

The developers who consistently hit their budgets are your power users — whether you knew them upfront (Path A) or discovered them through notifications (Path B). They're also the foundation of a good AI adoption story:

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

Enable "Stop usage" on Universal and Individual User Budgets — this is your hard cap per user. At the enterprise level, "Stop usage" should be a high backstop set well above expected spend (see [Enterprise budget backstop](#enterprise-budget-backstop)). It catches runaway months without blocking developers during normal operations. Use threshold alerts (75%, 90%, 100%) at the enterprise and cost center levels for day-to-day monitoring. The [WAF recommends](https://wellarchitected.github.com/library/governance/recommendations/managing-ai-credits/) focusing enforcement at the user level and alerts at the enterprise level.

### 3. Budgets only track from their creation date

When you first create a budget, it applies only to metered usage from that date forward. Prior consumption isn't counted. This means you can exceed your budget in the first cycle even with "Stop usage" enabled. Create or adjust budgets at the start of a billing cycle whenever possible. If creating mid-cycle, set the limit conservatively. See [Budgets and alerts](https://docs.github.com/en/enterprise-cloud@latest/billing/concepts/budgets-and-alerts#your-first-billing-cycle-after-creating-a-budget) for details.

### 4. Raise Individual User Budgets before upgrading tiers *(post-promotional period)*

After August 2026, an Individual User Budget on a Business license lets a user borrow more from the pool at no extra cost. Upgrading from Business to Enterprise adds $20/month in licensing alongside $20 in credit value. From a credit-pool perspective, there is no net gain. If someone needs more capacity post-promo, raise their Individual User Budget first.

> [!NOTE]
> During the promotional period (June 1 – August 31, 2026), Enterprise seats include disproportionately more AICs (7,000 vs. 3,000), so the upgrade is worthwhile for power users who already have a GHEC seat. See the [Promotional period](#promotional-period-june-1--august-31-2026) section.

### 5. Gate budget increases on prior-month usage data

Individual User Budgets don't expand the pool. They raise the per-user ceiling, which accelerates depletion for everyone. Require usage data before granting increases: if someone didn't hit their limit last month, they don't need a higher one.

### 6. Share pool depletion metrics monthly

Publish a simple end-of-month summary ("Pool was 74% consumed, no one was blocked"). When people can see the pool is healthy, they're less likely to inflate usage defensively or rush to consume credits early in the cycle.

---

## Reducing token consumption at the source

Budgets control how much each user *can* spend — but the most effective cost lever is making every credit count. Well-scoped agent sessions, deliberate model selection, and deterministic guardrails (tests, linters, security scans) all reduce retries and wasted tokens, which directly lowers credit consumption without limiting developer productivity.

Key resources for developers:

- **Interactive token optimization guide** — Scenarios, a cost calculator, a model-selection playbook, and copy-paste templates: [GitHub Copilot Token Optimizer](https://ashy-dune-0b4215a0f.7.azurestaticapps.net/index.html)
- **Optimize AI usage** — GitHub's five strategies for higher-quality agents that complete tasks in fewer attempts: model selection, prompt guidance, the research-plan-implement workflow, deterministic guardrails, and concise `copilot-instructions.md` files: [Optimize AI usage](https://docs.github.com/en/enterprise-cloud@latest/copilot/tutorials/optimize-ai-usage)

> [!TIP]
> Teams that invest in agent quality guardrails often see **fewer retries and lower total token spend** — even when individual steps use slightly more tokens upfront. Pair this with the budget strategy above: when power users hit their limits less often, you spend less time adjusting budgets and more time shipping. For developers who want hands-on practice, share the [Context Engineering Lab](https://copilot-academy.github.io/labs/context-engineering-lab) — a 2-hour workshop on measuring and reducing token consumption.

---


## When developers are blocked

When someone reports being blocked, work through these checks in order:

1. **Did they hit their Universal or Individual User Budget?**
   - Yes: raise their budget or grant an Individual User Budget with a higher cap. This is the cause nine times out of ten.
   - No: keep checking.

2. **Is the shared pool depleted?**
   - No: the pool still has capacity. The issue is the user's personal budget (step 1) or their license/feature access. Cost Center budgets are irrelevant here — they only track overage after the pool is exhausted.
   - Yes: keep checking.

3. **Has the Enterprise Budget been reached?**
   - Yes: raise it. It's capping total metered charges.

4. **Are they in a cost center with a budget that has "Stop usage" enabled?**
   - Yes and the pool is depleted: the cost center budget is capping their overage. Raise it or remove the cap.
   - No: check whether "Stop usage" is enabled on the Enterprise Budget, or whether their license was removed.

> [!TIP]
> Mid-month blocks are almost always the Universal User Budget. Cost Center budgets only matter after the pool runs out — they cannot unblock a user who hit their personal cap while pooled credits remain.

> [!NOTE]
> A common misconception is that placing a user in a Cost Center with a higher budget will let them exceed their Universal User Budget. It won't. Cost Center budgets track overage spend, not pooled entitlement usage. The only way to give a user more headroom within the pool is to raise their Universal User Budget or assign an Individual User Budget.

---

*Budget guidance adapted from [xrvk](https://github.com/xrvk)*
