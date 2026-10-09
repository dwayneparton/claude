---
name: github-pr
description: Push the current feature branch and open a GitHub PR with a short description, or a `gh stack` when PRs depend on each other. Use when the user says 'open a PR', 'send up a PR', or 'create a pull request'. Runs the project's tests and lint first and never merges.
---

## Steps

1. **Verify branch and commits exist:**
   - Confirm you're on a feature branch (not `main` or `master`).
   - If on `main`/`master`: create a descriptive branch (`git checkout -b <type>/<short-description>`), stage, and commit changes.
   - If already on a feature branch with commits: proceed — do not create a new branch.

2. **Run tests, lint, and formatting:**
   - Check the project for available test/lint/format commands (e.g., `package.json` scripts, `Makefile`, etc.).
   - Run them and fix any failures before proceeding.
   - Do NOT skip or silence failing checks — fix the underlying issues.

3. **Review .github/workflows:**
   - Read the workflow files to understand what CI checks will run on the PR.
   - If there are checks you can run locally (type-check, lint, test), run them now to catch issues early.
   - Note any required checks so you can verify they pass after opening the PR.

4. **Check whether this is a stack:**
   - It is a stack if the work is a planned series of dependent PRs, or if this branch is based on another unmerged feature branch instead of the default branch (for example, `gh pr list --state open --head <parent-branch>` finds a PR for the branch this one was cut from).
   - For a stack, use GitHub stacked PRs, never a plain `gh pr create` against another PR's branch. Install the extension if needed (`gh extension install github/gh-stack`), adopt or build the stack (`gh stack init <branch1> <branch2> ...` for existing branches, `gh stack add` for new layers), check it with `gh stack view`, then push and open every layer with `gh stack submit`. Set each PR's description in the format from step 5 with `gh pr edit <number> --body ...`, then skip step 5.
   - Otherwise continue to step 5.

5. **Push and Open PR:**
   - Push the branch: `git push -u origin <branch-name>`
   - Open the PR using `gh pr create`:
     ```
     gh pr create --title "<short title>" --body "$(cat <<'EOF'
     ## Summary
     <1-3 bullet points describing what changed and why>

     ## Test plan
     - [ ] <how to verify the changes>

     🤖 Generated with [Claude Code](https://claude.com/claude-code)
     EOF
     )"
     ```
   - Return the PR URL to the user.

## Important

- Always verify you're on a feature branch — never push directly to main/master.
- Never force-push or amend commits without explicit user approval.
- Keep PR titles under 70 characters. Put details in the body, not the title.
- If there are no changes to send up, report that and do nothing.
- Never merge PRs. PRs are delivered for human review and merge.
- PRs that depend on each other are always a GitHub stack (`gh stack`), never PRs hand-pointed at each other's branches.
