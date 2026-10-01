---
name: my-init
description: Deeply explore a repository and create or update its root AGENTS.md with verified architecture, commands, testing, code-style, planning, and development constraints. Use when initializing durable Codex guidance for a project or when the user asks for a richer alternative to `/init`.
---

# Custom Project Initialization

Initialize a project by deeply exploring the codebase and generating or updating `AGENTS.md` at the project root. This file is durable guidance for Codex and other compatible coding agents. If a repository declares another instruction file as its source of truth, preserve that arrangement and update the authoritative file instead of creating conflicting guidance.

## Phase 1: Explore the Codebase

Thoroughly investigate the project to understand its full shape. Use parallel exploration where possible. Gather information on ALL of the following:

### Stack & Framework Detection
- Language(s), framework(s), runtime version(s)
- Package manager (npm, yarn, pnpm, bundler, pip, cargo, go mod, etc.)
- Database, cache, queue, search (e.g. PostgreSQL, Redis, Sidekiq, Elasticsearch)
- Frontend stack (Tailwind, React, Vue, Hotwire/Turbo, Stimulus, etc.)
- Deployment target (Docker, Heroku, Fly, Vercel, etc.)

### Project Structure
- Top-level directory layout and what each directory contains
- Key entry points (main files, application configs, route definitions)
- Monorepo structure if applicable

### Architecture & Patterns
- MVC, service objects, interactors, jobs, concerns, components — whatever patterns the project uses
- Authorization approach (Pundit, CanCanCan, custom)
- Authentication approach (Devise, custom, OAuth)
- API patterns (REST, GraphQL, RPC)
- Background job framework and queue names
- Real-time features (WebSockets, ActionCable, SSE)

### Dev Commands Discovery
Find ALL available dev commands by checking:
- `Makefile` or `Justfile` (list all targets)
- `package.json` scripts
- `Rakefile` and available rake tasks
- `docker-compose.yml` / `Dockerfile` (service definitions)
- `Procfile` / `Procfile.dev`
- `bin/` directory scripts
- CI config files (`.github/workflows/`, `.circleci/`, etc.)
- Any custom CLI tools or shell scripts

### Testing
- Test framework(s) (RSpec, Minitest, Jest, Vitest, pytest, etc.)
- How to run the full suite and a single file
- Test helpers, factories, fixtures
- Any excluded/tagged test groups

### Linting & Formatting
- Linter(s) and formatter(s) in use (RuboCop, ESLint, Prettier, Standard, etc.)
- Config files and any notable overrides
- How to run lint checks and auto-fix

### Database
- Migration approach
- How to run migrations, rollbacks, seeds, resets

### Credentials & Config
- How secrets/credentials are managed (Rails credentials, .env, Vault, etc.)
- Environment-specific configurations

## Phase 2: Generate AGENTS.md

Create or update `AGENTS.md` at the project root with the following sections. Be concise — prefer tables and bullet points over prose. Only include sections that are relevant to the project.

### Required Sections

```markdown
# AGENTS.md

## Important Constraints

- **NEVER start the server.** Do not run dev servers, application servers, or any long-running processes unless explicitly instructed to do so. Assume the server is already running.
- Detect how the server runs (Docker, local process, etc.) and use that context to determine how commands should be executed.
- If the project uses Docker, prefix commands appropriately (e.g., `docker exec`, `docker compose run`, or use Make targets that wrap Docker).
- All commands listed below should be used as the primary way to interact with the project.

## Common Commands

[List ALL discovered dev commands organized by category: Tests, Linting, Database, Shell Access, Other. Include the exact command to run and a brief description. Use code blocks.]

## Architecture

[Stack summary, key layers, directory structure, patterns used. Be specific — name the gems, packages, and tools. Describe what each layer does in 1-2 lines.]

## Testing

[Framework, how to run tests (full suite + single file), notable helpers, excluded tags.]

## Code Style

[Linter config, target language version, notable disabled rules.]
```

### Optional Sections (include only if relevant)

- **Routes Structure** — key route namespaces and patterns
- **Authorization** — how it works, where policies live
- **Background Jobs** — framework, queues, retry config
- **MCP / AI Tools** — if the project has AI/LLM integrations
- **ViewComponents** — if the project uses component-based UI
- **Credentials** — how secrets are managed (never include actual secrets)
- **Deployment** — deploy process if discoverable

### Custom Sections (always include these)

#### Plan Section
Add this section to AGENTS.md:

```markdown
## Plan

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.
```

## Phase 3: Verify

After writing AGENTS.md:
1. Re-read the generated file to confirm accuracy
2. Ensure all discovered commands are listed and correct
3. Confirm the Important Constraints section is present with the server/command rules
4. Confirm the Plan section is present
