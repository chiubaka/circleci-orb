---
status: accepted
date: 2026-06-13
decision-makers: Daniel Chiu
---

# Category-based release notes for application monorepos

## Context and Problem Statement

The orb’s Changesets release machinery (`changesets-release-pr`, `changesets-gated-publish` → `github-release-train`) formats batch release notes from per-package `CHANGELOG.md` files. For **library** monorepos, grouping by semver bump magnitude (Major / Minor / Patch) matches consumer expectations.

For **deployable application** monorepos, stakeholders expect product-style groupings (Features / Improvements / Bug Fixes) rather than semver vocabulary. Changesets has no native category field; categories must be introduced as a presentation convention that survives from changeset authoring through `CHANGELOG.md` to the release-PR body and GitHub Release notes.

## Decision Drivers

- **Library default unchanged:** existing consumers must keep Major / Minor / Patch unless they opt in.
- **End-to-end consistency:** release-PR body and GitHub Release must use the same grouping as `CHANGELOG.md` when category mode is enabled.
- **Graceful degradation:** missing category prefixes are rejected at verify time (application repos); explicit `Other:` is required for the Other Changes section.
- **Testability:** formatter and rewriter logic lives in this repo with Bats coverage and embedded CircleCI staging copies kept in sync.

## Considered Options

- Bump-type grouping only (status quo)
- Category grouping via inline tokens parsed only at batch-format time (Option 2 in the design spec)
- Category grouping via summary prefix tokens, `CHANGELOG.md` rewrite after `changeset version`, and category-aware batch formatter (chosen)

## Decision Outcome

Chosen option: **Opt-in category mode** on `changesets-release-pr`, `github-release-train`, and `changesets-gated-publish` via `release-notes-grouping: category` (default `bump-type`).

When category mode is enabled:

1. Authors prefix each changeset summary with a category token: `Feature:`, `Improvement:`, `Fix:`, or `Other:` (plural forms and `Bug Fix:` / `Other Changes:` variants are accepted).
2. Application monorepos enable `require-changeset-category-prefix: true` on `verify-changesets` so PRs fail when a summary headline omits a prefix.
3. After `changeset version`, `rewriteChangelogCategories.mjs` rewrites the top version block in each changed `CHANGELOG.md` from bump-type headings to category headings and strips the prefix from bullet text.
4. `formatChangesetsBatchReleaseNotes.mjs` groups batch notes under **Features / Improvements / Bug Fixes / Other Changes**. Untagged changelog bullets fail formatting in category mode.

**Justification:** Keeps library defaults intact, aligns stakeholder-facing surfaces with per-package changelogs, and avoids forking Changesets’ release-plan writer.

### Consequences

- Good, because application repos get product-style release notes without a second authoring workflow.
- Good, because library repos require no config changes.
- Good, because category and semver bump remain independent axes.
- Bad, because authors must learn the prefix token convention in category mode.
- Bad, because org ADR 0038’s default presentation wording must be read together with its category-mode extension.

### Confirmation

- Bats tests cover category grouping, ordering, explicit Other prefix, prefix validation, multi-package batches, default-mode regression, and embedded script parity.
- Orb parameters `release-notes-grouping` and `require-changeset-category-prefix` appear on release and verify commands/jobs.

## Related ADRs

- [Org ADR 0026](../../org/docs/adr/0026-use-changesets-for-application-releases.md) — user-facing release intent for applications
- [Org ADR 0038](../../org/docs/adr/0038-release-train-identifiers-and-github-releases.md) — train identifiers and GitHub Release notes (extended for category presentation)
- [0001](0001-chiubaka-circleci-orb-design-defaults-and-escape-hatches.md) — orb defaults and escape hatches
