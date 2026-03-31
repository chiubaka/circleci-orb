---
name: feature-module-change-playbook
description: >-
  Playbook for adding or changing a feature module with clear per-slice
  layering, wiring boundaries, and public API surfaces in an org-standard
  architecture.
---

# Feature module change playbook

## Goal

Ship feature-module changes that preserve architectural boundaries:

- Vertical feature ownership and per-slice layers.
- Composition/wiring at the edges.
- Intentional public APIs through barrels.

## Relevant org ADRs

- `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`
- `org/docs/adr/0008-barrel-files-public-api-boundaries.md`
- `org/docs/adr/0005-composition-roots-and-wiring-boundaries.md`
- `org/docs/adr/0006-consistency-and-extension-for-new-features.md`
- `org/docs/adr/0009-prefer-small-focused-files.md`

## When to use this skill

Use this skill when:

- Adding a new capability to an existing feature module.
- Splitting mixed logic into `domain/`, `application/`, and `infrastructure/`.
- Introducing or updating adapter implementations.
- Deciding what should be exported from feature/layer barrels.

## Step-by-step playbook

1. Locate the owning feature module and extend it first before creating a new top-level module.
2. Place behavior by responsibility:
   - `domain/`: domain types and invariants.
   - `application/`: orchestration and port contracts.
   - `infrastructure/`: adapter implementations.
3. Keep composition and wiring at explicit edges (host app/composition root), not in domain/application internals.
4. Add or refine barrels intentionally:
   - Feature root barrel for cross-feature consumers.
   - Layer barrels for cross-layer access (`domain/`, `application/`, `infrastructure/`, `presentation/` when those trees exist).
   - Slice barrels for first-class directories under composition hosts (see ADR 0008 / ADR 0016).
   - `infrastructure/<category>/index.ts` for each immediate adapter category.
5. Keep files focused; split mixed-responsibility files unless items are expected to evolve together.

## Common mistakes to avoid

- Deep-importing another feature's internals instead of using its public barrel.
- Mixing transport/framework wiring into core domain/application logic.
- Turning barrels into broad re-export catalogs.
- Creating generic `shared` folders when ownership belongs to a concrete feature.

## Lightweight review checklist

- [ ] Feature ownership is clear and code is colocated with that feature.
- [ ] Domain code does not depend on infrastructure code.
- [ ] Application orchestration depends on ports/abstractions, not vendor details.
- [ ] Composition logic remains at the edge.
- [ ] Barrel exports are minimal and intentional.
- [ ] New files are focused and named after their primary responsibility.

## Illustrative portable layout

```text
<feature>/
  index.ts
  domain/
    index.ts
    <DomainType>.ts
  application/
    index.ts
    <UseCaseOrService>.ts
    <AbstractionOrInterface>.ts
  infrastructure/
    index.ts
    <category>/
      index.ts
      <ImplementationOfAbstractionOrInterface>.ts
```
