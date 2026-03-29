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

Identify:
- Total tasks and their dependencies
- Which tasks can run in parallel vs. which must be sequential
- A sensible teammate-to-task mapping (1 teammate can own 1-3 related tasks)
- Aim for 5-6 tasks per teammate

### STEP 1: Create the Agent Team

Tell Claude to create a team in natural language. Describe the team structure, roles, and what each teammate should focus on. Claude handles spawning teammates and setting up the shared task list.

Example prompt to create the team:

```
Create an agent team called "<short-name>" to implement <description>.

Spawn teammates:
- "<name>-agent": <what they own — files, components, endpoints>
- "<name>-agent": <what they own>
- "<name>-agent": <what they own>

Each teammate should use the /sdlc skill and follow ALL steps in order.
Require plan approval before any teammate makes changes.
```

**Key parameters to specify:**
- Number of teammates and their names
- What each teammate owns (files, components, areas)
- Model to use for teammates (e.g., "Use Sonnet for each teammate")
- Whether to require plan approval before implementation

### STEP 2: Set Up Tasks

The shared task list coordinates work across the team. Create tasks for every piece of work identified in Step 0. Tasks have three states: pending, in progress, and completed. Tasks can depend on other tasks — blocked tasks won't be claimed until dependencies complete.

Tell the lead to create tasks with clear descriptions:

```
Create tasks for the team:
1. "<task title>" — <what to implement, acceptance criteria, which spec task it maps to>
   Depends on: none
2. "<task title>" — <what to implement, acceptance criteria>
   Depends on: task 1
3. "<task title>" — <what to implement, acceptance criteria>
   Depends on: none
```

**Task descriptions MUST include:**
- Exactly what to implement (files, components, endpoints)
- Acceptance criteria
- Which spec task(s) it maps to (if from a spec)
- Explicit instruction: "Use `/sdlc` skill and follow ALL steps in order"

Teammates self-claim unblocked tasks from the shared list. When a teammate completes a task that others depend on, blocked tasks unblock automatically.

### STEP 3: Coordinate (Your Main Loop)

**You are the team lead. Your ONLY actions are:**

1. **Monitor** — Watch for teammate messages reporting PR completion. Use `Shift+Down` to cycle through teammates in in-process mode, or click panes in split-pane mode.
2. **Steer** — Message teammates directly to redirect approaches that aren't working or give additional context.
3. **Inspect** — Review each PR for completeness:
   ```bash
   gh pr view <NUMBER> --json title,body,additions,deletions,files,reviews,statusCheckRollup
   gh pr diff <NUMBER>
   ```
4. **Validate** — Verify before marking ready:
   - [ ] Implementation matches the spec/task requirements
   - [ ] Copilot/CodeRabbit feedback has been received AND resolved
   - [ ] CI checks are passing
   - [ ] Spec tasks marked complete in PR
   - [ ] PR description is clear and accurate
5. **Report** — When ALL checks pass, notify the user that the PR is ready for their review and merge
6. **Unblock** — After a dependency PR is merged by the user, notify waiting teammates
7. **Repeat** — Continue until all tasks are complete

### STEP 4: Shutdown

When all tasks are complete and all PRs are ready (or merged by the user):

1. Verify all spec tasks are marked done
2. Ask all teammates to shut down (teammates can approve or reject with explanation)
3. Clean up the team via the lead (teammates should NOT run cleanup)
4. Report final summary to user:
   - List all PRs with status (ready for review / merged)
   - Note any PRs still awaiting user merge
   - Summarize what was delivered

---

## Team Lead Rules (NON-NEGOTIABLE)

- **NEVER write code yourself** — all implementation goes through teammates
- **NEVER create branches or commits** — teammates handle this via SDLC
- **NEVER skip PR inspection** — every PR gets reviewed before marking ready
- **NEVER merge PRs** — PRs are delivered for human review and merge
- **NEVER mark a teammate's PR as ready** until you've inspected it
- **ALWAYS ensure teammates follow full SDLC** — if a teammate skips steps, message them directly

## Handling Teammate Issues

If a teammate reports problems or skips SDLC steps:

1. **Message them directly** telling them exactly what step they missed
2. **Do NOT do the work for them** — they must follow the workflow
3. If a teammate is stuck after 2 retries, report to user and ask for guidance
4. If a teammate stops on an error, either give them instructions to recover or spawn a replacement

## Tips

- **Avoid file conflicts** — break work so each teammate owns different files
- **Start with 3-5 teammates** — more adds coordination overhead with diminishing returns
- **Require plan approval** for complex or risky tasks so you can review before implementation
- **Use broadcast sparingly** — it messages all teammates and costs scale with team size
