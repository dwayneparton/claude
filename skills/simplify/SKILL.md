---
name: simplify
description: "Review changed code for scope, reuse, quality, efficiency, and comment hygiene, then fix any issues found."
---

# Simplify

A lightweight code cleanup pass on the current branch's changes. This is a pre-flight check, not a redesign — fix what's obviously wrong, then move on.

The goal is the smallest, most precise change that completes the task. A simpler PR is easier to understand, review, and push through. Some tasks genuinely need a lot of code — that's fine. What we're after is no code the task didn't ask for.

## Steps

1. **Get the diff:**
   ```bash
   git diff main...HEAD --stat
   git diff main...HEAD
   ```
   The three-dot form diffs from the merge base, so a stale local `main` doesn't pull unrelated files into the review. Read the diff first, then open changed files where you need surrounding context.

2. **Review for scope:**
   - Judge against the task statement you were given. If you weren't given one, infer it from the branch name and commit messages.
   - Does every change in the diff serve the task? Remove anything that doesn't — drive-by refactors, unrelated formatting, speculative "while I'm here" additions.
   - Did the public surface grow more than the task required? New exports, parameters, options, config keys, or types that nothing uses yet should come out. Add them when something needs them.
   - Is anything more general than the task needs? Solve the problem in front of you, not the one you imagine coming next.
   - Are there loose ends — half-finished paths, unused helpers, dead branches left from an earlier approach? Tie them up or remove them.
   - When you're unsure whether something is needed, leave it and note it in the report. Removing needed code costs more than leaving a little extra.

3. **Review for reuse:**
   - Is there duplicated logic that could use an existing utility or function in the codebase?
   - Were helpers or abstractions created that already exist elsewhere?
   - Search the codebase for similar patterns before introducing new ones.

4. **Review for quality:**
   - Copy-paste code with minor variations that should be consolidated
   - Leaky abstractions — implementation details exposed where they shouldn't be
   - Unnecessary nesting that could be flattened (early returns, guard clauses)
   - Overly clever code that could be simpler

5. **Review for efficiency:**
   - Redundant computations (same value calculated multiple times)
   - Missed concurrency opportunities (independent async work done sequentially)
   - Hot-path bloat (expensive operations in tight loops)

6. **Review comments and leftovers:**
   - Comments should be efficient: short, accurate, and earning their place. A good comment says something the code cannot — a non-obvious *why*, a workaround for an external constraint, a gotcha the next reader would hit.
   - Trim wordy comments. One line where one line will do; no paragraph above a function whose name already explains it.
   - Delete comments that restate the code (`// increment the counter`), narrate the change (`// changed from X to Y`, `// added for issue #12`), or are leftovers from planning (`// Step 3`, `// TODO: implement`).
   - Check accuracy. A comment that no longer matches the code beside it is worse than none — fix it or remove it.
   - When a comment exists only to explain what a name means, consider renaming instead.
   - Remove implementation debris: debug logging, commented-out code, unused imports and variables, stray `console.log` / print statements.

7. **Fix issues found:**
   - Make the fixes directly — don't just report them.
   - Keep fixes minimal and scoped to the issues found.
   - Do NOT refactor beyond what's needed. This is a cleanup pass, not an architecture review.

8. **Verify, then commit (if any fixes):**
   Run the project's tests, typecheck, and lint for the areas you touched. If a fix breaks something, revert that fix — don't widen the change to make it pass.
   ```bash
   git add <fixed-files>
   git commit -m "refactor(<scope>): <what was simplified>"
   ```

9. **Report:**
   - If fixes were made: list what was changed and why.
   - If nothing was found: say so and move on.
   - Note anything you deliberately left alone and why.

## Important

- Only review code changed on the current branch (`git diff main...HEAD`). Do not review the entire codebase.
- Fix issues directly. The output of this skill is cleaner code, not a report.
- Stay scoped. A cleanup pass that turns into a refactor has missed the point.
- Smaller is the default, not a target. Don't strip code a task legitimately needs; strip code the task didn't ask for.
- If you find something that needs deeper attention, note it but don't fix it here — that's what `refactor-scout` is for.
