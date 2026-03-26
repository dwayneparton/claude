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

Creates symlinks from this repo into `~/.claude` for: `agents/`, `skills/`, `commands/`, `agent-memory/`, and `settings.json`. Also installs scheduled tasks as macOS Launch Agents. Backs up existing files before replacing.

## Architecture

### How Claude Code Discovers Config

Claude Code reads config from `~/.claude`. This repo is the source of truth — `install.sh` symlinks everything into place. The directory structure here mirrors what Claude Code expects:

- **`agents/<name>.md`** — Agent definitions with YAML frontmatter (`name`, `description`, `color`). Referenced by `subagent_type` in Agent tool calls.
- **`skills/<name>/SKILL.md`** — Skill definitions with YAML frontmatter (`name`, `description`). Invoked via `Skill tool: skill="<name>"`.
- **`commands/<name>.md`** — Slash commands. Invoked via `/<name>` in conversation.
- **`settings.json`** — Global settings: model, hooks, plugins.

### Agent → Skill Pipeline

The core workflow is an orchestrated pipeline where agents and skills compose:

1. **`/sdlc` skill** is the master workflow — it defines 8 mandatory steps from branch creation through PR finalization.
2. **`dev` agent** is a thin wrapper that loads `/sdlc` and follows it.
3. **`/team` command** spawns multiple `dev` agents in parallel, each following the full SDLC workflow independently, with a coordinator agent managing merges.

The SDLC steps invoke other agents and skills in sequence:
- Step 2: `requirements-analyzer` agent
- Step 3: `planner` agent
- Step 4.25: `/test-coverage` skill (Standard + Large)
- Step 4.5: `/simplify` skill
- Step 5: `/github-pr` skill
- Step 6.3: `/github-resolve` skill

### Spec-Driven Development

The `/spec-writer` skill produces numbered spec files in `specs/` using an RFC-inspired format with type contracts, behavioral specs (RFC 2119), and task checklists. Specs invoke both `api-ergonomics-reviewer` and `consultant` agents during review to ensure design decisions are stress-tested before finalizing. Specs feed into `/sdlc` or `/team` for implementation.

### Exploration

The `/spike` skill supports structured, timeboxed exploration — answering "can we?" or "should we?" before committing to a direction. Spikes produce findings (saved to `spikes/`), not production code. They connect curiosity to outcomes.

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
| Setting | `settings.json` | Valid JSON, follows Claude Code settings schema |
| Task | `scheduled/tasks/<name>.yaml` | YAML with `name`, `schedule`, `prompt` |

After adding new files, re-run `./install.sh` (only needed if new top-level directories were added; existing symlinked directories pick up new files automatically).

## Conventions

- Agent descriptions use trigger phrases (e.g., "MUST BE USED when user asks to...") to help Claude Code route to the right agent.
- Skills define mandatory step ordering — skipping steps is explicitly forbidden in the SDLC skill.
- The test policy is strict: never `test.skip` / `it.skip` / `describe.skip`. Fix, replace, refactor, or remove — never skip.
- Branch naming: `<type>/<short-description>` where type is `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- Commit format: `type(scope): message`.
