---
status: accepted
date: 2026-03-26
decision-makers: Daniel Chiu
---

# ADR 0011: Use `#/` as the package-local test import root

## Context and Problem Statement

[ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) established `~/` as the intra-package alias for production code under `src/` and reserved `@scope/pkg` imports for cross-package/public API boundaries. As test suites grow, deep relative imports inside `test/` become noisy and brittle.

We need a package-local convention for test support imports that improves ergonomics while preserving architectural clarity: production code should stay distinct from test-only code, and package imports should stay unambiguous in a monorepo.

## Decision Drivers

- **Boundary clarity:** keep `src/`, `test/`, and `@scope/pkg` imports visually and semantically distinct.
- **Ergonomics:** avoid deep `../../..` paths in large test trees.
- **Monorepo safety:** avoid prefixes that collide with scoped workspace package imports.
- **Tooling predictability:** keep the convention straightforward across TypeScript, test runners, and lint.
- **Test-code containment:** do not make test code appear as a production/public module graph.

## Considered Options

- Keep using `~/` for `src/` only and use relative imports for `test/`.
- Introduce `~test/` for `test/`.
- Introduce `@test/` or `@tests/` for `test/`.
- Introduce custom punctuation aliases (for example `!/`, `$/`, or `%/`) for `test/`.
- Introduce `#/` for `test/`.
- Use real package self-imports for local test internals.

## Decision Outcome

Chosen option: "Introduce `#/` for package-local test imports (`test/*`)."

Justification: `#/` creates a non-overlapping namespace next to `~/` and `@scope/pkg`: `~/` remains production-local, `#/` is test-local, and `@scope/pkg` remains cross-package/public API. This keeps intent explicit at the import site and avoids overloading `@` in a monorepo.

### Rules

1. **Production-local imports:** `~/...` maps to `src/*` only.
2. **Test-local imports:** `#/...` maps to `test/*` only.
3. **Cross-package imports:** continue to use real package names (`@scope/pkg`) and package public APIs.
4. **No production dependency on test root:** code in `src/` must not import from `#/`.
5. **Test-helper scope:** prefer local test helpers first; only promote helper reuse when there is clear repeated need.

### Consequences

- Good, because test imports remain short and resilient as test depth increases.
- Good, because `~/` vs `#/` vs `@scope/pkg` makes dependency intent obvious.
- Good, because the convention scales consistently across packages.
- Bad, because `#/` is less common than some alternatives and requires team familiarity.
- Bad, because alias configuration must be mirrored across TS/test/lint tooling.

### Confirmation

- **Configuration:** package `tsconfig.json` includes both `~/* -> src/*` and `#/* -> test/*`.
- **Tooling parity:** test runner and lint/import resolution are configured to recognize both aliases.
- **Boundary checks:** review and lint rules ensure `src/**` does not import `#/`.
- **Verification:** repository-level checks pass after adoption (`pnpm build`, `pnpm lint`, `pnpm test`).

## Pros and Cons of the Options

### Keep `~/` only + relative `test/` imports

- Good, because it avoids adding another alias.
- Good, because it keeps test code physically local by default.
- Bad, because deep relative imports degrade readability and maintenance in larger test trees.

### Use `~test/` for tests

- Good, because it is visually similar to `~/`.
- Good, because it removes deep relative paths.
- Bad, because it can imply a parallel first-class root beside production code and blur boundaries.

### Use `@test/` or `@tests/`

- Good, because it is explicit and readable.
- Bad, because it overloads the `@...` namespace used for real workspace package imports.

### Use custom punctuation aliases (`!/`, `$/`, `%/`)

- Good, because they avoid namespace overlap with `@scope/pkg`.
- Bad, because they are non-standard and less familiar to most TypeScript ecosystems.
- Bad, because punctuation-heavy prefixes can create parser/tooling edge cases or future conflicts.

### Use `#/` for tests (chosen)

- Good, because it is clearly distinct from both `~/` and `@scope/pkg`.
- Good, because it signals test-only scope without implying a publishable package.
- Bad, because it is a less common convention and needs brief onboarding context.

### Use package self-imports for test internals

- Good, because it aligns with package naming semantics.
- Bad, because it is verbose and can encourage exposure of internal file structure.

## More Information

- [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) — `~/` for intra-package source imports and `@scope/pkg` for inter-package imports.
- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — package boundaries and module structure.
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — public API boundaries and import discipline.
