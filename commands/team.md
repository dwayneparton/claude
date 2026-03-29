# Team Command

Spawn a coordinated agent team to implement a spec or multi-task feature. You act as the team lead — no code, no commits, only delegation and quality control.

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` enabled in settings.json.

## Usage

```bash
/team docs/specs/0001-my-feature.md
/team Implement user authentication with OAuth and session management
/team https://github.com/owner/repo/issues/42
```

## Action

### STEP 0: Understand the Work

1. **If given a spec file path:** Read it to extract all tasks.
2. **If given an issue URL:** Fetch it with `gh issue view`.
3. **If given a description:** Break it into discrete, parallelizable tasks.

Produce a task map: which tasks exist, their dependencies, and which teammate owns what (1 teammate can own 1-3 related tasks, aim for 5-6 tasks per teammate). Break work so each teammate owns different files to avoid conflicts.

### STEP 1: Create Team and Tasks

Create the team and set up tasks in natural language. Start with 3-5 teammates. Use plan approval for complex or risky tasks.

Example:

```text
Create an agent team called "auth-feature" to implement OAuth authentication.

Spawn teammates:
- "schema-agent": owns database migrations and models (src/db/)
- "api-agent": owns API endpoints and middleware (src/routes/, src/middleware/)
- "ui-agent": owns login/signup UI components (src/components/auth/)

Each teammate must use the /sdlc skill and follow ALL steps in order.
Require plan approval before any teammate makes changes.

Tasks:
1. "Add user and session tables" — schema-agent. Acceptance: migrations run, models exported.
2. "Implement OAuth endpoints" — api-agent. Depends on: task 1. Acceptance: /auth/login and /auth/callback work.
3. "Build login UI" — ui-agent. Depends on: task 2. Acceptance: login flow completes end-to-end.
```

**Every task description MUST include:**
- Exactly what to implement (files, components, endpoints)
- Acceptance criteria
- Which spec task(s) it maps to (if from a spec)
- Instruction to use `/sdlc` skill

Teammates self-claim unblocked tasks. When a dependency completes, blocked tasks unblock automatically.

### STEP 2: Coordinate (Your Main Loop)

1. **Monitor** — Watch for teammate messages. Use `Shift+Down` to cycle through teammates (in-process mode) or click panes (split-pane mode).
2. **Steer** — Message teammates directly to redirect approaches or give context.
3. **Inspect** — Review each completed PR:
   ```bash
   gh pr view <NUMBER> --json title,body,additions,deletions,files,reviews,statusCheckRollup
   gh pr diff <NUMBER>
   ```
4. **Validate** before marking ready:
   - [ ] Implementation matches spec/task requirements
   - [ ] Automated review feedback resolved
   - [ ] CI checks passing
   - [ ] PR description is clear
5. **Report** — Notify user when a PR is ready for review
6. **Unblock** — After user merges a dependency PR, notify waiting teammates
7. **Repeat** until all tasks complete

### STEP 3: Shutdown

1. Verify all tasks are done
2. Ask all teammates to shut down
3. Clean up the team (only the lead runs cleanup — teammates must NOT)
4. Report final summary: all PRs with status, any awaiting merge, what was delivered

---

## Team Lead Rules (NON-NEGOTIABLE)

- **NEVER write code** — all implementation goes through teammates
- **NEVER create branches or commits** — teammates handle this via SDLC
- **NEVER skip PR inspection** — every PR gets reviewed before marking ready
- **NEVER merge PRs** — deliver for human review and merge
- **ALWAYS ensure teammates follow full SDLC** — if a teammate skips steps, message them directly with what they missed. If stuck after 2 retries, report to user. If stopped on error, give recovery instructions or spawn a replacement.
