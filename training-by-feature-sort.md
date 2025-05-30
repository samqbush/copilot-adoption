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
  
  /* Adjusted column widths */
  .sortable th:nth-child(1), .sortable td:nth-child(1) { width: 18%; }  /* Feature */
  .sortable th:nth-child(2), .sortable td:nth-child(2) { width: 14%; }  /* IDEs */
  .sortable th:nth-child(3), .sortable td:nth-child(3) { width: 10%; }  /* Release Stage */
  .sortable th:nth-child(4), .sortable td:nth-child(4) { width: 12%; }  /* GA Date */
  .sortable th:nth-child(5), .sortable td:nth-child(5) { width: 22%; }  /* Video */
  .sortable th:nth-child(6), .sortable td:nth-child(6) { width: 24%; }  /* Policy Toggle */
  
  /* Special handling for GA Date column */
  .sortable td:nth-child(4), .sortable th:nth-child(4) {
    text-align: center; /* Center-align dates for better readability */
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

<div class="table-container">
<table id="featureTable" class="sortable">
  <thead>
    <tr>
      <th>Feature</th>
      <th>IDEs</th>
      <th>Release Stage</th>
      <th>Release Date</th>
      <th>Video</th>
      <th><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-policies-and-features-for-copilot-in-your-enterprise">Policy Toggle</a></th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#using-agent-mode">Agent mode in the IDE</a></td>
      <td>VS Code, <a href="https://github.blog/changelog/2025-05-13-agent-mode-mcp-and-next-edit-suggestions-come-to-github-copilot-in-visual-studio-17-14/">Visual Studio</a></td>
      <td>GA/Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-04-03-github-copilot-in-vs-code-march-release-v1-99/#agent-mode-is-now-available-in-vs-code-stable">April 4, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=sYepbevm8TY&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=2&pp=iAQB0gcJCTgDd0p55Nqk">Use GitHub Copilot agent mode to create an application from scratch</a></td>
      <td></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-github-copilot-in-your-organization/reviewing-activity-related-to-github-copilot-in-your-organization/reviewing-audit-logs-for-copilot-business">Audit logs</a></td>
      <td>All IDEs</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2023-09-07-github-copilot-september-7th-update/#%f0%9f%aa%b5-review-copilot-updates-with-audit-log-integration">September 7, 2023</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github#powered-by-skills">Bing/Web Search</a></td>
      <td>GitHub.com, VS Code, Visual Studio</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-02-14-personal-custom-instructions-bing-web-search-and-more-in-copilot-on-github-com/#search-the-web-%f0%9f%94%8d-in-copilot-chat-using-bing">Feb 14, 2025</a></td>
      <td></td>
      <td>Copilot can search the web</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/finding-public-code-that-matches-github-copilot-suggestions">Block/Reference suggestions in public code</a></td>
      <td>GitHub.com, VS Code, Visual Studio, Neovim, Xcode, Mobile, JetBrains</td>
      <td>GA</td>
      <td><a href="https://github.blog/news-insights/product-news/code-referencing-now-generally-available-in-github-copilot-and-with-microsoft-azure-ai/">September 30, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=8SOh3A9LEeE">TechRill - GitHub Copilot Code Referencing</a></td>
      <td>Suggestions matching public code (duplication detection filter)</td>
    </tr>
    <tr>
      <td><a href="https://code.visualstudio.com/docs/copilot/language-models#_bring-your-own-language-model-key">Bring your own language model key</a></td>
      <td>VS Code</td>
      <td>Public Preview - Free & Pro user only</td>
      <td>TBD</td>
      <td></td>
      <td></td>
    </tr>
    <tr>
      <td><a href="https://code.visualstudio.com/api/extension-guides/chat">Chat skills/participants in VS Code</a></td>
      <td>VS Code</td>
      <td>GA</td>
      <td><a href="https://code.visualstudio.com/updates/v1_95">October 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=OdW2r3raAHI">Building your own GitHub Copilot chat participant in VS Code</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line">GitHub CLI</a></td>
      <td>GitHub CLI</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-03-21-github-copilot-general-availability-in-the-cli/">March 21, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=fHwtrOcLAnI">GitHub Copilot in the CLI</a></td>
      <td>Copilot in the CLI</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/code-review/using-copilot-code-review">Code review</a></td>
      <td>GitHub.com, VS Code</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-copilot-code-review-now-generally-available/">April 4, 2025</a></td>
      <td><a href="https://youtu.be/cyPaAkRfEBQ">GitHub Copilot code review</a></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/code-review/configuring-coding-guidelines">Coding guidelines</a> *</td>
      <td>GitHub.com</td>
      <td>Public Preview</td>
      <td>TBD</td>
      <td><a href="https://www.youtube.com/live/m217SuEWFUc?feature=shared&t=1810">Deep Dive into Copilot Code Review</a></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/configuring-and-auditing-content-exclusion/excluding-content-from-github-copilot">Content Exclusions</a></td>
      <td>All IDEs</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-11-12-content-exclusion-ga/">November 12, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=J2qaVAaQzY8">GitHub Copilot Features - Content exclusions</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/github-copilot-chat-cheat-sheet?tool=vscode">Chat Context Variables</a></td>
      <td>VS Code, Jet Brains</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-02-12-vs-code-copilot-chat-january-2024-version-0-12/#context-variables">January 2024</a></td>
      <td><a href="https://youtu.be/N62d9PgiqoY">More Context == Better GitHub Copilot Responses in Visual Studio</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide">Copilot Chat</a></td>
      <td><a href="https://github.blog/news-insights/product-news/github-copilot-chat-now-generally-available-for-organizations-and-individuals/">VS Code & Visual Studio</a>, <a href="https://github.blog/changelog/2024-03-07-github-copilot-chat-general-availability-in-jetbrains-ide">JetBrains</a>, <a href="https://github.blog/changelog/2025-03-11-github-copilot-for-xcode-chat-is-now-generally-available/">Xcode</a>, <a href="https://github.blog/changelog/2025-04-15-github-copilot-chat-for-eclipse-is-now-generally-available/">Eclipse</a></td>    <td>GA</td>
      <td>See IDE links</td>
      <td><a href="https://www.youtube.com/watch?v=P3Q5wa0mI_0&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=58&pp=iAQB">Copilot Chat - Power User</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/getting-code-suggestions-in-your-ide-with-github-copilot">Copilot Code Completion</a></td>
      <td>VS Code, JetBrains, Visual Studio, <a href="https://github.blog/changelog/2025-02-14-code-completion-in-github-copilot-for-xcode-is-now-generally-available">Xcode</a>, <a href="https://github.blog/changelog/2025-03-11-code-completion-in-github-copilot-for-eclipse-is-now-generally-available">Eclipse</a>, Neovim</td>
      <td>GA</td>
      <td>See IDE links</td>
      <td><a href="https://www.youtube.com/watch?v=EsRPYoXY9IA&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=57&pp=iAQB">Rewriting your Java code with Copilot-based suggestions in VS Code</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#copilot-edits">Copilot Edits</a></td>
      <td><a href="https://code.visualstudio.com/updates/v1_97#_copilot-edits-general-availability">VS Code</a>, Visual Studio, <a href="https://github.blog/changelog/2025-04-28-copilot-edits-for-jetbrains-ides-is-generally-available/">JetBrains</a></td>
      <td>GA</td>
      <td>See IDE links</td>
      <td><a href="https://youtu.be/NvWl-bZTDKw">The all NEW GitHub Copilot Experience</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/copilot-chat-cookbook/documenting-code">Document & Explain Code</a></td>
      <td>VS Code, Visual Studio, JetBrains, Xcode, Eclipse</td>
      <td>GA</td>
      <td>See Copilot Chat IDE Links</td>
      <td><a href="https://youtu.be/fm4JCyXbWPo?feature=shared">Using GitHub Copilot to write documentation for you!</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/creating-a-custom-model-for-github-copilot">Fine Tuning & Custom Models</a> *</td>
      <td>All IDEs</td>
      <td>Private Preview</td>
      <td>TBD</td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/copilot-chat-cookbook/testing-code/generate-unit-tests">Generate Unit Tests</a></td>
      <td>VS Code, Visual Studio, JetBrains, Xcode, Eclipse</td>
      <td>GA</td>
      <td>See Copilot Chat IDE links</td>
      <td><a href="https://github.blog/ai-and-ml/github-copilot/how-to-generate-unit-tests-with-github-copilot-tips-and-examples/">How to generate unit tests with GitHub Copilot: Tips and examples</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github">Immersive Chat</a></td>
      <td>GitHub.com, @github skill in IDEs</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-12-18-copilot-chat-on-github-is-now-generally-available-for-all-users">December 18, 2024</a></td>
      <td></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/indexing-repositories-for-copilot-chat">Indexing Repositories</a></td>
      <td>Code in GitHub.com</td>
      <td>GA</td>
      <td>See Copilot Chat IDE links</td>
      <td><a href="https://www.youtube.com/watch?v=MqBBEgpYh0Y">Using your repository for RAG: Learnings from GitHub Copilot Chat</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#additional-ways-to-access-copilot-chat">Inline Chat</a></td>
      <td><a href="https://github.blog/changelog/2024-02-12-vs-code-copilot-chat-january-2024-version-0-12/">VS Code</a>, Visual Studio, <a href="https://github.blog/changelog/2024-09-11-inline-chat-is-now-available-in-github-copilot-in-jetbrains">JetBrains</a></td>
      <td>GA</td>
      <td>See IDE links</td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://devblogs.microsoft.com/java/technical-preview-github-copilot-upgrade-assistant-for-java/">Java Upgrade Assistant</a></td>
      <td>VS Code</td>
      <td>Private Preview</td>
      <td>TBD</td>
      <td><a href="https://www.youtube.com/watch?v=TRPKspCqN78">GitHub Copilot Upgrade Assistant for Java: Try It First!</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/managing-copilot-knowledge-bases">Knowledge Bases</a> *</td>
      <td>VS Code, GitHub.com, Visual Studio</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-02-27-copilot-enterprise-is-now-generally-available/">February 27, 2024</a></td>
      <td><a href="https://youtu.be/vUX5u_4B2AM?feature=shared&t=370">Say hello to GitHub Copilot Enterprise!</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/building-copilot-extensions/about-building-copilot-extensions">Marketplace Extensions</a></td>
      <td>Visual Studio, VS Code, GitHub.com, JetBrains, Mobile</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-02-19-announcing-the-general-availability-of-github-copilot-extensions">February 19, 2025</a></td>
      <td><a href="https://youtu.be/ky5TMI9skLE?feature=shared">GitHub Copilot Extensions : Build Your First Extension</a></td>
      <td>Copilot Extensions</td>
    </tr>
    <tr>
      <td><a href="https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp">MCP servers</a></td>
      <td>VS Code, <a href="https://github.blog/changelog/2025-05-13-agent-mode-mcp-and-next-edit-suggestions-come-to-github-copilot-in-visual-studio-17-14/">Visual Studio</a>, <a href="https://github.blog/changelog/2025-05-19-agent-mode-and-mcp-support-for-copilot-in-jetbrains-eclipse-and-xcode-now-in-public-preview/">Jetbrains, Eclipse, Xcode</a></td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-04-04-github-mcp-server-public-preview/">April 4, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=WySJOAlVpQ0">Tug on Dev! - GitHub Copilot Agent Mode with MCP</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/rest/copilot/copilot-metrics?apiVersion=2022-11-28">Metrics API</a></td>
      <td>N/A</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-10-30-github-copilot-metrics-api-ga-release-now-available">October 30, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=43yFNFT8-R4">GitHub Copilot Features - Metrics API</a></td>
      <td>Copilot Metrics API access</td>
    </tr>
    <tr>
      <td>User Engagement API</td>
      <td>N/A</td>
      <td>Private Preview</td>
      <td>TBD</td>
      <td></td>
      <td>TBD</td>
    </tr>
    <tr>
      <td>Direct Data Access</td>
      <td>N/A</td>
      <td>Private Preview</td>
      <td>TBD</td>
      <td></td>
      <td>TBD</td>
    </tr>
    <tr>
      <td>GitHub-native Dashboard</td>
      <td>GitHub.com</td>
      <td>Private Preview</td>
      <td>TBD</td>
      <td></td>
      <td>TBD</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-github-mobile">Mobile</a></td>
      <td>Mobile</td>
      <td>GA</td>
      <td><a href="https://github.blog/news-insights/product-news/github-copilot-chat-in-github-mobile/">May 7, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=EQH-V5jQ0aA">Copilot features - videos - GitHub Mobile</a></td>
      <td>Copilot Chat in GitHub Mobile</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/ai-models/changing-the-ai-model-for-copilot-chat">Model picker</a></td>
      <td>GitHub.com, VS Code, Visual Studio, Xcode, Eclipse, JetBrains</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-04-multiple-new-models-are-now-generally-available-in-github-copilot/">April 4, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=d1nyiOPBO04">Configuring and Using Multiple AI Models with GitHub Copilot</a></td>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/managing-copilot/managing-copilot-for-your-enterprise/managing-policies-and-features-for-copilot-in-your-enterprise#copilot-access-to-alternative-ai-models">Access to alternative models</a></td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/github-models/prototyping-with-ai-models">Model Playground</a></td>
      <td>GitHub.com</td>
      <td>Public Preview</td>
      <td>TBD</td>
      <td><a href="https://www.youtube.com/watch?v=OCNvxcMfunA">GitHub Models: Your AI exploration playground</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/getting-code-suggestions-in-your-ide-with-github-copilot#about-next-edit-suggestions">Next Edit Suggestions</a></td>
      <td><a href="https://github.blog/changelog/2025-04-03-github-copilot-in-vs-code-march-release-v1-99/">VS Code</a>, <a href="https://github.blog/changelog/2025-05-13-agent-mode-mcp-and-next-edit-suggestions-come-to-github-copilot-in-visual-studio-17-14/">Visual Studio</a></td>
      <td>GA</td>
      <td>See IDE Links</td>
      <td><a href="https://www.youtube.com/watch?v=zPUvU6XYhpw&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=6&pp=iAQB">Next Edit Suggestions for GitHub Copilot in action</a></td>
      <td>Editor preview features</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/about-github-copilot/github-copilot-features#policy-management">Organization-wide policy management</a></td>
      <td>N/A</td>
      <td>GA</td>
      <td><a href="https://github.blog/news-insights/product-news/github-copilot-is-generally-available-for-businesses/">December 7, 2022</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/using-github-copilot-for-pull-requests/creating-a-pull-request-summary-with-github-copilot">Prompt Files</a></td>
      <td>VS Code</td>
      <td>GA</td>
      <td><a href="https://code.visualstudio.com/updates/v1_100">May 8, 2025</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/using-github-copilot-for-pull-requests/creating-a-pull-request-summary-with-github-copilot">Pull request summaries</a></td>
      <td>GitHub.com</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-07-31-github-copilot-chat-and-pull-request-summaries-are-now-powered-by-gpt-4o/">July 31, 2024</a></td>
      <td><a href="https://www.youtube.com/watch?v=BVX074EMnds">Copilot Pull Request Summaries</a></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/adding-repository-custom-instructions-for-github-copilot">Repository Custom instructions</a></td>
      <td>GitHub.com, VS Code, Visual Studio</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-03-06-github-copilot-updates-in-visual-studio-code-february-release-v0-25-including-improvements-to-agent-mode-and-next-exit-suggestions-ga-of-custom-instructions-and-more/#custom-instructions-generally-available">March 6, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=cu9zZAFmoDg&list=PLCiDM8_DsPQ1WJ5Ss3e0Lsw8EaijUL_6D&index=41&pp=iAQB">Using Custom Instructions with Copilot to enhance our prompts</a></td>
      <td>N/A</td>
    </tr>
        <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/customizing-copilot/adding-organization-custom-instructions-for-github-copilot">Organization Custom Instructions</a> *</td>
      <td>N/A</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-04-17-organization-custom-instructions-now-available/">April 17, 2025</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/copilot-chat/asking-github-copilot-questions-in-your-ide#using-images-in-copilot-chat">Images in Chat</a></td>
      <td>Claude Sonnet 3.5/3.7, Gemini 2.0 Flash, Gemini 2.5 Pro, GPT-4o/4.1</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-04-16-using-vision-input-in-copilot-chat-with-claude-and-gemini-is-now-in-public-preview/">April 16, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=pEEw7BvaK50">Copilot Vision is HERE! Watch It Turn Images into Code!</a></td>
      <td>Editor preview features</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/asking-github-copilot-questions-in-windows-terminal">Windows Terminal</a></td>
      <td>Windows Terminal</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2024-10-29-github-copilot-is-now-available-in-windows-terminal/">October 29, 2024</a></td>
      <td><a href="https://youtu.be/rwKfazgCw9E?feature=shared">Windows Terminal now has GitHub Copilot!?</a></td>
      <td>Copilot in the CLI</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/enterprise-cloud@latest/copilot/using-github-copilot/using-github-copilot-for-pull-requests/using-copilot-to-help-you-work-on-a-pull-request">Workspace</a></td>
      <td>GitHub.com</td>
      <td>Public Preview</td>
      <td>TBD</td>
      <td><a href="https://youtu.be/2ZjE8MPtXyw?feature=shared">This is why GitHub Workspaces is changing the developer experience</a></td>
      <td>Copilot in GitHub.com</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/coding-agent">Copilot Coding Agent</a> *</td>
      <td>GitHub.com</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-05-19-github-copilot-coding-agent-in-public-preview/">May 19, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=EPyyyB23NUU">GitHub Copilot Coding Agent Overview</a></td>
      <td>Copilot coding agent access</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/managing-copilot/monitoring-usage-and-entitlements/monitoring-your-copilot-usage-and-entitlements">Premium Request reports</a></td>
      <td>GitHub.com</td>
      <td>GA</td>
      <td><a href="https://github.blog/changelog/2025-05-16-github-copilot-premium-request-report-available-today/">May 16, 2025</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://learn.microsoft.com/en-us/azure/developer/java/migration/migrate-github-copilot-app-modernization-for-java-quickstart-assess-migrate">Copilot App Modernization for Java</a></td>
      <td>VS Code</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-05-19-github-copilot-app-modernization-for-java-now-in-public-preview/">May 19, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=TBS2sv-e80o">Java App Modernization Simplified with AI | BRK131</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://devblogs.microsoft.com/dotnet/github-copilot-upgrade-dotnet/">Copilot App Modernization for .NET</a></td>
      <td>Visual Studio</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-05-19-github-copilot-app-modernization-upgrade-for-net-now-in-public-preview/">May 19, 2025</a></td>
      <td><a href="https://www.youtube.com/watch?v=3NFWcHrsba0">Using agentic AI to simplify .NET upgrades with GitHub Copilot | DEM549</a></td>
      <td>N/A</td>
    </tr>
    <tr>
      <td><a href="https://docs.github.com/en/copilot/using-github-copilot/copilot-spaces/about-organizing-and-sharing-context-with-copilot-spaces">Copilot Spaces</a></td>
      <td>GitHub.com</td>
      <td>Public Preview</td>
      <td><a href="https://github.blog/changelog/2025-05-29-introducing-copilot-spaces-a-new-way-to-work-with-code-and-context/">May 29, 2025</a></td>
      <td></td>
      <td>N/A</td>
    </tr>
  </tbody>
</table>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
  // Get the table element
  const table = document.getElementById('featureTable');
  const headers = table.querySelectorAll('th');
  const tableBody = table.querySelector('tbody');
  const rows = Array.from(tableBody.querySelectorAll('tr'));
  
  // Direction tracking variables
  let currentColumn = -1;
  let currentDirection = 'asc';
  
  // Function to clean and transform cell content for sorting
  function getCellValue(row, index) {
    const cell = row.querySelector(`td:nth-child(${index + 1})`);
    let text = cell.textContent.trim().toLowerCase();

    if (index === 3) { // Release Date column
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
  function sortTable(index, direction) {
    // Remove classes from all headers
    headers.forEach(header => {
      header.classList.remove('asc', 'desc');
    });
    
    // Add class to the current header
    headers[index].classList.add(direction);
    
    // Sort the rows
    const sortedRows = rows.sort((a, b) => {
      const aValue = getCellValue(a, index);
      const bValue = getCellValue(b, index);
      
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
    currentColumn = index;
    currentDirection = direction;
  }

  // Add click event to each header
  headers.forEach((header, index) => {
    header.addEventListener('click', function() {
      // Determine sorting direction
      const direction = index === currentColumn && currentDirection === 'asc' ? 'desc' : 'asc';
      sortTable(index, direction);
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
  
  // Sort by date (column 3, index 3) descending by default
  sortTable(3, 'desc');
});
</script>

<br>
<br>

Official Feature Lists:

- [GitHub Copilot Features](https://github.com/features/copilot)
- [GitHub Copilot Documentation](https://docs.github.com/en/enterprise-cloud@latest/copilot/about-github-copilot/github-copilot-features)