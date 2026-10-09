# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Public Repository — No Secrets or PII

This repo is **public**. Never commit secrets, credentials, API keys, tokens, or personally identifiable information. This includes absolute paths containing usernames (e.g., `/Users/jane/...`) — use `~` or relative paths instead. If a value must be secret, reference it via environment variable, not inline.

## What This Repo Is

The source of truth for my personal Claude Code config. Nothing is copied or symlinked into `~/.claude`; Claude Code reads from this checkout (see README).

- **`plugin/`** — The `dp` plugin, installed through the marketplace in `.claude-plugin/marketplace.json`. Skills live in `plugin/skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`); hooks live in `plugin/hooks/hooks.json`.
- **`user/CLAUDE.md`** — Global user instructions, imported from `~/.claude/CLAUDE.md`.
- **`user/statusline.sh`** — Status line script, referenced from `statusLine` in `~/.claude/settings.json`.

User settings (`~/.claude/settings.json`) are not in this repo. Plugins can't set permissions, effort, or the status line, and Claude Code writes to that file itself.

The frontmatter `description` is the documentation. It is how Claude Code routes to a skill and how humans browsing the repo understand it, so write it carefully. There is no separate index.

## Workflow Composition

The `sdlc` skill is the master workflow for all coding tasks; `plugin/skills/sdlc/SKILL.md` is the authoritative step list. It uses built-in agents (`general-purpose`, `Plan`) and the built-in `/simplify` skill, and calls `dp:github-pr` and `dp:github-resolve` from this plugin. Plugin skills are namespaced, so one skill calls another as `dp:<name>`. A skill should not reference an agent, skill, or command that is not in `plugin/` or built into Claude Code.

## Engineering Philosophy (from VISION.md)

- **Iterate small** — smallest useful increment, validate direction before polishing
- **Think in platforms** — evaluate what work opens up, not just what it solves; favor composable parts
- **Know the risk** — understand blast radius before moving fast
- **Choose boring technology** — simplest thing that works; no complexity for complexity's sake
- **Scope to the deadline** — time is fixed, scope flexes

## Conventions

- The test policy is strict: never `test.skip` / `it.skip` / `describe.skip`. Fix, replace, refactor, or remove — never skip.
- Branch naming: `<type>/<short-description>` where type is `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- Commit format: `type(scope): message`.
