---
name: sdlc
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This skill provides the step-by-step workflow for orchestrating the complete software development lifecycle using specialized agents. Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# SDLC Workflow Skill

This skill defines the workflow for all coding tasks. Every step exists for a reason — each one earns the right to move to the next. Move with intention: match the ceremony to the blast radius.

The output of this workflow is a **reviewable PR**: one coherent intent, sized so a human can hold it in their head, attacked by an adversarial reviewer before it ever reaches GitHub (every PR of substance; docs-only and trivial changes excepted). Bigger is not better. When the work grows past what one PR can carry, it becomes a stack.

## Core Rules

- NEVER skip tests (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ALWAYS fix, replace, refactor, or remove tests — never skip them
- NEVER merge PRs — PRs are delivered ready for human review and merge
- NEVER push before the review gate (Step 7) has run — nothing leaves the machine unreviewed. Every PR of substance needs at least one adversarial Codex review that passed; only docs-only or trivial changes skip it (see 7.0)
- NEVER request a Copilot review. Copilot reviews only when the repo triggers it automatically; when it does, its feedback is addressed in Step 9

### Required CLIs

These CLIs are used. Assume each is installed and authenticated — do NOT run preflight checks like `gh auth status` or `codex login status`. Handle failures when they happen:

| CLI | Used for | Not installed | Auth error |
|-----|----------|---------------|------------|
| `gh` | All GitHub operations | STOP — install from https://cli.github.com | STOP — run `gh auth login` |
| `codex` | Adversarial review (Step 7) | STOP — install from https://github.com/openai/codex (`brew install codex`) | STOP — run `codex login` |
| `gh stack` | Stacked PRs (Steps 3, 7, 8, 9) | Install it yourself: `gh extension install github/gh-stack` — no need to stop | (uses `gh` auth) |

After the user fixes the problem, resume where you stopped.

### Model Selection

Do not accept whatever model a tool defaults to. Pick the model for the job, and pick it here so it is easy to change in one place:

| Role | Tool | Model | Why |
|------|------|-------|-----|
| Requirements analysis | Agent `general-purpose` | `sonnet` | Fetching, reading, and synthesis. Fast is right. |
| Planning | Agent `Plan` | `opus` | Architectural judgment: where code belongs, what to split. Worth the stronger model. |
| Implementation, triage, fixes | This session | (as configured) | You own the change and the decisions about it. |
| Simplify pass | Agent `general-purpose` (fresh, not a fork) | `sonnet` | A cleanup pass, by design. Fresh context keeps it unbiased toward the current implementation. |
| Adversarial review | `codex exec` | `gpt-5.6-sol`, reasoning effort `high` | The review is the point of the step. Use the strongest reasoning available, from a different model family than the author, so it brings a perspective the author does not have. |

If the user tells you a different model for a role, use it for the rest of the session and say so in the final report.

### Test Policy

**NEVER skip tests.** If a test cannot pass:
- **Fix it** — Update assertions to match correct behavior
- **Replace it** — Write a new test that properly validates the behavior
- **Refactor it** — Restructure to test what's actually testable
- **Remove it** — Delete entirely if it tests something that no longer exists

If tests require infrastructure (auth, database, external services), SET UP that infrastructure. Do not skip tests because setup is hard.

---

## STEPS

### STEP 0: Gauge the Work

**Execute FIRST before anything else.**

Assess the task's complexity and blast radius. This determines how much ceremony the task needs.

| Size | Examples | Blast radius | Steps |
|------|----------|-------------|-------|
| **Small** | Typo, config change, one-line fix, docs update, simple rename | Minimal — trivially reverted | 0 → 1 → (2.1 if from an issue) → 4 → 6 → 7 (Codex unless docs-only or trivial) → 8 → 9 → 10 |
| **Standard** | Feature, bug fix, refactor, new component, API change | Moderate — affects real behavior or multiple files | 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 |
| **Large** | Multi-system change, breaking API, data migration, security-sensitive | High — failure is expensive and hard to reverse | All steps with extra rigor in 2, 3, and 7; almost always a stack |

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

**Small tasks skip 2.2 and proceed to Step 4 — but 2.1 still runs whenever the input is a GitHub issue.** An issue is never accepted on faith, however small the fix looks.

#### 2.1 Validate the task before accepting it (any size, when working from an issue)

An issue is not automatically real, and a request is not automatically right. Before writing requirements, pressure-test the premise. This is a deep dive, not a skim.

For a **GitHub issue** (`gh issue view [NUMBER] --json title,body,labels,comments`):

- **Reproduce it.** Run the scenario the issue describes. When it is pertinent — a bug, a regression, a wrong result — write a **failing test that proves the issue** before anything else. Keep that test; it becomes the regression test and the anchor for the fix. If you cannot reproduce it, say so with what you tried.
- **Check it is not already solved.** Search open and closed issues and PRs (`gh issue list --search`, `gh pr list --state all --search`), and the code on `main` — the fix may have landed, be in flight, or already exist as a utility or setting nobody found.
- **Check it belongs here.** Is the defect in this repo's code, or in a dependency, a sibling service, configuration, or the caller? A symptom surfacing here is not the same as a cause living here. Fixing it in the wrong layer is how platforms accrete app-specific patches.
- **Check the ask is the right ask.** Issues often prescribe a fix. Separate the underlying problem from the proposed solution, and ask whether a better alternative exists.

For a **feature or change request**, do the same in spirit: confirm the capability does not already exist, that it aligns with the repo's direction (read `VISION.md`, `AGENTS.md`, and `CLAUDE.md` when present), and that this repo is where it belongs.

Outcomes:

- **Confirmed** — record the reproduction (and the failing test) and proceed to 2.2.
- **Not reproducible, already solved, belongs elsewhere, or not worth doing** — STOP. Report the evidence to the user with a recommended disposition (close, transfer, rescope, or proceed anyway). Do not close or relabel the issue yourself; that is the user's call. Resume only on their answer.

#### 2.2 Analyze requirements

**Check for existing specs first.** If a spec file was referenced in the task description, or if a relevant spec exists in `specs/`, read it. A spec that covers the requirements and has a task checklist satisfies this step — link to it and proceed directly to Step 3 (or Step 4 if the spec also includes a detailed plan).

Launch a requirements agent:

```
Agent tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: "Analyze requirements for: [TASK DESCRIPTION]

           - Analyze task/issue/error to understand requirements
           - Use WebSearch to research technologies
           - Use WebFetch for referenced URLs
           - Analyze codebase for patterns
           - List open questions and ambiguities instead of guessing

           Output: Complete requirements with acceptance criteria, plus open questions"
  description: "Analyze requirements"
```

For GitHub issues, fetch first:
```bash
gh issue view [NUMBER] --json title,body,labels,comments
```

Ask the user about any open questions with AskUserQuestion before moving on.

**DO NOT PROCEED until requirements are complete.**

---

### STEP 3: Planning (Standard + Large)

**Skip for Small tasks — proceed directly to Step 4.**

Launch the Plan agent:

```
Agent tool:
  subagent_type: "Plan"
  model: "opus"
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

### STEP 5: Test Coverage (Standard + Large)

**Skip for Small tasks — proceed directly to Step 6.**

Verify the changes on this branch (`git diff main`) are properly tested:
- New and changed code has tests covering the happy path, error cases, and edge cases
- Tests follow the project's existing test patterns, location, and naming
- Coverage is checked with the project's tooling when it has some (e.g. a `coverage` script)

Testing earns the right to ship with confidence. This step is not optional for Standard and Large tasks.

Fix any coverage gaps, commit the fixes, then proceed to code cleanup.

**DO NOT PROCEED until test coverage is addressed.**

---

### STEP 6: Code Cleanup (simplify)

**Run the built-in `/simplify` skill in a fresh agent, not this session, so it is not biased toward the current implementation.**

```
Agent tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: "Run the simplify skill (Skill tool: skill=\"simplify\") on the changes in `git diff main`. Commit any fixes. Report what you changed."
  description: "Simplify pass"
```

This reviews all changed code for:
- **Reuse** — duplicated logic that could use existing utilities
- **Quality** — copy-paste patterns, leaky abstractions, unnecessary nesting
- **Efficiency** — redundant computations, missed concurrency, hot-path bloat

Review what it changed, then proceed to the review gate.

**DO NOT PROCEED until simplify has run and any findings are addressed.**

---

### STEP 7: Adversarial Review Gate (Codex)

**Nothing is pushed until this gate passes.** Codex, a different model family from the author, plays adversary: its job is to find reasons this change should not ship as-is, not to approve it. You triage what it finds, fix what is right, decline what is not with a reason, bring direction questions to the user, then decide whether the change has been challenged enough or needs another adversarial round.

Review depth scales with the PR. Every PR of substance gets at least one round; how many more is your call (7.4). The PR is reviewed again after it goes up (Copilot on GitHub where the repo triggers it automatically, and Codex again on the way to production), so this gate does not need to be exhaustive. It needs to catch what is worth catching before a human spends attention on it.

#### 7.0 Decide whether the PR needs an adversarial review

Decide; do not ask. The user can override.

- **No adversarial review:** the change is docs-only (Markdown, comments, docstrings, with no code, config, or build effect) or tiny with no behavior change (typo, formatting, a rename the compiler or type-checker fully verifies). Review the diff yourself against the prompt's questions, record `Adversarial review: skipped — <reason>` for the PR body and report, and go to Step 8.
- **At least one Codex round:** everything else. This includes any change to behavior, config, dependencies, CI, tests, or shared code, and Small changes that touch any of those. When in doubt, run it.

#### 7.1 Prepare

1. **Green first.** Run the project's tests, lint, and type-check. Reviewers should read working code; fix failures before asking anyone to review.
2. **Capture the intent and surface.** Write down, in your own words: one to three sentences of what this change is for and the approach it takes; the list of files it touches (`git diff main --name-only`); and its size (`git diff main --shortstat`). Every finding is measured against these.
3. **Write the review prompt** to a temp directory outside the repo so it cannot be committed. Shell state does not survive between Bash tool calls, so the directory is derived from the branch name and **every command below re-derives it on its first line**:

```bash
REVIEW_DIR="${TMPDIR:-/tmp}/sdlc-review/$(git branch --show-current | tr '/' '-')"; mkdir -p "$REVIEW_DIR"
```

Fill in the template below and save it as `$REVIEW_DIR/prompt.md`, overwriting it each round.

```markdown
You are an adversarial reviewer. A different model wrote this change and believes it is ready to become a pull request. Your job is to find out why it is not: argue against it, attack its premise, and hunt for the failure the author did not consider. You are not here to approve. Approval is what is left when your best attacks fail.
Read-only: do NOT modify any files. Use git and file reads to inspect.

## The change
- Base branch: main. Review everything in `git diff main` (and `git log main..HEAD`).
- Intent: <INTENT STATEMENT>
- Task / issue: <LINK OR DESCRIPTION, OR "none">
- Files touched: <LIST>
- Size: <SHORTSTAT>
- Repo direction: read VISION.md, AGENTS.md, and CLAUDE.md at the repo root if present, and infer conventions from the surrounding code.

<ROUND 2+ ONLY:
## Since the last round
- Fixed: <one line each — the finding and how it was fixed>
- Declined: <one line each — the finding and why>
- Not examined closely last round: <from the previous coverage line>
Attack the fixes first; they have not been reviewed. Then the areas not examined. Do not re-raise declined items unless you have new evidence.>

## Attack it, in priority order
1. **Should this change exist?** Argue the case against it. Is the problem real? Is it already solved elsewhere in this repo (a utility, setting, or pattern the author missed)? Is there a materially better alternative — including "do nothing" or "fix it in the layer where the cause lives"? Attack the premise, not just the code.
2. **Alignment.** Does this fit the direction of the repo (vision, conventions, existing architecture)? Does every part of the diff serve the stated intent, or does some of it drift into a different change?
3. **Where does this code belong?** Implementation vs platform: is feature-specific logic leaking into shared/platform layers, or reusable logic buried inside a feature? Does it duplicate or near-duplicate something that exists? Would a maintainer looking for this a year from now find it where it is?
4. **What breaks?** Construct the inputs, states, orderings, and environments that make this fail: edge cases, concurrency, partial failure, bad or missing data, upgrade and rollback, callers the author did not check.
5. **What is missing?** Untested paths, failure modes that can actually happen, compatibility/migration/rollout concerns, docs or config this change makes stale.
6. **Reviewability.** Is this one coherent idea a reviewer can hold in their head? Should it be split into a stack of smaller PRs? Is anything in the diff larger than it needs to be?

## Ground rules
- Adversarial is not speculative. Every finding needs evidence in the code, and every defect needs a concrete failing scenario. Verify by reading the code and its callers. A wrong "this will crash" costs more than silence.
- If an attack fails, drop it. Do not report what you tried and could not break.
- No style nits, no reformatting, no defensive code for scenarios that cannot occur, no "for completeness" tests of behavior this change did not touch.

## Output format
Numbered findings. For each:
`<file>:<line>` — **<blocker|high|medium|low>** — <needed|alignment|placement|breaks|missing|reviewability>
Claim: <one sentence>. Evidence: <what in the code shows it>. Fix: <one line>.

Then a **Verdict**: one of `ready`, `ready after fixes`, or `rethink`, with a short paragraph explaining why — and, for `rethink`, the alternative you would take.

Then one **Coverage** line: what you attacked closely, and what you did not.
```

#### 7.2 Run Codex

Run it as a background Bash command (`run_in_background: true`); you are re-invoked when it finishes. Do not poll. Replace `<N>` with the round number so earlier rounds are kept.

```bash
REVIEW_DIR="${TMPDIR:-/tmp}/sdlc-review/$(git branch --show-current | tr '/' '-')"
codex exec -s read-only -C "$(git rev-parse --show-toplevel)" \
  -m gpt-5.6-sol -c 'model_reasoning_effort="high"' \
  -o "$REVIEW_DIR/codex-<N>.md" - < "$REVIEW_DIR/prompt.md" > "$REVIEW_DIR/codex-<N>.log" 2>&1
```

Every round is a fresh `codex exec` session with no memory of earlier rounds; the "Since the last round" section is the only carry-over. Read `codex-<N>.md` when it completes. It holds only the final answer; the `.log` holds tool chatter and errors. If Codex errors (CLI missing, auth, model unavailable), handle it per "Required CLIs".

#### 7.3 Triage — critically

For every finding:

- **Verify before you act.** An adversarial reviewer is told to find problems, so expect some that are not there. It states things confidently that are sometimes false. Confirm each claim by reading the surrounding code, callers, or types, or by running the relevant test. If it does not hold, decline it and say specifically why.
- **Classify by scope**, against the intent statement and touched surface from 7.1:
  - **Accept** — a real defect, a missing piece the intent requires, a duplication of something that exists, or code that belongs in a different layer and moving it is small. Fix it.
  - **Decline** — stylistic, speculative, defensive code for impossible cases, "for completeness" work, or a claim that failed verification. Record the reason.
  - **Flag for the user** — anything that would change the PR's *direction*: "this isn't needed", "this is solved by X", "this belongs in another repo/layer", "there is a better approach", "split this into a stack", or a fix that would grow the PR beyond a reviewable size or add files the plan never touched. **Do not act on these on your own.** Also flag any `rethink` verdict.
- **Bloat budget.** Review-driven fixes should be small relative to the change. If the accepted set would grow the diff by more than roughly 20% or push it past a reviewable size, the largest items are probably direction questions — move them to flagged.

**Ask the user about flagged items** with AskUserQuestion, one question per item, up to four per call. Each question says which round raised it, where, what it asks, why you flagged it, and your recommendation as the first option marked "(Recommended)". Options: **Take it**, **Decline it**, **Split it out** (a follow-up PR or a new stack layer). "Other" is available automatically — if the user says to stop, stop and report.

Direction questions are the most valuable output of this gate. Do not soften them or bury them in a list of nits.

#### 7.4 Fix, then decide whether another adversarial round is needed

1. Implement the accepted items and any "take it" answers. Run tests, lint, type-check. Commit with the appropriate type (`fix(...)`, `refactor(...)`, `test(...)`), not a generic "address review" message.
2. **Re-check size.** If the diff has grown past a reviewable PR, restructure into a stack now (see `github-pr` step 4) — before anything is pushed. For a stack, also verify **each layer is green on its own**: check out every layer bottom-up (`gh stack bottom`, then `gh stack up`) and run tests, lint, and type-check there. An upper layer must never be what makes a lower one pass.
3. **Decide whether the PR needs another round.** This is your call. Base it on what the last round showed, not on habit. Run another round (7.1 prompt refresh with "Since the last round" → 7.2 → 7.3) when any of these holds:
   - An accepted fix changed behavior, structure, or public surface. Nobody has attacked the fix yet.
   - The round found a `blocker` or `high`, or the verdict was `rethink`. A reviewer that found one serious problem has often not found the last one.
   - The change is Large or security-sensitive (auth, crypto, permissions, data migration, PII, billing) and only one round has run.
   - The coverage line says a risky part of the diff was not examined closely.

   Stop when none of these hold: no unaddressed `blocker`, `high`, or `medium`, the verdict is `ready` or `ready after fixes` with those fixes done, and every fix was trivial (typos, comments, renames). Record in one line why you stopped where you did.
4. **Cap: 3 rounds.** Past that, the reviewer is usually nitpicking or contradicting itself. At the cap, stop the loop and **ask the user** with AskUserQuestion, listing what is still open: **Proceed to PR with the remaining findings logged** (Recommended when what remains is low/medium and each has a stated reason), **Run one more round**, or **Stop here**. Only their answer moves you past this step.

#### 7.5 Record the review log

Keep a short log for the final report (Step 10):

```
## Pre-PR adversarial review
Reviewer: Codex (gpt-5.6-sol, high) · N round(s) — <why N was enough>
Accepted: <one line each — what changed and why>
Declined: <one line each — what was asked and why not>
Decisions: <one line each — what the user was asked, what they chose>
Final verdict: <verdict>
```

When 7.0 skipped the review, the log is the single `Adversarial review: skipped — <reason>` line.

The one-line version in the PR body tells the human reviewer what was already attacked, so they can spend their attention elsewhere.

**DO NOT PROCEED until the gate has exited cleanly, 7.0 skipped it, or the user has chosen to proceed at the round cap.**

---

### STEP 8: Pull Request Creation

**Use the github-pr skill to create a PR.**

```
Skill tool: skill="dp:github-pr"
```

The skill handles pushing the branch, PR creation, and description formatting. Add the review log to the PR body as one line, e.g. `Adversarial review: Codex · 2 rounds · ready — 3 fixed, 1 declined`, and keep the detail for the report. For a stack, confirm every layer passed its own checks (7.4 step 2), then push and open the layered PRs with `gh stack submit` instead of a single `gh pr create`, and put that line in the bottom PR with a one-line pointer in each layer above.

**Capture the PR number for remaining steps.**

**DO NOT PROCEED until PR is created.**

---

### STEP 9: PR Review Loop

**Runs for every size.** The pre-PR gate reviewed the code. This step gets the *PR* ready for human review: CI green on the pushed head, plus GitHub Copilot's review and any human or bot comments already on the PR, addressed.

**Never request Copilot.** Copilot reviews only when the repo triggers it automatically. When it does, address its feedback. When it does not, skip the Copilot part. Always pass `--no-request`:

```
Skill tool: skill="dp:github-resolve"  args="--no-request"
```

For a stack, run it on each PR bottom-up, finishing one layer before moving to the next.

In that mode the skill never request or re-request Copilot. They wait briefly for an automatic review, address it if one arrives, follow automatic re-reviews on later pushes when the repo does that, and otherwise run the CI gate and address whatever comments are already there. They pause to ask the user whenever a comment would change the PR's approach or scope. Follow their exit conditions; do not extend the loop past them.

---

### STEP 10: Report to User

```
PR #[NUMBER] ready: [URL]

Changes:
- [summary bullets]

Adversarial review: Codex · [N] round(s) · final verdict [verdict] — [why N was enough]
- Accepted: [count] · Declined: [count] · Decisions you made: [count]
- [anything still open for the human reviewer, or "nothing open"]

PR review loop: [github-resolve exit reason — e.g. Copilot addressed, Copilot not triggered], CI [status]

Ready for your review.
```

If 7.0 skipped the adversarial review, replace that block with the one-line skip reason.

**NEVER merge PRs. PRs are delivered for human review and merge.**

---

## Workflow Variations

### GitHub Issue URL

1. STEP 0: Gauge the work
2. STEP 1: Branch as `fix/issue-123-description`
3. Fetch issue: `gh issue view [NUMBER] --json title,body,labels,comments`
4. Remaining steps per task size

### Quick Fix (fix:, error:, bug: prefix)

1. STEP 0: Gauge the work (likely Small or Standard)
2. STEP 1: Branch as `fix/short-error-desc`
3. Remaining steps per task size

### Multi-PR Tasks (Solo)

1. Complete the workflow for the first PR
2. **STOP** — Wait for user to review and merge
3. Only after the first PR is merged: Start the next PR

**When working solo, keep one PR open at a time.** This keeps the feedback loop tight and avoids merge conflicts.

---

## Error Handling

| Error | Action |
|-------|--------|
| Agent fails | Retry once with adjusted params, then STOP and report |
| Git conflict | STOP, report to user, wait for resolution |
| Tests fail | Fix, rerun until pass |
| `gh` / `codex` not installed or not authenticated | STOP, per "Required CLIs" |
| Codex model unavailable (`-m` rejected) | Fall back to Codex's default model for this run, and say so in the report |
| Codex produces no output or times out | Retry once; if it fails again, STOP and report — never push a PR of substance unreviewed without the user's say-so |
| Review gate hits the round cap | Stop the loop, carry remaining findings into the PR body and report |

---

## Agent & Skill Reference

| Step | Tool | Name | Model | When |
|------|------|------|-------|------|
| 2 | Agent | `general-purpose` | sonnet | Standard + Large |
| 3 | Agent | `Plan` | opus | Standard + Large |
| 6 | Agent → Skill | `general-purpose` running built-in `simplify` | sonnet | Always |
| 7 | CLI | `codex exec` | gpt-5.6-sol (high) | Every PR except docs-only or trivial; extra rounds by judgment (7.4) |
| 8 | Skill | `github-pr` | — | Always |
| 9 | Skill | `github-resolve` with `--no-request` (per PR for a stack) | — | Always |

---

## Success Criteria

Workflow complete when ALL true:
- Feature branch created from main
- Requirements documented (Standard + Large)
- Plan created (Standard + Large)
- Code implemented with atomic commits
- Test coverage verified (Standard + Large)
- Code cleaned via /simplify in a fresh agent (scope, reuse, quality, efficiency, comments)
- Adversarial review gate passed: at least one Codex round for any PR of substance, findings triaged, accepted fixes committed, direction questions decided by the user, the decision to stop at N rounds recorded, review log written (docs-only or trivial: skip reason recorded)
- PR (or stack) created with a concise description and the one-line review summary
- PR review loop complete: CI green, and Copilot's automatic review addressed if one was triggered — Copilot never requested
- PR delivered ready for human review and merge
