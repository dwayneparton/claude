# Claude Code Config

Version-controlled configuration for [Claude Code](https://claude.com/claude-code) — agents, skills, commands, and settings that define how I work with AI.

## Setup

Clone the repo and run the install script to symlink everything into `~/.claude`:

```bash
git clone <repo-url> ~/Documents/GitHub/claude
cd ~/Documents/GitHub/claude
./install.sh
```

The script backs up any existing files before replacing them with symlinks. Changes take effect immediately.

## What's Here

### Agents

Specialized agents that handle distinct parts of the workflow:

- **dev** — Orchestrates the full software development lifecycle from requirements through PR
- **planner** — Breaks down features into actionable, phased implementation plans
- **requirements-analyzer** — Extracts and researches requirements from GitHub issues
- **tech-scout** — Researches and recommends libraries and technologies for a given problem
- **practicality** — Grounds ambitious plans into practical, shippable steps
- **refactor-scout** — Identifies refactoring opportunities, duplication, and cohesion issues
- **api-ergonomics-reviewer** — Reviews public API surfaces for developer experience quality

### Skills

Slash commands that automate common workflows:

- `/sdlc` — End-to-end development lifecycle: branch, requirements, plan, implement, PR, review, CI
- `/spec-writer` — Writes feature specification documents using an RFC-inspired format
- `/github-pr` — Creates a branch, runs checks, and opens a PR
- `/github-resolve` — Resolves PR review comments and replies on GitHub
- `/github-pr-review-check` — Checks GitHub for reviews requiring approval
- `/test-coverage` — Identifies test gaps and writes targeted tests
- `/simplify` — Reviews changed code for reuse, quality, and efficiency

### Commands

- `/team` — Spawns a coordinated agent team to implement a spec or multi-task feature in parallel

## Adding New Config

- **Agent**: Add a `.md` file in `agents/` with the required frontmatter
- **Skill**: Add a directory in `skills/<name>/` with a `SKILL.md` file
- **Command**: Add a `.md` file in `commands/`
- **Settings**: Edit `settings.json` directly

## Inspired By

- [fx/cc](https://github.com/fx/cc) — Claude Code configuration that inspired several agents and the SDLC workflow skill
