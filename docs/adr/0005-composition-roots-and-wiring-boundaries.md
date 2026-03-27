---
status: accepted
date: 2026-03-24
decision-makers: Daniel Chiu
---

# ADR 0005: Composition roots and wiring boundaries

## Context and Problem Statement

[ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) defines **per-feature** hexagonal-style directories and DDD-friendly naming (`domain/`, `application/`, `infrastructure/`, …) within vertical slices and packages. Older [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md) terminology is **superseded** for layout but preserved for history. This ADR does not fully specify **where assembly lives**: constructing implementations, reading configuration/environment, registering a DI container, and mapping HTTP requests to application calls.

Without a shared mental model, wiring can **sprawl** (mixing domain logic with registration), or **concentrate** in ways that become hard to scan as features accrue. We want **principles** for where composition belongs and how to keep it **maintainable** over time—not a one-time refactor of any particular file.

## Decision Drivers

- **Separation of concerns:** Domain and application **behavior** should remain testable and readable without drowning in framework or container details.
- **Scannable composition:** As wiring grows, readers should find **structure** (named steps, parallel sections, or dedicated modules) rather than an undifferentiated block.
- **Presentation boundary:** HTTP handlers, env parsing, and adapter mapping are **edges**; they should not silently absorb unrelated responsibilities without review.
- **Evolution:** New work should **extend** along these boundaries rather than inventing a new wiring shape every time.

## Considered Options

- **Wiring anywhere:** Allow DI, env, and HTTP mapping in any layer if convenient.
- **Composition roots at the edges:** Keep **assembly** (container registration, env-to-config wiring, mounting routes) in **known** places—e.g. dedicated `di/` or `config/` modules and the HTTP entry—while **domain** and **application** code stay free of container APIs except at explicit composition boundaries.
- **Mandatory split packages:** Move all HTTP into separate published packages immediately.

## Decision Outcome

**Chosen option: composition roots at the edges.**

**Justification:** It preserves ADR 0007’s dependency direction while making **where things get plugged together** obvious. Assembly stays **near the edges** of the hexagon (infrastructure, presentation, and explicit composition modules in a server host app) rather than spreading into domain or application **types** and **orchestration** logic inside transport-agnostic packages. Within those roots, prefer **named** steps or sections so related registrations stay grouped and diffs stay reviewable. A **thin** HTTP/presentation entry is the **direction of travel**: mount the app, apply cross-cutting concerns, delegate to application facades exposed by backend packages—without requiring an immediate extract of any specific file; extraction into modules or packages is a **natural** step when surface area grows.

### Consequences

- Good, because **L3xo**-style orchestration and **services** stay focused on behavior while `di/` and `app` (or equivalent) own **how** instances are built.
- Good, because reviewers can ask: “Does this change belong in **wiring** or in **domain/application**?”
- Bad, because **concentrated** composition files can still get large—mitigate with **internal** structure (functions, submodules) without abandoning the single composition-root idea.
- Bad, because “edges” must be **interpreted** per package; confirmation relies on review as much as on folders alone.

### Confirmation

- **Review:** local review guidance should include prompts for wiring vs. domain concerns and mixed responsibilities.
- **Large changes:** Non-trivial new wiring or new HTTP surface should get an explicit **architecture or design** pass in PR description or review.
- **Examples of layout** (illustrative; see [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md)): transport-agnostic wiring may live beside feature modules in a backend package; a server host app owns HTTP framework wiring, env/config, and composition that binds concrete adapters to backend facades. For a repo-local illustration, see `org/docs/adr/examples/composition-root-example.md`.

## Pros and Cons of the Options

### Wiring anywhere

- Bad, because boundaries blur and reviews cannot rely on a consistent place for assembly.

### Composition roots at the edges (chosen)

- Good, because it aligns with hexagonal intent and keeps orchestration readable.

### Mandatory split packages

- Bad, because it imposes heavy ceremony for a small repo stage; optional later per feature needs.

## More Information

- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — vertical modules, per-slice layers, packages, and `core`.
- [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md) — **superseded** for layout; historical DDD naming rationale.
- [ADR 0006](0006-consistency-and-extension-for-new-features.md) — how new features stay consistent with existing wiring idioms.
