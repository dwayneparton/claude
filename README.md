# Claude Code Config

Version-controlled configuration for [Claude Code](https://claude.com/claude-code): global instructions, a status line, and the skills and hooks that define how I work with AI.

## Layout

| Path | What it is | How Claude Code gets it |
| --- | --- | --- |
| `plugin/` | The `dp` plugin: skills (`/dp:sdlc`, `/dp:github-pr`, ...) and hooks | Installed from this repo as a plugin marketplace |
| `user/CLAUDE.md` | Global instructions for every repo | Imported from `~/.claude/CLAUDE.md` |
| `user/statusline.sh` | Status line: model, git branch, context usage | Referenced by `statusLine` in `~/.claude/settings.json` |
| `.claude-plugin/marketplace.json` | Lists the `dp` plugin | Read by `claude plugin marketplace add` |

Each skill is self-documenting: the YAML frontmatter at the top of its `SKILL.md` says what it does and when it's used.

## Setup

Install the plugin from the local checkout. It loads in place, so edits apply on `/reload-plugins` or the next session:

```bash
claude plugin marketplace add ~/Documents/GitHub/claude
claude plugin install dp@personal
```

Point `~/.claude/CLAUDE.md` at this repo with a single import line:

```markdown
@~/Documents/GitHub/claude/user/CLAUDE.md
```

Add the status line to `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "bash ~/Documents/GitHub/claude/user/statusline.sh" }
```

## Settings

`~/.claude/settings.json` stays a real file and is maintained by hand. Claude Code writes to it (`/model`, `/config`, plugin installs), settings files can't include each other, and plugins can't set permissions, effort, or the status line. Org-managed settings override it.
