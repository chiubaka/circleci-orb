---
name: monorepo-new-package
description: >-
  Standards and SOP for adding a new package in a pnpm/Turbo-style monorepo:
  layout, task wiring, TypeScript, ESLint, testing, and import boundaries.
  Use when scaffolding a new app/library package or aligning package config
  with org architecture conventions.
---

# New package in an org-standard monorepo

## Relevant org ADRs

- `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`:
  use vertical feature modules and per-slice layering in package internals.
- `org/docs/adr/0008-barrel-files-public-api-boundaries.md`:
  define clear package/feature/layer public surfaces with intentional barrels.
- `org/docs/adr/0010-import-specifier-conventions-for-monorepo-packages.md`:
  use package-root imports for cross-package APIs and aliases for intra-package imports.
- `org/docs/adr/0011-test-import-alias-hash-root.md`:
  keep `#/`-style test imports scoped to tests and out of production source.
- `org/docs/adr/0006-consistency-and-extension-for-new-features.md`:
  extend existing repository idioms unless there is a deliberate, documented exception.
- `org/docs/adr/0009-prefer-small-focused-files.md`:
  keep new package files focused and scannable by default.

## Placement

- Add packages under existing workspace globs declared by the repository (for example, `apps/*` and `packages/*` are common).
- Prefer `apps/` for deployable/runtime entrypoints and `packages/` for shared libraries/tooling.
- If a new workspace glob is needed, add it before expecting workspace linking or task discovery to work.

## Package manifest (`package.json`)

- Use a **scoped** name consistent with sibling packages in the same monorepo.
- Set `"type": "module"` for ESM.
- Include scripts expected by the monorepo task runner (commonly `build`, `lint`, `test`, and `typecheck` for TypeScript).
- After adding the package, run workspace install at repo root (for example `pnpm install`) so links resolve.

## TypeScript (extensionless imports)

- **Extend** repo base TypeScript config with a local `tsconfig.json`; do not duplicate base compiler options wholesale.
- For **source authoring** (Vitest, IDE, `tsc --noEmit`), set:
  - `"module": "ESNext"`
  - `"moduleResolution": "Bundler"` (or `"bundler"`; match casing to existing packages)
  - `"noEmit": true` when the package uses a bundler for emit (e.g. tsup) or when you only typecheck.
  - `"rootDir"` / `"include"` appropriate to `src/` (and `test/` if you typecheck tests in the main config — see existing packages).
- This combination **avoids requiring `.js` / `.ts` extensions** in import paths while aligning with modern bundler-driven builds.
- Add **`typecheck`**: `"typecheck": "tsc -p tsconfig.json --noEmit"` (adjust project flag if you split configs).
- **Path to base**: `extends` depth depends on package nesting.
- **Intra-package aliases:** configure local aliases in each new package `tsconfig.json`:
  - `"baseUrl": "."`
  - For `src/`-based packages, a common convention is:
    - `"paths": { "~/*": ["src/*"], "#/*": ["test/*"] }`
  - Use `~/...` for package-internal production imports from `src/` (ADR 0010 style).
  - Use `#/...` for package-internal test imports from `test/` (ADR 0011 style).
  - Do not import `#/...` from production `src/` code.
- **Inter-package imports:** keep workspace imports as scoped package names (`@scope/pkg`) and avoid aliasing those names via local `paths`.

## ESLint

- Add package-local `eslint.config.*` that composes from root config and enables type-aware linting for package TypeScript files.
- Add **`tsconfig.eslint.json`**: extends the package `tsconfig.json`, widen `rootDir` to `.`, and `include` everything ESLint should type-check (typically `src/**/*.ts`, `test/**/*.ts`, `vitest.config.ts`, and optionally `eslint.config.ts` — mirror an existing package).
- Add package-local import-boundary rules that reflect ADRs and backend practice:
  - **Protect production from test imports (ADR 0011):** in `files: ["src/**/*.ts"]`, forbid:
    - `ImportDeclaration[source.value=/^#\\//]`
    - `ImportDeclaration[source.value=/^(\\.\\.\\/)+test(\\/|$)/]`
  - **Preserve package API boundaries (ADR 0010):**
    - For app packages that consume a workspace dependency, forbid deep subpath imports (e.g. disallow `@scope/backend/*`, require `@scope/backend` root import).
  - **Avoid deep relative imports (shared lint convention):**
    - Keep the root-config `no-restricted-imports` policy that disallows `../../...` style imports in favor of aliases.
- **When the package is feature-modular (ADR 0007/0008):**
    - Define feature-module boundary element types and dependency rules (for example via `eslint-plugin-boundaries`).
    - Add test import restrictions so feature tests deep-import only the feature under test, with cross-feature imports through barrels.

## Tests (Vitest)

- Add `vitest.config.*` with `environment: "node"` and `include: ["test/**/*.test.ts"]` unless package needs different defaults.
- Mirror alias intent in Vitest `resolve.alias`:
  - `~ -> <package>/src`
  - `# -> <package>/test`
- Add **`test`**: `"test": "vitest run"`.
- **Layout** convention: `test/` sibling of `src/`, mirrored structure, tests named `*.test.ts`.

## Build and artifacts

- Libraries that publish or expose `dist/`: set `main` / `types` / `exports` as appropriate; add **`clean`** for build output; ensure task-runner output globs match actual artifacts.
- Prefer **tsup** or **tsc** consistently with similar packages; keep `files` / `exports` accurate if publishing.

## Verification

- From repo root, run standard verification commands used by the monorepo (commonly `build`, `lint`, `test`, and `typecheck` where configured).

## Illustrative portable skeleton

```text
packages/example-lib/
  package.json
  tsconfig.json
  tsconfig.eslint.json
  eslint.config.ts
  vitest.config.ts
  src/
    index.ts
  test/
    index.test.ts
```

```json
{
  "name": "@scope/example-lib",
  "type": "module",
  "scripts": {
    "build": "tsup src/index.ts --dts",
    "lint": "eslint .",
    "test": "vitest run",
    "typecheck": "tsc -p tsconfig.json --noEmit"
  }
}
```

## New-package checklist

- [ ] Lives under an existing `pnpm-workspace` glob (or glob updated).
- [ ] `package.json` scripts: `lint`, `test`; plus `build` / `typecheck` when applicable.
- [ ] `tsconfig.json` extends `tsconfig.base.json`; bundler-style resolution for extensionless imports.
- [ ] `tsconfig.json` defines `baseUrl` + `paths` for `~/* -> src/*` and `#/* -> test/*` (or package-appropriate equivalents when source is not under `src/`).
- [ ] `eslint.config.ts` + `tsconfig.eslint.json` wired to root ESLint.
- [ ] `eslint.config.ts` includes `src/**` guardrails that forbid test imports (`#/` and direct `../test` paths).
- [ ] For app consumers of workspace packages, deep subpath imports (e.g. `@scope/pkg/*`) are restricted when the public API should be package-root only.
- [ ] For backend feature-modular packages, `eslint-plugin-boundaries` and backend-style test import restrictions are configured.
- [ ] `vitest.config.ts` mirrors aliases (`~` to `src`, `#` to `test`) and includes `test/**/*.test.ts`.
- [ ] `pnpm install` from root; Turbo sees the new package tasks.
