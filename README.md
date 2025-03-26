# Minimum Required Tasks for Copilot Adoption at Scale

These checklists outline the essential steps for a successful large-scale Copilot rollout.  While numerous Copilot resources exist, these checklists focus on the minimum requirements to avoid overwhelming users with too much information at once.  They are not exhaustive, but they represent the critical elements for initial success.

## Phase 1 - Pilot

> [!TIP]
> For any security questions or requirements it is recommended to first check [GitHub Copilot Trust Center](https://resources.github.com/copilot-trust-center/#privacy) and the [Compliance tab](https://docs.github.com/en/enterprise-cloud@latest/admin/overview/accessing-compliance-reports-for-your-enterprise) in GitHub under Your Enterprise > Compliance

### Setup & Configuration

#### Configure IDP

- [ ] [Configure Authentication to GitHub EMU via IDP](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/getting-started-with-enterprise-managed-users#configure-authentication)
- [ ] [Configure SCIM provisioning for EMU](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/provisioning-user-accounts-with-scim/configuring-scim-provisioning-for-users)

#### Design organization & team structure

##### GitHub Enterprise Server (GHES)

- Create production organization in your Copilot EMU
  - Create teams and map to IDP groups
- Create test/preview organization in your Copilot EMU
  - Create teams and map to LDAP groups

##### Enterprise Managed Users (EMU)

- Option 1 - Use existing org/team structure to provide access
  - This option can be cumbersome if a large number of organizations exist
- Option 2 - Create additional organizations to control copilot access -  follow GHES steps

##### Copilot Business Only (Standalone)

- Create enterprise teams since organizations do not exist in this instance
- Map teams to IDP groups

> [!NOTE]
> See the [user management](./user-mgmt/) folder for script examples of creating & mapping teams to IDPs

#### Copilot Policies

##### Enterprise configuration

- [ ] Assign each organization ability to assign Business or Enterprise licenses and grant all users in the organization a license
- [ ] [Enable the desired policies at the Enterprise level](https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-policies-and-features-for-copilot-in-your-enterprise)
- [ ] Enable the desired models at the Enterprise level
  - Use No Policy if enabling in test/preview organization

##### Organization configuration

- [ ] [Enable the desired policies on the production org](https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-github-copilot-in-your-organization/managing-policies-for-copilot-in-your-organization)
- [ ] [Enable the desired policies on the test/preview org](https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-github-copilot-in-your-organization/managing-policies-for-copilot-in-your-organization)
- [ ] [Install desired extensions at the org level](https://docs.github.com/en/copilot/customizing-copilot/extending-the-capabilities-of-github-copilot-in-your-organization)
- [ ] Add teams to appropriate organization

#### Network & Security Policy

Configure GitHub Enterprise settings to align with your organization's security and policy requirements

- [ ] [Configure Network Settings for GitHub Copilot](https://docs.github.com/en/copilot/managing-copilot/managing-github-copilot-in-your-organization/configuring-your-proxy-server-or-firewall-for-copilot)
- [ ] [Restrict network traffic to your enterprise with an IP allow list](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/hardening-security-for-your-enterprise/restricting-network-traffic-to-your-enterprise-with-an-ip-allow-list)
- [ ] [Require two-factor authentication for organizations in your enterprise](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/enforcing-policies-for-security-settings-in-your-enterprise#requiring-two-factor-authentication-for-organizations-in-your-enterprise)
- [ ] [Ensure proxy configuration for smooth GitHub Copilot integration in enterprise networks](https://docs.github.com/en/copilot/managing-copilot/configure-personal-settings/configuring-network-settings-for-github-copilot)

### Provide Self Serve Training

- [ ] Bundle training and provide a distribution method using the content below
  - [Example](https://github.com/maxmash1/copilot-intro) of how this can be bundled together
  - [Training by Feature](./training-by-feature.md)

#### Copilot Fundamentals

- Install the Copilot extension in your IDE of choice from the IDE marketplace or organization-specific installation  
  - VS Code is recommended for the latest preview features
- [Getting code suggestions in your IDE with GitHub Copilot](https://docs.github.com/en/copilot/using-github-copilot/getting-code-suggestions-in-your-ide-with-github-copilot)
- [Chat in the IDE](https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide)
- [Prompt Engineering](https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/prompt-engineering-for-copilot-chat)
  - If [public code suggestions](https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-policies-and-features-for-copilot-in-your-enterprise#suggestions-matching-public-code) are disabled then prompt engineering should be a required training.  See [examples](./prompt-engineering-for-disabled-public-code.md)
- [GitHub Copilot in VS Code](https://code.visualstudio.com/docs/copilot/overview)

#### Advanced

- [Customize Copilot with personal custom instructions](https://docs.github.com/en/copilot/customizing-copilot/adding-personal-custom-instructions-for-github-copilot)
- Create a series of interactive tutorials or challenges that encourage users to try out Copilot in their coding work.
  - [Example](https://github.com/maxmash1/copilot-workshop)
- [Copilot Extensions](https://resources.github.com/learn/pathways/copilot/extensions/essentials-of-github-copilot-extensions/)

#### GitHub Specific Fundamentals

- [Chat in GitHub or with @github extension](https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github)
- [Code Review](https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review)

#### Additional Training

- [Copilot Certification](https://github.com/orgs/community/discussions/144443)
  - The official GitHub Copilot certification
- [GitHub Copilot - Training, Tips, & Tricks](https://www.youtube.com/playlist?list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D)
  - A comprehensive playlist for those that prefer to learn by watching versus reading.
- [Microsoft Learning Training](https://learn.microsoft.com/en-us/training/browse/?products=github&terms=GitHub%20Copilot)
  - For those that prefer training module style learning from Microsoft on Generally Available features

#### Troubleshooting

Ensure that users are aware of the support resources available to them and providing common troubleshooting links.

- [Troubleshooting common issues with GitHub Copilot](https://docs.github.com/en/copilot/troubleshooting-github-copilot/troubleshooting-common-issues-with-github-copilot)
- [Viewing logs for GitHub Copilot in your environment](https://docs.github.com/en/copilot/troubleshooting-github-copilot/viewing-logs-for-github-copilot-in-your-environment)
- [Troubleshooting firewall settings for GitHub Copilot](https://docs.github.com/en/copilot/troubleshooting-github-copilot/troubleshooting-firewall-settings-for-github-copilot)
- [Troubleshooting network errors for GitHub Copilot](https://docs.github.com/en/copilot/troubleshooting-github-copilot/troubleshooting-network-errors-for-github-copilot)
- [Troubleshooting issues with GitHub Copilot Chat](https://docs.github.com/en/copilot/troubleshooting-github-copilot/troubleshooting-issues-with-github-copilot-chat)

### Invite Pilot Teams

- [ ] Add pilot teams to organizations via IDP group
- [ ] Send welcome email with self serve training to pilot teams

### Optional Setup

#### Cost Centers

- [ ] [Create cost centers & allocate spending](https://docs.github.com/en/enterprise-cloud@latest/billing/using-the-new-billing-platform/charging-business-units#creating-a-cost-center)

#### Developer ROI

> [!TIP]
> If this section seems overwhelming, there are vendors who assist with this analysis and provide out-of-the-box solutions

##### Baseline

- [ ] Read [Research: quantifying GitHub Copilot’s impact on developer productivity and happiness](https://github.blog/news-insights/research/research-quantifying-github-copilots-impact-on-developer-productivity-and-happiness/)
- [ ] Read [Why developer satisfaction is your best productivity metric](https://resources.github.com/developer-productivity/why-developer-satisfaction-is-your-best-productivity-metric/)
- [ ] Define trackable key performance indicators (KPIs) that reflect the goals and expected benefits of using GitHub Copilot.
- [ ] Conduct a baseline measurement of development metrics prior to introducing GitHub Copilot.

##### Copilot Metrics

- [ ] Use one of the following for a dashboard
  - [Power BI App](https://appsource.microsoft.com/en-us/product/power-bi/github.github-copilot-metrics)
  - [NodeJS Copilot Metrics Viewer](https://github.com/github-copilot-resources/copilot-metrics-viewer)
  - [Grafana Metrics Viewer](https://github.com/kleeadrian/Grafana-Copilot-Metrics)
  - Create your own using [API](https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics?apiVersion=2022-11-28)
    - [Getting started with Copilot Metrics APIs](https://docs.github.com/en/copilot/rolling-out-github-copilot-at-scale/analyzing-usage-over-time-with-the-copilot-metrics-api)
    - [Copilot Usage GitHub Action](https://github.com/marketplace/actions/copilot-usage-action) - Get Copilot usage data as .md, CSV, XML, JSON, or emailed PDF report
    - [Copilot Metrics Retention GitHub Action](https://github.com/marketplace/actions/copilot-metrics-retention) - GitHub Action designed to persistently store Copilot Usage Metrics data over time in a JSON file format.
- Focus on engagement metrics vs acceptance metrics that can be a red herring and should be avoided in the beginning
  - Compare the number of licensed users, total engaged users, and the overall developer population
- [ ] Add qualitative metrics by implementing surveys
  - [Pull Request Survey Engine]( https://github.com/github/copilot-survey-engine)
  - [Survey Guide](https://docs.google.com/document/d/1IJasrJNkM3GE9a6a25DfU5DrXrtr4I6OYl6WUYIS0sE/edit?tab=t.0)
    - [Google Forms Survey Template](https://docs.google.com/forms/d/1HVPK1OjOYV-y5ZUcHWB_qvUhiVssHchh6LdiEyBXeD4/edit)

## Phase 2 - Early Adopters & Early Majority

### Start an internal community

- [ ] **Identify internal advocates/champions** -  Find employees who have successfully used GitHub Copilot. These advocates can share their experiences, offer insights, and help guide others in the community.
- [ ] **Determine the best community building tool** - Choose a tool that most of your employees are already familiar with such as Slack, Discord, Confluence, GitHub Discussions, etc.
- [ ] **Populate your new community channel** - Kickstart the channel by adding initial content such as FAQs, case studies, and success stories.
- [ ] **Market your GitHub Copilot community internally** - Promote the new community within your organization. Invite your developers to explore, participate, and engage with the content and discussions. Highlight the benefits of GitHub Copilot and the value of being part of this community.

### Invite additional teams

- [ ] Design a team priority rollout plan
- [ ] Add additional teams based on the rollout plan

## Phase 3 - Enterprise-wide

- [ ] Mandate Usage from Executive Leadership using success stories gathered from advocates, the internal community, and metrics gathered if implemented
- [ ] Add remaining teams via IDP group

## Appendix

### Word-of-mouth evangelism

- Organize training sessions to demonstrate GitHub Copilot’s features and benefits.
- [Conduct hands-on / hackathon to let people feel the latest AI coding](https://github.com/users/samqbush/projects/2/views/1?pane=issue&itemId=98034156)

### Phase 4 - Maintain & Improve

- Analyze usage data to pinpoint patterns that suggest underutilization
- Conduct a survey to identify the gaps in knowledge or barriers to effective GitHub Copilot use
- Organize focus groups with developers to discuss challenges and solicit suggestions
- Formulate a plan to address identified issues and improve enablement resources
  - [Remind inactive users](https://docs.github.com/en/copilot/rolling-out-github-copilot-at-scale/reminding-inactive-users)

### Additional Reading

- [Taking GitHub Copilot to the stars, not just the skies](https://resources.github.com/artificial-intelligence/scaling-github-copilot-across-your-organization/) - a detailed whitepaper on GitHub & Accenture's rollouts of Copilot with implementation advice
- [Advice on Driving Adoption](https://docs.github.com/en/copilot/rolling-out-github-copilot-at-scale/driving-copilot-adoption-in-your-company) - GitHub official documentation on adoption
- GitHub Copilot Adoption Blueprint - ask your Customer Success Manager for a company specific GitHub Project.  If you prefer to export this project's issues, you can run the [plan export](./plan-export.sh) script
- [GitHub Learning Pathways](https://resources.github.com/learn/pathways/copilot/essentials/essentials-of-github-copilot/)

### [Requesting Access to Copilot](https://docs.github.com/en/enterprise-cloud@latest/copilot/rolling-out-github-copilot-at-scale/setting-up-a-self-serve-process-for-github-copilot-licenses#approach-1-use-githubs-request-access-feature)

While this method will slow down your adoption rate of Copilot, it can be [automated](https://docs.github.com/en/enterprise-cloud@latest/copilot/rolling-out-github-copilot-at-scale/setting-up-a-self-serve-process-for-github-copilot-licenses#example-implementations) if this approach is required due to regulation requirements such as self attestation.
