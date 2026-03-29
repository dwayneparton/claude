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
- **`settings.json`** — Global settings: model, hooks, plugins.

### Structural Hooks

Hooks make rules deterministic — they run automatically at specific lifecycle points, unlike CLAUDE.md instructions which the LLM may forget after compaction.

- **Post-compaction context** (`SessionStart`, matcher: `compact`) — Re-injects critical SDLC rules after conversation compaction. Prevents agent drift in long sessions.
- **Protected files** (`PreToolUse`, matcher: `Edit|Write`) — Blocks edits to `.env`, lock files, and `.git/`. Defined in `hooks/protect-files.sh`.
- **Auto-format** (`PostToolUse`, matcher: `Edit|Write`) — Runs Prettier on edited files. Eliminates formatting-only commits.
- **Task completion validation** (`Stop`, type: `prompt`) — Asks a model whether all requested tasks are complete before letting the agent stop. Catches premature completion.

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

### Advisory Agents

Three agents provide decision support from different angles. Use the right one for the question being asked:

- **`consultant`** — "Is this *decision* sound?" Evaluates trade-offs, surfaces counterpoints, and stress-tests a specific choice (e.g., "Should we switch from Postgres to MongoDB?"). Use when committing to a direction that's hard to reverse.
- **`practicality`** — "Is this *plan* shippable?" Grounds ambitious plans into incremental, deliverable steps (e.g., "This 6-month roadmap needs to ship in 4 weeks"). Use when scope is creeping or discussions are too abstract.
- **`vision`** — "Does this *work* serve the strategic direction?" Checks whether proposed features, fixes, or refactors align with the project's north star (e.g., "Does adding this feature fit our vision?"). Use when direction feels unclear or priorities conflict.

When multiple could apply: start with the one that matches the user's immediate need. A user asking "should we?" wants the consultant. A user saying "how do we ship this?" wants practicality. A user wondering "does this matter?" wants vision.

### Spec-Driven Development

The `/spec-writer` skill produces numbered spec files in `specs/` using an RFC-inspired format with type contracts, behavioral specs (RFC 2119), and task checklists. Specs invoke both `api-ergonomics-reviewer` and `consultant` agents during review to ensure design decisions are stress-tested before finalizing. Specs feed into `/sdlc` or `/team` for implementation.

### Vision Alignment

The `/vision` skill creates and maintains a project vision document (`docs/VISION.md` or equivalent) that defines purpose, success criteria, guiding principles, and boundaries. The `vision` agent uses this skill and can operate in three modes: **create** (draft a new vision), **update** (revise an existing one), or **alignment check** (evaluate whether proposed work serves the vision). The vision document is referenced from `CLAUDE.md` so all agents can align their work against it.

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
| Hook | `hooks/<name>.sh` + `settings.json` | Executable script; registered in settings.json `hooks` |
| Setting | `settings.json` | Valid JSON, follows Claude Code settings schema |
| Task | `scheduled/tasks/<name>.yaml` | YAML with `name`, `schedule`, `prompt` |

After adding new files, re-run `./install.sh` (only needed if new top-level directories were added; existing symlinked directories pick up new files automatically).

**README.md must stay in sync.** When adding a new agent, skill, command, or scheduled task, add a one-line entry to the corresponding section in `README.md`. The README is the public-facing overview — every capability should be listed there with a brief description.

## Conventions

- Agent descriptions use trigger phrases (e.g., "MUST BE USED when user asks to...") to help Claude Code route to the right agent.
- Skills define mandatory step ordering — skipping steps is explicitly forbidden in the SDLC skill.
- The test policy is strict: never `test.skip` / `it.skip` / `describe.skip`. Fix, replace, refactor, or remove — never skip.
- Branch naming: `<type>/<short-description>` where type is `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- Commit format: `type(scope): message`.
