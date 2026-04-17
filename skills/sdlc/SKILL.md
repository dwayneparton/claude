---
name: sdlc
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This skill provides the step-by-step workflow for orchestrating the complete software development lifecycle using specialized agents. Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# SDLC Workflow Skill

This skill defines the workflow for all coding tasks. Every step exists for a reason — each one earns the right to move to the next. Move with intention: match the ceremony to the blast radius.

## Core Rules

- NEVER skip tests (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ALWAYS fix, replace, refactor, or remove tests — never skip them
- NEVER merge PRs — PRs are delivered ready for human review and merge

### Test Policy

**NEVER skip tests.** If a test cannot pass:

- **Fix it** — Update assertions to match correct behavior
- **Replace it** — Write a new test that properly validates the behavior
- **Refactor it** — Restructure to test what's actually testable
- **Remove it** — Delete entirely if it tests something that no longer exists

If tests require infrastructure (auth, database, external services), SET UP that infrastructure. Do not skip tests because setup is hard.

---

## STEPS

### STEP 0: Setup

#### 0.1 Gauge the Work

Assess the task's complexity and blast radius. This determines how much ceremony the task needs.

| Size         | Examples                                                              | Blast radius                                       | Steps                                      |
| ------------ | --------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------ |
| **Small**    | Typo, config change, one-line fix, docs update, simple rename         | Minimal — trivially reverted                       | 0 → 1 → 4 → 4.5 → 5 → 8                    |
| **Standard** | Feature, bug fix, refactor, new component, API change                 | Moderate — affects real behavior or multiple files | 0 → 1 → 2 → 3 → 4 → 4.25 → 4.5 → 5 → 6 → 8 |
| **Large**    | Multi-system change, breaking API, data migration, security-sensitive | High — failure is expensive and hard to reverse    | All steps with extra rigor in 2-3          |

When in doubt, size up. It's cheaper to over-prepare than to ship a bad change.

---

### STEP 1: Workspace Preparation

**Create clean feature branch BEFORE any implementation.**

#### 1.1 Check for uncommitted changes

```bash
git status
```

If uncommitted changes exist:

- Ask user: "Uncommitted changes found. Stash them or abort?"
- If stash: `git stash push -m "SDLC auto-stash"`
- If abort: STOP

#### 1.2 Sync and create branch

```bash
git fetch origin
git checkout main
git pull origin main
git checkout -b <type>/<short-description>
```

Branch types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

**DO NOT PROCEED until branch is created.**

---

### STEP 2: Requirements Analysis (Standard + Large)

**Skip for Small tasks — proceed directly to Step 4.**

**Check for existing specs first.** If a spec file was referenced in the task description, or if a relevant spec exists in `specs/` (e.g., from `/spec-writer`), read it. A spec that covers the requirements and has a task checklist satisfies this step — link to it and proceed directly to Step 3 (or Step 4 if the spec also includes a detailed plan).

Launch the requirements-analyzer agent:

```
Agent tool:
  subagent_type: "requirements-analyzer"
  prompt: "Analyze requirements for: [TASK DESCRIPTION]

           - Analyze task/issue/error to understand requirements
           - Use WebSearch to research technologies
           - Use WebFetch for referenced URLs
           - Use AskUserQuestion for ambiguities
           - Analyze codebase for patterns

           Output: Complete requirements with acceptance criteria"
  description: "Analyze requirements"
```

For GitHub issues, fetch first:

```bash
gh issue view [NUMBER] --json title,body,labels,comments
```

**DO NOT PROCEED until requirements are complete.**

---

### STEP 3: Planning (Standard + Large)

**Skip for Small tasks — proceed directly to Step 4.**

Launch the planner agent:

```
Agent tool:
  subagent_type: "planner"
  prompt: "Create implementation plan for:

           [REQUIREMENTS FROM STEP 2]

           - Break into atomic steps
           - Identify files to modify
           - Determine test requirements
           - Evaluate what this opens up, not just what it solves
           - Flag if multiple PRs needed

           Output: Numbered implementation steps"
  description: "Plan implementation"
```

For GitHub issues, also update the issue:

```bash
gh issue edit [NUMBER] --add-label "in-progress"
gh issue comment [NUMBER] --body "[PLAN SUMMARY]"
```

**DO NOT PROCEED until plan exists.**

---

### STEP 4: Implementation

**Implement the plan.** For Standard/Large tasks, follow the plan from Step 3. For Small tasks, implement the change directly.

Requirements:

- Atomic commits (format: `type(scope): message`)
- Follow existing patterns in the codebase
- Run tests as you go
- Do NOT create a PR yet

Verify commits exist:

```bash
git log --oneline -5
git diff main --stat
```

**DO NOT PROCEED until commits exist on feature branch.**

---

### STEP 4.25: Test Coverage (Standard + Large)

**Skip for Small tasks — proceed directly to Step 4.5.**

**Run the test-coverage skill to verify your changes are properly tested.**

```
Skill tool: skill="test-coverage"
```

This ensures:

- New code has tests covering happy path, error cases, and edge cases
- Existing test patterns are followed
- Coverage is verified with available tooling

Testing earns the right to ship with confidence. This step is not optional for Standard and Large tasks.

Fix any coverage gaps, commit the fixes, then proceed to code cleanup.

**DO NOT PROCEED until test coverage is addressed.**

---

### STEP 4.5: Code Cleanup (simplify)

**Run the simplify skill before creating the PR.**

```
Skill tool: skill="simplify"
```

This reviews all changed code for:

- **Reuse** — duplicated logic that could use existing utilities
- **Quality** — copy-paste patterns, leaky abstractions, unnecessary nesting
- **Efficiency** — redundant computations, missed concurrency, hot-path bloat

Fix any issues found, commit the fixes, then proceed to PR creation.

**DO NOT PROCEED until simplify has run and any findings are addressed.**

---

### STEP 5: Pull Request Creation

**Use the github-pr skill to create a PR.**

```
Skill tool: skill="github-pr"
```

The skill handles pushing the branch, PR creation, and description formatting.

**Capture the PR number for remaining steps.**

**DO NOT PROCEED until PR is created.**

---

### STEP 6: Review & Quality (Standard + Large)

**Skip for Small tasks — proceed directly to Step 8.**

#### 6.1 Self-Review

Review the PR diff for:

- Code quality and correctness
- Test coverage gaps
- Security issues
- Performance concerns

```bash
gh pr diff [NUMBER]
```

If issues are found, fix them and commit before proceeding.

#### 6.2 Handle Automated Review Feedback (Copilot/CodeRabbit)

Resolve any existing unresolved automated review threads:

```
Skill tool: skill="github-resolve"
```

**DO NOT PROCEED until all review issues resolved.**

---

### STEP 8: Finalization

#### 8.1 Final Verification

```bash
gh pr view [NUMBER] --json state,mergeable,reviews,statusCheckRollup
```

Confirm:

- PR is open and mergeable
- All checks pass (if CI was run)
- No unresolved comments

#### 8.2 Update Task Tracking Docs

If a spec file, project doc, or task list was referenced in the original request, update it to mark completed tasks:

- Check off completed items (e.g., `- [ ]` -> `- [x]`)
- Only mark items that are **actually addressed by the changes in this PR**
- Commit the doc update to the PR branch

If no relevant tracking doc exists, skip this step.

#### 8.3 Update Issue (if applicable)

```bash
gh issue comment [NUMBER] --body "PR #[PR_NUMBER] is ready for review: [URL]"
gh issue edit [NUMBER] --add-label "ready-for-review"
```

#### 8.4 Report to User

```
PR #[NUMBER] ready: [URL]

Changes:
- [summary bullets]

Ready for your review.
```

**NEVER merge PRs. PRs are delivered for human review and merge.**

---

## Workflow Variations

### GitHub Issue URL

1. STEP 0: Auth + gauge
2. STEP 1: Branch as `fix/issue-123-description`
3. Fetch issue: `gh issue view [NUMBER] --json title,body,labels,comments`
4. Remaining steps per task size

### Quick Fix (fix:, error:, bug: prefix)

1. STEP 0: Auth + gauge (likely Small or Standard)
2. STEP 1: Branch as `fix/short-error-desc`
3. Remaining steps per task size

### Multi-PR Tasks (Solo)

1. Complete the workflow for the first PR
2. **STOP** — Wait for user to review and merge
3. Only after the first PR is merged: Start the next PR

**When working solo, keep one PR open at a time.** This keeps the feedback loop tight and avoids merge conflicts. This rule does NOT apply when working as part of a `/team` — coordinated parallel PRs are expected in that context.

---

## Error Handling

| Error        | Action                                                |
| ------------ | ----------------------------------------------------- |
| Agent fails  | Retry once with adjusted params, then STOP and report |
| Git conflict | STOP, report to user, wait for resolution             |
| Tests fail   | Fix, rerun until pass                                 |
| Auth fails   | STOP, tell user to run `gh auth login`                |

---

## Agent & Skill Reference

| Step | Tool  | Name                    | When             |
| ---- | ----- | ----------------------- | ---------------- |
| 2    | Agent | `requirements-analyzer` | Standard + Large |
| 3    | Agent | `planner`               | Standard + Large |
| 4.25 | Skill | `test-coverage`         | Standard + Large |
| 4.5  | Skill | `simplify`              | Always           |
| 5    | Skill | `github-pr`             | Always           |
| 6.2  | Skill | `github-resolve`        | Standard + Large |

---

## Success Criteria

Workflow complete when ALL true:

- Feature branch created from main
- Requirements documented (Standard + Large)
- Plan created (Standard + Large)
- Code implemented with atomic commits
- Test coverage verified (Standard + Large)
- Code reviewed via /simplify (reuse, quality, efficiency)
- PR created with description
- Self-review done, issues fixed (Standard + Large)
- Automated review feedback resolved (Standard + Large)
- Task tracking docs updated (if applicable)
- PR delivered ready for human review and merge
