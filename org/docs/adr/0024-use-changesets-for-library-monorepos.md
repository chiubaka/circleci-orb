---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Use Changesets with explicit release intent for Hyperdrive package versioning and publishing

## Context and Problem Statement

Library-oriented monorepos host many interdependent packages grouped by ecosystem (for example, Hyperdrive’s auth, payments, and core ecosystems). These repositories must:

- support batched releases that span many PRs
- allow ecosystem-level lockstep versioning where needed
- keep semver and dependency metadata accurate
- produce high-quality changelogs
- capture release intent in a way that is reviewable and not inferred from commit history alone

The fundamental question is:

> Should release behavior be declared explicitly via change files or inferred from commit history?

## Decision Drivers

* Explicit, reviewable release intent
* Support for batched releases across multiple PRs
* Strong support for monorepo and ecosystem/grouped packages
* Avoid dependence on perfect commit discipline
* Keep tooling lightweight and avoid heavy platform coupling
* Maintain flexibility to adapt release tooling as ecosystems evolve

## Considered Options

* Changesets (explicit change files with release intent)
* Release Please (release behavior inferred from commit history)
* semantic-release (commit-history-driven, repo-centric automation)
* Nx Release (monorepo-aware but tied to Nx platform)
* Commit-history-driven vs explicit release intent (cross-cutting concern)

## Decision Outcome
Chosen option: “Changesets with explicit release intent”.

Justification: Explicit release intent via changesets keeps release decisions visible in every PR, supports ecosystem-level grouping and batched release workflows, decouples release semantics from commit hygiene, and avoids introducing platform dependencies such as Nx. This approach serves Hyperdrive and any other library-oriented monorepo looking for predictable, reviewable releases.

## Pros and Cons of the Options

### Changesets (explicit release intent)

Each PR includes a `.changeset` file describing semver impact and changelog content.

* Good, because release intent is explicit and visible during review
* Good, because batching releases is natural (changesets accumulate)
* Good, because supports ecosystem-level grouping directly
* Good, because decouples release semantics from commit messages
* Good, because handles complex multi-package changes cleanly
* Bad, because adds workflow overhead (extra files)
* Bad, because contributors must remember to add changesets

👉 Chosen because it provides the most robust and explicit model for complex library-oriented monorepos.

---

### Release Please (commit-history-driven)

Infers release behavior from Conventional Commit history.

* Good, because reduces PR ceremony (no change files)
* Good, because integrates well with GitHub release PR workflows
* Good, because supports monorepos via manifest configuration
* Bad, because release intent is implicit in commit history
* Bad, because depends heavily on commit discipline
* Bad, because squash commits can distort intent
* Bad, because nuanced release scenarios are harder to express

👉 Rejected because implicit release intent is too fragile for complex monorepos.

---

### semantic-release

Fully automated release from commit history.

* Good, because highly automated
* Good, because minimal manual steps
* Bad, because assumes repo = single releasable unit
* Bad, because lacks strong monorepo support
* Bad, because incompatible with ecosystem grouping model

👉 Rejected due to poor fit for library-oriented monorepos.

---

### Nx Release

Monorepo-aware release system integrated into Nx.

* Good, because supports release groups and advanced workflows
* Good, because can unify multiple artifact types
* Bad, because introduces Nx as a platform dependency
* Bad, because Nx tends to expand scope beyond initial use
* Bad, because conflicts with preference for lightweight tooling

👉 Rejected due to coupling and platform concerns.

---

### Commit-history-driven release (cross-cutting concern)

Use Conventional Commits as the authoritative source of release behavior.

* Good, because reduces explicit metadata
* Good, because enables automation
* Bad, because commit messages become overloaded with meaning
* Bad, because release intent is not directly reviewable in PR diffs
* Bad, because multi-package and nuanced changes are hard to encode
* Bad, because errors in commit formatting propagate into releases

👉 Rejected because release intent should be explicit and reviewable.

---

### Explicit release intent (cross-cutting concern)

Use explicit files (e.g. changesets) to declare release behavior.

* Good, because release intent is visible and reviewable
* Good, because supports complex scenarios cleanly
* Good, because batching is natural and predictable
* Good, because decouples commit hygiene from release semantics
* Bad, because adds process overhead
* Bad, because requires contributor discipline

👉 Chosen because it provides clarity and robustness at scale.

## Consequences

* Release intent is explicitly captured in PRs
* Contributors must include changesets for releasable changes
* Releases are batched by consuming accumulated changesets
* Commit messages (even if Conventional Commits) are not the source of release truth

## Confirmation

* PRs affecting publishable packages include `.changeset` files
* Release PRs correctly reflect accumulated changesets
* Version bumps and changelogs align with intended semver behavior
* Release behavior does not depend on commit message parsing

## More Information

This decision intentionally decouples:

- **Commit intent** → expressed via Conventional Commits (optional, for hygiene)
- **Release intent** → expressed via Changesets (authoritative)

This separation preserves flexibility and avoids overloading commit messages with release semantics.

## Related ADRs

* [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) – defines the ecosystem grouping policy that informs how release intent is batched.
* [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) – explains the unified Changesets workflow that connects libraries and applications.
* [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) – explains how application monorepos only version deployable artifacts by default.
