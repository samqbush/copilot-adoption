# Strategies for Managing Copilot Usage-Based Billing

GitHub Copilot has transitioned from a premium-request counting model to **Usage-Based Billing (UBB)** built on **AI Credits (AICs)** — a token-consumption measure that scales with how much AI capacity each interaction uses. This guide explains how UBB works and provides practical strategies for configuring budgets that keep spending predictable while maximizing developer productivity.

---

## How Usage-Based Billing Works

GitHub Copilot uses **AI Credits (AICs)** as its billing unit — each credit equals $0.01 USD of token consumption. Every license includes AI Credits (Business: 1,900/month, Enterprise: 3,900/month) that pool enterprise-wide into a shared reservoir. When the pool runs out, additional usage is charged as metered billing — and that's where budgets come in.

For a full explanation of AI Credits, pooling, and what happens at overage, see [Usage-based billing for organizations and enterprises](https://docs.github.com/en/enterprise-cloud@latest/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises).

> [!IMPORTANT]
> Your licenses include pre-paid AI Credits (included credits). **Budgets cap what happens after those included credits run out.**

---

## Promotional Period (June – September 2026)

For the first three months of usage-based billing, existing Copilot customers receive increased AI Credit allowances:

| Plan | Standard AICs/user/month | Promotional AICs/user/month |
|------|--------------------------|----------------------------|
| Copilot Business | 1,900 | 3,000 |
| Copilot Enterprise | 3,900 | 7,000 |

### Why This Matters for Enterprise Seats

During the promotional period, Enterprise seats include **7,000 AICs** (vs. 3,000 for Business) — a 2.3× advantage per seat. If you have power users who will consume significantly more than 3,000 AICs/month, placing them on Enterprise seats during this window maximizes your pooled credits at no additional per-credit cost.

> [!NOTE]
> **Copilot Enterprise requires a GitHub Enterprise Cloud seat.** This optimization only applies to users who already have a GitHub Enterprise Cloud license. If a user is not on GitHub Enterprise Cloud, adding Copilot Enterprise also requires purchasing a GHEC seat — factor that additional cost into your analysis before upgrading.

After the promotional period ends (September 2026), the advantage normalizes: both tiers include AICs proportional to their license cost ($0.01/AIC), so upgrading a seat from Business to Enterprise adds $20/month in cost alongside $20 in additional credit value — no net gain. At that point, raising Individual User Budgets is more cost-effective than upgrading tiers (see Tip #5 below).

> [!TIP]
> Use the promotional period to identify your power users and get them on Enterprise seats. After the promo ends, shift your strategy to Individual User Budgets for users who need more capacity.

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

Without explicitly enabling the **"Stop usage"**, every budget is advisory only — it sends a notification when the threshold is crossed, but usage and billing continue uncapped. Enable this on every budget to guarantee actual cost ceilings.

### 3. Size the Enterprise Budget from Your Seat Mix

The Enterprise Budget is a post-pool safety net. Size it as: **total maximum consumption minus pool value = potential additional spend**. Add a buffer for that. It does nothing while the pool has capacity.

### 4. Budgets Only Track from Their Creation Date

When you first create a budget, it applies only to metered usage from the date of creation onwards — prior consumption is not counted. This means you may exceed your budget in the first billing cycle even with "Stop usage" enabled. **Create or adjust budgets at the start of a new billing cycle** whenever possible. If creating mid-cycle, set the initial limit conservatively to account for consumption that already occurred. See [Budgets and alerts](https://docs.github.com/en/enterprise-cloud@latest/billing/concepts/budgets-and-alerts#your-first-billing-cycle-after-creating-a-budget) for details.

### 5. Raise Individual User Budgets Before Upgrading License Tiers *(Post-Promotional Period)*

After the promotional period ends (September 2026), an Individual Budget on a Business license lets a user borrow more from the pool at no extra cost. At standard rates, upgrading from Business to Enterprise adds $20/month in licensing cost alongside $20 in additional AIC value — since credits are 1:1 with license cost, **there's no net gain**. If a user needs more capacity post-promo, raise their Individual User Budget first.

> [!NOTE]
> During the promotional period (June–September 2026), Enterprise seats include disproportionately more AICs (7,000 vs. 3,000), making the upgrade worthwhile for power users who already have a GHEC seat. See the [Promotional Period](#promotional-period-june--september-2026) section above.

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

*Budget guidance adapted from [xrvk](https://github.com/xrvk)*
