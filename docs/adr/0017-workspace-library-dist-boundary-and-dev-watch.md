---
status: accepted
date: 2026-03-29
decision-makers: Daniel Chiu
---

# ADR 0017: Workspace library `dist/` boundary and dev watch

## Context and Problem Statement

Workspace libraries in this monorepo expose their public API through `package.json` `exports` (typically `types` and `import` pointing at `dist/`). Consumers resolve `@scope/pkg` to the built artifacts, not to the library’s `src/`.

A tempting shortcut is to add `compilerOptions.paths` in **consumer** packages (apps or other libraries) so that `@scope/some-lib` resolves directly to `../packages/some-lib/src` (or similar). That avoids rebuilding the library on every change and can make the IDE feel “live.” It conflicts with how we want the monorepo to behave.

When consumer `tsconfig` maps a workspace package name to another package’s **source tree**, TypeScript merges those files into the consumer’s program graph. That causes several classes of problems:

- **Alias collision with [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md):** each package defines `~/` → its own `src/*`. If the consumer pulls in library source as if it were part of the project, the library’s `~/` imports are resolved in the **consumer’s** `paths` context—wrong root, wrong module, or confusing duplicate diagnostics.
- **Merged graphs:** the consumer typechecks implementation details and transitive files that should stay behind the library’s public barrel; refactors inside the library break unrelated projects in non-obvious ways.
- **Tooling mismatch:** Vitest and ESLint TypeScript-aware plugins often follow the same `paths`; tests and lint then analyze a hybrid graph that does not match runtime (Node still loads `dist/` from `node_modules`).
- **Project references:** mixing “link to source” with `composite` / solution-style setups increases ordering and emit ambiguity; the boundary between packages stops matching physical and published boundaries.

We need a single, consistent rule: **cross-package imports use package names; types and JS for those imports come from the library’s build output (`dist/`), not from its `src/`.** For local iteration, we still need fast feedback without hand-running full builds after every save.

## Decision Drivers

- **Boundary clarity:** `@scope/pkg` remains a real package boundary; consumers depend on declared exports, not arbitrary paths into `src/`.
- **Compatibility with [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) and [ADR 0011](0011-test-import-alias-hash-root.md):** `~/` and `#/` stay unambiguously **per-package**; no cross-package source pull-in that rebinds those aliases.
- **Predictable tooling:** TypeScript, Vitest, and ESLint see the same resolution story the runtime uses (`dist/` via workspace install).
- **Developer experience:** editing a library and its consumers together should stay fast (watch/incremental), without `paths` hacks.

## Considered Options

- Map `@scope/lib` to library `src/` from consumer `tsconfig` (and mirror in Vitest/ESLint).
- Rely on full `pnpm build` after every library change; no watch.
- Treat `dist/` as the typing and runtime boundary; add **`dev`** scripts on libraries that mirror **`build`** in watch mode (`tsup --watch` or `tsc --watch`); consumers use normal workspace resolution to `dist/`.

## Decision Outcome

Chosen option: **Treat `dist/` as the boundary for workspace libraries; do not add consumer `paths` to library source; use library `dev` (watch) for iterative work.**

Justification: keeping resolution aligned with `exports` preserves package boundaries, avoids `~/` / merged-graph bugs, and keeps test and lint programs faithful to what runs. Watch mode on the library restores fast feedback without sacrificing that model.

### Rules

1. **Consumers:** resolve workspace libraries through `package.json` / `node_modules` only (`exports` → `dist/`). Do **not** add `paths` from apps or other packages to a library’s `src/`.
2. **Libraries that emit `dist/`:** provide a **`dev`** script that mirrors **`build`** in watch mode—for example `tsup ... --watch` (omit `--clean` on watch so incremental rebuilds work) or `tsc -p tsconfig.build.json --watch` for `tsc`-built packages.
3. **Workflow:** when editing a library and its consumers, run watch for that library (e.g. `pnpm --filter @scope/lib dev` or a root `dev` that includes library packages) so `dist/` stays up to date.

### Consequences

- Good, because TypeScript, Vitest, and ESLint agree with runtime resolution.
- Good, because `~/` and `#/` stay local to each package per ADR 0010 / ADR 0011.
- Good, because public API discipline stays enforced at the barrel / `exports` level.
- Bad, because developers must remember to run library watch (or a composite dev task) when working across packages; cold starts still need an initial build.

### Confirmation

- **Configuration:** consumed workspace packages expose `dist/` via `exports`; no consumer `paths` to sibling `src/`.
- **Scripts:** libraries built with tsup or tsc include a `dev` watch script aligned with ADR 0017.
- **Verification:** repository checks pass (`pnpm build`, `pnpm lint`, `pnpm test`, `pnpm typecheck`).

## More Information

- [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) — `~/` vs `@scope/pkg` and intra- vs inter-package imports.
- [ADR 0011](0011-test-import-alias-hash-root.md) — `#/` for tests; keep merged graphs from pulling test paths into production unintentionally.
