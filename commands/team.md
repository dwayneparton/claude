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

1. **Create the team** with `TeamCreate` (params: `team_name`, `description`).
2. **Create tasks** with `TaskCreate` for every task from Step 0. Use `TaskUpdate` to set dependencies (`addBlockedBy`/`addBlocks`) so work proceeds in the correct order.
3. **Spawn teammates** with the `Agent` tool — set `team_name` to match the team and `name` to a descriptive agent name (e.g., `"schema-agent"`). Use `subagent_type: "dev"` and `mode: "plan"` for complex or risky tasks.

Start with 3-5 teammates. Each teammate prompt MUST include:
- Exactly what to implement (files, components, endpoints)
- Acceptance criteria
- Which spec task(s) it maps to (if from a spec)
- Instruction to use `/sdlc` skill and follow ALL steps in order

Teammates check `TaskList`, self-claim unblocked tasks via `TaskUpdate` (set `owner`), and mark tasks completed when done. When a dependency completes, blocked tasks unblock automatically.

### STEP 2: Coordinate (Your Main Loop)

1. **Monitor** — Teammate messages arrive automatically. Use `Shift+Down` to cycle through teammates (in-process mode) or click panes (split-pane mode).
2. **Steer** — Use `SendMessage` to redirect approaches or give context to specific teammates (by name).
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

1. Verify all tasks are done via `TaskList`
2. Send `SendMessage` with `{type: "shutdown_request"}` to each teammate
3. After all teammates have shut down, call `TeamDelete` to clean up team and task files
4. Report final summary: all PRs with status, any awaiting merge, what was delivered

---

## Team Lead Rules (NON-NEGOTIABLE)

- **NEVER write code** — all implementation goes through teammates
- **NEVER create branches or commits** — teammates handle this via SDLC
- **NEVER skip PR inspection** — every PR gets reviewed before marking ready
- **NEVER merge PRs** — deliver for human review and merge
- **ALWAYS ensure teammates follow full SDLC** — if a teammate skips steps, message them directly with what they missed. If stuck after 2 retries, report to user. If stopped on error, give recovery instructions or spawn a replacement.
