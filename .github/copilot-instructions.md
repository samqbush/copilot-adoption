This application is deployed on GitHub Pages as a Jekyll website.
### Custom Jekyll Plugins

Custom plugins are used and supported by GitHub pages.  This website uses the below custom plugins:
- [jekyll-gfm-admonitions](https://github.com/Helveg/jekyll-gfm-admonitions) for GitHub flavored alerts
- [jekyll-toc](https://github.com/allejo/jekyll-toc) for Table of Contents

Admonition syntax should follow styling for jekyll-gfm-admonitions

For kramdown heading IDs, use the inline form `## Heading {#id}` — not a standalone `{:#id}` attribute line on the following line.

### Internal links between pages

The site uses `permalink: pretty`, so every page is served as a trailing-slash
directory (e.g. `/copilot-metrics-billing/`). The `github-pages` gem enables the
`jekyll-relative-links` plugin, which rewrites relative Markdown links **that end
in `.md`** into correct permalinks (absolute, baseurl-aware).

Always link to another page by its source file with the `.md` extension, e.g.
`[Grafana guide](copilot-metrics-grafana.md)` or
`[Credentials](copilot-metrics-billing.md#set-up-the-two-credentials)`. The plugin
turns these into `/copilot-adoption/copilot-metrics-grafana/` etc.

Do **not** use extension-less relative links like `[x](./cost-management)` or
`[x](../cost-management)`. The plugin ignores them, so they stay literal and
break depending on the current page's trailing slash — a link that works from
the home page 404s from a subpage. Anchors are preserved, so `page.md#anchor`
works.

### Building & verifying

Run `bundle exec jekyll build` to confirm a page renders correctly (heading anchors, TOC, and admonitions) before finishing an edit. Use `bundle exec jekyll serve` to preview locally.

When you add or change links between pages, verify them against a running
`bundle exec jekyll serve`: fetch the rendered page and confirm each internal
`href` returns `200` (following redirects). Extension-less page links that resolve
to a 404 are the most common breakage.

### Content Purpose

These pages are opinionated implementation guides — worked examples readers can copy and adapt, not documentation. Position content across three tiers:

- **Aircraft manual** — [GitHub Docs](https://docs.github.com/en/enterprise-cloud@latest/): what every switch does.
- **Flight doctrine** — the [Well-Architected Framework](https://wellarchitected.github.com/): the design principles behind a good rollout — *what* to consider and *why* — but it stops short of naming specific tools.
- **A proven flight plan** — these guides: one concrete, runnable way to actually do it on a real stack.

Rules of the road:
- Do not restate what the docs or WAF already cover. Link out to them and move on.
- Verify every product, API, or feature-availability claim against `docs.github.com/en/enterprise-cloud@latest` (or a live test) before publishing it — do not state capabilities from memory. When a feature is new, note its availability date.
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
- Give one recommended way to do a task, not a menu of alternatives. If the UI already does it, don't enumerate CLI variants. Prefer cutting content over adding it — too many options and too much reading overwhelm a new Copilot admin.
- Use simple and straightforward language that is easy to understand. Avoid complex words or jargon that may confuse the reader.
- Be specific. Provide specific details and examples to support your points.
- When editing or writing content pages, run the humanizer skill on the new text before finalizing to remove AI writing patterns.