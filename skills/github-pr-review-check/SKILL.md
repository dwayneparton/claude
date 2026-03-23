---
name: github-pr-review-check
description: checks GitHub for reviews requiring my approval

---

## Steps

1. **Get GitHub username**
   - Run `gh api user --jq '.login'` to get the authenticated user's GitHub username.

2. **Find PRs requesting my review**
   - Run `gh search prs --review-requested=@me --state=open --json url,title,repository,author,updatedAt` to find open PRs where my review is requested.

3. **Find PR comments/threads mentioning me directly**
   - Run `gh search issues --mentions=@me --state=open --is=pr --json url,title,repository,author,updatedAt` to find open PRs with comments that directly @mention me.

4. **Present results**
   - Deduplicate results across the two queries (by URL).
   - For each item, display:
     - PR title
     - Repository
     - Author
     - Link to the PR
     - Why it appeared (review requested, mentioned, or both)
   - Group by repository for readability.
   - If no results, report that there are no PRs needing my attention.

## Important

- Only include PRs where the user is **directly** tagged — not team mentions or CODEOWNERS assignments.
- Use `gh` CLI exclusively — do not use the GitHub REST API directly.
- Do not take any action on the PRs — this skill is read-only.
