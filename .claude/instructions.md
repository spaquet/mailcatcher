# MailCatcher NG - Claude Code Instructions

## Project Overview

**MailCatcher NG** is a modern Ruby gem for email delivery troubleshooting and testing. It provides a beautiful web interface to catch and inspect transactional emails in development and testing environments.

**Project Structure:**
- **Ruby Gem** (main deliverable): Email catching and testing framework (Ruby 3.4+)
  - Core functionality for SMTP server, email capture, database storage, API endpoints
  - Deployed as a published gem on RubyGems.org
  - Used by developers and AI systems (Claude, MCP servers) for email testing workflows

- **Marketing Website** (`/website_src`): Documentation and feature showcase
  - Built with Astro JS 5.9 and Tailwind CSS 4.1
  - Deployed to GitHub Pages via GitHub Actions
  - Purpose: Present the gem's features and capabilities to potential users
  - Separate tech stack from the Ruby gem itself

## Technology Stack

### Ruby Gem (Primary Deliverable)

- **Language**: Ruby 3.4+
- **Dependency Management**: Bundler (Gemfile/Gemfile.lock)
- **Build Format**: `.gem` files (published to RubyGems.org)
- **Core Components**:
  - SMTP server for capturing emails
  - Email storage and database models (SQlite)
  - REST API for programmatic access
  - Web interface (Sinatra, Thin)

### Marketing Website (`website_src/`) - Documentation & Feature Showcase

- **Framework**: Astro JS 5.9 (Static Site Generation)
- **Styling**: Tailwind CSS 4.1 with @tailwindcss/vite plugin (NOT @astrojs/tailwind)
- **Deployment**: GitHub Pages via GitHub Actions (outputs to `website_src/dist`)
- **Package Manager**: npm
- **Purpose**: Present gem features, installation guides, and API documentation to users
- **Key Files:**
  - `website_src/src/styles/global.css` - Global styles and semantic layout classes
  - `website_src/tailwind.config.mjs` - Tailwind configuration with component plugins
  - `website_src/src/pages/` - Astro pages




## Project Structure

```
mailcatcher/
├── website_src/                    # MARKETING WEBSITE (Astro + Tailwind)
│   ├── src/
│   │   ├── pages/                  # Astro pages (.astro files)
│   │   │   ├── index.astro         # Home page with feature showcase
│   │   │   ├── install.astro       # Installation guide
│   │   │   ├── api.astro           # API documentation
│   │   │   ├── claude.astro        # Claude integration guide
│   │   │   ├── advanced.astro      # Advanced usage
│   │   │   ├── components.astro    # UI components
│   │   │   └── remote-access.astro # Remote access guide
│   │   ├── styles/
│   │   │   └── global.css          # Global styles + semantic layout classes
│   │   └── layouts/
│   │       └── Layout.astro        # Base layout component
│   ├── public/                     # Static assets
│   ├── astro.config.mjs            # Astro configuration (outputs to dist/)
│   ├── tailwind.config.mjs         # Tailwind configuration + component plugins
│   ├── package.json
│   └── tsconfig.json
│
├── .github/
│   └── workflows/
│       └── deploy-docs.yml         # GitHub Pages deployment (publishes website_src/dist)
│
├── .gitignore                      # Git ignore patterns
├── .claude/
│   └── instructions.md             # This file - project guidelines
│
├── Gemfile                         # Ruby gem dependencies
├── Gemfile.lock                    # (Locked versions - in .gitignore)
├── lib/                            # Ruby gem source code
├── bin/                            # Gem executables
├── spec/                           # Test suite
└── [Other Ruby gem files]
```


## Git Conventions

- **Commit format**: `<type>: <description>` (e.g., `feat: Add login page`, `fix: Correct hero spacing`)
- **Ignored files**: `/website_src/node_modules/`, `/website_src/dist/`, `/website_src/.astro/`, `Gemfile.lock`, etc. (see `.gitignore`)
- **Co-authored commits**: Include `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>` when appropriate

---

**Last Updated**: January 2026
**Primary Focus**: Ruby gem development
**Website Management**: Dedicated website agent
