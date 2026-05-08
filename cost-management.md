# Strategies for Managing Copilot Usage-Based Billing

GitHub Copilot has transitioned from a premium-request counting model to **Usage-Based Billing (UBB)** built on **AI Credits (AICs)** — a token-consumption measure that scales with how much AI capacity each interaction uses. This guide explains how UBB works and provides practical strategies for configuring budgets that keep spending predictable while maximizing developer productivity.

> [!TIP]
> This open source [budget command center](https://github.com/jonjozwiak/premium-requests-calculator) provides interactive tools for calculating, reviewing, and applying your budget configuration — including a Tier Planner and Promo Optimizer.

---

## How Usage-Based Billing Works

### What You Pay For

Every GitHub Copilot license comes with **AI Credits (AICs)** included — worth the same dollar value as the license itself. Using those included credits costs nothing extra.

| Plan | License Cost | AICs Included | Credit Value |
|------|-------------|---------------|--------------|
| Copilot Business | $19/user/month | 1,900 AICs | $19 |
| Copilot Enterprise | $39/user/month | 3,900 AICs | $39 |

### The Shared Pool

All AICs from every seat combine into **one enterprise-wide pool**. It doesn't matter which team purchased which license — everyone draws from the same reservoir. The pool resets each billing cycle; unused credits do not roll over.

> [!NOTE]
> **Example:** 80 Business + 20 Enterprise seats → 230,000 AICs pooled together ($2,300 in included credits). Every developer draws from the same reservoir.

### When the Pool Runs Out

When the pool hits zero, Copilot usage doesn't automatically stop. Additional usage is charged as **metered billing** — a per-credit fee for consumption beyond your included credits. The budgets in GitHub's billing settings exist to manage this additional usage, not the pool itself.

> [!IMPORTANT]
> Your licenses include pre-paid AI Credits (included credits). **Budgets cap what happens after those included credits run out.**

---

## The Four Budget Controls

The billing system gives you four distinct tools, each operating at a different level:

### Enterprise Budget *(Post-Pool Only)*

A hard ceiling on metered charges once the shared pool runs dry. Has zero effect while pool capacity remains. This is **not** a total budget — it only governs overage charges.

### Cost Center Budget *(Post-Pool Only)*

Cap on metered charges for a GitHub org or group of users. Useful for departmental chargeback, but cannot protect a group's share of the pre-paid pool.

### Universal User Budget *(Always Active)*

Caps how much of the shared pool any single person can draw per month. **This is your primary fairness control.** Without it, a single user or automated agent could consume the entire enterprise pool overnight.

### Individual User Budget *(Always Active)*

A higher personal cap for specific named users who demonstrably need more than the universal limit.

---

## Recommended Budget Strategy

The most effective approach to Copilot budget management follows a progressive discovery model that balances developer productivity with cost control:

### Step 1: Set the Universal User Budget at 2.5–3× Entitled Credits

Set every user's Universal User Budget to **2.5–3× their per-seat AI Credit entitlement**. For example:

- **Business users** (1,900 AICs included): Set ULB to **4,750–5,700 AICs**
- **Enterprise users** (3,900 AICs included): Set ULB to **9,750–11,700 AICs**

This generous-but-bounded approach enables the core benefit of pooling: heavier users borrow from lighter users' unused portions without any one person monopolizing the pool. If credits are left over at month-end, raise it. The goal is **near-zero remaining credits with no one blocked mid-month**.

> [!TIP]
> Capping at exactly 1× the per-license value defeats the purpose of pooling. Heavier users get blocked while light users waste credits. The 2.5–3× multiplier is the sweet spot for most organizations.

### Step 2: When a Power User Hits the Limit, Investigate

When a developer hits their Universal User Budget, **don't just raise the limit**. Instead:

1. **Move them into a personal Individual User Budget** or assign them to a **Cost Center Budget** with a higher allowance.
2. **Find out what project they're working on** — this context is invaluable for understanding where AI is delivering the most value.

### Step 3: Build Your Champions Program

The developers who consistently hit their budgets are your **power users** — and they're the foundation of a strong AI adoption story:

- **Identify them** through budget notifications and usage data
- **Collect their stories** — what projects they're accelerating, what problems Copilot is solving
- **Build a champions program** around them to evangelize AI usage across the organization
- **Demonstrate business value** by connecting their AI consumption to project outcomes

> [!NOTE]
> This progressive approach turns a cost management exercise into a **business value discovery process**. You're not just controlling spend — you're identifying where AI investment delivers the highest return.

---

## Essential Configuration Tips

### 1. Always Set a Universal User Budget

> [!WARNING]
> Without a Universal User Budget, a single user or automated agent can consume the entire enterprise pool overnight. This is your most critical configuration.

### 2. Always Enable "Stop Usage" on Budgets

Without explicitly enabling the **"Stop usage"** (`prevent_further_usage`) option, every budget is advisory only — it sends a notification when the threshold is crossed, but usage and billing continue uncapped. Enable this on every budget to guarantee actual cost ceilings.

### 3. Size the Enterprise Budget from Your Seat Mix

The Enterprise Budget is a post-pool safety net. Size it as: **total maximum consumption minus pool value = potential additional spend**. Add a buffer for that. It does nothing while the pool has capacity.

### 4. Budgets Only Track from Their Creation Date

A budget created or reset mid-cycle starts its counter at zero regardless of prior consumption. **Create or adjust budgets at the start of a new billing cycle** whenever possible. If creating mid-cycle, set the initial limit conservatively.

### 5. Raise Individual User Budgets Before Upgrading License Tiers

An Individual Budget on a Business license lets a user borrow more from the pool at no extra cost. Upgrading from Business to Enterprise adds $20/month in licensing cost alongside $20 in additional AIC value — since credits are 1:1 with license cost, **there's no net gain**. If a user needs more capacity, raise their Individual User Budget first.

### 6. Gate Individual Budget Increases on Prior-Month Usage Data

Individual Budgets don't expand the pool — they raise the per-user ceiling, accelerating depletion for everyone. Require usage data first: a user who didn't hit their current limit last month has no case for a higher one. **Power user status should be demonstrated, not self-reported.**

### 7. Share Pool Depletion Metrics Monthly

Publish a simple end-of-month summary (e.g., *"Pool was 74% consumed, no one was blocked"*). Users who can see the pool is healthy are less likely to inflate usage defensively. Transparency builds trust and reduces budget-increase requests.

---

## Cost Center Exclusion

One toggle fundamentally changes how Enterprise and Cost Center Budgets interact. **Decide on this setting before sizing any budgets** — it changes the math for everything else.

### Exclusion OFF (Default)

The Enterprise Budget is the single umbrella covering all metered charges beyond the pool, including those attributed to cost centers. Cost center budgets act as sub-limits within it.

**Best for:** Most organizations. Simpler — one cap covers everything.

### Exclusion ON

Enterprise and cost center budgets become fully independent meters. Charges attributed to a cost center are excluded from the enterprise counter entirely.

**Best for:** Organizations where departments manage their own AI spend. Every cost center must have its own budget.

> [!WARNING]
> **Never enable exclusion without configuring cost center budgets for every team.** Any cost center without a budget becomes completely uncapped for metered charges.

---

## When Developers Are Blocked

When a developer reports being blocked, work through these checks in order:

1. **Has the user hit their Universal or Individual User Budget?**
   - *Yes →* Raise their budget or move them to an Individual User Budget. This is the cause nine times out of ten.
   - *No →* Continue checking.

2. **Is the shared pool depleted?**
   - *No →* The pool still has capacity. Check the user's license status and feature access.
   - *Yes →* Continue checking.

3. **Has the Enterprise Budget been reached?**
   - *Yes →* Raise the Enterprise Budget. It's capping total metered charges.

4. **Is the user in a cost center with a budget?**
   - *Yes →* The cost center budget is the constraint. Raise it or remove the cap.
   - *No →* Investigate further — check if "Stop usage" is enabled, or if the user's license was removed.

> [!TIP]
> Mid-month blocks are almost always the Universal User Budget. The Enterprise Budget only matters after the pool runs out.

---

## Common Mistakes

### Treating the Enterprise Budget as a Total Budget

Finance sets a $5,000 "enterprise budget" expecting it to cap total monthly spend. Actual bill: $5,000 + $2,300 pool consumption = $7,300. The Enterprise Budget only caps metered charges **after** the pool runs out. Seat fees and pool consumption happen regardless.

### Not Enabling "Stop Usage"

Enterprise limit set to $500. Limit reached. Usage continues. The bill is $1,800. Without the `prevent_further_usage` flag, every budget is purely advisory.

### Enabling Cost Center Exclusion Without Cost Center Budgets

Exclusion flipped ON. Teams without a cost center budget now have no metered charge ceiling at all. **Always configure a budget for every cost center before enabling this toggle.**

---

## Budget Management via API

All budget management can be performed programmatically via the [Budget Management API](https://docs.github.com/en/rest/billing/budgets), allowing you to:

- Create, update, and delete budgets
- Adjust budget amounts and alert thresholds
- Automate budget provisioning as part of team onboarding workflows

The [Usage Summary API](https://docs.github.com/en/rest/billing/usage) lets you retrieve and analyze usage data filtered by organizations, repositories, cost centers, products, or SKUs — making it easier to identify trends and optimize your budget allocations over time.

---

By combining a well-tuned Universal User Budget with progressive discovery of power users, you create a system that is both cost-effective and a powerful driver of AI adoption across your organization.

*Billing model guidance adapted from [Dylan Rinker](https://gist.github.com/Dylan-Rinker/cb0ee4241d8d41a3e0fac9f16cd6c875)*
