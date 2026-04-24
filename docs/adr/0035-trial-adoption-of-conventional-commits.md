---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
---

# ADR 0035: Trial adoption of Conventional Commits as a commit message standard

## Context and Problem Statement

Repositories that follow this org ADR set do not yet mandate a formal commit message standard. Commit messages are generally descriptive and often written in a changelog-like style, but vary in structure and consistency.

As the ecosystem grows (multiple monorepos, packages, and apps), inconsistent commit history reduces readability, makes it harder to scan intent, and limits the usefulness of tooling that depends on structured commit messages.

At the same time, introducing a commit convention risks adding ceremony and friction, especially given a preference for frequent, small, low-cost checkpoint commits during development.

The question is:

**Should we adopt a standardized commit message convention (specifically [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)), and if so, how can we do so without negatively impacting developer velocity and flexibility?**

## Relationship to existing org ADRs

- **Versioning and releases:** Library and application versioning remains governed by Changesets and related ADRs ([ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0026](0026-use-changesets-for-application-releases.md), [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md), and adjacent release-model ADRs). Commit messages are **not** treated as authoritative release declarations.
- **Separation of concerns:** This ADR defines **human and optional tooling** conventions for git history. It does not change how versions or changelogs are produced for packages and apps where Changesets (or coordinated release manifests per [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md)) is the source of truth.

## Decision Drivers

- Improve readability and consistency of commit history across repositories
- Enable optional future tooling (e.g., changelog generation, commit linting) without coupling to release semantics
- Preserve fast, low-friction development workflows with frequent small commits
- Avoid excessive ceremony or cognitive overhead when committing
- Avoid overfitting commit messages to release or changelog semantics
- Allow flexibility while the ecosystem structure (especially scopes) is still evolving

## Considered Options

- Adopt Conventional Commits strictly across all commits
- Adopt Conventional Commits in a lightweight, low-ceremony form (trial)
- Standardize only PR titles / squash merge commits using Conventional Commits
- Do not adopt a commit convention

## Decision Outcome

Chosen option: **Adopt Conventional Commits in a lightweight, low-ceremony form (trial)**.

**Justification:** Conventional Commits provides a widely understood and tool-compatible structure for expressing commit intent. Strict adoption risks unnecessary friction and slower development. A lightweight trial allows evaluation of benefits, refinement of scope conventions, and observation of real-world friction before committing to a stricter policy.

### Consequences

- Good, because commit history becomes more structured and easier to scan
- Good, because the ecosystem gains compatibility with existing tooling (e.g., commitlint, changelog generators) without requiring immediate integration
- Good, because this approach preserves flexibility and avoids premature standardization of scopes
- Good, because it allows empirical evaluation before committing to a stricter policy
- Bad, because commit categorization (e.g., `refactor` vs `chore`) may remain inconsistent during the trial
- Bad, because lack of strict enforcement may reduce consistency across contributors
- Bad, because developers may experience mild ambiguity when choosing types or scopes

### Confirmation

This ADR will be evaluated qualitatively during the trial period based on:

- Developer experience (e.g., perceived friction when committing)
- Frequency and usefulness of structured commit messages in practice
- Whether commit velocity or willingness to make small commits is negatively impacted
- Whether emerging scope patterns become clear and stable over time

A follow-up ADR will be created to either:

- Formalize and enforce a stricter Conventional Commits policy, or
- Adjust or abandon the approach based on observed outcomes

## Pros and Cons of the Options

### Adopt Conventional Commits strictly across all commits

- Good, because it enforces consistency and structured commit history
- Good, because it enables strong tooling integration and automation
- Neutral, because it provides clear rules but may require additional documentation and training
- Bad, because it introduces ceremony and may discourage small, frequent commits
- Bad, because commit type and scope classification can be inherently fuzzy
- Bad, because it may lead to bikeshedding over taxonomy (e.g., `chore` vs `refactor`)

### Adopt Conventional Commits in a lightweight, low-ceremony form (trial)

- Good, because it improves structure without imposing heavy process
- Good, because it allows experimentation and learning before committing to a strict policy
- Good, because it preserves flexibility in scope definition while the architecture evolves
- Neutral, because consistency may vary during the trial period
- Bad, because lack of enforcement may limit immediate benefits
- Bad, because ambiguity in types and scopes remains unresolved

### Standardize only PR titles / squash merge commits using Conventional Commits

- Good, because it ensures clean shared history with minimal developer friction
- Good, because it avoids impacting local development workflows
- Neutral, because it shifts responsibility to PR authors rather than commit authors
- Bad, because intermediate commit history remains inconsistent
- Bad, because it provides less granular insight into development intent

### Do not adopt a commit convention

- Good, because it preserves maximum flexibility and zero additional ceremony
- Good, because developers can commit without any cognitive overhead
- Neutral, because informal conventions may still emerge organically
- Bad, because commit history remains inconsistent and harder to scan
- Bad, because it limits the usefulness of tooling that depends on structured commits
- Bad, because it does not scale well across a growing ecosystem

## More Information

### Specification and type vocabulary

During the trial, commit messages should **generally follow** the [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification (type, optional scope, optional `!` for breaking changes, description, optional body and footers).

For **allowed `type` values**, this org standard aligns with the `type-enum` used by [`@commitlint/config-conventional`](https://github.com/conventional-changelog/commitlint/tree/master/%40commitlint/config-conventional) (the Angular-style set: `build`, `chore`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `style`, `test`). That keeps terminology consistent with common lint presets if a repository adopts commitlint later.

### Separation from release semantics

- Package versioning in monorepos is handled by Changesets and is **not** derived from commit messages.
- Future app-level tooling may generate changelogs from commit history between git pointers, but commit messages are **not** treated as authoritative release declarations.

### Trial period expectations

- Use the **type** vocabulary above; **scope** is optional and should be used only when it adds clarity
- Developers should prioritize clarity over perfect categorization
- Frequent small commits are encouraged and should remain low-friction

### Revisit criteria

This ADR should be revisited after sufficient usage to determine:

- Whether the benefits justify broader enforcement
- Whether scope conventions have stabilized
- Whether commit friction has increased or remained acceptable
