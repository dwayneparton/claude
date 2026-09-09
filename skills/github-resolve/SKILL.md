---
name: github-resolve
description: Resolve PR review comments (Copilot and human) by implementing changes, committing and pushing, replying and resolving threads, then re-requesting Copilot review and waiting for its next pass. Requests the first Copilot review if none was ever asked for. Guards the PR's intent and size, and pauses to ask you when a review would change the PR's approach or scope. Loops until Copilot approves, gives a terminal approval assessment (approval recommended, needs a closer look, needs human review), or has no further requests.

---

This skill runs as a **loop against GitHub Copilot's code review**. Each round resolves the comments that exist now, pushes, re-requests Copilot, arms a listener for Copilot's next review, and repeats. Human reviewer comments are addressed whenever they are present, but the loop never waits on a human — only on Copilot.

The loop exists to make the PR **correct and clear**, not bigger. An AI reviewer will happily suggest an unbounded amount of defensive code, extra tests, refactors, and rewording. The job here is to be the second set of eyes that weighs each suggestion against what the PR is actually for, takes the ones that improve it, declines the rest with a reason, and hands anything that would change the PR's direction to a human.

## Exit conditions

Stop the loop and report to the user when any of these is true:

- **Copilot is satisfied and CI is green:** its newest review is `APPROVED`, or is `COMMENTED` with zero actionable inline comments (body typically reads "generated no comments"), **and** the CI gate (below) passes on the current head commit. A clean review with a red required check is not done.
- **Copilot gave a terminal assessment and CI is green:** its newest review's overview carries an approval assessment of *approval recommended*, *needs a closer look*, or *needs human review* (see "Copilot's approval assessment" below). Any addressable comments in that same review are still resolved, pushed, replied to, and gated — but Copilot is **not** re-requested afterward. The PR is handed to the human reviewer with the assessment noted.
- **You told it to stop:** when asked for a decision (see "Asking you" below), you answered that you want to take over or stop.
- **Round cap reached:** 5 rounds by default. Going past this usually means Copilot is nitpicking or contradicting itself; hand back to the user with a summary instead of churning.
- **Copilot never answered:** the listener timed out (20 minutes) without a new Copilot review. Report it; do not blindly re-request again.
- **Nothing actionable and no Copilot review pending:** run the CI gate anyway, fix what it turns up, then report and stop.

No exit except "you told it to stop", "round cap", and "Copilot never answered" may be taken while a **required** check is failing on the head commit, unless you have been asked about that failure and accepted it (pre-existing, infrastructure, or unreadable). CI status is part of the definition of done, not a side note.

Flagged items are **not** an exit. They pause the round so you can decide, then the loop continues with your answer.

## Setup (once per invocation)

```
gh pr view --json number,url,headRefName,baseRefName,title,body,additions,deletions,changedFiles
gh repo view --json nameWithOwner --jq .nameWithOwner
gh pr diff --name-only
```

- Confirm the checked-out branch is the PR's head branch. If not, stop and tell the user.
- Set `round=1`. Keep `owner`, `repo`, `pr` handy for every command below.

### Capture the PR's intent and size

Before reading any review comment, write down (in your working notes, not on GitHub):

- **Intent statement:** one to three sentences, in your own words, of what this PR is for and the approach it takes. Derive it from the title, body, commit messages, and the diff itself — the diff wins if the body is stale.
- **Touched surface:** the list of files the PR changes. Anything a reviewer asks you to change *outside* this list is a scope question by default.
- **Original size:** `additions`, `deletions`, `changedFiles` from `gh pr view`. Every later round is measured against this.

Refer back to these every time you triage. They are the yardstick for "does this comment belong in this PR?"

### Bootstrap: make sure Copilot has been asked to review

Before the first round, check whether Copilot has ever been involved with this PR:

```
# Has Copilot ever submitted a review?  (0 = never)
gh api "repos/{owner}/{repo}/pulls/{pr}/reviews?per_page=100" \
  --jq '[.[] | select(.user.login=="copilot-pull-request-reviewer[bot]") | .id] | max // 0'

# Is Copilot currently a pending requested reviewer?
gh api "repos/{owner}/{repo}/pulls/{pr}/requested_reviewers" \
  --jq '[.users[].login] | index("copilot-pull-request-reviewer[bot]") != null'
```

- **Never reviewed and not requested:** Copilot was never called. Request it now (step 8's request command, baseline `0`), tell the user you are kicking off the first Copilot review, and jump straight to step 9 to arm the listener. Do not triage yet — there is nothing from Copilot to triage. Human comments that already exist get handled in the round that follows Copilot's review.
- **Never reviewed but already requested:** Copilot is queued. Do not request again; jump to step 9 with baseline `0` and wait.
- **Has reviewed before:** proceed normally into the loop at step 1.

This bootstrap request happens **only** when Copilot was never called. It is not a substitute for the per-round re-request in step 8.

## Copilot's approval assessment

Every Copilot review now includes an **approval assessment** in its overview (the review body), saying whether Copilot thinks the PR is ready to approve. When an admin has enabled it, Copilot may also submit a formal `APPROVED` review; that approval is dismissed by any later push, like a human's.

Read the assessment from the newest Copilot review's body (step 10). Match case-insensitively; treat as **terminal** if it contains any of:

- `approval recommended` or `ready to approve`
- `needs a closer look`
- `needs human review` or `human review`

A formal `APPROVED` state is also terminal. Anything else — *changes needed*, *not ready*, or no assessment found — means Copilot still wants changes and the loop continues.

What terminal means:

- **Still resolve what is addressable.** Copilot often says "approval recommended" and still leaves a few comments. Triage and fix them exactly as in any other round: implement, CI gate, reply, resolve Copilot threads, ask you about anything flagged.
- **Do not re-request Copilot** after that push. Its judgment has been given; the human reviewer takes it from here. If the push dismissed a formal approval, say so in the report — that is expected, not a regression.
- *Needs a closer look* and *needs human review* are Copilot saying it is not confident. Do not try to talk it into confidence with more rounds; fix what is concrete, then hand off with that assessment stated plainly.

## Scope and bloat guardrails

These apply to every comment in every round.

**Verify before you act.** Copilot states things confidently that are sometimes false ("this will throw when X is null", "this is never awaited"). Before accepting a correctness claim, confirm it by reading the surrounding code, the callers, or the types — or by running the relevant test. If the claim does not hold, push back and say specifically why. Never add code to defend against a scenario that cannot happen.

**Classify every comment by scope**, using the intent statement and touched surface from setup:

| Class | Meaning | Default action |
|---|---|---|
| **In scope** | Fixes a real defect, inaccuracy, or unclear wording in code this PR already changes, in service of the PR's stated purpose. | Accept or partial. Smallest change that resolves the concern. |
| **Out of scope** | Touches files or behavior the PR does not change; "while you're here" refactors; new tests, docs, logging, config, or abstractions beyond what the PR's purpose warrants; pre-existing issues the PR merely sits next to. | Push back with a reason, resolve the Copilot thread, note it in the final report as a possible follow-up. Do **not** implement. |
| **Intent change** | Proposes a different design, algorithm, API shape, or overall approach than the PR takes; or is a *correct* finding that the PR's approach is fundamentally wrong. | Do not implement. Flag for human decision (see below). |
| **Unverifiable / ambiguous** | You cannot confidently tell whether it is right or what it wants. | Flag for human decision. |

**Code comments, docstrings, messages, and names.** Accept wording changes that fix something *inaccurate* or genuinely *unclear*. Decline rewording that is merely stylistic, restates the code, or asserts a "clarification" that is not true. Clear and accurate beats verbose.

**Bloat budget.** Review-driven changes should be small relative to the PR. Before implementing a round's accepted set, estimate its size. If it would grow the PR by more than roughly 20% of the original net lines, add files the PR did not originally touch, or add a dependency, then something in the accepted set is not really in scope — move the largest items to *flag for human decision* rather than implementing them. Report the PR's size against the original after every round.

**Required checks are part of done.** A merge-blocking check failing on this PR is always in scope to fix, with these rules:

- **Coverage gates.** Tests that cover *this PR's changed lines* to satisfy a required coverage check are in scope, even though "for completeness" tests normally are not — the gate makes them part of the PR's definition of done. Keep them targeted: test the behavior the PR added or changed, nothing adjacent. A gate that fails because of pre-existing, untouched code (a repo-wide threshold the PR did not move) is **flagged**, not fixed here.
- **Never make CI green by weakening it.** Do not lower a threshold, skip or delete a failing test, mark a check non-required, add `continue-on-error`, or edit the workflow to avoid the failure. Fix the code, or flag it.
- **Optional checks** that fail are noted in the report, not fixed, unless the fix is the same one a comment already asked for.

**Things that are almost never in scope for a review fix**, unless the comment points to a real defect in the PR's own code: extra null/undefined guards, try/catch wrappers, additional logging, new configuration options, new helper abstractions or utility modules, broad renames, reformatting untouched code, "for completeness" tests of behavior the PR did not change, and expanding docs beyond the changed behavior.

**Asking you about flagged items.** When a comment lands in *intent change* or *unverifiable*, or the bloat budget or CI gate produces something only you can decide, **do not act on it and do not post anything about it on GitHub**. Leave the thread untouched and add the item to the round's flagged list. The decision is yours, made in this session, not a comment for some maintainer to find later.

Flagged items are asked about at step 7b, after the round's in-scope work is pushed, green, and replied to — so you decide with the finished round in front of you. Use the **AskUserQuestion** tool, one question per flagged item, up to four per call. Each question states, in plain words: who raised it and where (file, line), what it asks for, why you flagged it (intent change, out of scope, unverifiable, CI), and your recommendation as the first option marked "(Recommended)". Options are always: **Take it** (implement in this PR), **Decline it** (reply with reasoning, resolve if Copilot), **Split it out** (reply that it belongs in a follow-up, resolve if Copilot). "Other" is available automatically; if you answer with something else, follow that, and if you say to stop, take the "you told it to stop" exit.

Once answered, act on every decision in the same round: implement accepted items, commit, push, re-run the CI gate, then reply and resolve as the decision dictates. Only then move on to re-requesting Copilot.

When this skill runs inside a sub-agent (for example under `/github-resolve-stack`), you cannot ask the user directly. In that case return the flagged list in your report and wait to be messaged the decisions, then apply them the same way.

## Loop — repeat until an exit condition is met

### 1. Fetch the current review state

- Inline review comments: `gh api "repos/{owner}/{repo}/pulls/{pr}/comments?per_page=100"`
- Issue-level comments: `gh api "repos/{owner}/{repo}/issues/{pr}/comments?per_page=100"`
- Review threads with resolution state and node IDs (needed later to resolve them):
  ```
  gh api graphql -F owner={owner} -F repo={repo} -F pr={pr} -f query='
    query($owner:String!,$repo:String!,$pr:Int!){
      repository(owner:$owner,name:$repo){
        pullRequest(number:$pr){
          reviewThreads(first:100){
            nodes{
              id isResolved isOutdated
              comments(first:1){ nodes{ databaseId author{login} path body } }
            }
          }
        }
      }
    }'
  ```
- Work only from **unresolved** threads. Ignore threads that are already `isResolved: true`.
- Copilot's login is `copilot-pull-request-reviewer[bot]`.

### 2. Triage each comment thread critically

- Read the referenced files and line ranges for each comment, and understand what change is being requested.
- Group related comments that touch the same files.
- Verify the claim (see guardrails). Then classify by scope: **in scope**, **out of scope**, **intent change**, or **unverifiable**.
- For in-scope comments, judge on the merits: is it correct, does it fit the codebase's existing conventions, does it introduce risk, or is it subjective/stylistic preference? Sort into **accept** (valid, worth implementing), **partial** (valid concern but the suggested fix isn't right — implement the underlying concern differently), or **push back** (mistaken or would make things worse).
- Valid comments should inform the change; they should not be applied blindly or allowed to overhaul the PR's direction, especially where multiple comments pull in different directions or a comment is more taste than substance.
- Run the bloat budget check on the accepted set before moving on.
- On round 2+, watch for Copilot re-raising something you already pushed back on, or reversing an earlier suggestion. Do not flip-flop the code to satisfy it — push back again with the same reasoning and let the round cap end the loop if needed.

### 3. Implement the accepted changes

- Make the code changes for each accepted or partially-accepted comment.
- Prefer the smallest diff that resolves the actual concern. Do not "tidy up" adjacent code, add speculative handling, or generalize beyond what the comment needs.

### 4. Update the PR description if needed

- If the changes alter the scope or behavior described in the PR body, update it:
  ```
  gh pr edit {pr} --body "$(cat <<'BODY'
  updated body here
  BODY
  )"
  ```
- Do NOT update the description if the changes are minor fixes that don't affect the summary.
- If you find yourself needing to *materially* rewrite the description to cover the round's changes, that is a sign the changes drifted from the intent. Stop and reconsider the classification before pushing.

### 5. Look at CI on the current head before committing

- Run `gh pr checks {pr} --json name,bucket,state,workflow,link,description` for the commit that is already on the PR.
- If required checks are already failing, diagnose them now using the **CI gate** procedure below and fold the fix into this round's commit, so one push carries both the review fixes and the CI fix.
- Do not wait on pending checks here; the gate after the push (step 6b) does the waiting.

### 6. Commit and push

- Stage only the files that were modified to address comments (and CI fixes).
- Write a clear commit message summarizing what was resolved, e.g. `Address Copilot review (round {round}): <summary>`.
- Push the commit to the current branch with a plain `git push`.
- Re-read the PR size (`gh pr view --json additions,deletions,changedFiles`) and note it against the original in the round's status line.
- If nothing changed this round (every comment was pushed back or flagged), skip the commit but still run step 6b on the existing head, then step 7, then step 8 or the human-decision exit as appropriate.

### 6b. CI gate on the pushed commit

Run the **CI gate** (procedure below). It waits for checks on the head commit you just pushed, fixes required failures, and re-pushes as needed. Do not move to step 7 until the gate passes or every remaining failure is flagged. Replies in step 7 that say "Done" should be true on a green commit.

#### The CI gate procedure

Used by step 5, step 6b, and before every "satisfied" or "nothing actionable" exit.

1. **Wait for the head commit's checks to finish.** `gh pr checks {pr} --watch` blocks until every check completes. Run it through Bash with `timeout` 600000; if it is still pending when the call times out, run it again, up to three times (30 minutes). Beyond that, treat CI as unavailable and flag it.
2. **Read the results**, separating required from optional:
   ```
   gh pr view {pr} --json headRefOid --jq .headRefOid
   gh pr checks {pr} --required --json name,bucket,state,workflow,link,description
   gh pr checks {pr} --json name,bucket,state,workflow,link,description
   ```
   `bucket` is one of `pass`, `fail`, `pending`, `skipping`, `cancel`. Anything in the required list with `fail` or `cancel` blocks the exit.
3. **Diagnose each required failure.**
   - **GitHub Actions job:** the run ID is in `link` (`.../actions/runs/{run_id}/job/...`). `gh run view {run_id} --log-failed` gives the failing steps. Read them for the root cause: test failure, lint, type error, build error, coverage below threshold.
   - **External status check** (Codecov, Sonar, a bot with no Actions run): read the check-run output and statuses on the head SHA:
     ```
     gh api "repos/{owner}/{repo}/commits/{sha}/check-runs" \
       --jq '.check_runs[] | select(.conclusion=="failure") | {name, details_url, title: .output.title, summary: .output.summary}'
     gh api "repos/{owner}/{repo}/commits/{sha}/status" \
       --jq '.statuses[] | select(.state=="failure") | {context, description, target_url}'
     ```
     If the summary and description do not say what failed and the details URL needs a login you do not have, add it to the flagged list so you are asked about it — never silently skip an unreadable required check.
4. **Classify** each failure:
   - **Caused by this PR** (including coverage on its changed lines): fix it in code, per the "Required checks are part of done" rules.
   - **Flaky or infrastructure** (network, runner, timeout, a test unrelated to any changed file that also fails on trunk): re-run once with `gh run rerun {run_id} --failed`. If it fails again, add it to the flagged list. Do not "fix" flaky tests by retrying in code or loosening assertions.
   - **Pre-existing** (a threshold or lint rule that fails on untouched code): add it to the flagged list.
5. **Fix, commit, push, and re-enter the gate** from step 1. Cap at three fix cycles per round; after that, add whatever is still red to the flagged list — you will be asked at step 7b whether to accept it, keep trying, or stop.
6. Record the final check state (green, or the failures awaiting your decision) for the round's status line and the final report.

### 7. Reply to every triaged comment and resolve Copilot threads

- For accepted/partial comments that were addressed, reply confirming the change:
  ```
  gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -f body="Done — addressed in <short description of change>."
  ```
- For comments you pushed back on (mistaken, risky, or stylistic), reply with the reasoning instead of silently skipping them:
  ```
  gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -f body="Held off on this — <concrete reason: convention, risk, why the claim doesn't hold, or why the current approach is preferred>."
  ```
- For out-of-scope comments, say so plainly and name the follow-up if one is warranted:
  ```
  gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies -f body="Out of scope for this PR — <what this PR is for>. <Worth a follow-up: yes/no and why>."
  ```
- For flagged comments, post **nothing** yet. They are decided at step 7b and replied to there.
- For issue-level comments, reply on the issue thread the same way (addressed, pushed back, or out of scope):
  ```
  gh api repos/{owner}/{repo}/issues/{pr}/comments -f body="<Addressed: summary — or — Held off / Out of scope: reason>."
  ```
- **Resolve every Copilot / AI-review thread you addressed, pushed back on, or declined as out of scope**, using the thread node `id` from step 1:
  ```
  gh api graphql -F id={thread_node_id} -f query='
    mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }'
  ```
- Do NOT resolve threads from a human reviewer — let the reviewer resolve them after verifying, even when you pushed back. Flagged threads stay untouched until step 7b.

### 7b. Pause and ask you about flagged items

- If the round produced no flagged items, skip this step.
- Otherwise ask, per "Asking you about flagged items" in the guardrails: AskUserQuestion, one question per item, your recommendation first.
- Act on each answer now, in this round:
  - **Take it:** implement, commit, push, re-run the CI gate (step 6b), then reply "Done — …" and resolve the thread if it is Copilot's.
  - **Decline it:** reply "Held off on this — <your reasoning, or the reason you gave>" and resolve the thread if it is Copilot's.
  - **Split it out:** reply "Out of scope for this PR — will be handled in a follow-up" and resolve the thread if it is Copilot's.
  - **Stop / take over:** take the "you told it to stop" exit and write the final report.
- CI items you accepted as pre-existing or infrastructure are recorded as accepted in the report and no longer block exits.

### 8. Record the baseline, then re-request Copilot

- **Gate:** step 7b must be complete — no flagged item may still be undecided when Copilot is re-requested, or it will simply re-raise them.
- **Terminal assessment:** if the review this round addressed carried a terminal assessment (see "Copilot's approval assessment"), **do not re-request**. Run the CI gate one final time on the pushed head and take the "Copilot gave a terminal assessment" exit.
- Capture the newest Copilot review ID *before* re-requesting, so the listener can tell a new review from the old one (use `0` if Copilot has never reviewed):
  ```
  gh api "repos/{owner}/{repo}/pulls/{pr}/reviews?per_page=100" \
    --jq '[.[] | select(.user.login=="copilot-pull-request-reviewer[bot]") | .id] | max // 0'
  ```
- Re-request the review:
  ```
  gh pr edit {pr} --add-reviewer @copilot
  ```
  If that fails, fall back to the REST API:
  ```
  gh api -X POST repos/{owner}/{repo}/pulls/{pr}/requested_reviewers -f 'reviewers[]=copilot-pull-request-reviewer[bot]'
  ```
  A "review already requested" error is fine — Copilot is already queued; continue to the listener.

### 9. Arm the listener for Copilot's next review

Use the **Monitor** tool with a command that polls every 30 seconds and exits on the first Copilot review newer than the baseline. Fill in `{owner}`, `{repo}`, `{pr}`, and `{baseline}`; set `timeout_ms` to `1200000` (20 minutes), `persistent: false`, and a specific description such as `Copilot re-review on PR #{pr} (round {round})`.

```
baseline={baseline}
while true; do
  r=$(gh api "repos/{owner}/{repo}/pulls/{pr}/reviews?per_page=100" \
    --jq "[.[] | select(.user.login==\"copilot-pull-request-reviewer[bot]\" and .id > $baseline)] | max_by(.id) | select(. != null) | \"\(.id) \(.state) \(.submitted_at)\"" 2>/dev/null || true)
  if [ -n "$r" ]; then echo "COPILOT_REVIEW $r"; exit 0; fi
  sleep 30
done
```

- Keep working or wait; the notification will arrive on its own. Do not run your own foreground polling loop.
- If the monitor is killed by timeout with no `COPILOT_REVIEW` line, that is the "Copilot never answered" exit condition.

### 10. Evaluate Copilot's new review

When the `COPILOT_REVIEW {id} {state} {time}` event arrives:

- Copilot posts comments incrementally after submitting the review, so **wait about 60 seconds** before reading, then fetch:
  ```
  gh api "repos/{owner}/{repo}/pulls/{pr}/reviews/{review_id}" --jq .body
  gh api "repos/{owner}/{repo}/pulls/{pr}/comments?per_page=100" \
    --jq '[.[] | select(.pull_request_review_id == {review_id})] | length'
  ```
- **Read the approval assessment** from the body (see "Copilot's approval assessment") and record it for the round: terminal or not, and the phrase found.
- If `state` is `APPROVED`, or the comment count is `0` / the body says it generated no comments, Copilot is done. **Run the CI gate** on the current head before exiting; if it finds a required failure caused by the PR, fix it, push, and — only if the assessment was *not* terminal — go back to step 8 so Copilot sees the new commit. Otherwise take the **Copilot is satisfied and CI is green** exit.
- If the assessment is terminal **and** there are comments, run one more round (steps 1–7b) to resolve the addressable ones, then exit at step 8's terminal gate without re-requesting.
- **Otherwise** increment `round`. If `round` exceeds the cap, exit and report what Copilot is still asking for. Else go back to step 1.

## Final report (every exit)

Whatever the exit reason, end with a report the user can act on without reading the thread:

- The exit reason and the PR URL.
- **Copilot's assessment:** the phrase from its latest review (or "none"), and whether a formal approval was given or dismissed by a later push.
- **Size:** original vs. current `additions` / `deletions` / `changedFiles`, one line. Call it out if growth exceeded the bloat budget.
- **CI:** required checks on the head commit, green or not, and any optional failures noted. CI failures you accepted are listed under "Decisions".
- **Changed:** one short paragraph of what was actually modified across all rounds.
- **Declined:** out-of-scope and pushed-back items, one line each, with whether a follow-up is worth filing.
- **Decisions:** every item you were asked about, one line each: what it was, what you chose, and what was done as a result.
- **Still open:** anything asked but not acted on (for example because you chose to stop), with what remains to do.

## Important

- Only address comments that request concrete code changes. Skip praise, questions, or discussion-only comments.
- Keep the PR's intent. A review fix should make the PR more correct or clearer, never a different PR. When in doubt, decline or ask — do not implement on your own judgment.
- Decisions are asked for in this session, never delegated to a GitHub comment. Nothing is ever posted that says "flagged for human review".
- Required CI is part of done. Never weaken a check, skip a test, or lower a threshold to get green.
- Never force-push or amend existing commits. Always create new commits.
- Never merge the PR. Copilot approval or a clean review is a signal for the human reviewer, not a merge trigger.
- The listener is only for Copilot. Never wait on, poll for, or re-request human reviewers.
- Once Copilot has given a terminal assessment, never re-request it. Fix what is concrete, then hand the PR to the human reviewer.
- Sign replies and comments as the working agent, per global attribution guidelines — not as the user.
- Give a one-line status at the start of each round (round number, how many comments, in-scope / declined / flagged counts, current size vs. original) so the user can follow along across a long session.
