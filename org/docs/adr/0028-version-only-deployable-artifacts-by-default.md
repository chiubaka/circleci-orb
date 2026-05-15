---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Version only deployable artifacts in application monorepos by default

## Context and Problem Statement

Application monorepos often contain many internal packages that support deployable artifacts such as backend services, web apps, and mobile apps. In architectures where apps are intentionally thin, most logic resides in internal packages (e.g. shared frontend logic, domain modules, adapters).

We must determine:

> Which packages should participate in versioning and release workflows?

A naive approach would version every package, but this introduces noise, increases operational overhead, and shifts focus away from shipping user-facing changes. At the same time, internal packages can meaningfully affect deployable artifacts, raising questions about how their changes should influence releases.

## Decision Drivers

- Keep versioning aligned with real, user-facing releases
- Minimize operational overhead and cognitive load
- Avoid version churn in internal implementation details
- Preserve clarity and usefulness of changelogs
- Maintain explicit and predictable release behavior
- Align with Changesets’ explicit release intent model

## Considered Options

- Version all packages in application monorepos
- Version only deployable artifacts (default), skip internal packages
- Selectively version internal packages based on significance
- Avoid versioning entirely

## Decision Outcome

Chosen option: "Version only deployable artifacts by default; internal packages do not participate in versioning unless explicitly designated".

Justification: Deployable artifacts are the only units that correspond to externally meaningful releases. Internal packages are primarily architectural seams and do not require independent version tracking in most cases. Keeping them unversioned reduces noise and keeps release workflows focused on shipped value.

## Key Principles

### Versioning reflects shipped artifacts

Version numbers represent deployable applications (e.g. web, mobile, backend), not every internal module.

### Internal packages are not release surfaces by default

Internal packages (e.g. `@l3xo/frontend`, `@l3xo/core`, `@l3xo/react`) are treated as implementation details unless explicitly elevated to release-tracked units.

### Release intent is explicit, not inferred

Changesets does not infer downstream version bumps from changes in internal packages. Developers must explicitly declare which deployable artifacts are affected.

## Practical Behavior

### When internal packages change

- If it has **no user-visible impact**, no changeset is required
- If it affects one or more deployable artifacts, a changeset must be added for those artifacts
- The internal package itself remains unversioned

### Example

A change to `@l3xo/frontend`:

- affects `@l3xo/web` → add changeset for `@l3xo/web`
- affects both `@l3xo/web` and `@l3xo/mobile` → add changeset for both
- does not affect shipped behavior → no changeset required

### No automatic downstream propagation

Changesets will not automatically bump deployable artifacts based on changes in skipped/internal packages. Release intent must be declared explicitly in the changeset.

## Pros and Cons of the Options

### Version only deployable artifacts (default)

- Good, because versioning aligns with real releases
- Good, because changelogs remain focused and meaningful
- Good, because it reduces noise and complexity
- Good, because it minimizes process overhead
- Bad, because internal package version history is not tracked

👉 Chosen because it prioritizes simplicity and shipping velocity.

### Version all packages

- Good, because consistent with library monorepos
- Bad, because creates unnecessary churn
- Bad, because pollutes changelogs
- Bad, because increases cognitive overhead

👉 Rejected due to poor signal-to-noise ratio.

### Selectively version internal packages

- Good, because allows flexibility for important internal modules
- Good, because can capture meaningful internal release history
- Bad, because introduces policy ambiguity
- Bad, because increases decision-making overhead

👉 Not the default, but allowed as an exception.

### No versioning

- Good, because simplifies workflows
- Bad, because removes release traceability
- Bad, because makes debugging and rollback harder

👉 Rejected due to lack of observability.

## Consequences

- Only deployable artifacts participate in Changesets by default
- Internal packages may remain at `0.0.0` or be excluded from versioning
- Developers are responsible for mapping internal changes to affected deployable artifacts
- Release PRs reflect only deployable artifact changes
- Versioning remains tightly coupled to shipped behavior

## Confirmation

- Only deployable artifacts appear in Changesets configuration
- Internal packages are skipped or excluded
- Changesets accurately reflect user-facing changes
- No expectation exists that internal package changes automatically trigger releases

## More Information

This ADR complements:

- Library ADR: ecosystem-level lockstep versioning ([ADR 0023](0023-lockstep-versioning-for-related-package-groups.md))
- Library ADR: explicit release intent via Changesets ([ADR 0024](0024-use-changesets-for-library-monorepos.md))

It reflects a key distinction:

- Library monorepos version reusable packages
- Application monorepos version deployable artifacts

## Related ADRs

- [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md)
- [ADR 0024](0024-use-changesets-for-library-monorepos.md)
- [ADR 0025](0025-versioning-plugins-vs-core.md)
- [ADR 0026](0026-use-changesets-for-application-releases.md)
- [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md)
- [ADR 0038](0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) — coordinated deploys pin immutable **artifact tags** named in the manifest; those tags correspond to versioned deployable artifacts in this policy
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — artifact tags vs environment promotion tags
