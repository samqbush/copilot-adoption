> [!NOTE]
> The READMEs in this repository have been converted to GitHub Pages.  Please visit [https://samqbush.github.io/copilot-adoption/](https://samqbush.github.io/copilot-adoption/)



## Local Development
- [jekyll-gfm-admonitions](https://github.com/Helveg/jekyll-gfm-admonitions) for GitHub flavored alerts
- [jekyll-toc] for Table of Contents
- Requires [GH Actions build](./.github/workflows/gh-pages.yml) & deploy due to the above custom plugins

```shell
# Remove unused gems
bundle clean --force

# Install gems & run local server
bundle install
JEKYLL_ENV=production bundle exec jekyll serve
```