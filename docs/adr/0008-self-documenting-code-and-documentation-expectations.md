---
status: accepted
date: 2026-03-24
decision-makers: Daniel Chiu
---

# ADR 0008: Self-documenting code and documentation expectations

## Context and Problem Statement

We want code to be **readable** and **self-documenting** first: the right **names** and **decomposition** should carry most of the meaning. We also use **ESLint** with JSDoc-related rules (including `jsdoc/require-jsdoc`) so that exports and certain constructs carry documentation that IDEs can surface.

Those two forces can be misread as “comments are the main clarity tool” or “we should change lint rules to match taste.” We need a **single recorded principle** so humans and agents align on **when** prose adds value and **when** to refactor instead—without reopening ESLint policy on every change.

## Decision Drivers

- **Clarity at the source:** Prefer fixing unclear code via structure and naming before relying on comments.
- **IDE utility:** JSDoc and comments should often add information **hover** and navigation can show (parameters, behavior, invariants types alone do not express).
- **Stable tooling:** Keep existing ESLint JSDoc rules unless a separate decision explicitly changes them.
- **Public surfaces:** Richer documentation on facades, package APIs, and stable contracts is welcome when it **adds substance** (behavior, edge cases, security or business context), not when it only duplicates types.

## Considered Options

- **Comments-first:** Rely on narrative comments and JSDoc whenever something is hard to follow; de-prioritize refactors for readability.
- **Code-first, purposeful docs:** Prefer self-documenting code; use JSDoc/comments where they add non-obvious value or IDE-visible detail; refactor when prose would merely patch bad structure.
- **Relax ESLint JSDoc rules:** Reduce `jsdoc/require-jsdoc` (or similar) to match a “minimal comment” style.

## Decision Outcome

**Chosen option: code-first, purposeful docs.**

**Justification:** It matches how we want the codebase to feel under review and under AI-assisted edits: structure and names are the primary story; documentation amplifies that story where types and signatures are insufficient. We keep current ESLint JSDoc rules so documentation expectations stay **consistent** and automated; satisfying those rules is not a substitute for clear code, but it does not conflict with this principle when JSDoc explains **behavior** and **intent**, not only repeated types.

### Consequences

- Good, because reviewers can ask for **refactors** when comments would paper over confusing structure, without arguing about whether lint “requires” comments.
- Good, because **public** APIs can still be thoroughly documented for consumers and IDE hover.
- Good, because we **do not** churn ESLint config to chase a subjective “feel.”
- Bad, because **mandated** JSDoc on some exports can feel verbose if authors only restate signatures—mitigate by writing **substantive** lines (behavior, preconditions, non-obvious semantics) per [`REVIEW-CHECKLIST.md`](../../../REVIEW-CHECKLIST.md).

### Confirmation

- **AGENTS.md** and **REVIEW-CHECKLIST.md** reference this ADR and restate the principle briefly for day-to-day work.
- **Lint:** Existing `pnpm lint` continues to enforce JSDoc rules; no change to those rules under this ADR.
- **Review:** Reviewers use [`REVIEW-CHECKLIST.md`](../../../REVIEW-CHECKLIST.md) (JSDoc section) for judgment on substance vs. redundancy.

## Pros and Cons of the Options

### Comments-first

- Bad, because comments drift from code and can hide structural problems.

### Code-first, purposeful docs (chosen)

- Good, because naming and decomposition remain the primary lever for clarity.
- Good, because JSDoc remains aligned with ESLint and IDE affordances.

### Relax ESLint JSDoc rules

- Bad, because it trades away **consistent** enforcement without solving readability at the source.
- Rejected for this ADR; a future ADR could revisit tooling if pain is widespread.

## More Information

- Related: [ADR 0011](0011-vertical-feature-modules-hexagonal-slices-and-packages.md) (where code lives by **feature module** and layer); this ADR does not change those boundaries—only how we document and clarify behavior within them.
