---
status: accepted
date: 2026-03-27
decision-makers: Daniel Chiu
---

# ADR 0014: Stable facade construction and centralized composition

## Context and Problem Statement

As orchestration-heavy packages evolve, composition logic often starts as small convenience factories (`create*`) near a first consumer, then multiplies across files as new dependencies and config are added. That pattern creates drift in wiring behavior, duplicates env/config mapping, and makes constructor ownership boundaries less obvious.

We need a repeatable construction pattern that scales as packages grow and remains consistent with composition-root boundaries from [ADR 0005](0005-composition-roots-and-wiring-boundaries.md).

## Decision Drivers

- Avoid wiring drift and duplicated composition logic
- Keep orchestration ownership explicit and discoverable
- Provide one stable construction API for callers
- Make dependency assembly easy to review and extend
- Keep package-level migration work incremental rather than disruptive

## Considered Options

- Ad hoc helper factories (`create*`) per call site or feature
- Direct `new Facade(...)` construction at each composition root
- Stable config-first facade entrypoint with centralized loader/composer

## Decision Outcome

Chosen option: "Stable config-first facade entrypoint with centralized loader/composer".

Justification: This pattern gives callers one predictable entrypoint while preserving clear ownership boundaries inside the facade constructor. It also centralizes dependency assembly and config evolution in one place, reducing wiring drift and improving reviewability.

### Consequences

- Good, because callers use one stable construction contract rather than many factories
- Good, because composition logic changes are concentrated and auditable
- Good, because facade constructors remain the primary ownership boundary for orchestration dependencies
- Good, because migration from legacy factories can happen incrementally behind one entrypoint
- Bad, because config and loader/composer modules may become broad without periodic decomposition
- Bad, because some teams may over-generalize config too early; schema discipline is required

### Confirmation

- **Review checks:** New orchestration-heavy package APIs should expose one stable, config-first facade entrypoint (for example `Facade.init(config)`).
- **Composition checks:** Adapter/client/service construction should be centralized in one dedicated loader/composer module, not repeated across `create*` helpers.
- **Ownership checks:** The facade constructor should remain the authoritative dependency boundary (`new Facade(...)`), with helper logic kept private unless truly reusable.
- **Extension checks:** New dependency or adapter wiring should extend config schema plus loader/composer rather than introducing another construction pathway.
- **Migration checks:** When retiring legacy factories, keep one compatibility path only long enough to migrate callers, then remove it.

## Pros and Cons of the Options

### Ad hoc helper factories (`create*`) per call site or feature

- Good, because it is quick for early-stage development
- Good, because each caller can optimize for local needs
- Bad, because wiring behavior drifts and duplicates across helpers
- Bad, because ownership boundaries become implicit and fragmented
- Bad, because migration and review complexity increase as factories multiply

### Direct `new Facade(...)` construction at each composition root

- Good, because ownership boundaries are explicit at call sites
- Good, because no extra entrypoint indirection is required
- Neutral, because this can work for very small packages with few dependencies
- Bad, because constructor argument churn leaks into every caller
- Bad, because repeated adapter assembly encourages copy-paste composition

### Stable config-first facade entrypoint with centralized loader/composer (chosen)

- Good, because callers depend on a stable API while internals evolve
- Good, because config and dependency assembly changes are localized
- Good, because the facade constructor remains the clear orchestration boundary
- Neutral, because an additional layer (loader/composer) is introduced
- Bad, because poor naming or schema design can still produce accidental complexity

## More Information

- [ADR 0005](0005-composition-roots-and-wiring-boundaries.md) — composition roots at edges and wiring boundaries
- [ADR 0006](0006-consistency-and-extension-for-new-features.md) — consistency expectations when extending features
- [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md) — class-owned orchestration boundaries
