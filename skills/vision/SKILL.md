---
name: vision
description: "Create, update, or validate a project vision document. Use this skill when the user asks to 'create a vision', 'define the vision', 'write a vision', 'check vision alignment', or needs to establish the strategic direction and success criteria for a project, library, service, or product. Produces a VISION.md that all agents can reference for alignment."
---

# Vision

This skill produces and maintains a project vision document — the strategic north star that defines what a project is trying to achieve, what success looks like, and what principles guide decisions. The vision serves as an alignment tool for both humans and AI agents working in the project.

## 1. Core Principles

1. **Understand Before Prescribing** — Deeply analyze the project before suggesting a vision. The vision must reflect what the project *is*, not what you imagine it could be.
2. **Collaborate, Don't Dictate** — The vision belongs to the user. Ask questions, surface observations, propose — but the user decides.
3. **Actionable Over Aspirational** — Every principle in the vision must be concrete enough to evaluate a feature or decision against. "Be fast" is useless. "Response times MUST stay under 200ms for core operations" is actionable.
4. **Living Document** — A vision that never changes is either perfect or ignored. It should evolve as the project evolves.
5. **Right-Sized** — A weekend side project doesn't need the same vision ceremony as a production platform. Match the depth to the project.

## 2. Workflow

Execute these phases in order. Do not skip phases.

### Phase 1: Discovery

#### 1.1 Project Analysis

Use the `Explore` agent (subagent_type: `Explore`) to understand the project. Launch multiple agents in parallel to cover:

- **Identity**: What is this? A library, CLI tool, web app, API service, mobile app, framework, monorepo, config repo, or something else?
- **Maturity**: Is this greenfield, early-stage, established, or legacy? How much code exists? How active is development?
- **Architecture**: What are the major components, patterns, and technologies in use?
- **Users**: Who uses this? Developers (if a library), end users (if a product), internal teams (if a service)?
- **Existing Documentation**: Is there an existing VISION.md, README, CONTRIBUTING.md, or CLAUDE.md that describes goals or principles?
- **Existing Tests**: What does the test suite tell you about what the project values (correctness, performance, coverage)?

#### 1.2 Git History Analysis

Run git commands to understand the project's trajectory:

```bash
# Recent activity and direction
git log --oneline -30
# Contributors
git shortlog -sn --no-merges | head -10
# How old is the project
git log --reverse --format="%ai" | head -1
```

This tells you what the project has been *doing*, not just what it says it is.

#### 1.3 Existing Vision Check

Check for any existing vision, mission, or strategy documents:

```bash
find . -maxdepth 3 -iname "*vision*" -o -iname "*mission*" -o -iname "*strategy*" -o -iname "*goals*" | head -20
```

Also check `README.md`, `CLAUDE.md`, and any `docs/` directory for sections that describe the project's purpose or direction.

If an existing vision document exists, read it thoroughly. The goal may be to *update* rather than *create*.

### Phase 2: Clarification

**This phase is mandatory.** Use `AskUserQuestion` to confirm your understanding and fill gaps. Do not proceed to writing without user input.

#### 2.1 Present Your Understanding

Summarize what you've learned about the project in 3-5 sentences. Include:

- What type of thing this is (library, service, product, etc.)
- Who it's for
- What it appears to be trying to achieve
- What stage it's at

Ask the user: **"Is this accurate? What would you correct or add?"**

#### 2.2 Ask Targeted Questions

Based on what you've learned, ask the questions that matter most. Not all questions apply to every project — pick the 3-5 most relevant:

- **For libraries**: What problem does this solve that existing libraries don't? What's the target API surface — minimal or comprehensive? What ecosystems should it support?
- **For services/APIs**: What are the reliability and performance expectations? Who are the consumers? What's the scaling trajectory?
- **For products**: Who is the target user? What's the core value proposition? What differentiates this from alternatives?
- **For tools/CLIs**: What workflow does this optimize? What's the user's current alternative? Where does this tool's responsibility end?
- **For config/infrastructure repos**: What systems does this configure? What's the blast radius of changes? Who needs to understand this?
- **For all**: What does success look like in 6 months? What would make this project a failure? Are there principles you already follow that should be codified?

#### 2.3 Scope the Vision

Based on the user's answers, confirm the scope:

- **Document location**: Propose where the vision should live. Default to `docs/VISION.md`. If a `docs/` directory doesn't exist but the project is small, `VISION.md` at root is fine. If the project already has a vision document elsewhere, update it in place.
- **Depth**: A solo side project might need a half-page vision. A production platform might need 2-3 pages with detailed principles. Confirm the right level with the user.

### Phase 3: Draft the Vision

#### 3.1 Determine Project Type Label

Choose the most accurate label for the project. This appears in the document header and helps agents understand context:

- `Library` — reusable code consumed by other projects
- `Service` — running process that serves requests
- `Product` — user-facing application
- `Tool` — developer or operational utility
- `Framework` — opinionated structure for building things
- `Platform` — foundation that other things are built on
- `Configuration` — settings, infrastructure, or environment definitions

Use the label the user confirms, or the one that best fits.

#### 3.2 Write the Vision Document

Write the vision document following this structure. Adapt sections based on the project type — not every section is required for every project.

```markdown
# Vision: <Project Name>

> <One-sentence mission statement — what this project exists to do.>

| Field        | Value                              |
| ------------ | ---------------------------------- |
| type         | <Library / Service / Product / etc.> |
| status       | <Draft / Active / Evolving>        |
| last-updated | <YYYY-MM-DD>                       |

## Purpose

<2-4 sentences explaining why this project exists, what problem it solves,
and who it serves. This should be clear enough that someone encountering
the project for the first time understands its reason for being.>

## Success Criteria

<Concrete, evaluable criteria for what success looks like. These should be
specific enough to answer "are we succeeding?" without ambiguity.>

- <Criterion 1>
- <Criterion 2>
- <Criterion 3>

## Guiding Principles

<The decision-making framework for this project. Each principle should be
concrete enough to resolve a real disagreement about direction. Include
a brief "which means..." clause that makes the principle actionable.>

### <Principle Name>

<Principle statement — what we believe and why.>

**Which means:** <How this principle translates to concrete decisions.
What we do and don't do because of this principle.>

### <Principle Name>

...

## Boundaries

<What this project is NOT. This section prevents scope creep and helps
agents and contributors understand where the project's responsibility ends.>

- **Out of scope:** <Things this project deliberately does not do>
- **Not a goal:** <Outcomes that might seem related but aren't what we're optimizing for>

## Quality Standards

<The non-negotiable quality bar for this project. These are the standards
that every change — whether from a human or an AI agent — must meet.>

- <Standard 1>
- <Standard 2>

## Evolution

<How this vision should change over time. What signals would indicate
the vision needs updating? Who decides?>
```

#### 3.3 Writing Guidelines

When writing the vision:

- **Be specific to this project.** Generic principles like "write clean code" add no value. Every principle should reflect a real choice this project has made or needs to make.
- **Include the "which means" clause.** A principle without practical implications is decoration. The "which means" clause is what makes principles useful for decision-making.
- **Make success criteria evaluable.** "Users love it" is not evaluable. "Library install-to-first-working-call takes under 5 minutes" is.
- **Write for AI agents too.** Agents will read this document to align their work. Use clear, unambiguous language. Avoid metaphors or cultural references that require human context to interpret.
- **Reflect the user's voice.** This is their vision, not yours. Use the language and priorities they expressed during clarification.

### Phase 4: CLAUDE.md Integration

After writing the vision document, update the project's `CLAUDE.md` to reference it.

#### 4.1 Check for Existing CLAUDE.md

Read the project's `CLAUDE.md` (if it exists). Look for:

- An existing reference to a vision document
- A section about project goals or principles that the vision now supersedes
- The right location to add the reference

#### 4.2 Add Vision Reference

Add a section to `CLAUDE.md` that references the vision. The exact format depends on the existing structure, but it should:

- Point to the vision document location
- Briefly explain what it is and why agents should read it
- Be placed near the top of the file (after project description, before technical details)

Example addition:

```markdown
## Vision

This project's vision, success criteria, and guiding principles are defined in [docs/VISION.md](docs/VISION.md). All agents and contributors should align their work with this vision. When evaluating whether a feature, fix, or change is appropriate, check it against the vision's guiding principles and boundaries.
```

If the CLAUDE.md already has a goals or principles section that the vision supersedes, note this to the user and suggest consolidation — but don't remove content without permission.

### Phase 5: Review

#### 5.1 Alignment Check

Before presenting the final vision, verify:

- [ ] Every success criterion is specific enough to evaluate against
- [ ] Every principle has a "which means" clause
- [ ] The boundaries section addresses at least one common misconception about the project's scope
- [ ] The document reads clearly to both a human and an AI agent
- [ ] The CLAUDE.md reference is in place

#### 5.2 Present to User

Present the completed vision with:

1. The file path where it was written
2. A brief summary of what's in it
3. The CLAUDE.md changes made
4. An invitation to revise — "This is a draft. What would you change?"

## 3. Output

After completing all phases, report:

1. The vision file created or updated (with path)
2. A one-line summary of the project's mission
3. The number of guiding principles defined
4. CLAUDE.md changes made
5. Any open questions or areas where the user should refine the vision
