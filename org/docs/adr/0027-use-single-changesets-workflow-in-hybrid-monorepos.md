---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Use a single Changesets workflow in hybrid monorepos

## Context and Problem Statement

Some monorepos mix publishable libraries and deployable applications. Each artifact type needs explicit release intent, but they share a repository and contributors.

We must determine:

> Should these artifact types use separate release systems or a unified workflow?

## Decision Drivers

* Minimize tooling complexity
* Maintain consistency across monorepos
* Avoid duplicated workflows
* Align with Changesets design principles
* Support both libraries and applications cleanly

## Considered Options

* Separate Changesets workflows per artifact type
* Single unified Changesets workflow
* Separate tools for apps and libraries

## Decision Outcome

Chosen option: **Single unified Changesets workflow**.

Justification: Changesets is designed for one release intent system per repository. Splitting workflows adds complexity, fragments context, and ignores the tooling’s architectural intent.

## Pros and Cons of the Options

### Single unified workflow

* Good, because it aligns with Changesets architecture
* Good, because it reduces cognitive overhead
* Good, because supports hybrid repos naturally
* Good, because enforces a single source of release truth
* Bad, because different artifact types share infrastructure

👉 Chosen because simplicity and consistency outweigh separation.

---

### Multiple workflows

* Good, because it allows separation of concerns
* Bad, because it is poorly supported by tooling
* Bad, because it increases operational complexity
* Bad, because it fragments release intent

👉 Rejected due to complexity and fragility.

---

### Separate tools

* Good, because tools can specialize
* Bad, because it introduces fragmentation
* Bad, because it increases maintenance burden
* Bad, because it weakens consistency across repos

👉 Rejected due to operational overhead.

## Consequences

* One `.changeset/` directory per repository
* Both apps and libraries participate in the same release system
* CI differentiates behavior:
  - libraries → publish
  - apps → deploy
* Release PRs may include both app and library changes

## Confirmation

* Only one Changesets config exists per repo
* No duplicate release systems are present
* Release PRs reflect all relevant changes across artifact types

## More Information

This ADR builds on:

* Library ADR: ecosystem-level lockstep versioning ([ADR 0023](0023-lockstep-versioning-for-related-package-groups.md))
* Library ADR: explicit release intent via Changesets ([ADR 0024](0024-use-changesets-for-library-monorepos.md))
* Application ADR: Changesets-based release intent ([ADR 0026](0026-use-changesets-for-application-releases.md))
* Plugin policy ADR that separates core vs adapter release expectations ([ADR 0025](0025-versioning-plugins-vs-core.md))
* Application policy for deployable-only versioning ([ADR 0028](0028-version-only-deployable-artifacts-by-default.md))

It ensures libraries and applications share a unified release model while allowing different post-release behaviors.

## Related ADRs

* [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) – defines ecosystem grouping, which still governs which packages move together.
* [ADR 0024](0024-use-changesets-for-library-monorepos.md) – captures explicit release intent for libraries within the shared workflow.
* [ADR 0025](0025-versioning-plugins-vs-core.md) – explains how core and plugin packages participate in grouped releases.
* [ADR 0026](0026-use-changesets-for-application-releases.md) – applies the same Changesets workflow to deployable applications.
