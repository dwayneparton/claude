---
name: github-pr
description: Send up PR to GitHub.

---

## Steps

1. **Create New Branch**
   - Generate a descriptive branch name based on the changes (e.g., `fix/login-validation`, `feat/add-user-export`).
   - Run `git checkout -b <branch-name>` from the up-to-date base branch (usually `main`).
   - Stage and commit all relevant changes with a clear commit message.

2. **Run tests, lint, and formatting**
   - Check the project for available test/lint/format commands (e.g., `package.json` scripts, `Makefile`, etc.).
   - Run them and fix any failures before proceeding.
   - Do NOT skip or silence failing checks — fix the underlying issues.

3. **Review .github/workflows**
   - Read the workflow files to understand what CI checks will run on the PR.
   - If there are checks you can run locally (type-check, lint, test), run them now to catch issues early.
   - Note any required checks so you can verify they pass after opening the PR.

4. **Push and Open PR:**
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

- Always create a new branch — never push directly to main/master.
- Never force-push or amend commits without explicit user approval.
- Keep PR titles under 70 characters. Put details in the body, not the title.
- If there are no changes to send up, report that and do nothing.
