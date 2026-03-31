---
status: accepted
date: 2026-03-31
decision-makers: Daniel Chiu
---

# ADR 0019: Vendor-specific infrastructure slices

## Context and Problem Statement

Repositories sometimes add a top-level slice with a generic name such as `persistence`, `integrations`, or `database`, but the actual contents are concrete adapters for one vendor or library. That naming hides concrete dependencies, makes imports read as though an abstraction exists when it does not, and makes later decomposition harder when vendor-owned helpers and feature-local adapters need to coexist.

## Decision Drivers

- Architectural honesty about concrete third-party dependencies.
- Clear imports that show when code depends on a vendor-specific adapter stack.
- Locality for feature-owned adapters and related schema/config.
- A repeatable org-level pattern that works for Drizzle today and other vendors later.
- Avoiding fake abstraction layers that increase indirection without substitutability.

## Considered Options

- Keep generic top-level slices such as `persistence` even when they only expose one vendor.
- Put all vendor-specific code only inside each feature with no shared vendor slice.
- Use explicit `infrastructure/<vendor>` slices for shared concrete vendor concerns and keep feature-owned adapters under each feature's `infrastructure/<vendor>`.

## Decision Outcome

Chosen option: use explicit `infrastructure/<vendor>` slices for shared concrete vendor concerns and keep feature-owned adapters under each feature's `infrastructure/<vendor>`.

Justification: This keeps the dependency graph honest. Callers can tell from the import path when they are depending on a concrete vendor stack, while features still own their adapters locally. The pattern scales to multiple vendors without implying an abstraction that does not exist.

### Consequences

- Good, because imports such as `~/infrastructure/drizzle` or `~/feature/infrastructure/openAi` communicate concrete dependencies directly.
- Good, because shared vendor utilities can exist without collapsing feature-owned adapters into one horizontal global folder.
- Good, because feature-local files can stay close to the repository/adapters that consume them.
- Good, because the same pattern can be reused for future vendors or adapter categories.
- Bad, because changing vendors is intentionally visible and may require broader import churn.
- Bad, because a repository may have more top-level concrete slices, which requires discipline to keep them small and intentional.

### Confirmation

- Review imports for concrete honesty: if a slice is vendor-specific, name it after the vendor instead of a generic abstraction.
- Keep feature-local adapters in `feature/infrastructure/<vendor>/`.
- Add a category barrel at `infrastructure/<vendor>/index.ts` when a shared vendor slice exists; do not add a top-level `infrastructure/index.ts` unless the repository truly needs one stable public surface there.

## Pros and Cons of the Options

### Keep generic top-level slices such as `persistence`

- Good, because names can look technology-agnostic at first glance.
- Bad, because the imports become misleading when the slice only exposes one concrete vendor stack.
- Bad, because feature-local vendor code tends to accrete upward into a misleading global utility layer.

### Only feature-local vendor code with no shared vendor slice

- Good, because feature ownership stays strict.
- Good, because there is no cross-feature shared concrete layer to maintain.
- Bad, because shared vendor types, helpers, and tooling entrypoints can become duplicated.

### Explicit `infrastructure/<vendor>` slices with feature-local adapters (chosen)

- Good, because it balances feature locality with honest shared vendor-specific infrastructure.
- Good, because it gives a consistent import story across repositories and vendors.
- Bad, because it still requires judgment about what belongs in the shared vendor slice versus a specific feature.

## More Information

- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) establishes `infrastructure/<category>/` as the adapter-category boundary.
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) governs when category barrels are created and what they should expose.
