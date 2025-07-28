---
layout: default
title: Training by Feature
description: This matrix provides a curated list of GitHub Copilot features, their recommended documentation, training resources, and GA dates. Enterprise-only features are marked with an asterisk (*)
---

<style>
  /* Table container to allow wider table than parent container */
  .table-container {
    width: 100%;
    max-width: 100%;
    overflow-x: auto;
    margin-bottom: 1rem;
  }
  
  .sortable {
    border-collapse: collapse;
    width: 100%;
    min-width: 1100px; /* Ensures table has a minimum width */
    table-layout: fixed; /* Ensures consistent column widths */
  }
  .sortable th, .sortable td {
    padding: 12px; /* Increased padding for better spacing */
    text-align: left;
    border: 1px solid #ddd; /* Added border for better separation */
    overflow-wrap: break-word;
    word-wrap: break-word;
    hyphens: auto;
  }
  .sortable th {
    cursor: pointer;
    background-color: #f9f9f9; /* Lighter background for headers */
    position: sticky; /* Keeps headers visible when scrolling */
    top: 0;
    z-index: 1;
    text-align: left; /* Ensures proper alignment */
    padding-right: 25px; /* Add space for sort icon */
    position: relative; /* For positioning the icon */
  }
  .sortable th:hover {
    background-color: #e2e2e2;
    color: #0078d4; /* Highlight color for better visibility */
  }
  
  /* Add clear sort icons that indicate sortability */
  .sortable th::after {
    content: "↕";
    position: absolute;
    right: 8px;
    color: #999;
    font-size: 0.85em;
  }
  
  /* Change icon based on sort state */
  .sortable th.asc::after {
    content: "↑";
    color: #0078d4;
  }
  .sortable th.desc::after {
    content: "↓";
    color: #0078d4;
  }
  
  /* Additional visual cue on hover */
  .sortable th:hover::after {
    color: #0078d4;
  }
  
  .sortable td {
    white-space: normal;
  }
  
  /* Adjusted column widths for GitHub.com table only */
  #githubTable.sortable th:nth-child(1), #githubTable.sortable td:nth-child(1) { width: 18%; }  /* Feature */
  #githubTable.sortable th:nth-child(2), #githubTable.sortable td:nth-child(2) { width: 10%; }  /* Release Stage */
  #githubTable.sortable th:nth-child(3), #githubTable.sortable td:nth-child(3) { width: 12%; }  /* GA Date */
  #githubTable.sortable th:nth-child(4), #githubTable.sortable td:nth-child(4) { width: 22%; }  /* Video */
  #githubTable.sortable th:nth-child(5), #githubTable.sortable td:nth-child(5) { width: 24%; }  /* Policy Toggle */
  
  /* Special handling for GA Date column */
  .sortable td:nth-child(3), .sortable th:nth-child(3) {
    text-align: center; /* Center-align dates for better readability */
  }
  
  /* IDE Matrix table specific column widths */
  #ideMatrix th:nth-child(1), #ideMatrix td:nth-child(1) { width: 20%; }  /* Feature */
  #ideMatrix th:nth-child(2), #ideMatrix td:nth-child(2) { width: 9%; }   /* VS Code */
  #ideMatrix th:nth-child(3), #ideMatrix td:nth-child(3) { width: 9%; }   /* Visual Studio */
  #ideMatrix th:nth-child(4), #ideMatrix td:nth-child(4) { width: 9%; }   /* JetBrains */
  #ideMatrix th:nth-child(5), #ideMatrix td:nth-child(5) { width: 8%; }   /* Xcode */
  #ideMatrix th:nth-child(6), #ideMatrix td:nth-child(6) { width: 8%; }   /* Eclipse */
  #ideMatrix th:nth-child(7), #ideMatrix td:nth-child(7) { width: 10%; }  /* Other */
  #ideMatrix th:nth-child(8), #ideMatrix td:nth-child(8) { width: 15%; }  /* Video */
  
  /* Cell styling for IDE Matrix table */
  #ideMatrix td {
    padding: 8px; /* Smaller padding for IDE table cells */
    text-align: center;
  }
  
  #ideMatrix td:first-child {
    text-align: left; /* Keep feature names left-aligned */
  }
  
  #ideMatrix th {
    text-align: center;
    padding: 10px 5px;
  }
  
  #ideMatrix th:first-child {
    text-align: left; /* Keep feature header left-aligned */
  }
  
  .sortable tr:hover {
    background-color: #f1f1f1; /* Subtle hover effect for rows */
  }
  
  /* For better link display */
  .sortable td a {
    word-break: break-word;
    color: #0078d4; /* Consistent link color */
    text-decoration: none;
  }
  .sortable td a:hover {
    text-decoration: underline;
  }

  /* Add a note above the table about sorting */
  .sort-note {
    margin-bottom: 10px;
    font-style: italic;
    color: #555;
  }
  
  /* Make page container wider if theme supports it */
  .main-content {
    max-width: 96% !important;
  }
  
  /* Media query for responsive behavior */
  @media screen and (max-width: 1200px) {
    .table-container {
      overflow-x: scroll;
    }
  }
</style>

<p class="sort-note">Click on any column header to sort the table. Click again to reverse the sort order.</p>

<h2>GitHub.com Features</h2>
<div class="table-container">
<table id="githubTable" class="sortable">
  <thead>
    <tr>
      <th>Feature</th>
      <th>Release Stage</th>
      <th>Release Date</th>
      <th>Video</th>
      <th><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-policies-and-features-for-copilot-in-your-enterprise">Policy Toggle</a></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github#powered-by-skills">Bing/Web Search</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-02-14-personal-custom-instructions-bing-web-search-and-more-in-copilot-on-github-com/#search-the-web-%f0%9f%94%8d-in-copilot-chat-using-bing">Feb 14, 2025</a></td>
      <td></td>
      <td>Copilot can search the web</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/finding-public-code-that-matches-github-copilot-suggestions">Block/Reference suggestions in public code</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/news-insights/product-news/code-referencing-now-generally-available-in-github-copilot-and-with-microsoft-azure-ai/">September 30, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=8SOh3A9LEeE">TechRill - GitHub Copilot Code Referencing</a></td>
      <td>Suggestions matching public code (duplication detection filter)</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review">Code review</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-copilot-code-review-now-generally-available/">April 4, 2025</a></td>
      <td><a href="https://youtu.be/cyPaAkRfEBQ">GitHub Copilot code review</a></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review#customizing-copilots-reviews-with-custom-instructions-1">Code Review Customization via Instructions</a></td>
      <td>Preview</td>
      <td><a href="https://github.blog/changelog/2025-07-18-upcoming-deprecations-and-changes-to-copilot-code-review/">August 1, 2025</a></td>
      <td></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github">Immersive Chat</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-12-18-copilot-chat-on-github-is-now-generally-available-for-all-users">December 18, 2024</a></td>
      <td></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/indexing-repositories-for-copilot-chat">Instant Semantic Indexing</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-03-12-instant-semantic-code-search-indexing-now-generally-available-for-github-copilot/">May 12, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=MqBBEgpYh0Y">Using your repository for RAG: Learnings from GitHub Copilot Chat</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/managing-copilot-knowledge-bases">Knowledge Bases</a> *</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-02-27-copilot-enterprise-is-now-generally-available/">February 27, 2024</a></td>
      <td><a href="https://youtu.be/vUX5u_4B2AM?feature=shared&t=370">Say hello to GitHub Copilot Enterprise!</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/building-copilot-extensions/about-building-copilot-extensions">Marketplace Extensions</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-02-19-announcing-the-general-availability-of-github-copilot-extensions">February 19, 2025</a></td>
      <td><a href="https://youtu.be/ky5TMI9skLE?feature=shared">GitHub Copilot Extensions : Build Your First Extension</a></td>
      <td>Copilot Extensions</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics?apiVersion=2022-11-28">Metrics API</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-10-30-github-copilot-metrics-api-ga-release-now-available">October 30, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=43yFNFT8-R4">GitHub Copilot Features - Metrics API</a></td>
      <td>Copilot Metrics API access</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/ai-models/changing-the-ai-model-for-copilot-chat">Model picker</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=d1nyiOPBO04">Configuring and Using Multiple AI Models with GitHub Copilot</a></td>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-policies-and-features-for-copilot-in-your-enterprise#copilot-access-to-alternative-ai-models">Access to alternative models</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/github-models/prototyping-with-ai-models">Model Playground</a></td>
      <td>Preview</td>
      <td><a href="https://github.blog/changelog/2024-10-29-github-models-is-now-available-in-public-preview/">October 29, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=OCNvxcMfunA">GitHub Models: Your AI exploration playground</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/about-github-copilot/github-copilot-features#policy-management">Organization-wide policy management</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/news-insights/product-news/github-copilot-is-generally-available-for-businesses/">December 7, 2022</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/using-github-copilot-for-pull-requests/creating-a-pull-request-summary-with-github-copilot">Pull request summaries</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-07-31-github-copilot-chat-and-pull-request-summaries-are-now-powered-by-gpt-4o/">July 31, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=BVX074EMnds">Copilot Pull Request Summaries</a></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot">Repository Custom instructions</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-03-06-github-copilot-updates-in-visual-studio-code-february-release-v0-25-including-improvements-to-agent-mode-and-next-exit-suggestions-ga-of-custom-instructions-and-more/#custom-instructions-generally-available">March 6, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=cu9zZAFmoDg&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=41&pp=iAQB">Using Custom Instructions with Copilot to enhance our prompts</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/adding-organization-custom-instructions-for-github-copilot">Organization Custom Instructions</a> *</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-17-organization-custom-instructions-now-available/">April 17, 2025</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/coding-agent">Copilot Coding Agent</a></td>
      <td>Preview</td>
      <td><a href="https://github.blog/changelog/2025-06-24-github-copilot-coding-agent-is-now-available-for-copilot-business-users/">May 19, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=EPyyyB23NUU">GitHub Copilot Coding Agent Overview</a></td>
      <td>Copilot coding agent access <br>
      Block Copilot coding agent in all enterprise repositories</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/managing-copilot/understanding-and-managing-copilot-usage/understanding-and-managing-requests-in-copilot">Premium Requests</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-06-18-update-to-github-copilot-consumptive-billing-experience/">June 18, 2025</a></td>
      <td></td>
      <td>Additional Copilot premium requests</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/reference/metrics-data#copilot-activity-report">Activity Report</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-07-18-new-github-copilot-activity-report-with-enhanced-authentication-and-usage-insights/">July 17, 2025</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/copilot-spaces/about-organizing-and-sharing-context-with-copilot-spaces">Copilot Spaces</a></td>
      <td>Preview</td>
      <td><a href="https://github.blog/changelog/2025-05-29-introducing-copilot-spaces-a-new-way-to-work-with-code-and-context/">May 29, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=a0LWEWLUt48">What is GitHub Copilot Spaces? Centralize your project’s context</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/configuring-and-auditing-content-exclusion/excluding-content-from-github-copilot">Content Exclusions</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-11-12-content-exclusion-ga/">November 12, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=J2qaVAaQzY8">GitHub Copilot Features - Content exclusions</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-github-copilot-in-your-organization/reviewing-activity-related-to-github-copilot-in-your-organization/reviewing-audit-logs-for-copilot-business">Audit logs</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2023-09-07-github-copilot-september-7th-update/#%f0%9f%aa%b5-review-copilot-updates-with-audit-log-integration">September 7, 2023</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github-mobile">Mobile</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/news-insights/product-news/github-copilot-chat-in-github-mobile/">May 7, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=EQH-V5jQ0aA">Copilot features - videos - GitHub Mobile</a></td>
      <td>Copilot Chat in GitHub Mobile</td>
    </tr>
      <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line">GitHub CLI</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-03-21-github-copilot-general-availability-in-the-cli/">March 21, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=fHwtrOcLAnI">GitHub Copilot in the CLI</a></td>
      <td>Copilot in the CLI</td>
    </tr>
      <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/asking-github-copilot-questions-in-windows-terminal">Windows Terminal</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-10-29-github-copilot-is-now-available-in-windows-terminal/">October 29, 2024</a></td>
      <td><a href="https://youtu.be/rwKfazgCw9E?feature=shared">Windows Terminal now has GitHub Copilot!?</a></td>
      <td>Copilot in the CLI</td>
    </tr>
  </tbody>
</table>
</div>

<h2>IDE Features</h2>
<div class="table-container">
<table id="ideMatrix" class="sortable">
  <thead>
    <tr>
      <th>Feature</th>
      <th>VS Code</th>
      <th>Visual Studio</th>
      <th>JetBrains</th>
      <th>Xcode</th>
      <th>Eclipse</th>
      <th>NeoVim</th>
      <th>Video</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#using-agent-mode">Agent mode</a></td>
      <td><a href="https://github.blog/changelog/2025-04-03-github-copilot-in-vs-code-march-release-v1-99/#agent-mode-is-now-available-in-vs-code-stable">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-06-17-visual-studio-17-14-june-release/">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-07-16-agent-mode-for-jetbrains-eclipse-and-xcode-is-now-generally-available/">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-07-16-agent-mode-for-jetbrains-eclipse-and-xcode-is-now-generally-available/">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-07-16-agent-mode-for-jetbrains-eclipse-and-xcode-is-now-generally-available/">GA</a></td>
      <td></td>
      <td><a href="https://www.youtube.com/watch?v=sYepbevm8TY&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=2&pp=iAQB0gcJCTgDd0p55Nqk">Use GitHub Copilot agent mode to create an application from scratch</a></td>
    </tr>
    <tr>
      <td><a href="https://code.visualstudio.com/docs/copilot/language-models#_bring-your-own-language-model-key">Bring your own language model key</a></td>
      <td><a href="https://code.visualstudio.com/docs/copilot/language-models#_bring-your-own-language-model-key">Preview</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
    </tr>
    <tr>
      <td><a href="https://code.visualstudio.com/api/extension-guides/chat">Chat skills/participants</a></td>
      <td><a href="https://code.visualstudio.com/updates/v1_95">GA</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td><a href="https://www.youtube.com/watch?v=OdW2r3raAHI">Building your own GitHub Copilot chat participant in VS Code</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/github-copilot-chat-cheat-sheet?tool=vscode">Chat Context Variables</a></td>
      <td><a href="https://github.blog/changelog/2024-02-12-vs-code-copilot-chat-january-2024-version-0-12/#context-variables">GA</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td><a href="https://youtu.be/N62d9PgiqoY">More Context == Better GitHub Copilot Responses in Visual Studio</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide">Copilot Chat</a></td>
      <td><a href="https://github.blog/news-insights/product-news/github-copilot-chat-now-generally-available-for-organizations-and-individuals/">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-04-15-github-copilot-chat-for-eclipse-is-now-generally-available/">GA</a></td>
      <td><a href="https://github.blog/changelog/2024-03-07-github-copilot-chat-general-availability-in-jetbrains-ide">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-03-11-github-copilot-for-xcode-chat-is-now-generally-available/">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-04-15-github-copilot-chat-for-eclipse-is-now-generally-available/">GA</a></td>
      <td>GA</td>
      <td><a href="https://www.youtube.com/watch?v=P3Q5wa0mI_0&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=58&pp=iAQB">Copilot Chat - Power User</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/getting-code-suggestions-in-your-ide-with-github-copilot">Copilot Code Completion</a></td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-02-14-code-completion-in-github-copilot-for-xcode-is-now-generally-available">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-03-11-code-completion-in-github-copilot-for-eclipse-is-now-generally-available">GA</a></td>
      <td>GA</td>
      <td><a href="https://www.youtube.com/watch?v=EsRPYoXY9IA&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=57&pp=iAQB">Rewriting your Java code with Copilot-based suggestions in VS Code</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#copilot-edits">Copilot Edits</a></td>
      <td><a href="https://code.visualstudio.com/updates/v1_97#_copilot-edits-general-availability">GA</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-28-copilot-edits-for-jetbrains-ides-is-generally-available/">GA</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td><a href="https://youtu.be/NvWl-bZTDKw">The all NEW GitHub Copilot Experience</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/copilot-chat-cookbook/documenting-code">Document & Explain Code</a></td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td><a href="https://youtu.be/fm4JCyXbWPo?feature=shared">Using GitHub Copilot to write documentation for you!</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/copilot-chat-cookbook/testing-code/generate-unit-tests">Generate Unit Tests</a></td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td><a href="https://github.blog/ai-and-ml/github-copilot/how-to-generate-unit-tests-with-github-copilot-tips-and-examples/">How to generate unit tests with GitHub Copilot: Tips and examples</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#additional-ways-to-access-copilot-chat">Inline Chat</a></td>
      <td><a href="https://github.blog/changelog/2024-02-12-vs-code-copilot-chat-january-2024-version-0-12/">GA</a></td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-09-11-inline-chat-is-now-available-in-github-copilot-in-jetbrains">GA</a></td>
      <td>GA</td>
      <td>GA</td>
      <td>GA</td>
      <td></td>
    </tr>
    <tr>
      <td><a href="https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp">MCP servers in IDEs</a></td>
      <td><a href="https://github.blog/changelog/2025-07-14-model-context-protocol-mcp-support-in-vs-code-is-generally-available/">GA</a></td>
      <td><a href="https://github.blog/changelog/2025-06-17-visual-studio-17-14-june-release/">Preview</a></td>
      <td><a href="https://github.blog/changelog/2025-05-19-agent-mode-and-mcp-support-for-copilot-in-jetbrains-eclipse-and-xcode-now-in-public-preview/">Preview</a></td>
      <td><a href="https://github.blog/changelog/2025-05-19-agent-mode-and-mcp-support-for-copilot-in-jetbrains-eclipse-and-xcode-now-in-public-preview/">Preview</a></td>
      <td><a href="https://github.blog/changelog/2025-05-19-agent-mode-and-mcp-support-for-copilot-in-jetbrains-eclipse-and-xcode-now-in-public-preview/">Preview</a></td>
      <td></td>
      <td><a href="https://www.youtube.com/watch?v=Coot4TFTkN4">MCP Servers in VS Code</a></td>
    </tr>
    <tr>
      <td><a href="https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp">Remote MCP Authentication in IDEs</a></td>
      <td><a href="https://github.blog/changelog/2025-06-13-github-copilot-in-vs-code-may-release-v1-101/">Preview</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td><a href="https://www.youtube.com/watch?v=PdQWgF4oV7Q">The Download: Remote GitHub MCP Server</a></td>
    </tr>
    <tr>
      <td><a href="https://code.visualstudio.com/docs/copilot/copilot-customization#_prompt-files-experimental">Prompt Files</a></td>
      <td><a href="https://code.visualstudio.com/updates/v1_100">Experimental</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
    </tr>
    <tr>
      <td><a href="https://learn.microsoft.com/en-us/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java-quickstart-assess-migrate">Copilot App Modernization for Java</a></td>
      <td><a href="https://github.blog/changelog/2025-05-19-github-copilot-app-modernization-for-java-now-in-public-preview/">Preview</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td><a href="https://www.youtube.com/watch?v=TBS2sv-e80o">Java App Modernization Simplified with AI | BRK131</a></td>
    </tr>
    <tr>
      <td><a href="https://devblogs.microsoft.com/dotnet/github-copilot-upgrade-dotnet/">Copilot App Modernization for .NET</a></td>
      <td></td>
      <td><a href="https://github.blog/changelog/2025-05-19-github-copilot-app-modernization-upgrade-for-net-now-in-public-preview/">Preview</a></td>
      <td></td>
      <td></td>
      <td></td>
      <td></td>
      <td><a href="https://www.youtube.com/watch?v=3NFWcHrsba0">Using agentic AI to simplify .NET upgrades with GitHub Copilot | DEM549</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#using-images-in-copilot-chat">Images in Chat</a></td>
      <td>Preview</td>
      <td>Preview</td>
      <td>Preview</td>
      <td>Preview</td>
      <td>Preview</td>
      <td>Preview</td>
      <td><a href="https://www.youtube.com/watch?v=pEEw7BvaK50">Copilot Vision is HERE! Watch It Turn Images into Code!</a></td>
    </tr>
        <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/getting-code-suggestions-in-your-ide-with-github-copilot#about-next-edit-suggestions">Next Edit Suggestions</a></td>
      <td><a href="https://github.blog/changelog/2025-04-03-github-copilot-in-vs-code-march-release-v1-99/#ux-improvements-help-you-work-faster-and-stay-focused">GA</a></td>
      <td><a href="https://learn.microsoft.com/en-us/visualstudio/ide/copilot-next-edit-suggestions?view=vs-2022">GA</a></td>
      <td>Preview</td>
      <td>Preview</td>
      <td>Preview</td>
      <td>Preview</td>
      <td><a href="https://www.youtube.com/watch?v=zPUvU6XYhpw&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=6&pp=iAQB">Next Edit Suggestions for GitHub Copilot in action</a></td>
    </tr>
  </tbody>
</table>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
  // Get the table element
  const githubTable = document.getElementById('githubTable');
  const ideTable = document.getElementById('ideMatrix');
  const githubHeaders = githubTable.querySelectorAll('th');
  const ideHeaders = ideTable.querySelectorAll('th');
  const githubTableBody = githubTable.querySelector('tbody');
  const ideTableBody = ideTable.querySelector('tbody');
  const githubRows = Array.from(githubTableBody.querySelectorAll('tr'));
  const ideRows = Array.from(ideTableBody.querySelectorAll('tr'));
  
  // Direction tracking variables
  let currentGithubColumn = -1;
  let currentGithubDirection = 'asc';
  let currentIdeColumn = -1;
  let currentIdeDirection = 'asc';
  
  // Function to clean and transform cell content for sorting
  function getCellValue(row, index, isGithubTable) {
    const cell = row.querySelector(`td:nth-child(${index + 1})`);
    let text = cell.textContent.trim().toLowerCase();

    // For GitHub.com table, Release Date is now index 2
    if ((isGithubTable && index === 2) || (!isGithubTable && index === 3)) {
      // If the cell contains a link, get the link text
      const link = cell.querySelector('a');
      if (link) text = link.textContent.trim().toLowerCase();
      // If the text is a valid date, return its timestamp
      if (text.match(/\d{4}|january|february|march|april|may|june|july|august|september|october|november|december/)) {
        const dateObj = new Date(text);
        if (!isNaN(dateObj)) return dateObj.getTime();
      }
      // Otherwise, treat as -Infinity so it sorts to the bottom in descending order
      return -Infinity;
    }
    if (!isNaN(text) && text !== '') {
      return Number(text);
    }
    return text;
  }

  // Function for comparing values
  function compareValues(v1, v2) {
    return v1 === v2 ? 0 : 
           v1 === Infinity ? 1 : 
           v2 === Infinity ? -1 : 
           v1 > v2 ? 1 : -1;
  }

  // Sort function
  function sortTable(tableType, index, direction) {
    let headers, rows, tableBody, isGithubTable;
    
    if (tableType === 'github') {
      headers = githubHeaders;
      rows = githubRows;
      tableBody = githubTableBody;
      isGithubTable = true;
    } else {
      headers = ideHeaders;
      rows = ideRows;
      tableBody = ideTableBody;
      isGithubTable = false;
    }
    
    // Remove classes from all headers
    headers.forEach(header => {
      header.classList.remove('asc', 'desc');
    });
    
    // Add class to the current header
    headers[index].classList.add(direction);
    
    // Sort the rows
    const sortedRows = rows.sort((a, b) => {
      const aValue = getCellValue(a, index, isGithubTable);
      const bValue = getCellValue(b, index, isGithubTable);
      
      return direction === 'asc' ? 
        compareValues(aValue, bValue) : 
        compareValues(bValue, aValue);
    });
    
    // Remove all rows from the table
    while (tableBody.firstChild) {
      tableBody.removeChild(tableBody.firstChild);
    }
    
    // Re-add rows in the sorted order
    sortedRows.forEach(row => {
      tableBody.appendChild(row);
    });
    
    // Update tracking variables
    if (tableType === 'github') {
      currentGithubColumn = index;
      currentGithubDirection = direction;
    } else {
      currentIdeColumn = index;
      currentIdeDirection = direction;
    }
  }

  // Add click event to each header
  githubHeaders.forEach((header, index) => {
    header.addEventListener('click', function() {
      // Determine sorting direction
      const direction = index === currentGithubColumn && currentGithubDirection === 'asc' ? 'desc' : 'asc';
      sortTable('github', index, direction);
    });

    // Add tabindex for accessibility
    header.setAttribute('tabindex', '0');

    // Add keyboard support
    header.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        header.click();
      }
    });
  });
  
  ideHeaders.forEach((header, index) => {
    header.addEventListener('click', function() {
      // Determine sorting direction
      const direction = index === currentIdeColumn && currentIdeDirection === 'asc' ? 'desc' : 'asc';
      sortTable('ide', index, direction);
    });
    
    // Add tabindex for accessibility
    header.setAttribute('tabindex', '0');
    
    // Add keyboard support
    header.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        header.click();
      }
    });
  });
  
  // Sort GitHub table by date (column 2, index 2) descending by default
  sortTable('github', 2, 'desc');
  // Sort IDE table by feature column (column 0, index 0) ascending by default
  sortTable('ide', 0, 'asc');
});
</script>

<br>
<br>

Official Feature Lists:

- [GitHub Copilot Features](https://github.com/features/copilot)
- [GitHub Copilot Documentation](https://docs.github.com/en/enterprise-cloud@latest/copilot/about-github-copilot/github-copilot-features)