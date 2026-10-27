---
name: commit-message
description: >-
  Produces git commit messages and pull request titles in Conventional Commits
  format per org ADR 0046. Use when writing or suggesting commit messages,
  summarizing changes for a commit, creating or updating a pull request title,
  or when the user asks for a commit message or PR title.
---

# Commit messages and PR titles (Conventional Commits)

## Mandatory format

Use **[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)** for every commit message and every pull request title this org touches:

```text
<type>[(scope)][!]: <short description>

[optional body]

[optional footers]
```

Parentheses show an optional scope; `!` before `:` is optional and marks a breaking change (examples: `feat: …`, `feat(api): …`, `feat!: …`, `feat(api)!: …`).

- **type** — required; must be one of the allowed values below.
- **scope** — optional; use only when it adds clarity. Do not block work on scope bikeshedding.
- **`!`** before `:` — optional; indicates a breaking change (per the spec).
- **description** — imperative mood, concise (e.g. “add retry”, not “added” or “adds”).
- **Body / footers** — optional on commits; use for context that does not fit the subject line.

### Pull request titles

Repositories typically **squash-merge** PRs, and GitHub uses the **PR title** as the squash commit subject. Therefore:

- PR titles **must** use the Conventional Commits **subject line only** (same `<type>[(scope)][!]: <description>` form as a commit subject).
- Put longer rationale, test plans, and lists in the **PR body**, not the title.
- Prefer a title that describes the **merge delta** (what lands on the base branch), not an intermediate checkpoint commit.

## Allowed `type` values

Align with [`@commitlint/config-conventional`](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) (Angular-style enum):

`build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`

Pick the best-fitting type; **clarity beats perfect taxonomy** (e.g. `refactor` vs `chore` ambiguity is acceptable).

## Org policy (distilled from ADR)

- **Standard everywhere:** Conventional Commits for **all** commit messages and **all** PR titles—not a trial.
- **Low ceremony:** frequent small commits stay easy; do not invent process beyond the format.
- **Releases:** versioning and changelogs come from Changesets and related ADRs, **not** from commit messages or PR titles. Do not treat them as authoritative release declarations.
- **Scope:** optional; use when it clarifies, never as a mandatory taxonomy.

## Full normative context

See [ADR 0046: Adopt Conventional Commits for commit messages and PR titles](../../../docs/adr/0046-adopt-conventional-commits-for-commits-and-pr-titles.md).

## Examples

```text
feat(api): add idempotency key header validation

fix: handle null payload in legacy adapter

chore: bump test fixtures for node 22

docs(adr): clarify coordinated release pointer semantics

feat!: remove deprecated /v1 export endpoints
```

PR title examples (subject only):

```text
docs(adr): adopt Conventional Commits for commits and PR titles

fix(auth): reject expired refresh tokens on reuse
```
