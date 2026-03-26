---
name: simplify
description: "Review changed code for reuse, quality, and efficiency, then fix any issues found."
---

# Simplify

A lightweight code cleanup pass on the current branch's changes. This is a pre-flight check, not a redesign — fix what's obviously wrong, then move on.

## Steps

1. **Get the diff:**
   ```bash
   git diff main --name-only
   ```
   Read each changed file to understand what was modified.

2. **Review for reuse:**
   - Is there duplicated logic that could use an existing utility or function in the codebase?
   - Were helpers or abstractions created that already exist elsewhere?
   - Search the codebase for similar patterns before introducing new ones.

3. **Review for quality:**
   - Copy-paste code with minor variations that should be consolidated
   - Leaky abstractions — implementation details exposed where they shouldn't be
   - Unnecessary nesting that could be flattened (early returns, guard clauses)
   - Overly clever code that could be simpler

4. **Review for efficiency:**
   - Redundant computations (same value calculated multiple times)
   - Missed concurrency opportunities (independent async work done sequentially)
   - Hot-path bloat (expensive operations in tight loops)

5. **Fix issues found:**
   - Make the fixes directly — don't just report them.
   - Keep fixes minimal and scoped to the issues found.
   - Do NOT refactor beyond what's needed. This is a cleanup pass, not an architecture review.

6. **Commit fixes (if any):**
   ```bash
   git add <fixed-files>
   git commit -m "refactor: simplify — <brief description of cleanup>"
   ```

7. **Report:**
   - If fixes were made: list what was changed and why.
   - If nothing was found: say so and move on.

## Important

- Only review code changed on the current branch (`git diff main`). Do not review the entire codebase.
- Fix issues directly. The output of this skill is cleaner code, not a report.
- Stay scoped. A cleanup pass that turns into a refactor has missed the point.
- If you find something that needs deeper attention, note it but don't fix it here — that's what `refactor-scout` is for.
