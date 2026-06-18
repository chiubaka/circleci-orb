---
name: changeset-category-prefixes
description: >-
  Authors Changeset summary headlines with category prefixes for application monorepos
  (release-notes-grouping category). Use when writing .changeset/ files in deployable app repos
  that enforce require-changeset-category-prefix, or when the user mentions Feature:, Fix:,
  Improvement:, Other:, or category-based release notes.
---

# Changeset category prefixes (application monorepos)

## When this applies

Use this skill when the repository configures **category release notes**:

- `release-notes-grouping: category` on `changesets-release-pr` and `changesets-gated-publish`
- `require-changeset-category-prefix: true` on `verify-changesets` (recommended for app repos)

**Library monorepos** use plain summaries with no category prefix (Major / Minor / Patch grouping only).

Policy: [repo ADR 0002](../../../docs/adr/0002-category-based-release-notes-for-application-repos.md), [org ADR 0038](../../../org/docs/adr/0038-release-train-identifiers-and-github-releases.md).

## Rule (critical)

The **first line** after the changeset frontmatter `---` **must** start with an accepted category prefix, then the user-facing summary:

```markdown
---
"@myapp/web": minor
---

Feature: Add calendar export for deadline reminders
```

- **Semver bump** stays in frontmatter (`major` / `minor` / `patch`) — versioning contract.
- **Category prefix** is presentation only — which release-note section the entry appears under.
- **No prefix is invalid** — CI fails `verify-changesets` when `require-changeset-category-prefix` is true.
- **Do not omit a prefix** expecting “Other Changes” — use **`Other:`** explicitly for that section.

## Accepted prefixes and when to use each

| Release section | Accepted prefixes (case-insensitive) | When to use |
|-----------------|--------------------------------------|-------------|
| **Features** | `Feature:`, `Features:` | New user-visible capability, screen, workflow, integration, or behavior that did not exist before. |
| **Improvements** | `Improvement:`, `Improvements:` | Enhancement to existing behavior—clearer copy, better performance, UX polish, refactors with user impact—without a wholly new capability. |
| **Bug Fixes** | `Fix:`, `Fixes:`, `Bug Fix:`, `Bug Fixes:` | Correction of incorrect, broken, or regressed behavior relative to intended product behavior. |
| **Other Changes** | `Other:`, `Other Changes:` | Release-note-worthy work that is not a feature, improvement, or bug fix (e.g. internal-only ops, dependency-only maintenance, tooling). **Must** use this prefix explicitly; untagged entries are rejected. |

Canonical section headings in release PRs and GitHub Releases: **Features**, **Improvements**, **Bug Fixes**, **Other Changes**.

## Examples

### Feature

```markdown
---
"@snowday/directus": minor
---

Feature: Add a location-input interface backed by Google Places
```

### Improvement

```markdown
---
"@snowday/directus": patch
---

Improvement: Relabel the Deadlines "Status" field to "Date Status" for clarity
```

### Bug fix

```markdown
---
"@snowday/web": patch
---

Bug Fix: Correct empty-state rendering on the deadlines list
```

### Other (explicit)

```markdown
---
"@snowday/infra": patch
---

Other: Bump Node.js base image for security patches (no user-facing behavior change)
```

### Invalid (missing prefix)

```markdown
---
"@snowday/web": patch
---

Add export button
```

Fails `verify-changesets` when category prefix enforcement is enabled.

## Checklist

- [ ] Repo uses category release notes (`release-notes-grouping: category`).
- [ ] Summary headline starts with `Feature:`, `Improvement:`, `Fix:`, or `Other:` (or accepted variant).
- [ ] Headline after the prefix is short, user-facing, and scannable (details in body paragraphs below).
- [ ] Frontmatter semver bump reflects compatibility intent, independent of category choice.

## Source of truth in code

Prefix matching lives in `src/scripts/changesetCategoryPrefixes.mjs` (`CATEGORY_PREFIX_GUIDE`, `CATEGORY_TOKEN_RE`). Keep this skill aligned when that module changes.
