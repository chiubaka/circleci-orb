---
name: commit-message
description: >-
  Produces git commit messages in Conventional Commits format per org ADR 0035.
  Use when writing or suggesting commit messages, summarizing changes for a
  commit, or when the user asks for a commit message.
---

# Commit messages (Conventional Commits)

## Mandatory format

Use **[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)** for every commit message this org touches:

```
<type>[(scope)][!]: <short description>

[optional body]

[optional footers]
```

Parentheses show an optional scope; `!` before `:` is optional and marks a breaking change (examples: `feat: …`, `feat(api): …`, `feat!: …`, `feat(api)!: …`).

- **type** — required; must be one of the allowed values below.
- **scope** — optional; use only when it adds clarity. Do not over-specify scopes during the org trial.
- **`!`** before `:` — optional; indicates a breaking change (per the spec).
- **description** — imperative mood, concise (e.g. “add retry”, not “added” or “adds”).
- **Body / footers** — optional; use for context that does not fit the subject line.

## Allowed `type` values

Align with [`@commitlint/config-conventional`](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) (Angular-style enum):

`build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`

Pick the best-fitting type; **clarity beats perfect taxonomy** (e.g. `refactor` vs `chore` ambiguity is acceptable during the trial).

## Org policy (distilled from ADR)

- **Lightweight trial:** structured messages, **low ceremony** — frequent small commits stay easy.
- **Releases:** versioning and changelogs come from Changesets and related ADRs, **not** from commit messages. Do not treat commits as authoritative release declarations.
- **Scope:** optional; refine when patterns stabilize — do not block commits on scope bikeshedding.

## Full normative context

See [ADR 0035: Trial adoption of Conventional Commits](../../../docs/adr/0035-trial-adoption-of-conventional-commits.md).

## Examples

```
feat(api): add idempotency key header validation

fix: handle null payload in legacy adapter

chore: bump test fixtures for node 22

docs(adr): clarify coordinated release pointer semantics

feat!: remove deprecated /v1 export endpoints
```
