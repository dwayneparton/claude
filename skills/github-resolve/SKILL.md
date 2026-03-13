---
name: github-resolve
description: Resolve PR review comments by implementing the requested changes, committing, and replying on GitHub.

---

## Steps

1. **Get the current PR and its review comments:**
   - Run `gh pr view --json number,title,body,url` to get PR metadata.
   - Run `gh api repos/{owner}/{repo}/pulls/{number}/comments` to get all review comments.
   - Run `gh api repos/{owner}/{repo}/issues/{number}/comments` to get issue-level comments.
   - Filter to unresolved/pending comments that require code changes.

2. **Analyze each comment thread:**
   - Read the referenced files and line ranges for each comment.
   - Understand what change is being requested.
   - Group related comments that touch the same files.

3. **Implement the requested changes:**
   - Make the code changes requested by each comment.
   - If a comment is unclear or conflicts with another, flag it and skip rather than guessing.

4. **Update the PR description if needed:**
   - If the changes alter the scope or behavior described in the PR body, update it:
     ```
     gh pr edit {number} --body "$(cat <<'EOF'
     updated body here
     EOF
     )"
     ```
   - Do NOT update the description if the changes are minor fixes that don't affect the summary.

5. **Check GitHub Actions status and fix failures:**
   - Run `gh pr checks {number}` to see the status of all CI checks.
   - If all checks pass, skip to the next step.
   - If any checks have failed:
     - Run `gh run view {run_id} --log-failed` to get the failure logs for each failed run.
     - Analyze the failure logs to determine the root cause (test failures, lint errors, build errors, type errors, etc.).
     - Fix the issues in the code.
     - If a failure is unrelated to the PR changes (flaky test, infrastructure issue), note it but do not attempt to fix it.
   - Repeat until all fixable checks pass or only non-PR-related failures remain.

6. **Commit the changes:**
   - Stage only the files that were modified to address comments.
   - Write a clear commit message summarizing what was resolved.
   - Push the commit to the current branch.

7. **Reply to each resolved comment on GitHub:**
   - For each comment that was addressed, reply to the comment thread confirming the change:
     ```
     gh api repos/{owner}/{repo}/pulls/{number}/comments/{comment_id}/replies -f body="Done — addressed in <short description of change>."
     ```
   - For issue-level comments, reply on the issue thread:
     ```
     gh api repos/{owner}/{repo}/issues/{number}/comments -f body="Addressed: <summary of what was done>."
     ```
   - Do NOT resolve the threads — let the reviewer resolve them after verifying.

## Important

- Only address comments that request concrete code changes. Skip praise, questions, or discussion-only comments.
- Never force-push or amend existing commits. Always create new commits.
- If there are no actionable comments, report that and do nothing.
