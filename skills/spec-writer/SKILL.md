---
name: spec-writer
description: "Write feature specification documents for planned work. This skill should be used when the user asks to 'write a spec', 'create a spec', 'spec out', 'design a feature', 'write a feature spec', 'spec this', or needs a detailed feature specification before implementation. Produces numbered spec files in specs/."
---

# Spec Writer

This skill produces feature specification documents using an RFC-inspired format. Specs are written to `specs/` and serve as the authoritative reference for both human developers and AI agents implementing the feature.

## 1. Core Principles

1. **Research First** - Thoroughly understand the codebase and prior art before writing anything
2. **Right-Size Specs** - Each spec should be large enough to be useful but small enough to express in a single document
3. **Clarify Before Writing** - Use AskUserQuestion for scope splits and design choices
4. **Verify After Writing** - Cross-check every spec against the actual codebase
5. **Ergonomics Matter** - Specs should be readable and actionable by both AI and human implementors

## 2. Workflow

Execute these phases in order.

### Phase 1: Research

#### 1.1 Local Codebase Exploration

Use the `Explore` agent (subagent_type: `Explore`) to understand the relevant parts of the codebase:

- Identify existing patterns, abstractions, and conventions
- Find related features or systems already implemented
- Map out the files, modules, and data models that the feature would touch or extend
- Note any constraints (auth patterns, API conventions, DB schema patterns, component libraries)

Launch multiple Explore agents in parallel if the feature spans distinct areas (e.g., frontend + backend + database).

#### 1.2 Technology and Pattern Research

When the feature involves technologies, libraries, or patterns that may benefit from external research, use the `tech-scout` agent (subagent_type: `tech-scout`) to:

- Discover how similar features are commonly implemented in the ecosystem
- Identify relevant libraries, APIs, or standards
- Find best practices and anti-patterns

Skip this step only when the feature is purely internal (e.g., a UI layout change with no new technology).

#### 1.3 Web Discovery

Use `WebSearch` to find:

- How other products implement similar features (UX patterns, data models, API designs)
- Relevant RFCs, standards, or specifications
- Community discussions about tradeoffs for this type of feature

Focus searches on understanding the problem space, not on finding code to copy.

#### 1.4 Synthesize Research

Before proceeding, compile a mental model of:

- What exists in the codebase today
- What patterns and conventions must be followed
- What external patterns and best practices apply
- What the key design decisions and tradeoffs are

---

### Phase 2: Scope Analysis

Analyze whether the feature fits in a single spec or needs to be split.

**A single spec should:**
- Describe one cohesive feature or system
- Be implementable as 1-3 PRs (not necessarily one, but a tightly related set)
- Be readable in one sitting (~500-2000 lines of markdown)

**Split into multiple specs when:**
- The feature has clearly independent subsystems (e.g., "real-time chat" = transport layer spec + UI spec + persistence spec)
- Different parts have different dependencies or could be built in parallel
- A single document would exceed ~2000 lines

**When scope is ambiguous, use `AskUserQuestion`** to present:
- The proposed split (or unified approach)
- The reasoning for each option
- Any other design choices that affect scope

---

### Phase 3: Write Specs

#### 3.1 Determine File Numbering

Check existing specs to determine the next number:

```bash
ls specs/ 2>/dev/null | sort -n | tail -1
```

If no specs exist, start at `0001`. Otherwise increment from the highest existing number. Numbers are zero-padded to at least 4 digits (0001, 0002, ..., 0010, ..., 0100).

#### 3.2 Create the Spec File(s)

Ensure the directory exists:

```bash
mkdir -p specs
```

Write each spec to `specs/<number>-<name>.md` where `<name>` is a brief descriptive name using only lowercase alphanumerics and dashes.

Examples:
- `specs/0001-real-time-notifications.md`
- `specs/0002-creator-analytics-pipeline.md`
- `specs/0003-creator-analytics-dashboard.md`

#### 3.3 Spec Document Structure

Each spec MUST follow this RFC-inspired structure. Not every section is required for every spec — adapt as needed. A small feature may omit "Background" or "Non-Goals". A spec that is purely a data model change may have a minimal "UI Changes" section.

```markdown
# SPEC-<number>: <Title>

| Field      | Value                          |
| ---------- | ------------------------------ |
| status     | Draft                          |
| depends-on | SPEC-XXXX (or "none")          |
| target     | <YYYY-MM-DD or "unscoped">     |
| created    | <YYYY-MM-DD>                   |

## Table of Contents

1. [Overview](#1-overview)
2. [Terminology](#2-terminology)
3. [Background](#3-background)
4. [Goals](#4-goals)
5. [Non-Goals](#5-non-goals)
6. [Design](#6-design)
7. [Type Contracts](#7-type-contracts)
8. [Behavioral Specification](#8-behavioral-specification)
9. [Error Handling](#9-error-handling)
10. [Migration & Rollout](#10-migration--rollout)
11. [Open Questions](#11-open-questions)
12. [Tasks](#12-tasks)

## 1. Overview

<1-3 paragraphs: what this feature does and why it matters.>

## 2. Terminology

<Define domain-specific terms used in this spec. Helps both humans
and AI agents interpret the spec unambiguously.>

- **Term**: Definition.

## 3. Background

<Context that motivates this work. What exists today, what problem
does the user face, what triggered this spec.>

## 4. Goals

<Bullet list of what this spec aims to achieve.>

## 5. Non-Goals

<Bullet list of what is explicitly out of scope.>

## 6. Design

<The core design. Use subsections as needed. Include diagrams
(Mermaid) where they clarify flow or architecture. This section
should be detailed enough that an implementor — human or AI —
can build the feature without guessing.>

### 6.1 <Subsection>

<Details.>

## 7. Type Contracts

<Use language-agnostic pseudo-type syntax (see below) to define
the public API surface. This section is the authoritative reference
for what gets implemented.>

### 7.1 <Contract Name>

\```
contract ExampleConfig {
  name: String
  enabled: Boolean
  options?: List<String>
}
\```

## 8. Behavioral Specification

<Precise behavioral rules using RFC 2119 language (MUST, SHOULD, MAY).
Each rule should be testable.>

### 8.1 <Rule Group>

- `doThing(input)` MUST return a non-empty result.
- `doThing(input)` SHOULD complete within 200ms for typical inputs.

## 9. Error Handling

<How errors are surfaced, what the failure modes are, and what
recovery looks like.>

## 10. Migration & Rollout

<If the feature touches existing data or APIs: migration steps,
backward compatibility, and rollout strategy. Omit for greenfield
features with no migration concerns.>

## 11. Open Questions

<Unresolved design decisions. Each should be numbered and actionable.>

1. **Question**: <description>
   - Option A: <tradeoff>
   - Option B: <tradeoff>

## 12. Tasks

<Populated after the spec body is written. Nested markdown checklist.>

- [ ] Task 1
  - [ ] Subtask 1a
  - [ ] Subtask 1b
- [ ] Task 2
```

#### 3.4 Type Contract Syntax

When a spec defines data models, APIs, or interfaces, use language-agnostic pseudo-type syntax so the spec is implementable in any language. This is neither TypeScript nor any specific language — it is a neutral format.

| Syntax             | Meaning                                        |
| ------------------ | ---------------------------------------------- |
| `contract Foo`     | A named structural type (interface/struct)     |
| `extends Bar`      | Inherits all fields from `Bar`                 |
| `union T = A \| B` | Discriminated union (one of the listed types)  |
| `alias T = ...`    | Type alias                                     |
| `?`                | Optional field (may be absent or null)         |
| `List<T>`          | Ordered collection of `T`                      |
| `Map<K, V>`        | Key-value mapping                              |
| `->`               | Return type                                    |
| `"literal"`        | Literal string value                           |
| `String`           | UTF-8 string                                   |
| `Number`           | IEEE 754 double-precision float                |
| `Boolean`          | `true` or `false`                              |
| `Any`              | Unconstrained type                             |
| `Void`             | No return value                                |
| `Promise<T>`       | Asynchronous result of type `T`                |

Example:

```
contract NotificationConfig {
  channel: "email" | "push" | "sms"
  enabled: Boolean
  retryPolicy?: RetryPolicy
}

contract RetryPolicy {
  maxAttempts: Number
  backoffMs: Number
}

createNotification(config: NotificationConfig) -> Promise<Notification>
```

#### 3.5 RFC 2119 Language

Use RFC 2119 keywords (MUST, SHOULD, MAY) in the Behavioral Specification section to express requirement levels. This is not full RFC formality — the goal is precision for implementors, not standards-body compliance.

| Keyword | Meaning                                              |
| ------- | ---------------------------------------------------- |
| MUST    | Absolute requirement                                 |
| SHOULD  | Recommended unless there is a compelling reason not to |
| MAY     | Truly optional                                       |

---

### Phase 4: Review & Challenge

After the spec body is written, run two reviews. These can be launched in parallel.

#### 4.1 API Ergonomics Review

Invoke the `api-ergonomics-reviewer` agent (subagent_type: `api-ergonomics-reviewer`) to review the spec's type contracts and design for:

- **Naming consistency** - Are names clear, consistent, and discoverable?
- **Parameter ergonomics** - Is the parameter ordering intuitive? Are required vs optional fields well-chosen?
- **Return type clarity** - Are return types predictable and useful?
- **AI readability** - Can an AI agent unambiguously implement from this spec?
- **Developer experience** - Would a human developer find the API natural to use?

Provide the agent with the full spec file path and ask it to evaluate the public API surface defined in the Type Contracts and Behavioral Specification sections.

#### 4.2 Design Decisions Review

Invoke the `consultant` agent (subagent_type: `consultant`) to stress-test the spec's key design decisions:

- What are the trade-offs of the chosen approach?
- What alternatives were not considered?
- Are there one-way doors (hard-to-reverse decisions) that deserve more scrutiny?
- Does the design open doors for future work or close them?

Provide the agent with the full spec file path and ask it to evaluate the design choices in the Design and Type Contracts sections.

The goal is not to block — it's to make sure the spec author has seen the full picture before committing. Dissent is information, not obstruction.

#### 4.3 Incorporate Feedback

Incorporate feedback from both reviewers into the spec. If either review raises design questions that need user input, add them to the Open Questions section and use `AskUserQuestion` to resolve them.

---

### Phase 5: Task Breakdown

After the spec body is finalized, populate the `## 12. Tasks` section with a nested markdown checklist:

- Break the spec into discrete, implementable tasks
- Each task should be completable in a single PR
- Order tasks by dependency (foundational work first)
- Include subtasks where a task has distinct implementation steps

---

### Phase 6: Verification

After writing each spec, verify it against the codebase:

1. **Schema references** - Confirm that any database tables, columns, or types mentioned actually exist (or are clearly marked as new)
2. **API patterns** - Verify that proposed API endpoints follow existing conventions (naming, auth patterns, input validation)
3. **Component patterns** - Confirm that referenced UI components exist and that proposed new components follow project conventions
4. **File paths** - Verify that any referenced file paths are accurate
5. **Import patterns** - Confirm that any libraries or modules referenced are actually available in the project

For each discrepancy found:
- Fix the spec directly if the correction is clear
- Add an "Open Question" if the right approach is ambiguous

Report a summary of any corrections made or questions added during verification.

---

## 3. Output

After completing all phases, report:

1. The spec file(s) created (with paths)
2. A one-line summary of each spec
3. Any open questions that need user input
4. Suggested next steps (e.g., "Ready for implementation via /sdlc" or "Needs design decisions on open questions first")
