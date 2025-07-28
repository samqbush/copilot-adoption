# Strategies for Managing Copilot Premium Request Spending

As your organization adopts GitHub Copilot, developers will begin using premium features that may incur costs beyond the base license fees. To ensure predictable spending and maximize the value of your investment, it's important to have a strategy for managing these costs.

This guide outlines two key strategies for effective cost management: optimizing license tiers for heavy users and setting granular budgets for specific groups.

> [!NOTE]
> By default, the spending limit for Copilot premium features is set to $0. To implement these strategies, you will need to adjust your enterprise's billing settings to allow for spending.

> [!TIP]
> This open source [premium request calculator](https://github.com/jonjozwiak/premium-requests-calculator) can be used for calculating your monthly estimated premium requests and costs.

---

## Strategy 1: Optimize Licensing for Power Users

Different Copilot plans (Business and Enterprise) include a different monthly allowance of premium requests. While the Enterprise plan has a higher per-user cost, it includes a significantly larger allowance of premium requests.

For developers who frequently use features like in-depth code analysis or interact heavily with specialized models, it can be more cost-effective to upgrade them to Copilot Enterprise rather than paying for their premium request overages on the Copilot Business plan.

### Recommended Actions

1.  **Analyze Usage**: Regularly download and review the [GitHub Copilot Usage Report](https://docs.github.com/en/copilot/managing-copilot/understanding-and-managing-copilot-usage/monitoring-your-copilot-usage-and-entitlements#downloading-a-monthly-usage-report) for your enterprise.
2.  **Identify Power Users**: Identify developers who consistently generate a high volume of premium requests each month.
3.  **Upgrade Strategically**: For these power users, calculate your organization's "break-even" point. If the cost of their monthly overages on the Business plan exceeds the cost of an upgrade to the Enterprise plan, it's time to switch their license.
4.  **Isolate and Assign**: A common practice is to create a new, dedicated organization within your GitHub Enterprise for these power users. This makes it simple to [assign Copilot Enterprise licenses](https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-access-to-copilot-in-your-enterprise/enabling-copilot-for-organizations-in-your-enterprise) to that group while keeping other users on the Business plan.

---

## Strategy 2: Set Granular Spending Limits

You may want to give certain teams or individuals a budget for premium requests without allowing for unlimited spending. This is useful for teams working on critical R&D projects or those who need extra resources without granting them a full Enterprise license.

There are two primary methods for setting these specific budgets.

### Option A: Use a Separate Organization Budget

This approach offers maximum flexibility. You can create a new organization, move the desired users into it, and then apply a specific spending budget for Copilot to that organization.

1.  Create a new organization within your enterprise.
2.  Invite the users who require a dedicated budget.
3.  [Create a new budget](https://docs.github.com/en/enterprise-cloud@latest/billing/managing-your-billing/using-budgets-control-spending#managing-budgets-for-your-organization-or-enterprise) at the enterprise level.
4.  Configure the budget to apply only to the "Copilot Premium Request" SKU and scope it to the newly created organization.

### Option B: Use a Cost Center Budget

If your organization already uses GitHub's Cost Centers to align spending with business units, you can apply a budget directly to a cost center.

> **Note:**
> This option is only viable if your cost center structure aligns with your desired budgeting groups for Copilot. A user can only belong to one cost center at a time.

1.  [Create a new Cost Center](https://docs.github.com/en/enterprise-cloud@latest/billing/managing-your-billing/charging-business-units#creating-a-cost-center) if one doesn't already exist.
2.  Assign the relevant users to the cost center (this often requires using the [API](https://docs.github.com/en/enterprise-cloud@latest/rest/enterprise-admin/billing?apiVersion=2022-11-28#add-users-to-a-cost-center)).
3.  Create a new budget at the enterprise level, applying it to the "Copilot Premium Request" SKU and scoping it to the new cost center.

By combining these strategies, you can create a flexible and cost-effective approach to rolling out GitHub Copilot across your entire organization.