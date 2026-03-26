---
name: spike
description: "Run a timeboxed exploration to answer a technical question or validate an approach. Use when the user says 'spike', 'explore whether', 'can we use', 'what if we tried', 'is it feasible', 'prototype this', or needs to investigate before committing to a direction. Produces insight, not production code."
---

# Spike

A structured, timeboxed exploration. Spikes produce learning, not features. The output is a finding — what was tried, what was learned, and what it opens up.

Exploration is work. It's not a break from the job. It's part of the job.

## When to Use

- You need to answer "can we?" or "should we?" before committing to a direction
- A technical approach is uncertain and building the real thing to find out is too expensive
- You want to compare two approaches with working code, not just theory
- You need to understand an unfamiliar library, API, or pattern before designing around it

## Steps

### 1. Frame the Question

Define what you're exploring. A good spike has:
- **A question**: "Can we use WebSockets instead of polling for real-time updates?"
- **A success signal**: "We'll know the answer when we can demonstrate a round-trip message in under 100ms"
- **A scope boundary**: What you will NOT explore (keep it tight)

If the user's request is vague, use `AskUserQuestion` to sharpen the question before proceeding.

### 2. Research

Use `WebSearch`, `WebFetch`, and codebase exploration to understand the landscape before writing any code:

- How do others solve this? What are the known trade-offs?
- What does the project's existing code look like in the relevant area?
- Are there libraries or patterns that could shortcut the exploration?

If the exploration involves technology choices, launch the `tech-scout` agent (subagent_type: `tech-scout`) to evaluate options.

### 3. Explore

Build the minimum thing that answers the question. This is throwaway code — optimize for speed of learning, not quality.

- Work in a scratch branch: `git checkout -b spike/<topic>`
- Write just enough code to prove or disprove the hypothesis
- Take notes as you go — what works, what doesn't, what surprises you

### 4. Write Up

Produce a concise finding. Structure:

```markdown
# Spike: <Question>

## Question
<What you were trying to answer>

## Approach
<What you tried — keep it brief>

## Finding
<What you learned — the core insight>

## Recommendation
<What to do next based on what you learned>
- **Proceed**: <if the approach is viable, what's the next step?>
- **Defer**: <if it works but isn't worth doing now, why?>
- **Abandon**: <if the approach doesn't work, what's the alternative?>

## What This Opens Up
<What new possibilities or directions does this learning create?>
```

Save the writeup to `spikes/<topic>.md` (create the directory if needed).

### 5. Clean Up

- The spike branch is disposable. Ask the user: "Keep the spike branch for reference, or delete it?"
- If the spike leads to real work, suggest: "Ready to spec this out with `/spec-writer`" or "Ready to implement with `/sdlc`"

## Important

- Spikes are NOT implementation. Do not ship spike code to production.
- Spikes are NOT open-ended research. Stay focused on the question.
- A spike that takes longer than expected is a signal — the problem is harder than assumed. Surface that finding early rather than pushing through.
- The most valuable spike outcome is sometimes "we shouldn't do this" — that's learning, not failure.
