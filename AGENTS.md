# Project Overview

This repository contains two projects:

1. **MailCatcher NG** - Ruby gem (`mailcatcher-ng`) that catches emails during development
2. **Website** - Astro v6 website in `website_src/` promoting the project

## Directory Structure

```
mailcatcher/
├── bin/                          # Gem executables
├── lib/                          # Gem source code
├── spec/                         # Gem tests (RSpec)
├── Gemfile, Rakefile, *.gemspec  # Ruby configuration
├── website_src/                  # Astro v6 website
│   ├── src/                      # Pages and components
│   ├── astro.config.mjs
│   └── package.json
└── reference/                    # User documentation
```

## The Ruby Gem

**Tech Stack:** Ruby 3.3-4.0, ERB, SQLite, RSpec

**Setup:**

```bash
bundle install
bundle exec rake test    # Run tests
bundle exec mailcatcher  # Run locally
```

**Key files:**

- `lib/mail_catcher/version.rb` - Version number
- `lib/mail_catcher/` - Source code
- `spec/` - Tests
- `Rakefile` - Build/test tasks
- `CHANGELOG.md` - Changes

**When modifying the gem:**

1. Make changes in `lib/`
2. Update version in `lib/mail_catcher/version.rb` for releases
3. Update `CHANGELOG.md`
4. Run `bundle exec rake test` before committing
5. Commit → PR → merge to `main` → publish a GitHub Release (see Release Process)

## The Website

**Tech Stack:** Astro v6, Tailwind CSS, Vite, Node.js 24+

**Setup:**

```bash
cd website_src
nvm use                  # Use Node.js 24
npm install
npm run dev              # Hot reload development
npm run build            # Production build
```

**Key files:**

- `website_src/src/pages/` - Page routes
- `website_src/src/components/` - Reusable components
- `website_src/astro.config.mjs` - Configuration
- `website_src/.nvmrc` and root `.nvmrc` - Node.js 24 requirement
- Tailwind is v4 via the `@tailwindcss/vite` plugin (no `tailwind.config.js`)

**When modifying the website:**

1. cd into `website_src`
2. Ensure `nvm use` shows Node 24+
3. Make changes in `src/`
4. Run `npm run build` before committing
5. Merge to `main` → `.github/workflows/deploy-docs.yml` deploys to GitHub Pages (runs only when `website_src/**` or the workflow changes)

## Release Process

Releases are **automated via GitHub Actions** and are triggered by **publishing a GitHub Release**. Merging to `main` alone does not publish the gem.

```bash
# 1. Update version
vim lib/mail_catcher/version.rb

# 2. Update CHANGELOG
vim CHANGELOG.md

# 3. Commit on a branch, push, and open a PR to main
git checkout -b release/v1.X.X
git add -A
git commit -m "Release v1.X.X: description"
git push -u origin release/v1.X.X
gh pr create --base main

# 4. Merge the PR once CI passes

# 5. Publish the release (this triggers the gem publish)
gh release create vX.Y.Z --target main --title vX.Y.Z --notes "..."

# 6. .github/workflows/release.yml automatically:
#    - Builds the gem and verifies assets
#    - Publishes gem to RubyGems
#    - Creates the GitHub Release assets
```

The website is separate: `.github/workflows/deploy-docs.yml` deploys it on merges to `main` that touch `website_src/`.

**Do NOT manually run `bundle exec rake release`** - it's handled by the workflow.

## Testing

**Gem tests:**

```bash
bundle exec rake test           # Run all (RSpec, via the Rakefile `test` task)
```

Note: `bundle exec rake spec` is not a test task. It exits 0 without running anything.

**Website build:**

```bash
cd website_src && npm run build
```

## Common Issues

| Issue | Solution |
| --- | --- |
| Node version wrong in website | Run `nvm use` in `website_src/` |
| Gem tests fail | Run `bundle exec rake test` |
| Website won't build | `cd website_src && rm -rf node_modules && npm install && npm run build` |
| Bundler frozen error | Run `bundle install` to update `Gemfile.lock` |

## Git Branches

- `main` - Production. Merges trigger CI and website deploy (when `website_src/` changes). Gem publish happens on GitHub Release.
- Feature/fix/release branches - Create and PR to main

## Important Notes

1. **Two tech stacks** - Ruby and JavaScript/Node, context-switch as needed
2. **.nvmrc required** - Website needs Node 24+ configured in `.nvmrc` at root
3. **Gems are auto-published on GitHub Release** - publishing a release triggers `release.yml` to publish to RubyGems
4. **Version sync** - Keep gem version and CHANGELOG updated together
5. **Claude integration** - Gem includes MCP Server and Claude Plugin support
