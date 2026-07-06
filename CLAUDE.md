# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Public Repository — No Secrets or PII

This repo is **public**. Never commit secrets, credentials, API keys, tokens, or personally identifiable information. This includes absolute paths containing usernames (e.g., `/Users/jane/...`) — use `~` or relative paths instead. When adding scheduled tasks, agent memory, or any config that references external systems, ensure no sensitive values are embedded. If a value must be secret, reference it via environment variable, not inline.

## What This Repo Is

This is a version-controlled configuration repo for Claude Code. It defines agents, skills, commands, settings, and scheduled tasks that get installed via `install.sh`. Config is symlinked into `~/.claude`; scheduled tasks are registered as macOS Launch Agents. Changes to config take effect immediately after symlinking.

## Setup

```bash
./install.sh
```

Creates symlinks from this repo into `~/.claude` for: `agents/`, `skills/`, `commands/`, `hooks/`, `agent-memory/`, and `settings.json`. Also installs scheduled tasks as macOS Launch Agents. Backs up existing files before replacing.

## Architecture

### How Claude Code Discovers Config

Claude Code reads config from `~/.claude`. This repo is the source of truth — `install.sh` symlinks everything into place. The directory structure here mirrors what Claude Code expects:

- **`agents/<name>.md`** — Agent definitions with YAML frontmatter (`name`, `description`, `color`). Referenced by `subagent_type` in Agent tool calls.
- **`skills/<name>/SKILL.md`** — Skill definitions with YAML frontmatter (`name`, `description`). Invoked via `Skill tool: skill="<name>"`.
- **`commands/<name>.md`** — Slash commands. Invoked via `/<name>` in conversation.
- **`hooks/<name>.sh`** — Hook scripts called by settings.json hooks. Deterministic enforcement, not advisory.
- **`settings.json`** — Global settings: hooks, permissions, plugins.
- **`scheduled/`** — Cron-like tasks run via macOS Launch Agents.

**Each file is self-documenting.** The YAML frontmatter (`name`, `description`) is the authoritative record of what an agent or skill does and when to use it — Claude Code routes based on it. Browse the directories for the current inventory; this file intentionally does not duplicate it.

### Workflow Composition

The core pattern is composition: the `/sdlc` skill is the master workflow for all coding tasks; the `dev` agent is a thin wrapper that loads `/sdlc` and follows it; the `/team` command spawns multiple `dev` agents in parallel with a coordinator managing tasks and merges. SDLC steps invoke supporting agents and skills in sequence — `skills/sdlc/SKILL.md` is the authoritative step list.

### Hooks

Hooks make rules deterministic — they run automatically at specific lifecycle points, unlike CLAUDE.md instructions which the LLM may forget after compaction. Active hooks are registered in `settings.json`; scripts live in `hooks/`. Read `settings.json` for what's currently enforced.

### Scheduled Tasks

The `scheduled/` directory contains tasks that run on a cron-like schedule via macOS Launch Agents. Each task sends a prompt to `claude -p` in a fresh session.

- **`scheduled/tasks/<name>.yaml`** — Task definitions with schedule, model, working directory, and prompt
- **`scheduled/scripts/`** — TypeScript + Bash scripts that manage plist generation, launchd loading, and task execution
- **`scheduled/plists/`** — Generated plist files (gitignored)
- **`scheduled/logs/`** — Task output logs (gitignored)

Task YAML format:

```yaml
name: my-task
description: What this task does
working_directory: ~/path/to/run/in
model: sonnet
schedule:
  - Hour: 9
    Minute: 0
prompt: |
  The prompt to send to claude...
```

Schedule keys: `Hour`, `Minute`, `Weekday` (0=Sun), `Day`, `Month`.

Managing tasks:
- **Install:** `bash scheduled/scripts/install.sh` (also runs during `./install.sh`)
- **Uninstall:** `bash scheduled/scripts/uninstall.sh`
- **Run manually:** `bash scheduled/scripts/run-task.sh <task-name>`
- **List loaded:** `cd scheduled && npm run list`
- **View logs:** `cat scheduled/logs/<task-name>.out.log`

## Engineering Philosophy (from VISION.md)

This config embodies specific principles that agents and skills reference:

- **Iterate small** — smallest useful increment, validate direction before polishing
- **Think in platforms** — evaluate what work opens up, not just what it solves; favor composable parts
- **Know the risk** — understand blast radius before moving fast
- **Choose boring technology** — simplest thing that works; no complexity for complexity's sake
- **Scope to the deadline** — time is fixed, scope flexes

## Adding New Config

| Type | Location | Key requirement |
|---------|-------------------------------|------------------------------------------------|
| Agent | `agents/<name>.md` | YAML frontmatter: `name`, `description` |
| Skill | `skills/<name>/SKILL.md` | YAML frontmatter: `name`, `description` |
| Command | `commands/<name>.md` | Markdown with usage and action sections |
| Hook | `hooks/<name>.sh` + `settings.json` | Executable script; registered in settings.json `hooks` |
| Setting | `settings.json` | Valid JSON, follows Claude Code settings schema |
| Task | `scheduled/tasks/<name>.yaml` | YAML with `name`, `schedule`, `prompt` |

After adding new files, re-run `./install.sh` (only needed if new top-level directories were added; existing symlinked directories pick up new files automatically).

The frontmatter `description` is the documentation — write it carefully, since it's both how Claude Code routes to the right agent/skill and how humans browsing the repo understand it. No separate index needs updating.

## Conventions

- Agent descriptions use trigger phrases (e.g., "MUST BE USED when user asks to...") to help Claude Code route to the right agent.
- Skills define mandatory step ordering — skipping steps is explicitly forbidden in the SDLC skill.
- The test policy is strict: never `test.skip` / `it.skip` / `describe.skip`. Fix, replace, refactor, or remove — never skip.
- Branch naming: `<type>/<short-description>` where type is `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- Commit format: `type(scope): message`.
