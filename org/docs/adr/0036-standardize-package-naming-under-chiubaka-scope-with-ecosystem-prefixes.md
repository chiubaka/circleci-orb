---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
consulted: -
informed: -
---

# ADR 0036: Standardize package naming under `@chiubaka/*` with ecosystem prefixes

## Context and Problem Statement

[ADR 0034](0034-use-github-packages-with-single-chiubaka-scope-for-private-package-distribution.md) collapses all private packages under a **single** GitHub Packages scope (`@chiubaka/*`). The taxonomy in [ADR 0032](0032-monorepo-package-taxonomy-naming-and-domain-contracts.md) still uses **illustrative** multi-scope names such as `@protectiva/plugin-drizzle-postgres` or `@solarijs/react` to express **roles** and **ownership**; those **scope-level** brandings are not all representable as separate npm scopes under the single-registry constraint.

A **published** naming convention is required to:

- preserve ecosystem identity within a single scope
- maintain clarity and discoverability
- support future package grouping and access management
- avoid ambiguity as the number of packages grows

## Relationship to existing org ADRs

- **Registry:** [ADR 0034](0034-use-github-packages-with-single-chiubaka-scope-for-private-package-distribution.md) — all private packages publish under `@chiubaka/*` on `https://npm.pkg.github.com`.
- **Taxonomy and roles:** [ADR 0032](0032-monorepo-package-taxonomy-naming-and-domain-contracts.md) — directory layout, `domain` vs `contracts`, plugin vs integration, frontend splits. This ADR does **not** replace those rules; it maps **publishable** names into **`@chiubaka/<ecosystem>-…`** when the artifact is shared via GitHub Packages.
- **Frontend split:** [ADR 0033](0033-frontend-package-split-application-of-adr-0032-and-adr-0016.md) — unchanged in intent; published names follow the prefix pattern below.

## Decision Drivers

- Compatibility with single-scope constraint (`@chiubaka/*`)
- Clear mapping between package and ecosystem
- Scalability to dozens of packages
- Readability and consistency
- Avoidance of naming collisions
- Alignment with future access control needs

## Considered Options

- Flattened naming without ecosystem prefix (e.g. `@chiubaka/frontend`)
- Nested naming using delimiters (e.g. `@chiubaka/solari/frontend`)
- Ecosystem prefix using hyphen (e.g. `@chiubaka/solari-frontend`)
- Mixed or ad hoc naming

## Decision Outcome

Chosen option: **Ecosystem-prefixed flat naming using hyphens under `@chiubaka/*`**.

All **published** private packages must:

1. Use the `@chiubaka/*` scope
2. Begin with the **ecosystem** (or product line) name as a prefix
3. Use **hyphen-separated** naming for the remainder

### Examples

| Prior illustrative multi-scope name   | Published name under this ADR                  |
| ------------------------------------- | ---------------------------------------------- |
| `@solarijs/frontend`                  | `@chiubaka/solari-frontend`                    |
| `@solarijs/react`                     | `@chiubaka/solari-react`                       |
| `@protectiva/plugin-drizzle-postgres` | `@chiubaka/protectiva-plugin-drizzle-postgres` |

Naming should still reflect **role** from ADR 0032 (e.g. `plugin-*`, `frontend-plugin-*`) after the ecosystem prefix.

### Consequences

- Good, because ecosystem ownership is preserved within a single scope
- Good, because package grouping can be inferred via naming prefix
- Good, because naming remains flat and compatible with npm tooling
- Good, because it avoids scope proliferation and registry complexity
- Bad, because names become longer and slightly less clean
- Bad, because ecosystem identity is no longer encoded at the **scope** level
- Bad, because grouping is convention-based rather than enforced by tooling

### Confirmation

- All new **published** packages follow the `@chiubaka/<ecosystem>-<name>` format
- Existing packages are migrated to the new naming convention as they are published or republished
- CI or linting rules may be introduced to enforce naming consistency
- Code reviews verify adherence to naming conventions

## Pros and Cons of the Options

### Flattened naming without ecosystem prefix

- Good, because names are short and simple
- Bad, because ecosystem ownership is unclear
- Bad, because naming collisions become likely
- Bad, because grouping becomes difficult

### Nested naming (e.g. `@chiubaka/solari/frontend`)

- Good, because it preserves hierarchy
- Bad, because npm does not support nested scopes in this way
- Bad, because it breaks standard tooling expectations

### Ecosystem-prefixed naming (chosen)

- Good, because it preserves ecosystem identity
- Good, because it scales cleanly
- Good, because it is compatible with npm and GitHub Packages
- Neutral, because it increases name length
- Bad, because it relies on convention rather than enforcement

### Mixed or ad hoc naming

- Good, because it allows flexibility
- Bad, because it leads to inconsistency
- Bad, because it becomes unmaintainable at scale

## More Information

This naming convention acts as a **logical substitute for multi-scope architecture**, allowing ecosystem grouping without separate registry scopes.

It also enables future migration paths:

- to multi-scope registries, or
- to artifact platforms with grouping/entitlement support

If naming complexity becomes a usability issue, tooling (e.g. generators, lint rules, or documentation) should be introduced to mitigate friction.
