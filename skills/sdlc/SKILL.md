---
name: sdlc
description: "MUST BE LOADED for any coding task: implementing features, fixing bugs, writing code, refactoring, or making changes. This skill provides the step-by-step workflow for orchestrating the complete software development lifecycle using specialized agents. Load this skill when the user asks to 'add', 'create', 'build', 'fix', 'update', 'change', 'implement', or 'refactor' anything."
---

# SDLC Workflow Skill

This skill defines the workflow for all coding tasks. Every step exists for a reason — each one earns the right to move to the next. Move with intention: match the ceremony to the blast radius.

The output of this workflow is a **reviewable PR**: one coherent intent, sized so a human can hold it in their head, pressure-tested by independent reviewers before it ever reaches GitHub (for Small changes, at the user's discretion). Bigger is not better. When the work grows past what one PR can carry, it becomes a stack.

## Core Rules

- NEVER skip tests (`test.skip`, `it.skip`, `describe.skip` are FORBIDDEN)
- ALWAYS fix, replace, refactor, or remove tests — never skip them
- NEVER merge PRs — PRs are delivered ready for human review and merge
- NEVER push before the review gate (Step 7) has run — nothing leaves the machine unreviewed. For Standard and Large that means both external reviews passed; for Small it means the user chose external, local, or skip in 7.0

### Required CLIs

Three CLIs are used. Assume each is installed and authenticated — do NOT run preflight checks like `gh auth status` or `codex login status`. Handle failures when they happen:

| CLI | Used for | Not installed | Auth error |
|-----|----------|---------------|------------|
| `gh` | All GitHub operations | STOP — install from https://cli.github.com | STOP — run `gh auth login` |
| `codex` | External review (Step 7) | STOP — install from https://github.com/openai/codex (`brew install codex`) | STOP — run `codex login` |
| `copilot` | External review (Step 7) | STOP — install from https://github.com/github/copilot-cli (`brew install copilot-cli`) | STOP — run `copilot login` |
| `gh stack` | Stacked PRs (Steps 3, 7, 8, 9) | Install it yourself: `gh extension install github/gh-stack` — no need to stop | (uses `gh` auth) |

After the user fixes the problem, resume where you stopped.

### Model Selection

Do not accept whatever model a tool defaults to. Pick the model for the job, and pick it here so it is easy to change in one place:

| Role | Tool | Model | Why |
|------|------|-------|-----|
| Requirements analysis | Agent `requirements-analyzer` | `sonnet` | Fetching, reading, and synthesis. Fast is right. |
| Planning | Agent `planner` | `opus` | Architectural judgment: where code belongs, what to split. Worth the stronger model. |
| Implementation, triage, fixes | This session | (as configured) | You own the change and the decisions about it. |
| Simplify pass | Agent `general-purpose` (fresh, not a fork) | `sonnet` | A cleanup pass, by design. Fresh context keeps it unbiased toward the current implementation. |
| External review A | `codex exec` | `gpt-5.6-sol`, reasoning effort `high` | The review is the point of the step. Use the strongest reasoning available, from a different model family than the author. |
| External review B | `copilot -p` | `claude-opus-4.7` | Second strong, independent reviewer. Different vendor path than A so the two disagree in useful ways. |

If the user tells you a different model for a role, use it for the rest of the session and say so in the final report.

### Test Policy

**NEVER skip tests.** If a test cannot pass:
- **Fix it** — Update assertions to match correct behavior
- **Replace it** — Write a new test that properly validates the behavior
- **Refactor it** — Restructure to test what's actually testable
- **Remove it** — Delete entirely if it tests something that no longer exists

If tests require infrastructure (auth, database, external services), SET UP that infrastructure. Do not skip tests because setup is hard.

### Reviewable PR Size

A PR is reviewable when it carries **one intent** and a reviewer can hold the whole diff in their head. Rule of thumb: roughly 400 changed lines or fewer (excluding generated files, lockfiles, and snapshots) and no more than about ten files. These are heuristics, not limits — a 600-line mechanical rename can be more reviewable than a 150-line change that mixes three ideas.

When the work will not fit, **build a stack** (see "Stacks" under Workflow Variations). Decide this in planning (Step 3) when you can see it coming, and re-check at the review gate (Step 7) when the diff has grown past what was planned.

---

## STEPS

### STEP 0: Gauge the Work

**Execute FIRST before anything else.**

Assess the task's complexity and blast radius. This determines how much ceremony the task needs.

| Size | Examples | Blast radius | Steps |
|------|----------|-------------|-------|
| **Small** | Typo, config change, one-line fix, docs update, simple rename | Minimal — trivially reverted | 0 → 1 → (2.1 if from an issue) → 4 → 6 → 7 (ask) → 8 → 10 |
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

For a **feature or change request**, do the same in spirit: confirm the capability does not already exist, that it aligns with the repo's direction (read `VISION.md` and `CLAUDE.md` when present), and that this repo is where it belongs.

Outcomes:

- **Confirmed** — record the reproduction (and the failing test) and proceed to 2.2.
- **Not reproducible, already solved, belongs elsewhere, or not worth doing** — STOP. Report the evidence to the user with a recommended disposition (close, transfer, rescope, or proceed anyway). Do not close or relabel the issue yourself; that is the user's call. Resume only on their answer.

#### 2.2 Analyze requirements

**Check for existing specs first.** If a spec file was referenced in the task description, or if a relevant spec exists in `specs/`, read it. A spec that covers the requirements and has a task checklist satisfies this step — link to it and proceed directly to Step 3 (or Step 4 if the spec also includes a detailed plan).

Launch the requirements-analyzer agent:

```
Agent tool:
  subagent_type: "requirements-analyzer"
  model: "sonnet"
  prompt: "Analyze requirements for: [TASK DESCRIPTION]

           Validation so far: [REPRODUCTION / PRIOR ART / OWNERSHIP FINDINGS FROM 2.1]

           - Analyze task/issue/error to understand requirements
           - Use WebSearch to research technologies
           - Use WebFetch for referenced URLs
           - Use AskUserQuestion for ambiguities
           - Analyze codebase for patterns and existing utilities that already do part of this

           Output: Complete requirements with acceptance criteria"
  description: "Analyze requirements"
```

**DO NOT PROCEED until requirements are complete.**

---

### STEP 3: Planning (Standard + Large)

**Skip for Small tasks — proceed directly to Step 4.**

Launch the planner agent:

```
Agent tool:
  subagent_type: "planner"
  model: "opus"
  prompt: "Create implementation plan for:

           [REQUIREMENTS FROM STEP 2]

           - Break into atomic steps
           - Identify files to modify
           - Decide where the code belongs: implementation (feature-specific) vs platform
             (shared, reusable). Reuse existing utilities before creating new ones.
           - Determine test requirements
           - Evaluate what this opens up, not just what it solves
           - Shape the PR: if the change exceeds a reviewable PR (~400 changed lines,
             ~10 files, or more than one intent), split it into a stack of layered PRs,
             each independently reviewable and green.

           Output: Numbered implementation steps, plus PR shape (single PR or stack layers)"
  description: "Plan implementation"
```

If the plan calls for a stack, set it up now — see "Stacks" under Workflow Variations.

For GitHub issues, also update the issue:
```bash
gh issue edit [NUMBER] --add-label "in-progress"   # only if the label exists in the repo
gh issue comment [NUMBER] --body "[PLAN SUMMARY]"
```

**DO NOT PROCEED until plan exists.**

---

### STEP 4: Implementation

**Implement the plan.** For Standard/Large tasks, follow the plan from Step 3. For Small tasks, implement the change directly.

Requirements:
- Atomic **local** commits (format: `type(scope): message`)
- Follow existing patterns in the codebase
- Run tests as you go
- Do NOT push and do NOT create a PR yet — the review gate (Step 7) comes first

Verify commits exist:
```bash
git log --oneline -5
git diff main --stat
```

**DO NOT PROCEED until commits exist on feature branch.**

---

### STEP 5: Test Coverage (Standard + Large)

**Skip for Small tasks — proceed directly to Step 6.**

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

### STEP 6: Code Cleanup (simplify)

**Run the simplify skill before the review gate — in a fresh agent, not this session.**

By now you have been staring at this implementation for a while and are biased toward it. Simplify works best with none of that baggage: no memory of the approaches you tried, no attachment to the names you chose, no knowledge of what the plan said. Launch it in a **new** agent (a fresh `general-purpose` agent, never a `fork`) so the only thing it knows is the diff and the codebase:

```
Agent tool:
  subagent_type: "general-purpose"
  model: "sonnet"
  prompt: "Load the simplify skill (Skill tool: skill=\"simplify\") and run it against the
           current branch's changes vs main.

           The task: <A CLEAR EXPLANATION OF THE TASK — what the change is for, what it must
           do, and the acceptance criteria. Describe the what, not the how: no plan, no
           approach, no history of what was tried.>

           Make the fixes directly and commit them as the skill instructs. You have no other
           context on this change on purpose — judge the diff on what it is, not on how it
           got here. Report what you changed and why, and anything you noticed but
           deliberately left alone."
  description: "Simplify pass (fresh context)"
```

The task explanation is the only context it gets — as much as it needs to judge scope, none of how you got here. Do not pass it the plan, your approach, the alternatives you rejected, or your reasoning. If it removes something the task genuinely needs, that is a signal the code did not make its own necessity clear — restore it, make the necessity obvious (a test, a name, a one-line comment), and move on.

The simplify skill reviews all changed code for:
- **Scope** — changes the task didn't ask for, unneeded public surface, loose ends
- **Reuse** — duplicated logic that could use existing utilities
- **Quality** — copy-paste patterns, leaky abstractions, unnecessary nesting
- **Efficiency** — redundant computations, missed concurrency, hot-path bloat
- **Comments** — wordy, inaccurate, or redundant comments

Fix any issues found, commit the fixes, then proceed to the review gate.

**DO NOT PROCEED until simplify has run and any findings are addressed.**

---

### STEP 7: Review Gate (Codex + Copilot)

**Nothing is pushed until this gate passes.** Two independent external reviewers pressure-test the branch. You triage their findings, fix what is right, decline what is not with a reason, bring direction questions to the user, and repeat until the change is clean.

#### 7.0 Decide whether to run it

- **Standard and Large:** run it. Do not ask.
- **Small:** if an external review would clearly add value (the "small" change touches behavior, security, or shared code), run it without asking. If you are unsure whether it is worth the minutes, **ask** with AskUserQuestion:
  - **External review (Recommended if any behavior changed)** — Codex + Copilot, as below
  - **Local review only** — you review the diff yourself against the review prompt's questions, no external CLIs
  - **Skip** — proceed straight to Step 8
  If the answer is anything but external, record the choice for the final report and move on.

#### 7.1 Prepare

1. **Green first.** Run the project's tests, lint, and type-check. Reviewers should read working code; fix failures before asking anyone to review.
2. **Capture the intent and surface.** Write down, in your own words: one to three sentences of what this change is for and the approach it takes; the list of files it touches (`git diff main --name-only`); and its size (`git diff main --shortstat`). Every finding is measured against these.
3. **Write the review prompt** to a temp directory outside the repo so it cannot be committed. Shell state does not survive between Bash tool calls, so the directory is derived from the branch name and **every command below re-derives it on its first line**:

```bash
REVIEW_DIR="${TMPDIR:-/tmp}/sdlc-review/$(git branch --show-current | tr '/' '-')"; mkdir -p "$REVIEW_DIR"
```

Fill in the template below and save it as `$REVIEW_DIR/prompt.md`. Both reviewers get the identical prompt.

```markdown
You are a senior engineer pressure-testing a change BEFORE it becomes a pull request.
Read-only: do NOT modify any files. Use git and file reads to inspect.

## The change
- Base branch: main. Review everything in `git diff main` (and `git log main..HEAD`).
- Intent: <INTENT STATEMENT>
- Task / issue: <LINK OR DESCRIPTION, OR "none">
- Files touched: <LIST>
- Size: <SHORTSTAT>
- Repo direction: read VISION.md and CLAUDE.md at the repo root if present, and
  infer conventions from the surrounding code.

## What I need from you, in priority order
1. **Is this change needed?** Is the problem real? Is it already solved elsewhere in
   this repo (a utility, setting, or pattern the author missed)? Is there a materially
   better alternative — including "do nothing" or "fix it in the layer where the cause
   lives"? Pressure-test the premise, not just the code.
2. **Alignment.** Does this fit the direction of the repo (vision, conventions,
   existing architecture)? Does every part of the diff serve the stated intent, or
   does some of it drift into a different change?
3. **Where does this code belong?** Implementation vs platform: is feature-specific
   logic leaking into shared/platform layers, or reusable logic buried inside a
   feature? Does it duplicate or near-duplicate something that exists? Would a
   maintainer looking for this a year from now find it where it is?
4. **What is missing?** Untested paths, failure modes that can actually happen,
   compatibility/migration/rollout concerns, docs or config this change makes stale.
5. **Correctness.** Real defects with a concrete failing scenario. Verify against the
   code and callers before claiming; do not speculate.
6. **Reviewability.** Is this one coherent idea a reviewer can hold in their head?
   Should it be split into a stack of smaller PRs? Is anything in the diff larger
   than it needs to be?

## Ground rules
- Verify claims by reading code. A wrong "this will crash" costs more than silence.
- No style nits, no reformatting, no defensive code for scenarios that cannot occur,
  no "for completeness" tests of behavior this change did not touch.
- If something is fine, say nothing about it. Fewer, verified findings beat many.

## Output format
Numbered findings. For each:
`<file>:<line>` — **<blocker|high|medium|low>** — <needed|alignment|placement|missing|correctness|reviewability>
Claim: <one sentence>. Evidence: <what in the code shows it>. Fix: <one line>.

Then a **Verdict**: one of `ready`, `ready after fixes`, or `rethink`, with a short
paragraph explaining why — and, for `rethink`, the alternative you would take.
```

#### 7.2 Run both reviewers in parallel

Use two background Bash commands (`run_in_background: true`); you are re-invoked when each finishes. Do not poll.

**Codex** (reads the prompt from stdin, writes only its final answer to a file):

```bash
REVIEW_DIR="${TMPDIR:-/tmp}/sdlc-review/$(git branch --show-current | tr '/' '-')"
codex exec -s read-only -C "$(git rev-parse --show-toplevel)" \
  -m gpt-5.6-sol -c 'model_reasoning_effort="high"' \
  -o "$REVIEW_DIR/codex.md" - < "$REVIEW_DIR/prompt.md" > "$REVIEW_DIR/codex.log" 2>&1
```

**Copilot** (read-only tool allowlist; `--silent` prints only the answer):

```bash
REVIEW_DIR="${TMPDIR:-/tmp}/sdlc-review/$(git branch --show-current | tr '/' '-')"
copilot -p "$(cat "$REVIEW_DIR/prompt.md")" --model claude-opus-4.7 \
  --silent --no-ask-user --deny-tool='write' \
  --allow-tool='shell(git diff:*)' --allow-tool='shell(git log:*)' \
  --allow-tool='shell(git show:*)' --allow-tool='shell(git status:*)' \
  --allow-tool='shell(cat:*)' --allow-tool='shell(sed:*)' --allow-tool='shell(head:*)' \
  --allow-tool='shell(tail:*)' --allow-tool='shell(grep:*)' --allow-tool='shell(rg:*)' \
  --allow-tool='shell(find:*)' --allow-tool='shell(ls:*)' --allow-tool='shell(wc:*)' \
  > "$REVIEW_DIR/copilot.md" 2> "$REVIEW_DIR/copilot.log"
```

(Pattern syntax per `copilot help permissions`: exact command, or `:*` for a prefix. `write` is denied outright.)

Read `codex.md` and `copilot.md` when both complete — they hold only each reviewer's final answer; the `.log` files hold tool chatter and errors. If one reviewer errors (CLI missing, auth, model unavailable), handle it per "Required CLIs" — do not silently continue with one reviewer.

#### 7.3 Triage — critically

Merge the two lists and dedupe. Then, for every finding:

- **Verify before you act.** Reviewers state things confidently that are sometimes false. Confirm each claim by reading the surrounding code, callers, or types, or by running the relevant test. If it does not hold, decline it and say specifically why.
- **Classify by scope**, against the intent statement and touched surface from 7.1:
  - **Accept** — a real defect, a missing piece the intent requires, a duplication of something that exists, or code that belongs in a different layer and moving it is small. Fix it.
  - **Decline** — stylistic, speculative, defensive code for impossible cases, "for completeness" work, or a claim that failed verification. Record the reason.
  - **Flag for the user** — anything that would change the PR's *direction*: "this isn't needed", "this is solved by X", "this belongs in another repo/layer", "there is a better approach", "split this into a stack", or a fix that would grow the PR beyond a reviewable size or add files the plan never touched. **Do not act on these on your own.** Also flag any `rethink` verdict.
- **Bloat budget.** Review-driven fixes should be small relative to the change. If the accepted set would grow the diff by more than roughly 20% or push it past a reviewable size, the largest items are probably direction questions — move them to flagged.

**Ask the user about flagged items** with AskUserQuestion, one question per item, up to four per call. Each question says who raised it (Codex, Copilot, or both), where, what it asks, why you flagged it, and your recommendation as the first option marked "(Recommended)". Options: **Take it**, **Decline it**, **Split it out** (a follow-up PR or a new stack layer). "Other" is available automatically — if the user says to stop, stop and report.

Direction questions are the most valuable output of this gate. Do not soften them or bury them in a list of nits.

#### 7.4 Fix, verify, repeat

1. Implement the accepted items and any "take it" answers. Run tests, lint, type-check. Commit with the appropriate type (`fix(...)`, `refactor(...)`, `test(...)`), not a generic "address review" message.
2. **Re-check size.** If the diff has grown past a reviewable PR, restructure into a stack now (see "Stacks") — before anything is pushed. For a stack, also verify **each layer is green on its own**: check out every layer bottom-up (`gh stack bottom`, then `gh stack up`) and run tests, lint, and type-check there. An upper layer must never be what makes a lower one pass.
3. **Re-run the gate** (7.1 prompt refresh → 7.2 → 7.3) if any accepted fix changed behavior or structure. Skip the re-run only when every fix was trivial (typos, comments, renames).
4. **Exit** when a round produces no unaddressed `blocker`, `high`, or `medium` findings and both verdicts are `ready` or `ready after fixes` with those fixes done. **Cap: 3 rounds.** Past that, reviewers are usually nitpicking or contradicting each other. At the cap, stop the loop and **ask the user** with AskUserQuestion, listing what is still open: **Proceed to PR with the remaining findings logged** (Recommended when what remains is low/medium and each has a stated reason), **Run one more round**, or **Stop here**. Only their answer moves you past this step.

#### 7.5 Record the review log

Keep a short log for the PR description (Step 8) and the final report (Step 10):

```
## Pre-PR review
Reviewers: Codex (gpt-5.6-sol, high) · Copilot (claude-opus-4.7) · N round(s)
Accepted: <one line each — what changed and why>
Declined: <one line each — what was asked and why not>
Decisions: <one line each — what the user was asked, what they chose>
Verdicts: Codex <verdict> · Copilot <verdict>
```

This makes the PR honest about what was already pressure-tested, so the human reviewer can spend their attention elsewhere.

**DO NOT PROCEED until the gate has exited cleanly, or the user has chosen to proceed at the round cap or in 7.0.**

---

### STEP 8: Pull Request Creation

**Use the github-pr skill to create a PR.**

```
Skill tool: skill="github-pr"
```

The skill handles pushing the branch, PR creation, and description formatting. Include the review log from 7.5 in the PR body. For a stack, confirm every layer passed its own checks (7.4 step 2), then push and open the layered PRs with `gh stack submit` instead of a single `gh pr create`, and put the review log in the bottom PR with a one-line pointer in each layer above.

**Capture the PR number(s) for remaining steps.**

**DO NOT PROCEED until PR is created.**

---

### STEP 9: PR Review Loop (Standard + Large)

**Skip for Small tasks — proceed directly to Step 10.**

The pre-PR gate reviewed the code. This step reviews the *PR*: CI on the pushed head, GitHub Copilot's review on GitHub, and any human comments that arrive while you are still here.

```
Skill tool: skill="github-resolve"          # single PR
Skill tool: skill="github-resolve-stack"    # stack
```

Those skills own the loop: they wait on CI, request Copilot's GitHub review, triage and fix, and pause to ask the user whenever a comment would change the PR's approach or scope. Follow their exit conditions; do not extend the loop past them.

---

### STEP 10: Report to User

```
PR #[NUMBER] ready: [URL]          (for a stack: one line per layer, bottom first)

Changes:
- [summary bullets]

Pre-PR review: [Codex verdict] · [Copilot verdict] · [N] round(s)
- Accepted: [count] · Declined: [count] · Decisions you made: [count]
- [anything still open for the human reviewer, or "nothing open"]

PR review loop: [github-resolve exit reason, CI status]  (Standard + Large)

Ready for your review.
```

If the gate was skipped or run locally for a Small task, say so in one line.

**NEVER merge PRs. PRs are delivered for human review and merge.**

---

## Workflow Variations

### GitHub Issue URL

1. STEP 0: Gauge the work
2. STEP 1: Branch as `fix/issue-123-description`
3. STEP 2.1: Validate the issue — reproduce, prove with a failing test when pertinent, confirm it is unsolved and belongs here. Runs for every size, Small included.
4. Remaining steps per task size

### Quick Fix (fix:, error:, bug: prefix)

1. STEP 0: Gauge the work (likely Small or Standard)
2. STEP 1: Branch as `fix/short-error-desc`
3. Remaining steps per task size

### Stacks

Use a stack when one intent will not fit a reviewable PR, or when the plan has layers that each stand alone (schema → service → UI; extract utility → use utility). Each layer is a branch that builds on the one below it, is green on its own, and carries one idea.

```bash
gh stack init                        # from the first layer's branch; targets main
# ...implement and commit layer 1...
gh stack add <type>/<layer-2-name>   # new branch on top of the current layer
# ...implement and commit layer 2, and so on...
gh stack view                        # sanity-check the shape
gh stack submit                      # Step 8: push all layers and open the PRs
gh stack sync                        # keep local in sync with remote after pushes
```

Turning an existing set of branches into a stack: `gh stack init <branch1> <branch2> ...`.

The review gate (Step 7) reviews the whole stack's diff against `main` once, and its findings are fixed in the layer where they belong. Independently of that, **every layer must be green on its own** — tests, lint, and type-check run on each layer's checkout, bottom-up, before `gh stack submit`. Step 9 uses `github-resolve-stack`.

### Multi-PR Tasks (Solo)

Dependent layers of one intent are a **stack** — open them together. Independent PRs are not:

1. Complete the workflow for the first PR
2. **STOP** — Wait for user to review and merge
3. Only after the first PR is merged: Start the next PR

**When working solo, keep one independent PR (or one stack) open at a time.** This keeps the feedback loop tight and avoids merge conflicts. This rule does NOT apply when working as part of a `/team` — coordinated parallel PRs are expected in that context.

---

## Error Handling

| Error | Action |
|-------|--------|
| Agent fails | Retry once with adjusted params, then STOP and report |
| Git conflict | STOP, report to user, wait for resolution |
| Tests fail | Fix, rerun until pass |
| `gh` / `codex` / `copilot` not installed or not authenticated | STOP, per "Required CLIs" |
| Reviewer model unavailable (`--model` / `-m` rejected) | Fall back to the tool's default model for this run, and say so in the report |
| Reviewer produces no output or times out | Retry once; if it fails again, STOP and report — do not proceed on one reviewer without telling the user |
| Review gate hits the round cap | Stop the loop, carry remaining findings into the PR body and report |

---

## Agent & Skill Reference

| Step | Tool | Name | Model | When |
|------|------|------|-------|------|
| 2 | Agent | `requirements-analyzer` | sonnet | Standard + Large |
| 3 | Agent | `planner` | opus | Standard + Large |
| 5 | Skill | `test-coverage` | — | Standard + Large |
| 6 | Agent → Skill | `general-purpose` running `simplify` | sonnet | Always |
| 7 | CLI | `codex exec` | gpt-5.6-sol (high) | Standard + Large; Small on request |
| 7 | CLI | `copilot -p` | claude-opus-4.7 | Standard + Large; Small on request |
| 8 | Skill | `github-pr` | — | Always |
| 9 | Skill | `github-resolve` / `github-resolve-stack` | — | Standard + Large |

---

## Success Criteria

Workflow complete when ALL true:
- Feature branch created from main
- Task validated — reproduced and proven with a test where pertinent; confirmed unsolved and belonging to this repo (Standard + Large)
- Requirements documented (Standard + Large)
- Plan created, including PR shape — single PR or stack (Standard + Large)
- Code implemented with atomic commits
- Test coverage verified (Standard + Large)
- Code cleaned via /simplify in a fresh agent (scope, reuse, quality, efficiency, comments)
- Review gate passed: Codex + Copilot findings triaged, accepted fixes committed, direction questions decided by the user, review log written (Small: run, local, or skipped by the user's choice)
- PR (or stack) created with description including the review log
- PR review loop complete: CI green, Copilot's GitHub review addressed (Standard + Large)
- PR delivered ready for human review and merge
