---
status: accepted
date: 2026-09-03
decision-makers: Daniel Chiu
---

# ADR 0046: Adopt Conventional Commits for commit messages and PR titles

## Context and Problem Statement

[ADR 0035](0035-trial-adoption-of-conventional-commits.md) introduced [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) as a **lightweight trial**: structured messages without strict enforcement, while scopes and day-to-day friction were still being evaluated.

That trial has been useful. Commit history is more scannable, and the Angular-style type vocabulary aligns with common tooling. The remaining gap is **shared history on the default branch**: repositories typically **squash-merge** pull requests, and GitHub uses the **PR title** as the squash commit subject. Informal or non-conventional PR titles therefore become the lasting commit titles on the shared branch even when intermediate commits were well formed.

The question is:

**Should we graduate from the trial and require Conventional Commits for both individual commit messages and pull request titles?**

## Relationship to existing org ADRs

- **Versioning and releases:** Library and application versioning remains governed by Changesets and related ADRs ([ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0026](0026-use-changesets-for-application-releases.md), [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md), and adjacent release-model ADRs). Commit messages and PR titles are **not** treated as authoritative release declarations.
- **Prior trial:** This ADR **supersedes** [ADR 0035](0035-trial-adoption-of-conventional-commits.md). The type vocabulary and separation from release semantics from the trial remain; the trial framing and “generally follow” soft requirement do not.

## Decision Drivers

- Keep shared (especially squash-merged) history readable and consistent across repositories
- Ensure PR titles match the format that becomes the default-branch commit subject under squash merge
- Retain compatibility with optional tooling (for example commitlint) without coupling to release semantics
- Preserve fast, low-friction development with frequent small commits
- Avoid excessive ceremony or bikeshedding over type/scope taxonomy
- Avoid overfitting commit or PR text to changelog or semver semantics

## Considered Options

- Keep the lightweight trial (ADR 0035) indefinitely
- Adopt Conventional Commits for all commits and PR titles (this ADR)
- Require Conventional Commits only for PR titles / squash merge subjects
- Require Conventional Commits with mandatory CI linting and a closed scope enum

## Decision Outcome

Chosen option: **Adopt Conventional Commits for all commits and PR titles**.

**Justification:** The trial showed acceptable friction. Making the convention normative for **every commit message** and **every PR title** keeps both local and shared history consistent. Explicit PR-title rules close the squash-merge gap: the title that lands on the default branch must already be a valid Conventional Commits subject. Scopes stay optional, and clarity still beats perfect categorization—this is a firm format standard, not heavy process or mandatory automation.

### Consequences

- Good, because default-branch history stays structured when PRs are squash-merged
- Good, because contributors and reviewers share one format for commits and PR titles
- Good, because the ecosystem remains compatible with commitlint and related tooling if a repository opts in later
- Good, because release authority stays with Changesets rather than commit parsing
- Neutral, because type choice (for example `refactor` vs `chore`) can still be judgment calls
- Bad, because authors must rewrite informal PR titles before merge
- Bad, because without repository-level lint automation, consistency still depends on review discipline

### Confirmation

Compliance is confirmed by:

- Review of commit subjects and PR titles against the Conventional Commits subject form and the allowed type vocabulary below
- Preferring PR titles that remain accurate as the squash commit subject for the merge delta
- Optional repository adoption of commitlint (or equivalent) using `@commitlint/config-conventional` type enums—encouraged where useful, not required by this ADR

## Pros and Cons of the Options

### Keep the lightweight trial (ADR 0035) indefinitely

- Good, because it maximizes flexibility
- Bad, because “trial” language understates an already settled practice
- Bad, because PR titles remain an unstated gap under squash merge

### Adopt Conventional Commits for all commits and PR titles

- Good, because one standard covers local commits and shared squash history
- Good, because it matches how GitHub squash merge records history
- Neutral, because enforcement may remain social or review-based until tooling is added per repository
- Bad, because contributors must learn and apply the format everywhere, including PR titles

### Require Conventional Commits only for PR titles / squash merge subjects

- Good, because shared history becomes clean with less local ceremony
- Bad, because intermediate commits stay inconsistent and harder to scan in long-lived branches
- Bad, because agents and contributors already treat Conventional Commits as the commit norm from the trial

### Require Conventional Commits with mandatory CI linting and a closed scope enum

- Good, because automation would catch format mistakes early
- Bad, because a closed scope enum is premature while repository layouts still evolve
- Bad, because mandatory linting on every commit can discourage small checkpoint commits if misconfigured

## More Information

### Specification and type vocabulary

Commit messages and PR titles **must** follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

For commit messages:

```text
<type>[(scope)][!]: <short description>

[optional body]

[optional footers]
```

For pull request titles, use the **subject line only** (type, optional scope, optional `!`, description)—the same form that becomes the squash commit title. Put longer rationale in the PR body, not the title.

For **allowed `type` values**, this org standard aligns with the `type-enum` used by [`@commitlint/config-conventional`](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) (the Angular-style set: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`).

### Application expectations

- **type** is required and must be one of the allowed values above
- **scope** is optional; use it when it adds clarity, not as a mandatory taxonomy
- Prefer clarity over perfect categorization when types overlap
- Frequent small commits remain encouraged; the format should stay low-ceremony
- PR titles should describe the **merge delta** (what lands on the base branch), not an intermediate checkpoint

### Separation from release semantics

- Package versioning in monorepos is handled by Changesets and is **not** derived from commit messages or PR titles
- Future app-level tooling may generate notes from commit history between git pointers, but those messages are **not** authoritative release declarations

### Related history

- [ADR 0035](0035-trial-adoption-of-conventional-commits.md) — superseded trial adoption; retained for decision history
