# Claude Code Config

Version-controlled configuration for [Claude Code](https://claude.com/claude-code) — agents, skills, agent memory, and settings.

## Setup

Clone the repo and run the install script to symlink everything into `~/.claude`:

```bash
git clone <repo-url> ~/Documents/GitHub/claude
cd ~/Documents/GitHub/claude
./install.sh
```

The script backs up any existing files before replacing them with symlinks.

## Structure

```
├── agents/              # Custom agent definitions
│   ├── api-ergonomics-reviewer.md
│   └── refactor-scout.md
├── agent-memory/        # Persistent agent memory
│   └── refactor-scout/
├── skills/              # Custom slash command skills
│   ├── github-pr/
│   └── github-resolve/
├── settings.json        # Global Claude Code settings
├── install.sh           # Symlink installer
└── .gitignore
```

## What's Included

| Component | Description |
|-----------|-------------|
| **agents/api-ergonomics-reviewer** | Reviews public API surfaces for DX quality, naming consistency, and usability |
| **agents/refactor-scout** | Identifies refactoring opportunities, duplication, and cohesion issues |
| **skills/github-pr** | `/github-pr` — creates a branch, runs checks, opens a PR |
| **skills/github-resolve** | `/github-resolve` — resolves PR review comments and replies on GitHub |

## Adding New Config

- **Agent**: Create a new `.md` file in `agents/` with the required frontmatter (`name`, `description`, `model`)
- **Skill**: Create a new directory in `skills/<name>/` with a `SKILL.md` file
- **Settings**: Edit `settings.json` directly

Changes take effect immediately since `~/.claude` points to this repo via symlinks.
