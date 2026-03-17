# MailCatcher NG - Development Guide for Claude Code

This repository contains two interconnected projects:

1. **MailCatcher NG** - A Ruby gem that catches emails for development
2. **MailCatcher Website** - An Astro v6 website promoting the project

## Project Structure

```
mailcatcher/
├── bin/                          # Gem executables
├── lib/                          # Ruby gem source code
├── spec/                         # Ruby gem tests
├── Gemfile, Rakefile, *.gemspec  # Gem configuration
├── website_src/                  # Astro v6 website
│   ├── src/
│   ├── public/
│   ├── package.json
│   └── astro.config.mjs
├── reference/                    # Documentation
│   ├── INSTALLATION.md
│   ├── INTEGRATIONS.md
│   └── API.md
└── CLAUDE.md                     # This file
```

## The Ruby Gem: MailCatcher NG

### Overview

MailCatcher NG is a Ruby gem that intercepts emails sent during development, providing a web UI to view and manage them. It includes integrated support for Claude via MCP Server and Claude Plugin.

**Key Features:**
- SMTP server to catch email
- Web UI to browse messages
- Extract tokens, OTPs, and verification links
- Full-text search
- Claude Plugin for AI-assisted email testing
- MCP Server for programmatic access
- SQLite persistence (optional)

### Setup

```bash
# Development
bundle install
bundle exec rake spec                    # Run tests
bundle exec mailcatcher --foreground     # Run locally

# Build
bundle exec rake gem                     # Build gem
bundle exec rake release                 # Release to RubyGems
```

### Tech Stack

- **Language:** Ruby (requires 3.2+, tested up to 4.0.1)
- **Web UI:** ERB templates with CSS/JS
- **Database:** SQLite (optional)
- **Tests:** RSpec
- **Build:** Bundler, Rake

### Important Files

- `lib/mail_catcher/version.rb` - Version management
- `mailcatcher-ng.gemspec` - Gem metadata
- `lib/mail_catcher/` - Core gem code
- `spec/` - Test suite
- `Rakefile` - Build tasks (testing, gem building)

### Development Workflow

1. Make changes in `lib/mail_catcher/`
2. Update version in `lib/mail_catcher/version.rb` for releases
3. Update `CHANGELOG.md` with changes
4. Run tests: `bundle exec rake spec`
5. Build gem: `bundle exec rake gem`
6. Release: `bundle exec rake release`

### Claude Integration

MailCatcher NG (v1.5.2+) includes:

**Claude Plugin** - HTTP-based integration
```bash
mailcatcher --plugin --foreground
```
Then add plugin URL: `http://localhost:1080/.well-known/ai-plugin.json`

**MCP Server** - Direct programmatic access
```bash
mailcatcher --mcp --foreground
```
Configure in `~/.claude_desktop_config.json`

See [CLAUDE_INTEGRATION.md](CLAUDE_INTEGRATION.md) for detailed setup.

## The Website: Astro v6

### Overview

The website is built with Astro v6, styled with Tailwind CSS, and uses Vite for bundling. It promotes MailCatcher NG and provides documentation.

### Setup

```bash
cd website_src

# Requires Node.js 24+ (configured via .nvmrc)
nvm use

# Install dependencies
npm install

# Development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

### Tech Stack

- **Framework:** Astro v6
- **Styling:** Tailwind CSS
- **Bundler:** Vite
- **Runtime:** Node.js 24+

### Important Files

- `website_src/src/pages/` - Page components (Astro format)
- `website_src/src/components/` - Reusable components
- `website_src/astro.config.mjs` - Astro configuration
- `website_src/tailwind.config.js` - Tailwind configuration
- `website_src/package.json` - Dependencies and scripts

### Development Workflow

1. Navigate to `website_src/`: `cd website_src`
2. Ensure Node.js 24 is active: `nvm use`
3. Make changes in `src/pages/` or `src/components/`
4. Run `npm run dev` for hot reload
5. Build with `npm run build` before committing

### Build & Deploy

- The website is built and deployed via CI/CD pipeline
- Configuration is in `.github/workflows/`
- Output is static HTML deployed to GitHub Pages

## CI/CD & Deployment

### GitHub Actions Workflows

- **`.github/workflows/ci.yml`** - Runs tests on every push
  - Tests Ruby gem across Ruby 3.2-4.0
  - Tests website build
  - Uses Node.js 24

- **`.github/workflows/release.yml`** - Releases gem and builds website
  - Publishes gem to RubyGems
  - Builds and deploys website
  - Uses Node.js 24

### Version Management

- Gem version: `lib/mail_catcher/version.rb`
- Website: Uses version from gem
- Release process: Update version → Run `bundle exec rake release`

## Development Setup Checklist

### For Gem Development

- [ ] Ruby 3.2+ installed (or use nvm)
- [ ] Dependencies: `bundle install`
- [ ] Run tests: `bundle exec rake spec`

### For Website Development

- [ ] Node.js 24+ (configured in `.nvmrc`)
- [ ] Dependencies: `cd website_src && npm install`
- [ ] Can run: `npm run dev`

## Documentation

- **[INSTALLATION.md](reference/INSTALLATION.md)** - How to install MailCatcher
- **[INTEGRATIONS.md](reference/INTEGRATIONS.md)** - Integration guides
- **[API.md](reference/API.md)** - API reference
- **[CHANGELOG.md](CHANGELOG.md)** - Version history
- **[CLAUDE_INTEGRATION.md](CLAUDE_INTEGRATION.md)** - Claude Plugin & MCP setup

## Common Tasks

### Update Dependencies

**Gem:**
```bash
bundle update
# Update version in lib/mail_catcher/version.rb
# Update CHANGELOG.md
```

**Website:**
```bash
cd website_src
npm update
```

### Release a New Version

```bash
# 1. Update version
vim lib/mail_catcher/version.rb

# 2. Update CHANGELOG
vim CHANGELOG.md

# 3. Test everything
bundle exec rake spec
cd website_src && npm run build && cd ..

# 4. Commit
git add -A
git commit -m "Release v1.X.X"

# 5. Release gem
bundle exec rake release
```

### Troubleshooting

**Gem tests failing:**
```bash
bundle exec rake spec --verbose
```

**Website won't build:**
```bash
cd website_src
rm -rf node_modules package-lock.json
npm install
npm run build
```

**Node version issues:**
```bash
nvm use          # Applies .nvmrc setting
node -v          # Verify version 24+
```

## Git Workflow

- **Main branch:** `main` - production-ready code
- **Development:** Create branches for features/fixes
- **Release process:** Tag releases with `vX.X.X`

## Key Contact Points

- **Ruby gem bugs/features:** Modify `lib/mail_catcher/`
- **Website updates:** Edit `website_src/src/`
- **Documentation:** Update `reference/` or `website_src/src/pages/`
- **Releases:** Update version → Run `bundle exec rake release`

## Notes for Claude Code

When working with this project:

1. **Two separate tech stacks** - Context-switch between Ruby and Astro/JS
2. **Version sync** - Keep gem and website version in sync
3. **Testing** - Always run `bundle exec rake spec` before committing gem changes
4. **CI checks** - Ensure CI passes (GitHub Actions)
5. **Node version** - Website requires Node 24+ via `.nvmrc`
6. **Documentation** - Update CHANGELOG.md for user-facing changes

This repository is actively developed. Check git history for recent patterns and conventions.
