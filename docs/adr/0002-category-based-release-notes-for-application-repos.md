---
status: accepted
date: 2026-06-13
decision-makers: Daniel Chiu
---

# Category-based release notes for Changesets monorepos

## Context and Problem Statement

The orb’s Changesets release machinery (`changesets-release-pr`, `changesets-gated-publish` → `github-release-train`) formats batch release notes from per-package `CHANGELOG.md` files. Stakeholders across **library and application** monorepos expect product-style groupings (Breaking Changes, Features, Bug Fixes, and related sections) rather than semver vocabulary (Major / Minor / Patch) in release-PR bodies and GitHub Releases.

Changesets has no native category field; categories must be introduced as a presentation convention that survives from changeset authoring through `CHANGELOG.md` to the release-PR body and GitHub Release notes.

## Decision Drivers

- **Org-wide standard:** category mode and prefix enforcement are the default for Chiubaka Changesets repos.
- **End-to-end consistency:** release-PR body and GitHub Release must use the same grouping as `CHANGELOG.md` when category mode is enabled.
- **Explicit taxonomy:** missing category prefixes are rejected at verify time; explicit `Other:` is required for the Other Changes section.
- **Testability:** formatter and rewriter logic lives in this repo with Bats coverage and embedded CircleCI staging copies kept in sync.

## Considered Options

- Bump-type grouping only (legacy escape hatch)
- Category grouping via inline tokens parsed only at batch-format time
- Category grouping via summary prefix tokens, `CHANGELOG.md` rewrite after `changeset version`, and category-aware batch formatter (chosen)

## Decision Outcome

Chosen option: **Category mode by default** on `changesets-release-pr`, `github-release-train`, and `changesets-gated-publish` via `release-notes-grouping: category`. Set `release-notes-grouping: bump-type` to retain Major / Minor / Patch grouping (legacy escape hatch for external orb consumers).

When category mode is enabled:

1. Authors prefix each changeset summary with a category token. Accepted prefixes map to seven release-note sections:

   | Section | Prefixes |
   |---|---|
   | Breaking Changes | `Breaking:`, `Breaking Change:` |
   | Security | `Security:` |
   | Features | `Feature:`, `Features:` |
   | Improvements | `Improvement:`, `Improvements:` |
   | Bug Fixes | `Fix:`, `Fixes:`, `Bug Fix:`, `Bug Fixes:` |
   | Deprecations | `Deprecation:`, `Deprecated:` |
   | Other Changes | `Other:`, `Other Changes:` |

2. All Changesets repos enable `require-changeset-category-prefix: true` on `verify-changesets` (orb default) so PRs fail when a summary headline omits a prefix.
3. After `changeset version`, `rewriteChangelogCategories.mjs` rewrites the top version block in each changed `CHANGELOG.md` from bump-type headings to category headings and strips the prefix from bullet text.
4. `formatChangesetsBatchReleaseNotes.mjs` groups batch notes under the seven sections in fixed order. Untagged changelog bullets fail formatting in category mode.

**Justification:** Aligns stakeholder-facing surfaces with per-package changelogs across library and application monorepos without forking Changesets’ release-plan writer. Canonical prefix tokens live in `src/scripts/changesetCategoryPrefixes.mjs`; authoring voice rules live in org `changeset/SKILL.md`.

### Consequences

- Good, because library and application repos share one release-note presentation model.
- Good, because category and semver bump remain independent axes.
- Good, because breaking, security, and deprecation work gets dedicated sections.
- Bad, because authors must learn the prefix token convention.
- Bad, because consumers relying on implicit bump-type defaults must opt out explicitly.

### Confirmation

- Bats tests cover all seven prefix types, section ordering, prefix validation, multi-package batches, bump-type regression, and embedded script parity.
- Orb parameters `release-notes-grouping` (default `category`) and `require-changeset-category-prefix` (default `true`) appear on release and verify commands/jobs.

## Related ADRs

- [Org ADR 0024](../../org/docs/adr/0024-use-changesets-for-library-monorepos.md) — library release intent
- [Org ADR 0026](../../org/docs/adr/0026-use-changesets-for-application-releases.md) — application release intent
- [Org ADR 0038](../../org/docs/adr/0038-release-train-identifiers-and-github-releases.md) — train identifiers and GitHub Release notes
- [0001](0001-chiubaka-circleci-orb-design-defaults-and-escape-hatches.md) — orb defaults and escape hatches
