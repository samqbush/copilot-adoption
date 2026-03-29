# GitHub Copilot Adoption Resources

> [!NOTE]
> The original phased rollout checklist on this site has been retired. Official GitHub documentation now covers the same ground. Visit [https://samqbush.github.io/copilot-adoption/](https://samqbush.github.io/copilot-adoption/) for links to official resources and the unique guides that are still maintained.

## Unique Resources (Still Maintained)

- **[Strategies for Managing Copilot Premium Request Spending](https://samqbush.github.io/copilot-adoption/cost-management_premium-requests)** — Business vs Enterprise break-even analysis and granular budget strategies

## Local Development

- [jekyll-gfm-admonitions](https://github.com/Helveg/jekyll-gfm-admonitions) for GitHub flavored alerts
- [jekyll-toc](https://github.com/allejo/jekyll-toc) for Table of Contents
- Requires [GH Actions build](./.github/workflows/gh-pages.yml) & deploy due to the above custom plugins

```shell
# Remove unused gems
bundle clean --force

# Install gems & run local server
bundle install

JEKYLL_ENV=production bundle exec jekyll serve
```