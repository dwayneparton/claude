---
name: atlantis-deploy
description: Open a deploy PR that bumps a service's container_tag in its Atlantis (Terraform) repo. Use when the user says 'deploy', 'promote', 'ship to daily/staging/prod', 'bump the tag', 'roll back to <sha>', or gives a short SHA and an environment. Resolves the Atlantis repo for the service, edits the tfvars, and opens a PR whose description summarizes what changed between the old and new tag. Stops at the PR — the user reviews the Atlantis plan and applies.
---

## What this does

Services are deployed by pinning `container_tag` (a short SHA of the service repo commit) in the service's Atlantis repo tfvars. This skill opens that PR and stops. It never runs `atlantis apply` and never merges — the user reviews the plan and applies.

## Steps

1. **Find the Atlantis repo for the service.**
   - Prefer what the service repo documents. Search its docs first: `grep -rn -i atlantis README.md CLAUDE.md AGENTS.md docs/ 2>/dev/null`. A `docs/RUNBOOK.md` deploy/rollback section is the usual home and may override anything below — follow it.
   - If undocumented, infer: service `<name>` deploys via `atlantis-<name>`, checked out as a sibling directory (`../atlantis-<name>`) or on GitHub under the same owner as the service repo (`gh repo view --json owner -q .owner.login` from the service repo). Example: `../my-service` deploys via `../atlantis-my-service`.
   - If neither resolves, ask the user for the repo. Do not guess past one inference attempt.
   - Clone or `git pull` the Atlantis repo so you are working from current `main`.

2. **Resolve the short SHA.**
   - If the user gave one, use it verbatim (these are short SHAs, usually 7 chars — do not expand them).
   - If not, ask. Offer the obvious candidate: the newest commit on the service repo's `main` (`git log --oneline -5 main`), or for a rollback, the tag currently in a lower environment's tfvars.
   - Verify the SHA exists in the service repo (`git cat-file -e <sha>`) and is on `main`. An image only exists if CI built that commit — if the build is still running or failed, stop and say so.

3. **Pick the environments.**
   - List the tfvars: `ls *.tfvars` in the Atlantis repo. There is usually one file per environment (e.g. `daily.tfvars`, `staging.tfvars`, `production.tfvars`, often with an org prefix).
   - Default grouping: **daily + staging together in one PR**, **production as its own standalone PR**. Never fold production into a lower-environment PR.
   - If the user did not say which environments, ask — but state that default so a one-word answer works.
   - Some environments are auto-deployed on build (e.g. by Keel) and have `container_tag` commented out. Those need no PR; say so instead of uncommenting it.

4. **Edit the tag.**
   - Record the **old** tag per environment first — the PR description needs it, and it is the rollback target.
   - Change only the active `container_tag` under the `deployments` block. Leave commented examples, `cloud_run_jobs`, and every other value alone.
   - `git diff` and confirm the diff is one line per environment file. Anything else means you edited the wrong thing.

5. **Branch, commit, PR.**
   - Mirror the target repo's own recent history (`git log --oneline -10`, `gh pr list --state merged --limit 8 --json headRefName,title`) — deploy repos have their own terse convention, which wins over this repo's normal `type(scope):` format.
   - Common convention: branch `dev/<sha>` (daily+staging), `daily/<sha>`, `prod/<sha>`; commit and PR title `daily|staging -> <sha>` or `prod -> <sha>`.
   - PR description: see below.
   - Return the PR URL and stop. Atlantis plans automatically and posts the plan as a PR comment; the user reviews it, applies, and merges.

## PR description

Short. Say what this deploy changes for the service, not its commit history.

- 3-5 bullets max, only changes a reader would care about in production: behavior changes, config/env expectations, migrations, dependency or model bumps, notable fixes. Skip chores, test-only commits, and refactors with no runtime effect.
- Note anything needing action or attention around the deploy (migration to run, flag to flip, expected latency/cost shift).
- Include the compare link so the full history is one click away.

Build it from the service repo, not the Atlantis repo:

```
git -C ../<service> log --oneline <old-sha>..<new-sha>
git -C ../<service> diff --stat <old-sha>..<new-sha>
gh repo view --json url -q .url   # run in the service repo, for the compare link
```

Template:

```markdown
`<old-sha>` → `<new-sha>` ([compare](<service-repo-url>/compare/<old-sha>...<new-sha>))

- <key change>
- <key change>
```

When the environments in one PR are moving from different old tags, list each: `daily <old> → <new>`, `staging <old> → <new>`.

If the old and new tag are the same, there is nothing to deploy — say so and stop.

## Important

- This skill ends at the PR. Never comment `atlantis apply`, never merge, never approve.
- Never edit anything but `container_tag`. Infra changes belong in their own PR.
- A rollback is the same flow pointed at an earlier tag — say plainly that it is a rollback in the PR description.
