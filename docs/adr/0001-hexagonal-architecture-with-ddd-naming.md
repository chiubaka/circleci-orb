---
status: superseded-by-ADR-0007
date: 2026-03-19
decision-makers: Daniel Chiu
---
# ADR 0001: Hexagonal Architecture with DDD Naming

> **Superseded:** Layout and decomposition for this repository are defined by [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) (vertical feature modules, per-slice layers, packages, and `core`). This ADR remains useful for **historical context** and for the original **DDD naming vs. hexagonal vocabulary** tradeoff.

## Context and Problem Statement

We want a directory structure that makes our architectural intent obvious:

- **Hexagonal (Ports & Adapters)** dependency direction: core business logic depends on abstractions; framework/IO concerns live at the edges.
- **DDD naming**: prefer DDD-friendly terms like `*Service` and `*Repository` rather than forcing hexagonal vocabulary like `Port`/`Adapter`.

We also want a consistent convention for where contracts/interfaces live and where infrastructure-specific implementations live, so stubs and future infrastructure adapters can be swapped without changing orchestration code.

## Decision Drivers

- Keep the hexagonal dependency direction obvious and enforceable via directory/module boundaries.
- Preserve DDD-friendly terminology for interfaces and implementations.
- Make stubbing easy: initial implementations should live at the edges and satisfy application contracts.

## Considered Options

- Use hexagonal vocabulary throughout (e.g. `*Port` / `*Adapter`), including names in `application/` contracts and infrastructure implementations.
- Use DDD naming and DDD-ish layering without explicitly aligning directory boundaries to hexagonal dependency direction.
- Use hexagonal-style layering via directories (domain/application/infrastructure/presentation) while keeping DDD naming for the contracts and implementations.

## Decision Outcome

Chosen option: "Use hexagonal-style layering via directories while keeping DDD naming for contracts and implementations."

Justification: This best satisfies the decision drivers by enforcing dependency direction via boundaries while keeping terminology readable and making it straightforward to plug in stubs or real infrastructure adapters behind the same `*Service`/`*Repository` contracts.

### Consequences

- Good, because directory boundaries make the hexagonal dependency direction clear (`domain/` stays independent).
- Good, because the naming remains natural to DDD practitioners (`UsersService`, `ChatService`, etc.).
- Good, because stubs and future infrastructure implementations can be introduced under `infrastructure/` without changing orchestration (`application/`).
- Bad, because terminology (`Service`/`Repository`) is used where hexagonal would say `Port`/`Adapter`.
- Bad, because developers must rely on directory boundaries to enforce the dependency rule, not on naming alone.

### Confirmation

- The rule is confirmed during review by checking import direction (e.g. `domain/` does not import `infrastructure/`).
- We confirm correctness continuously with the normal verification workflow: `pnpm build`, `pnpm lint`, and `pnpm test`.

## Pros and Cons of the Options

### Hexagonal vocabulary (`*Port` / `*Adapter`) everywhere

* Good, because the architecture intent matches the terminology used by hexagonal.
* Bad, because it forces a non-DDD vocabulary onto contracts that may otherwise be clearer with `*Service`/`*Repository`.

### Adopted approach: hexagonal boundaries + DDD naming

* Good, because boundaries still enforce hexagonal dependency direction.
* Good, because `*Service`/`*Repository` naming stays consistent with DDD conventions.
* Bad, because the hexagonal terms (`Port`/`Adapter`) are implicit rather than explicit in naming.

## More Information

This ADR is intentionally historical and vocabulary-focused. For repository-local layout illustrations, see `org/docs/adr/examples/feature-module-layout-example.md` and `org/docs/adr/examples/composition-root-example.md`.

