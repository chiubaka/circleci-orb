---
status: accepted
date: 2026-05-08
decision-makers: Daniel Chiu
---

# Release train identifiers (`YYYY.MM.DD.N`) and GitHub Releases

## Context and Problem Statement

Monorepos that ship multiple versioned artifacts need a **release train** identifier: a single label for “this coordinated cut” that orchestration, manifests, CI, and humans can refer to without ambiguity.

Reasonable options include:

- A **calendar-style identifier** (`YYYY.MM.DD.N`), aligned with phased promotion and release manifests.
- An **umbrella semver** at the repository root, optionally maintained alongside independent package versions.

Separately, teams often publish **GitHub Releases** as the social and archival surface for a batch publish. That raises another question: should the GitHub Release tag follow the **train** identifier, **package** semver, or something else—and how do notes relate to Changesets?

This ADR records which **train identifier** we standardize on and how **GitHub Releases** relate to Changesets and existing orchestration ADRs.

## Decision Drivers

- **Orchestration-first clarity:** coordinated deploys, manifests, and promotion workflows need a stable, monotonic train identity that works across artifacts.
- **Operational pragmatism:** prefer conventions that compose with existing manifest and tag models without extra bespoke versioning machinery at the repository root.
- **Honest semantics:** train identifiers should not imply a second, competing semver contract for consumers who pin individual packages.
- **Compatibility:** align with Changesets as the system of record for **package-level** semver and changelogs ([ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0026](0026-use-changesets-for-application-releases.md)).
- **Auditability:** release history should tie together “what shipped together” without multiplying incompatible numbering schemes.

## Considered Options

- Calendar-based release train identifier (`YYYY.MM.DD.N`)
- Umbrella semver at the repository root (managed manually or derived from batch bump severity)
- GitHub Releases tagged only with individual package versions (one release per package)

## Decision Outcome

Chosen option: **Standardize on `YYYY.MM.DD.N` as the canonical release train identifier** for coordinated releases and related automation. **GitHub Releases**, when published for a monorepo batch, **SHOULD** use this same train identifier as the **GitHub release tag and title prefix** (for example `2026.04.06.1` or `v2026.04.06.1` if a `v` prefix is required by tooling—either form is acceptable if used consistently within a repository).

**Release notes** for that GitHub Release **SHOULD** be assembled from the **Changesets-generated changelogs** and summaries for packages and deployable artifacts included in that publish batch ([ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0026](0026-use-changesets-for-application-releases.md), [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md)). The train identifier names the **batch**; per-package semver remains the compatibility surface for consumers. **Implementation note (Chiubaka orb):** default automation renders those notes as a **structured batch summary**—grouped **Major / Minor / Patch** sections (matching Changesets’ default changelog headings), nested bullets per package, and a **Published versions** list—rather than a flat per-package excerpt block.

**Justification:** Calendar train identifiers match the orchestration model already defined for release manifests and promotion tags ([ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md), [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)), avoid inventing a parallel umbrella semver that does not map cleanly to independent package versions, and keep GitHub Releases aligned with “one batch / one train” without requiring one GitHub Release per published package.

### Consequences

- Good, because **one canonical train id** can span manifests, promotion flow, and GitHub Release tagging.
- Good, because **no extra root-level semver policy** is required solely for naming releases.
- Good, because **compatibility intent** stays on **package versions** and Changesets, reducing ambiguity for library consumers.
- Good, because **monotonic, sortable** train ids support operational ordering and multiple cuts per calendar day via `N`.
- Bad, because the train id **does not encode** semver bump magnitude for the batch (unlike an umbrella semver chosen to reflect “major vs minor”); teams rely on **per-package changelogs** and summaries for that signal.
- Bad, because repositories that **do not** use coordinated manifests still need local discipline to assign the next valid `N` for a given date when creating a train id (same discipline as [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)).

### Confirmation

- Repositories that publish GitHub Releases for batched monorepo publishes use a **train-aligned** tag consistent with this ADR.
- Release manifest `release` fields and promotion-tag logical ids remain consistent with [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) and [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md).
- Package semver and changelogs continue to come from **Changesets**, not from the train identifier alone.

## Pros and Cons of the Options

### Calendar-based train identifier (`YYYY.MM.DD.N`)

Train identity matches manifest `release` values and promotion-tag stems; increment rules for `N` are defined in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md).

- Good, because it **aligns orchestration, auditing, and GitHub tagging** when teams adopt GitHub Releases.
- Good, because it **avoids misleading** “repo-level semver” when packages version independently.
- Good, because it **reuses** an established pattern already specified for coordinated releases.
- Neutral, because “when” is visible in the id; **supplementary** context still comes from GitHub metadata and changelogs.
- Bad, because it does not communicate **aggregate semver intent** for the whole batch.

### Umbrella semver at the repository root

- Good, because a **single semver** can summarize “how large” a batch feels for marketing or platform narratives.
- Bad, because it is **easy to misread** as a consumer compatibility Version when packages keep **independent** semvers ([ADR 0023](0023-lockstep-versioning-for-related-package-groups.md)).
- Bad, because **automatic** alignment with independent packages requires **extra tooling or policy** beyond Changesets defaults.

### GitHub Releases per package version

- Good, because each tag matches **one npm version**.
- Bad, because **batched** monorepo publishes become **noisy** on GitHub and duplicate Changesets’ batch story.

## More Information

**Relationship to package semver:** Train identifiers name **release trains** for coordination and publishing ceremonies. **Packages and deployable artifacts** keep their normal **semver** and changelog story under Changesets. Artifact tags for immutable builds remain separate from promotion tags as described in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md).

**Repositories without coordinated manifests:** Some monorepos may still publish a **GitHub Release** per batch without adopting `.releases/` manifests. They **should still** use `YYYY.MM.DD.N` for train-aligned tags when they want a single umbrella label, and **should** follow the same `N` increment convention per date for consistency.

## Related ADRs

- [ADR 0024](0024-use-changesets-for-library-monorepos.md) — Changesets for libraries; batched release intent
- [ADR 0026](0026-use-changesets-for-application-releases.md) — Changesets for applications
- [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) — single Changesets workflow per repository
- [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) — release manifests; logical `release` field
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — promotion tags; logical release identifier and `N` rules
