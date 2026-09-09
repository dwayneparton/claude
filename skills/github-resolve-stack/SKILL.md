---
name: github-resolve-stack
description: Orchestrate /github-resolve across a GitHub stacked-PR stack (gh stack, rebased). Discovers the stack, captures the stack's intent, fans out parallel Sonnet/Opus agents per PR based on complexity, propagates lower-PR fixes upward, and reviews the whole stack so review-driven changes stay in the spirit of the stack. Pauses to ask you when a change would alter the stack's intent or scope.

---

This skill is the layer above `/github-resolve`. `/github-resolve` owns one PR: it triages Copilot's comments, fixes, pushes, re-requests, and loops. This skill owns the **stack**: which PRs exist, how they depend on each other, what the stack as a whole is trying to do, and whether the sum of all the per-PR fixes still adds up to that.

The orchestrating agent (normally the session running this skill — typically Fable) **never resolves review comments itself**. It delegates each PR to a sub-agent running `/github-resolve`, and spends its own attention on the things a per-PR agent cannot see: stack intent, cross-PR consistency, dependency order, propagation, and the consolidated decision list for the human.

## Exit conditions

Stop and report when any of these is true:

- **Stack is clean:** every PR's sub-agent exited with "Copilot is satisfied and CI is green" or "Copilot gave a terminal assessment and CI is green" (*approval recommended*, *needs a closer look*, *needs human review* — see `/github-resolve`), propagation is complete, the `/github-resolve` CI gate passes on every PR's *post-rebase* head commit, and the stack-level review (step 8) found no drift.
- **You told it to stop:** when asked for a decision (see step 7's pause), you answered that you want to take over or stop.
- **Propagation conflict:** merging a lower PR's fixes into an upper PR produced a conflict that is not trivially mechanical. Do not guess at a resolution across layers; stop and report.
- **A sub-agent exited on its own cap or timeout** (round cap, Copilot never answered). Report it alongside whatever else finished.

Flagged items are **not** an exit. Sub-agents report them, the orchestrator asks you in this session, and the loop continues with your answers. Nothing about a flag is ever posted to GitHub.

## Step 1 — Discover the stack

Stacks here are **GitHub native stacked PRs**, managed with the `gh stack` extension and kept rebased (not merge-forwarded). Make sure the extension is present, then let it describe the stack:

```
gh extension list | grep -q 'github/gh-stack' || gh extension install github/gh-stack

# Adopt the stack containing the current PR (accepts a PR number, URL, or branch) and describe it
gh stack checkout {pr}
gh stack view --json
gh repo view --json nameWithOwner,defaultBranchRef --jq '"\(.nameWithOwner) \(.defaultBranchRef.name)"'
```

`gh stack view --json` gives the ordered branches, their PR numbers, and trunk. Then, per PR:

```
gh pr view {pr} --json number,url,title,body,headRefName,baseRefName,additions,deletions,changedFiles
```

- Record the stack bottom to top. A branch with several children is a tree, not a chain — keep the parent/child edges.
- **Fallback** if the PRs are not linked as a GitHub stack (`gh stack checkout` finds nothing): walk base branches by hand — down with `gh pr list --state open --head {baseRefName}` until the base is trunk, up with `gh pr list --state open --base {headRefName}` breadth-first. Tell the user the PRs are not linked and offer `gh stack link` after the run; do not link them yourself.
- If the current PR targets trunk and nothing is based on it, there is no stack. Say so and offer plain `/github-resolve` instead.

## Step 2 — Capture the stack's intent

Do this before any review comment is read, in your working notes:

- **Stack intent statement:** two to four sentences on what the stack as a whole delivers and why it was split the way it was. Derive it from every PR's title, body, and diff — the diffs win if the bodies are stale.
- **Per-PR role:** one sentence per PR on what layer of the work it carries (e.g. "schema + migration", "repository layer", "API handler", "UI wiring"). A review fix that belongs to a different layer than the PR it lands in is a layering violation, even if it is "correct".
- **Touched surface per PR:** `gh pr diff {pr} --name-only` for each. Build the **overlap map**: which pairs of PRs touch the same file. Overlap is what makes parallel resolution unsafe.
- **Original sizes:** `additions`, `deletions`, `changedFiles` per PR and summed for the stack.

## Step 3 — Bootstrap Copilot on every PR at once

For each PR, apply `/github-resolve`'s bootstrap rule: if Copilot has never reviewed it *and* is not a pending requested reviewer, request it now. Do this for the whole stack up front so the waits overlap instead of serializing.

```
gh api "repos/{owner}/{repo}/pulls/{pr}/reviews?per_page=100" \
  --jq '[.[] | select(.user.login=="copilot-pull-request-reviewer[bot]") | .id] | max // 0'
gh api "repos/{owner}/{repo}/pulls/{pr}/requested_reviewers" \
  --jq '[.users[].login] | index("copilot-pull-request-reviewer[bot]") != null'
gh pr edit {pr} --add-reviewer @copilot     # only when both answers say "never"
```

## Step 4 — Plan waves and pick models

**Ordering rule.** Fixes flow upward: a change to PR *k* must be propagated into every PR above it before those PRs are resolved, or their agents will be working on a branch that does not contain the fix. So:

- A PR may start when every PR **below it that shares a file with it** has finished and been propagated (step 7).
- PRs that share no files with anything below them may start immediately, in parallel, even if they are higher in the stack. Their branches get rebased onto the lower fix *after* their agent finishes (step 7), which is safe because the files are disjoint; CI re-runs on the rebased branch and the stack review re-checks it.
- Because propagation is a **cascade rebase**, it can only run when no agent is working on a branch above the changed PR (the rebase needs to check those branches out). Deferring the rebase until the wave finishes is normal; starting an *overlapping* upper PR before its lower dependency has been rebased in is not.
- Cap concurrency at 4 sub-agents. More than that and you cannot keep the cross-PR picture in your head, which is the whole point of the orchestrator.
- Never spawn more agents than there are PRs. One agent per PR, one pass.

**Model selection.** Score each PR, then pick:

| Signal | Leans Sonnet | Leans Opus |
|---|---|---|
| Diff size | ≤ ~200 lines | larger |
| Unresolved actionable comments | ≤ 4 | more |
| Nature of comments | mechanical: naming, wording, obvious null path, test assertion | design-level, cross-file, "consider a different approach" |
| Overlap | touches no file shared with another PR | shares files with PRs above it (higher blast radius) |
| Position | leaf / top of stack | bottom layer with dependents |

Use **Sonnet** when every signal leans Sonnet. Use **Opus** if any signal leans Opus. When Copilot has not yet reviewed a PR (bootstrap case), you have no comment signal — default to Opus for bottom PRs and Sonnet for leaves, and note the guess. The orchestrator itself does not take a PR.

Write the plan down as waves before launching anything, e.g. `Wave 1: #41 (opus), #44 (sonnet) — Wave 2 after #41 propagates: #42 (opus) — Wave 3: #43 (sonnet)`, and give the user that one-liner.

## Step 5 — Prepare an isolated worktree per PR

Sub-agents must not share a working copy. Create one worktree per PR under the scratchpad:

```
git fetch origin
git worktree add "{scratchpad}/stack/pr-{pr}" "{headRefName}"
```

Give each sub-agent its worktree path. Every shell command a sub-agent runs must be prefixed with `cd {worktree} &&` (the shell cwd does not persist between calls).

Worktrees pin their branch: git will refuse to rebase or check out a branch that is checked out in another worktree. So **remove a PR's worktree as soon as its agent reports** (`git worktree remove --force "{scratchpad}/stack/pr-{pr}"`), before any `gh stack rebase` that would touch that branch. The main working copy is where `gh stack` runs; keep it on the stack, not inside a worktree.

## Step 6 — Launch the sub-agents

Use the Agent tool, `subagent_type: "general-purpose"`, `model` per the plan, one call per PR in a wave, all in a single message so they run concurrently. Prompt template:

```
You are resolving review comments on PR #{pr} ({url}), one PR in a stack of {n}.
Work ONLY in the worktree at {worktree}. Prefix every shell command with `cd {worktree} &&`.
Invoke the /github-resolve skill and follow it exactly, with these stack-specific additions:

STACK CONTEXT
- Stack intent: {stack intent statement}
- This PR's role in the stack: {per-PR role}
- Below this PR: {list of lower PRs + one-line roles}. Above it: {list of upper PRs + roles}.
- Files this PR touches: {list}. Files other PRs in the stack touch: {list with PR numbers}.

STACK RULES (these tighten /github-resolve, never loosen it)
- Your intent yardstick is BOTH this PR's role AND the stack intent. A fix that is correct but belongs to a different layer of the stack (a lower or upper PR's role) is a layering violation: do NOT implement it. Flag it and name the PR it belongs in.
- You are a sub-agent: you cannot ask the user and must NOT post anything to GitHub about flagged items. When /github-resolve reaches its pause (step 7b) with flagged items, finish the in-scope push, CI gate, and replies, then RETURN with `exit: human-decision` and the flagged list in your report. You will be messaged the user's decisions; apply them exactly as /github-resolve step 7b describes (implement / decline / split, reply, resolve), then continue the loop from step 8 and return a new report when you next exit.
- Do not touch files that belong to another PR in the stack unless a comment on THIS PR requires it and the change is confined to this PR's role. If you must, say so explicitly in your report.
- Never rebase, never force-push, never merge other branches into this one. Propagation between PRs is the orchestrator's job.
- Use `gh pr view {pr}` / `gh pr checks {pr}` with the explicit number, never bare.
- Listener: you are running as a sub-agent, where Monitor notifications may not reach you. Instead of the Monitor tool, wait with a blocking Bash poll (the same loop from /github-resolve step 9) using timeout 600000, and run it a second time if the first times out without a COPILOT_REVIEW line. Treat two timeouts as "Copilot never answered".

REPORT
End with exactly this structure so the orchestrator can parse it:
### RESOLVE REPORT PR #{pr}
- exit: <satisfied | terminal-assessment | human-decision | round-cap | copilot-timeout | nothing-actionable | error>
- assessment: <Copilot's approval assessment phrase, or "none">
- commits: <sha list or "none">
- size: <orig adds/dels/files> -> <now adds/dels/files>
- changed: <one paragraph>
- declined: <one line each, or "none">
- flagged: <one line each with your recommendation, or "none">
- touched-outside-role: <files, or "none">
```

Do not wait on agents by polling. Their completion notifications arrive on their own; keep the plan and the overlap map current while you wait.

## Step 7 — On each completion: record, then propagate upward

When a sub-agent reports:

1. **Parse the report.** Record exit reason, Copilot's assessment, commits, size delta, declined, flagged, and `touched-outside-role`.
2. **Remove that PR's worktree**, then **if it pushed commits, cascade-rebase everything above it** — as soon as no agent is running on a branch above it (otherwise defer until the wave completes). From the main working copy:
   ```
   gh stack checkout {changed PR}
   git fetch origin
   gh stack rebase --upstack          # rebases each branch above onto its updated parent, bottom-up
   gh stack push                      # force-with-lease per branch, only the ones that moved
   ```
   - `gh stack rebase` pauses on a conflict. A conflict in generated or lockfile content, or where both sides made the identical change, is mechanical: resolve it, `gh stack rebase --continue`, and note it in the propagation log. Anything else: `gh stack rebase --abort` and take the **Propagation conflict** exit. Never guess at a semantic resolution across layers.
   - This is the **only** place in either skill where a force-push is allowed, and it is `gh stack push`'s force-with-lease, not a raw `git push --force`. Sub-agents still never force-push.
   - If the PRs were not linked as a GitHub stack (step 1 fallback), do the same by hand, bottom-up: `git rebase origin/{parent}` on each upper branch in turn, then `git push --force-with-lease` for each.
   - If trunk itself moved during the session, `gh stack sync` will also rebase the bottom of the stack onto it; do that once at the end (step 8), not mid-wave.
3. **Run the CI gate on each rebased PR.** A rebase produces a new head commit, so the checks that were green before the rebase no longer count. Apply `/github-resolve`'s CI gate procedure (wait with `gh pr checks --watch`, read required failures, diagnose) to every PR whose branch moved. A failure introduced by propagation belongs to the *lower* PR's change, not the upper PR — send it back to the lower PR's agent via SendMessage (its context is intact) rather than patching it in the upper PR; a fix there triggers another cascade. Coverage gates follow the same rule as in `/github-resolve`: tests for the PR's own changed lines are in scope, thresholds failing on untouched code are flagged, and nothing is ever weakened to get green.
4. **Ask the user about flagged items, then resume the agent.** A `human-decision` report from PR *k* holds every PR above *k* that has not started, because their premises may change; PRs below or beside *k* keep going. Collect the flagged items and ask with **AskUserQuestion**, up to four per call, each question naming the PR, who raised it and where, what it asks, why it was flagged, and your recommendation first marked "(Recommended)". Options are always **Take it**, **Decline it**, **Split it out**; when the same concern was raised on several PRs, ask it once and say which PRs it applies to. If the answer is to stop, take the "you told it to stop" exit. Otherwise **SendMessage** the decisions to PR *k*'s agent (its context is intact) and let it apply them and continue; when it reports again, re-enter this step from 1. Release the held PRs once *k* has pushed and been propagated.
5. **Start the next wave** of PRs whose dependencies are now satisfied.

## Step 8 — Stack-level intent review

Run this once all agents have finished:

- **Whole-stack diff.** `git diff origin/{trunk}...origin/{top headRefName} --stat` and read the parts that changed this session. Ask: does this still deliver the stack intent statement, and nothing else?
- **Size.** Sum the per-PR deltas. Review-driven growth across the stack above roughly 20% of the original total is a red flag even if each PR stayed under its own budget; call it out.
- **Layering.** Any `touched-outside-role` entries, or fixes that a lower PR's role should have carried, are drift. Either move them (only if trivially mechanical and the agent for that PR is still available via SendMessage) or ask the user.
- **Cross-PR consistency.** Two agents may have "fixed" the same Copilot concern in different ways in different layers (two naming conventions, two error-handling styles, a helper added twice). Reconcile only if mechanical; otherwise ask the user.
- Anything this review turns up that needs a decision is asked the same way as step 7's pause (AskUserQuestion, recommendation first), and the answer is carried out — by the relevant agent via SendMessage, or by the orchestrator when it is mechanical — before the final report.
- **Descriptions.** Each PR body should still describe its PR. The bottom PR or the stack's tracking issue, if there is one, should still describe the stack.
- **Trunk sync.** Run `gh stack sync` once so the whole stack sits on current trunk and every PR's remote state matches. Any conflict here is treated like step 7's.
- **Copilot state.** Every PR whose agent exited "satisfied" or "terminal-assessment" should show its latest Copilot review as clean or carrying that assessment. A rebase rewrites the upper PRs' commits, can mark existing review threads outdated, and dismisses any formal Copilot approval — but the PR's own diff does not change unless files overlapped. Rules:
  - A PR with a **terminal assessment** is never re-requested, rebase or not. Note any dismissed formal approval in the report as expected.
  - A PR that exited "satisfied" without an assessment is re-requested only where the rebase *did* change its diff or overlapping files were involved; wait once (poll loop from `/github-resolve` step 9). Byte-identical diff: do not re-request; note it.

## Step 9 — Final report

One report for the whole stack, written so the human can act without opening any PR:

- **Exit reason** and the stack's PR list in order, with each PR's exit state and Copilot's assessment phrase.
- **Size table:** original vs. now, per PR and total.
- **What changed,** one short paragraph for the stack, not per PR.
- **Propagation log:** which rebases happened, any mechanical conflicts resolved, and the CI gate result per PR on its final head commit (required checks green, or the flagged failures).
- **Declined across the stack,** one line each, noting any worth a follow-up.
- **Decisions,** one line each: the PR it concerned, what was asked, what you chose, and what was done.
- **Still open,** anything asked but not carried out (for example because you chose to stop), with what remains.
- Worktrees removed, or the path if you left them for the human to inspect.

## Important

- The orchestrator delegates every PR. If you catch yourself reading Copilot comments and editing code, stop and hand it to an agent.
- Bottom-up is the safe default. Parallelism is earned by proving no file overlap, not assumed.
- A correct fix in the wrong layer is still drift. The stack's shape is part of its intent.
- Rebasing and force-pushing happen only in step 7's cascade, only by the orchestrator, only through `gh stack rebase` / `gh stack push` (force-with-lease). Sub-agents never do either.
- Never merge any PR in the stack. Clean Copilot reviews are a signal for the human reviewer.
- All comments and replies are signed as the working agent, per global attribution guidelines.
- Give the user the wave plan before launching, and a one-line status when each wave starts and finishes.
