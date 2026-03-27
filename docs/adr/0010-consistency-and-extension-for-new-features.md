---
status: accepted
date: 2026-03-24
decision-makers: Daniel Chiu
---

# ADR 0010: Consistency and extension for new features

## Context and Problem Statement

Smaller repositories have **fewer** repeated examples of each pattern than large monorepos. Without explicit conventions, **new** features tend to introduce **one-off** option shapes, naming, or wiring that **drift** from neighboring code. That drift is easy to miss in review because each change looks locally reasonable.

We want a **recorded** expectation: when adding capability, **prefer** matching existing **idioms** and **layers**, and verify consistency through **review** (and tests where they encode contracts)—so long-term evolution stays coherent.

## Decision Drivers

- **Predictability:** Similar problems should **look** similar in code and in review diffs.
- **Alignment with ADR 0011 and 0009:** New code should respect **per-feature** layer boundaries, module **barrels**, and composition roots unless a deliberate exception is documented.
- **Reviewability:** Checklist-style prompts help humans and agents catch **grab-bag** options and **mixed** responsibilities early.
- **Pragmatism:** Do not block useful work when no existing idiom fits—then prefer a **small**, well-named addition that future work can follow.

## Considered Options

- **No convention:** Let each feature choose structure ad hoc.
- **Strict pattern matching:** Require every new feature to copy an existing file’s structure one-for-one.
- **Prefer existing idioms, deliberate exceptions:** Default to **rhyming** with current code (naming, options types, stub vs. real adapter placement); document or discuss when breaking pattern is justified.

## Decision Outcome

**Chosen option: prefer existing idioms, deliberate exceptions.**

**Justification:** It balances **consistency** with **flexibility**. Reviewers ask whether the change **extends** an existing story (same layer, similar `*Service` wiring, coherent options type) or introduces a **new** pattern that others should follow. Exceptions are OK when the problem is genuinely new; they should be **visible** in PR discussion so the repo does not accumulate silent one-offs.

### Consequences

- Good, because **cruft drift** (inconsistent logger names, unrelated concerns in one file, option bags) gets a standard lens in review.
- Good, because **ADR 0009** composition guidance, **ADR 0011** module layout, and **ADR 0008** documentation expectations apply uniformly to new work.
- Bad, because **judgment** is required—“matches existing idiom” is not always objective; mitigate with [`REVIEW-CHECKLIST.md`](../../../REVIEW-CHECKLIST.md) prompts and ADR cross-links.

### Confirmation

- **REVIEW-CHECKLIST.md** includes a **Consistency and extension** section aligned with this ADR.
- **Tests:** Behavior changes follow existing TDD expectations in [`AGENTS.md`](../../../AGENTS.md); new contracts may add tests that lock intended usage.
- **CI:** [ADR 0011](0011-vertical-feature-modules-hexagonal-slices-and-packages.md) encourages **lint** for module boundaries when feasible; until rules exist, review carries the same expectations.

## Pros and Cons of the Options

### No convention

- Bad, because drift accumulates unnoticed.

### Strict pattern matching

- Bad, because it blocks legitimate new shapes and encourages cargo-cult copying.

### Prefer existing idioms, deliberate exceptions (chosen)

- Good, because it scales with repo growth and keeps review dialogue explicit.

## More Information

- [ADR 0011](0011-vertical-feature-modules-hexagonal-slices-and-packages.md) — vertical modules, layers per slice, packages, `core`.
- [ADR 0012](0012-barrel-files-public-api-boundaries.md) — barrels as public API boundaries.
- [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md) — **superseded** for layout; historical naming rationale.
- [ADR 0009](0009-composition-roots-and-wiring-boundaries.md) — where wiring and presentation assembly live.
