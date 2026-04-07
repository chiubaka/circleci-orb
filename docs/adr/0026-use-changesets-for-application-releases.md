---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Use Changesets for application versioning and user-facing release intent

## Context and Problem Statement

Application-oriented monorepos produce deployable artifacts (e.g., backend services, web apps, mobile apps) rather than published libraries. However, these applications still require:

- explicit versioning
- structured, user-facing release notes
- batched release workflows across multiple PRs
- a clear and reviewable record of release intent

Commit history and Conventional Commits are insufficient for this purpose. They tend to reflect implementation detail rather than user impact, and they make release behavior implicit rather than explicit.

Our library-facing ADRs already capture explicit release intent via [ADR 0024](0024-use-changesets-for-library-monorepos.md) and group related packages via [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md). We must now answer:

> How should application releases capture versioning and user-facing release intent in a way that is explicit, reviewable, and scalable?

## Decision Drivers

* Explicit, reviewable release intent captured at PR time
* High-quality user-facing release communication
* Avoid reliance on commit history inference
* Support batched releases across multiple PRs
* Maintain consistency with library-side workflows
* Avoid building custom release tooling

## Considered Options

* Changesets (explicit change files with summaries)
* Commit-history-driven tools (e.g. git-cliff)
* Release Please (commit-based automation)
* Manual release note writing at release time

## Decision Outcome

Chosen option: **Use Changesets as the system of record for application versioning and user-facing release intent**.

Justification: Changesets provides an explicit, PR-reviewable mechanism for capturing both versioning intent and user-facing release summaries. This avoids reliance on commit history, supports batching naturally, and aligns with the existing library workflow described in [ADR 0024](0024-use-changesets-for-library-monorepos.md).

## Pros and Cons of the Options

### Changesets (explicit release intent)

* Good, because release intent is explicit and reviewable in PRs
* Good, because summaries can be written for users rather than engineers
* Good, because batching releases is natural and predictable
* Good, because it decouples commit hygiene from release semantics
* Good, because it aligns application releases with library monorepo workflows
* Bad, because it introduces additional workflow overhead
* Bad, because it requires discipline in writing good summaries

👉 Chosen because it provides clarity, consistency, and scalability.

### Commit-history-driven tools

* Good, because they are lightweight
* Bad, because they rely on implicit intent
* Bad, because they produce poor user-facing output
* Bad, because commit discipline is unreliable

👉 Rejected due to poor quality and lack of explicit intent.

### Release Please

* Good, because it automates release PRs
* Bad, because it relies on commit history inference
* Bad, because it introduces branching complexity
* Bad, because nuanced release intent is hard to express

👉 Rejected due to implicitness and reduced control.

### Manual release notes

* Good, because quality can be high
* Bad, because it does not scale
* Bad, because it is error-prone and inconsistent

👉 Rejected due to lack of scalability.

## Consequences

* All releasable application changes must include a Changeset
* Changeset summaries must be written in user-facing language
* Version numbers become the authoritative identifier of releases
* Release notes are generated directly from curated summaries
* Commit messages are not used as the source of release truth

## Confirmation

* App repos contain a `.changeset/` directory
* PRs that affect user-visible behavior include Changesets
* Generated release notes are suitable for external communication
* No reliance on commit parsing for release behavior

## More Information

This extends the library-side decision to use Changesets with explicit release intent, applying the same principle to deployable applications, and codifies that application monorepos only version deployable artifacts by default ([ADR 0028](0028-version-only-deployable-artifacts-by-default.md)).

## Related ADRs

- See [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) for the ecosystem grouping policy that explains why some releases move together.
- See [ADR 0024](0024-use-changesets-for-library-monorepos.md) for the library-side release tooling that already captures explicit intent.
- See [ADR 0025](0025-versioning-plugins-vs-core.md) for how optional plugins and adapters relate to the core ecosystem surface.
- See [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) for the unified workflow that keeps application and library release tooling aligned.
- See [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) and [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) for coordinated multi-artifact deployment orchestration (release manifests and promotion tags). Changesets remain the source of truth for artifact version bumps; manifests pin which immutable artifact tags deploy together.
