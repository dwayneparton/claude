# Claude Code Config

Version-controlled configuration for [Claude Code](https://claude.com/claude-code) — agents, skills, commands, hooks, settings, and scheduled tasks that define how I work with AI.

## Setup

Clone the repo and run the install script to symlink everything into `~/.claude`:

```bash
git clone <repo-url> ~/Documents/GitHub/claude
cd ~/Documents/GitHub/claude
./install.sh
```

The script backs up any existing files before replacing them with symlinks. Changes take effect immediately.

## What's Here

| Directory | Contents |
| --- | --- |
| `agents/` | Agent definitions — specialized roles invoked via the Agent tool (development, planning, advisory) |
| `skills/` | Skills — step-by-step workflows invoked as slash commands (`/sdlc`, `/debug`, ...) |
| `commands/` | Slash commands, like `/team` for spawning coordinated agent teams |
| `hooks/` | Deterministic lifecycle automation — scripts registered in `settings.json` that run on tool use, session events, etc. |
| `scheduled/` | Cron-like tasks that run via macOS Launch Agents, each sending a prompt to `claude -p` |
| `settings.json` | Global settings: hooks, permissions, plugins |

Every agent, skill, and command is self-documenting: the YAML frontmatter at the top of each file describes what it does and when it's used. Browse the directories for the current inventory — there is intentionally no duplicate index here.

The centerpiece is the `/sdlc` skill — an end-to-end development workflow (branch, validate, requirements, plan, implement, test, external review, PR) that the `dev` agent follows and the `/team` command parallelizes across multiple agents.

## Adding New Config

- **Agent**: Add a `.md` file in `agents/` with the required frontmatter
- **Skill**: Add a directory in `skills/<name>/` with a `SKILL.md` file
- **Command**: Add a `.md` file in `commands/`
- **Scheduled task**: Add a `.yaml` file in `scheduled/tasks/` and run `bash scheduled/scripts/install.sh`
- **Settings**: Edit `settings.json` directly

## Inspired By

- [fx/cc](https://github.com/fx/cc) — Claude Code configuration that inspired several agents and the SDLC workflow skill
