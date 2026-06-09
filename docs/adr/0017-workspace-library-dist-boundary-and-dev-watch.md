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
- **Merged graphs:** the consumer typechecks implementation details and transitive files that should stay behind the library’s public barrel; refactors inside the library break unrelated projects in non-obvious ways. This does **not** mean “every package’s program includes the entire monorepo”—it means the program grows to the **transitive closure of `src/`** along workspace imports (consumer → dependency → dependency-of-dependency, for each package still mapped to `src/`). That closure can still be large in deep stacks and is duplicated across packages when each app/library runs its own lint/typecheck.
- **Tooling performance:** TypeScript-aware ESLint (and similar tools) build or reuse a TypeScript `Program` whose cost scales with files in that merged graph. Consuming sibling `src/` via `paths` inflates those programs compared to depending on dependency **declaration files** from `dist/`, which is a common cause of IDE and CI lint feeling slow or “stuck.”
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
- Map `@scope/lib` to library `src/` **and** replace intra-package `~/` with **package-scoped internal imports** (`@scope/lib/...` inside `@scope/lib`) so dependency `~/` does not collide in the consumer `paths` context (see [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md)).
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

## Pros and Cons of the Options

### Map `@scope/lib` to library `src/` from consumer `tsconfig` (rejected)

- Good, because the IDE and `tsc` can appear to use “always latest” dependency source without rebuilding `dist/`.
- Bad, because of **`~/` alias collision** unless consumers add compensating `paths` (for example mapping `~/` to a dependency’s `src/`), which violates [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md).
- Bad, because of **merged graphs**, **boundary blur**, **tooling/runtime mismatch**, and **ESLint/TypeScript program size** (see Context above).
- Bad, because types from `src/` can be **newer than runtime** if `dist/` in `node_modules` is stale—the “no stale build” benefit applies to the typechecker, not necessarily to what Node executes.

### Package-scoped internal imports plus `paths` → `src` (rejected)

Same as mapping to `src/`, but each package uses `@scope/that-pkg/...` for its own modules instead of `~/...`, so consumers do not need foreign `~/` shims when pulling dependency source into the graph.

- Good, because import specifiers are **unique per package**, which mitigates the `~/` collision symptom of the `src/` shortcut.
- Good, because it preserves the “live source” DX that `paths` → `src` offers in the editor.
- Bad, because it **does not un-merge graphs**: the consumer program still includes transitive dependency **implementation** `.ts` files, not just public types.
- Bad, because **ESLint and TypeScript cost** still scale with that transitive file set; this is not a reliable fix for slow type-aware lint or IDE analysis.
- Bad, because internal lines are indistinguishable from real **`@scope/pkg` cross-package imports**, weakening the `~/` vs `@scope/pkg` vocabulary from [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md).
- Bad, because using `@scope/pkg/test/...` (or similar) for test-only modules **looks like a published subpath** and confuses what `@scope/pkg` actually exports—why [ADR 0011](0011-test-import-alias-hash-root.md) keeps `#/` for test-local imports instead of package subpaths.
- Bad, because **runtime and `exports` discipline** still require a built `dist/` (or extensive subpath `exports` maps); this option mainly changes syntax, not package boundaries.

**Do not** reintroduce consumer `paths` to sibling `src/` or adopt package-scoped internals to avoid `dist/` without explicitly accepting these tradeoffs.

### Treat `dist/` as the boundary with library `dev` watch (chosen)

- Good, because consumer programs stay smaller: own `src/` plus dependency **declarations** from `dist/`, aligned with runtime `exports`.
- Good, because `~/` and `#/` remain strictly **per-package** per [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) and [ADR 0011](0011-test-import-alias-hash-root.md).
- Good, because type-aware ESLint and TypeScript analyze graphs closer to what ships.
- Bad, because cross-package work needs **`^build`**, an initial build, and/or library **`dev`** watch so `dist/` stays current.

### Confirmation

- **Configuration:** consumed workspace packages expose `dist/` via `exports`; no consumer `paths` to sibling `src/`.
- **Scripts:** libraries built with tsup or tsc include a `dev` watch script aligned with ADR 0017.
- **Verification:** repository checks pass (`pnpm build`, `pnpm lint`, `pnpm test`, `pnpm typecheck`).

## More Information

- [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) — `~/` vs `@scope/pkg`, rejected `@/` and package-scoped internal imports.
- [ADR 0011](0011-test-import-alias-hash-root.md) — `#/` for tests; rejected `@scope/pkg/test/...`-style self-imports that blur `exports`.
