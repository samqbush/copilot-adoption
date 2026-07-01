This application is deployed on GitHub Pages as a Jekyll website.
### Custom Jekyll Plugins

Custom plugins are used and supported by GitHub pages.  This website uses the below custom plugins:
- [jekyll-gfm-admonitions](https://github.com/Helveg/jekyll-gfm-admonitions) for GitHub flavored alerts
- [jekyll-toc](https://github.com/allejo/jekyll-toc) for Table of Contents

Admonition syntax should follow styling for jekyll-gfm-admonitions

### Content Purpose

These pages are opinionated implementation guides — worked examples readers can copy and adapt, not documentation. Position content across three tiers:

- **Aircraft manual** — [GitHub Docs](https://docs.github.com/en/enterprise-cloud@latest/): what every switch does.
- **Flight doctrine** — the [Well-Architected Framework](https://wellarchitected.github.com/): what to weigh, why, and the design trade-offs — deliberately tool-agnostic.
- **A flown mission** — these guides: one concrete, runnable way to actually do it on a real stack.

Rules of the road:
- Do not restate what the docs or WAF already cover. Link out to them and move on.
- Defer to WAF for framework and design thinking — don't re-derive governance principles or invent competing pillars.
- Pick one concrete stack and show it working end to end (specific tooling, real config, actual commands). WAF stays vendor-neutral on purpose; these guides deliberately don't.
- Frame each guide as one reference implementation, not the only way — adapt-to-your-stack, not gospel.
- The differentiator to keep clear: WAF is tool-agnostic design thinking; these guides are tool-specific worked examples you can lift and adapt.
- Write for the reader (a Copilot admin), not about the authors. Never narrate the authoring process or position the guide as "us vs GitHub." Keep editorial reasoning — "our framing," "this page adds," "the gap we fill," "GitHub says X but we say Y" — out of the published text. If a distinction matters to the reader (e.g. a term GitHub uses differently), state it neutrally as a heads-up, not as a we-vs-them argument.

### Page Edit Conventions

When editing a content page, update its "Last updated" date (e.g. `*Last updated: <Month D, YYYY>*` near the top) to the current date to reflect the change.
When editing a page, reread the page if we are changing logic as this may impact other sections of the page.

### Output
- Be concise and to the point. Avoid unnecessary words or phrases that do not add value to the content. Focus on delivering clear and direct information to the reader.
- Avoid repetition. Do not repeat the same information multiple times in different ways. Instead, present the information once in a clear and concise manner.
- Use simple and straightforward language that is easy to understand. Avoid complex words or jargon that may confuse the reader.
- Be specific. Provide specific details and examples to support your points.
- When editing or writing content pages, run the humanizer skill on the new text before finalizing to remove AI writing patterns.