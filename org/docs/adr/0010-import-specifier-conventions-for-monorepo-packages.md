---
status: accepted
date: 2026-03-26
decision-makers: Daniel Chiu
---

# ADR 0010: Import specifier conventions for monorepo packages

## Context and Problem Statement

Deep relative imports (`../../../`) reduce readability and are noisy to maintain as modules move. At the same time, this monorepo must support package-style imports between workspace packages (for example, `@scope/backend`) in a way that remains compatible with npm-style boundaries.

We need a convention for intra-package imports that improves local ergonomics without colliding with present or future `@scope/pkg` workspace package imports.

## Decision Drivers

- **Readability:** avoid deep relative paths in package-internal source code.
- **Boundary clarity:** preserve `@scope/pkg` imports as package/public-API boundaries.
- **Monorepo scalability:** keep conventions safe as more workspace packages are added.
- **Tooling compatibility:** align with TypeScript and current build/lint/test workflows.
- **Consistency:** make the default easy to apply in all new packages.

## Considered Options

- Use `@/` as package-local alias and `@scope/pkg` for workspace packages.
- Use `~/` as package-local alias and `@scope/pkg` for workspace packages.
- Use **package-scoped internal imports** (for example `@scope/common/types/...` instead of `~/types/...` inside `@scope/common`) and keep `@scope/pkg` for cross-package imports.
- Keep only relative imports and rely on lint rules to cap depth.

## Decision Outcome

Chosen option: "Use `~/` for intra-package imports and keep `@scope/pkg` for inter-package imports."

Justification: `~/` avoids namespace overlap with `@scope/pkg`, keeps package boundaries unambiguous, and removes pressure toward deep relative imports. It also fits current TypeScript setup by adding per-package `baseUrl`/`paths` without changing package-resolution semantics for workspace dependencies.

### Rules

1. **Intra-package alias:** each workspace package should map `~/*` to its local source root (typically `src/*`) in `tsconfig.json`.
2. **Inter-package imports:** imports across workspace packages should use scoped package names (for example, `@scope/backend`) and package public APIs.
3. **No `@` local alias:** do not introduce `@/` for package-local paths in this monorepo.
4. **Public API boundaries remain:** continue enforcing package and barrel boundaries per existing ADRs and lint rules.

### Consequences

- Good, because local imports are shorter and less fragile than deep relatives.
- Good, because package imports remain clearly distinguishable from local aliases.
- Good, because future workspace growth keeps a consistent, low-ambiguity import vocabulary.
- Bad, because package configs need explicit alias setup.
- Bad, because lint and tooling should continue to be verified when introducing new packages.

### Confirmation

- **Configuration:** new package `tsconfig.json` files include `baseUrl` and a `~/*` path mapping.
- **Verification:** repository-level checks pass after configuration changes: `pnpm build`, `pnpm lint`, `pnpm test`.
- **Review:** code review confirms package-crossing imports use `@scope/pkg` public APIs rather than local aliases.

## Pros and Cons of the Options

### Use `@/` for local alias

- Good, because many frontend ecosystems use this shape.
- Bad, because it is visually close to scoped package imports (`@scope/pkg`) and can blur intent in a monorepo.

### Use `~/` for local alias (chosen)

- Good, because it is concise and clearly distinct from package specifiers.
- Good, because it composes cleanly with workspace package imports.
- Bad, because some developers are more familiar with `@/`.

### Keep only relative imports

- Good, because it requires no alias configuration.
- Bad, because deep relatives are harder to scan and maintain.

### Use package-scoped internal imports (rejected)

Use the package’s published scope for **intra-package** paths as well—for example `import { User } from "@scope/users-domain/users/domain/User"` inside `@scope/users-domain`—often paired with consumer `tsconfig` `paths` that map `@scope/users-domain/*` to that package’s `src/*` so TypeScript can consume dependency **source** without building `dist/` first.

- Good, because specifiers are globally unique per package, which can reduce **`~/` alias collision** when a consumer maps `@scope/pkg` to sibling `src/` (see [ADR 0017](0017-workspace-library-dist-boundary-and-dev-watch.md)).
- Good, because it can feel like “always latest source” in the IDE when combined with `paths` → `src`.
- Bad, because every internal import **looks like a cross-package import**, which is the same ambiguity we rejected for `@/` as a local alias—only worse, since the prefix is a real workspace package name.
- Bad, because it encourages **deep subpath imports** that bypass barrels and blur what is actually exported from `@scope/pkg` (see [ADR 0008](0008-barrel-files-public-api-boundaries.md)).
- Bad, because it is **verbose** and documents internal file layout at every import site; [ADR 0011](0011-test-import-alias-hash-root.md) rejected the same shape for test-only code as “package self-imports.”
- Bad, because it does **not** remove the costs of merged TypeScript graphs, ESLint performance, or runtime/`dist` drift when consumers still resolve workspace packages to `src/`—those are covered in [ADR 0017](0017-workspace-library-dist-boundary-and-dev-watch.md).

**Do not** adopt package-scoped internals as a substitute for `~/` / `#/` or as a way to avoid the `dist/` boundary without accepting those tradeoffs.

## More Information

- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — feature/layer decomposition and package layout.
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — barrel/public API boundaries.
- [ADR 0017](0017-workspace-library-dist-boundary-and-dev-watch.md) — why consumers resolve workspace libraries through `dist/`, not sibling `src/`, and why package-scoped internals do not replace that model.
- Repository-local illustration: `org/docs/adr/examples/import-aliases-example.md`.
