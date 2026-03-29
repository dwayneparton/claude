---
name: debug
description: "Structured debugging workflow for production issues, errors, and unexpected behavior. Use when the user says 'debug', 'why is this failing', 'this is broken', 'investigate this error', 'something is wrong with', or needs to diagnose a problem before fixing it. Produces a root cause, not a guess."
---

# Debug

A structured workflow for diagnosing problems. Debugging is not guessing — it's narrowing. Each step reduces the space of possible causes until one remains.

## When to Use

- A production issue, error, or unexpected behavior needs diagnosis
- A test is failing and the cause isn't obvious
- Something "used to work" and doesn't anymore
- An error message is confusing or misleading

## Steps

### 1. Capture the Symptom

Define what's wrong in concrete terms:

- **What is happening?** (the actual behavior)
- **What should happen?** (the expected behavior)
- **When did it start?** (if known — check `git log` for recent changes)
- **How to reproduce?** (specific steps, inputs, or conditions)

If the user's report is vague, use `AskUserQuestion` to get specifics. "It's broken" is not a symptom — "the API returns 500 when the user has no profile" is.

### 2. Reproduce

Confirm the problem exists and is repeatable. Run the failing case:

- Run the failing test, endpoint, or script
- Check error logs, stack traces, console output
- If the issue is intermittent, identify the conditions that trigger it

If you cannot reproduce, say so and investigate environmental differences (config, data, dependencies) before proceeding.

### 3. Hypothesize

Based on the symptom and reproduction, form 2-3 competing hypotheses about root cause. For each hypothesis:

- **What would cause this?** (the theory)
- **What evidence would confirm it?** (the test)
- **What evidence would disprove it?** (the counter-test)

Launch parallel `Explore` agents (subagent_type: `Explore`) to investigate different hypotheses simultaneously. Each agent should search for specific evidence that confirms or disproves its assigned hypothesis.

```
Agent tool:
  subagent_type: "Explore"
  prompt: "Investigate hypothesis: [THEORY]. Look for: [EVIDENCE].
           Search: [SPECIFIC FILES/PATTERNS/LOGS]"
  description: "Investigate: [short hypothesis name]"
```

### 4. Narrow

Evaluate the evidence from each hypothesis:

- Which hypotheses are disproved? Eliminate them.
- Which have supporting evidence? Dig deeper.
- If all hypotheses are disproved, form new ones from what you learned.

Continue until one root cause remains with clear evidence.

### 5. Verify

Confirm the root cause by demonstrating the causal link:

- Show the specific code, config, or data that causes the problem
- Explain why it produces the observed symptom
- If possible, write a minimal reproduction (a failing test is ideal)

### 6. Hand Off to Fix

Once root cause is confirmed, hand off to the SDLC workflow:

```
The root cause is: [EXPLANATION]
The fix should: [WHAT NEEDS TO CHANGE]
Affected files: [LIST]
```

Suggest: "Ready to fix this with `/sdlc`" — the fix follows the normal development workflow (branch, implement, test, PR).

If the fix is trivial (one-line change, config update), say so. Not every bug needs full SDLC ceremony — let the user gauge the blast radius.

## Important

- **Don't guess.** Narrowing beats guessing. A wrong guess wastes more time than methodical investigation.
- **Don't fix before you understand.** The urge to "just try something" is strong. Resist it until you have a root cause.
- **Check recent changes first.** `git log --oneline -20` and `git diff HEAD~5` often reveal the cause faster than reading code.
- **Reproduce before investigating.** If you can't trigger the bug, you can't verify the fix.
- **A failing test is the best deliverable.** If you can write a test that fails for the right reason, the fix practically writes itself.
