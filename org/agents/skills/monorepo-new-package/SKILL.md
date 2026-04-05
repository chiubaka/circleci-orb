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
- `org/docs/adr/0017-workspace-library-dist-boundary-and-dev-watch.md`:
  treat `dist/` as the cross-package boundary; use library `dev` (watch) instead of consumer `paths` into library `src/`.
- `org/docs/adr/0016-frontend-responsibility-areas-and-layered-boundaries.md`:
  for client packages, align `src/app/` (composition), `src/core/` (high bar), and per-area
  `domain` / `application` / `infrastructure` / `presentation` with barrel-gated imports.
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
- Add **`typecheck`**: `"typecheck": "tsc -p tsconfig.json --noEmit"` (adjust project flag if you split configs; see **ESLint flat config** below when you add a second project for `eslint.config.ts`).
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
- Add **`tsconfig.eslint.json`**: extends the package `tsconfig.json`, widen `rootDir` to `.`, and `include` everything ESLint should type-check (typically `src/**/*.ts`, `src/**/*.tsx`, `test/**/*.ts`, `test/**/*.tsx`, `vitest.config.ts`, and optionally `eslint.config.ts` — mirror an existing package).

### `eslint.config.ts`: config directory and typechecking

- Do **not** use **`import.meta.dirname`** in package `eslint.config.ts` when the package’s TypeScript setup uses client-leaning **`ImportMeta`** (for example Vite’s `vite/client` types): those definitions often omit Node’s `dirname`, so **`tsc` and the IDE error** even though Node can run the config.
- Use **`configDirFromImportMetaUrl(import.meta.url)`** from **`@chiubaka/eslint-config`** and pass the result to **`tsconfigRootDir`** / **`configDir`** wherever those helpers require a filesystem directory.
- **Two different tsconfig files:** keep **`tsconfig.eslint.json`** for ESLint **`parserOptions.project`** (the wider set of linted files). When `eslint.config.ts` imports **`.ts` modules** (typical for monorepo paths into `@chiubaka/eslint-config` source or the repo root `eslint.config.ts`), add a separate **`tsconfig.eslint-config.json`** used only by **`tsc`**:
  - **`extends`** the repo **`tsconfig.base.json`**, **not** the package `tsconfig.json`, whenever the flat config imports **paths outside the package**—otherwise an inherited **`rootDir`** from the app/library `tsconfig.json` makes **`tsc`** reject those files.
  - Set **`module`**: **`ESNext`**, **`moduleResolution`**: **`Bundler`**, **`noEmit`**: **`true`**, **`allowImportingTsExtensions`**: **`true`**, **`types`**: **`["node"]`** (add **`@types/node`** to **`devDependencies`** even when the browser **`tsconfig.json`** uses only **`vite/client`**), and override **`declaration`** / **`declarationMap`** / **`sourceMap`** off if the base enables emit-oriented options—copy the shape from **`@l3xo/server`** or **`@l3xo/web`**.
  - **`include`**: **`["eslint.config.ts"]`** only.
- Wire **`typecheck`** so this file is checked in CI:  
  `"typecheck": "tsc -p tsconfig.json --noEmit && tsc -p tsconfig.eslint-config.json --noEmit"`  
  (Packages whose main `tsconfig.json` already enables `allowImportingTsExtensions` may use one dedicated project for `tsc` instead of `tsconfig.eslint-config.json`. For example **`@chiubaka/eslint-config`** uses **`tsconfig.typecheck.json`** with a **narrow `include`**—helpers, presets, `eslint.config.ts`, and Vitest config—because its default `tsconfig.json` also pulls in **`test/fixtures/**`** files that are intentionally invalid TypeScript for lint tests.)

- Add package-local import-boundary rules that reflect ADRs and repository practice:
  - **Protect production from test imports (ADR 0011):** in `files: ["src/**/*.ts", "src/**/*.tsx"]` (when the package uses TSX), forbid:
    - `ImportDeclaration[source.value=/^#\\//]`
    - `ImportDeclaration[source.value=/^(\\.\\.\\/)+test(\\/|$)/]`
  - **Preserve package API boundaries (ADR 0010):**
    - For app packages that consume a workspace dependency, forbid deep subpath imports (e.g. disallow `@scope/backend/*`, require `@scope/backend` root import).
  - **Avoid deep relative imports (shared lint convention):**
    - Keep the root-config `no-restricted-imports` policy that disallows `../../...` style imports in favor of aliases.

### Feature-module boundary preset (`@chiubaka/eslint-config`)

For packages with **vertical modules under `src/`** (ADR 0007 / ADR 0016), use **`createFeatureModuleBoundariesPreset`** from `@chiubaka/eslint-config` (same helper backend and frontend clients use). It wires **`eslint-plugin-boundaries`**, cross-feature **barrel-only** imports, and optional **per-feature test** import rules.

- **Peer-style devDependencies** (match sibling packages’ versions): `eslint-plugin-boundaries`, and when the preset’s TypeScript import resolver is enabled, `eslint-import-resolver-typescript`.
- **Backend-style** packages (TypeScript only under `src/`): call the preset with defaults (omit `sourceFileExtensions` and `internalPathGlobs` unless you have a reason to override). Keep `reservedTopLevelModules: ["core"]` (or extend if you add other non-feature roots).
- **Frontend / ADR 0016 client packages** (React, Vite, etc.):
  - Set `sourceFileExtensions: ["ts", "tsx"]` so boundaries and `no-restricted-imports` blocks apply to `.tsx` files.
  - Set `internalPathGlobs: FRONTEND_FEATURE_MODULE_INTERNAL_PATH_GLOBS` (exported next to the factory) so cross-feature deep bans include **`presentation/`**, not only `domain` / `application` / `infrastructure`.
  - Reserve **`app`** as a composition root: `reservedTopLevelModules: ["core", "app"]` when `src/app/` is the client composition layer (routing, shell, providers) rather than a domain feature.
  - **Barrel files:** feature roots may use `index.tsx` (not only `index.ts`); the preset discovers barrels for either extension.
  - **Composition → features:** import other areas through the feature root barrel (e.g. `~/chat`), not `~/chat/infrastructure/...` or other deep paths.
  - **Vite entry + global CSS:** TypeScript-oriented import resolvers often do not classify `.css` as a boundaries element, so `import "./styles.css"` in `src/main.tsx` can trip `boundaries/no-unknown`. After the preset, add a **narrow** flat-config override for that entry file only, turning **`boundaries/no-unknown`** off and documenting why (see `@l3xo/web`’s `eslint.config.ts`).

Exported path constants (for frontend consumers, re-exported from `@chiubaka/eslint-config`):

- `DEFAULT_FEATURE_MODULE_INTERNAL_PATH_GLOBS` — backend default internal layers.
- `FRONTEND_FEATURE_MODULE_INTERNAL_PATH_GLOBS` — adds `**/presentation/**` per ADR 0016.

### Legacy bullet (superseded by the preset)

- **When the package is feature-modular (ADR 0007/0008):** prefer **`createFeatureModuleBoundariesPreset`** instead of hand-rolling `eslint-plugin-boundaries` rules unless you have an exceptional layout.

## Tests (Vitest)

- Add `vitest.config.*` with `environment: "node"` and `include: ["test/**/*.test.ts"]` unless package needs different defaults.
- Mirror alias intent in Vitest `resolve.alias`:
  - `~ -> <package>/src`
  - `# -> <package>/test`
- Add **`test`**: `"test": "vitest run"`.
- **Layout** convention: `test/` sibling of `src/`, mirrored structure, tests named `*.test.ts`.
- For packages using **`sourceFileExtensions: ["ts", "tsx"]`** with the feature preset, enable **`enableTestImportRestrictions`** (default **true**) so tests under `test/<feature>/` also cover `*.tsx` test files when you add them.

## Build and artifacts

- Libraries that publish or expose `dist/`: set `main` / `types` / `exports` as appropriate; add **`clean`** for build output; ensure task-runner output globs match actual artifacts.
- Prefer **tsup** or **tsc** consistently with similar packages; keep `files` / `exports` accurate if publishing.

### Workspace libraries consumed by other packages (ADR 0017)

- **Boundary:** consumers resolve `@scope/pkg` via `package.json` `exports` to **`dist/`**, not to the library’s `src/`.
- **Do not** add `tsconfig` `paths` in apps or other packages that map a workspace package name to a sibling library’s source tree. That merges graphs, breaks per-package `~/` semantics (`org/docs/adr/0010-import-specifier-conventions-for-monorepo-packages.md`), and confuses Vitest / ESLint TypeScript resolution relative to runtime.
- **`dev` script:** for each library that other packages import, add **`dev`** mirroring **`build`** in watch mode—e.g. `tsup ... --watch` (omit `--clean` on watch for incremental rebuilds) or `tsc -p tsconfig.build.json --watch` when the library builds with `tsc`.
- **Workflow:** when editing a library and its consumers, run **`pnpm dev`** at the repo root if wired, or **`pnpm --filter @scope/pkg dev`** for that library, so `dist/` stays current while you work.

## Verification

- From repo root, run standard verification commands used by the monorepo (commonly `build`, `lint`, `test`, and `typecheck` where configured).

## Illustrative portable skeleton

```text
packages/example-lib/
  package.json
  tsconfig.json
  tsconfig.eslint.json
  tsconfig.eslint-config.json
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
    "build": "tsup src/index.ts --dts --clean",
    "dev": "tsup src/index.ts --dts --watch",
    "lint": "eslint .",
    "test": "vitest run",
    "typecheck": "tsc -p tsconfig.json --noEmit && tsc -p tsconfig.eslint-config.json --noEmit"
  }
}
```

## New-package checklist

- [ ] Lives under an existing `pnpm-workspace` glob (or glob updated).
- [ ] `package.json` scripts: `lint`, `test`; plus `build` / `typecheck` when applicable.
- [ ] For workspace **libraries consumed by other packages** (ADR 0017): `dev` script mirroring `build` in watch mode (`tsup --watch` or `tsc --watch`); no consumer `paths` into this package’s `src/`.
- [ ] `tsconfig.json` extends `tsconfig.base.json`; bundler-style resolution for extensionless imports.
- [ ] `tsconfig.json` defines `baseUrl` + `paths` for `~/* -> src/*` and `#/* -> test/*` (or package-appropriate equivalents when source is not under `src/`).
- [ ] `eslint.config.ts` + `tsconfig.eslint.json` wired to root ESLint.
- [ ] `eslint.config.ts` uses **`configDirFromImportMetaUrl(import.meta.url)`** from **`@chiubaka/eslint-config`** (not **`import.meta.dirname`**) for **`tsconfigRootDir`** / **`configDir`**.
- [ ] **`tsconfig.eslint-config.json`** (or an equivalent such as **`tsconfig.typecheck.json`**) + matching **`typecheck`** `tsc` when `eslint.config.ts` uses **`.ts` extension imports**, so CI typechecks the flat config (see **`@chiubaka/eslint-config`** for the narrow-include variant when **`test/fixtures/**`** must stay out of `tsc`).
- [ ] `eslint.config.ts` includes `src/**` guardrails that forbid test imports (`#/` and direct `../test` paths).
- [ ] For app consumers of workspace packages, deep subpath imports (e.g. `@scope/pkg/*`) are restricted when the public API should be package-root only.
- [ ] For **feature-modular** packages (ADR 0007 / ADR 0016): `createFeatureModuleBoundariesPreset` from `@chiubaka/eslint-config`, plus `eslint-plugin-boundaries` (and `eslint-import-resolver-typescript` when using the preset’s resolver).
- [ ] **Frontend** feature-modular apps: `sourceFileExtensions: ["ts", "tsx"]`, `FRONTEND_FEATURE_MODULE_INTERNAL_PATH_GLOBS`, `reservedTopLevelModules` includes **`app`** when using `src/app/` as composition; narrow **`boundaries/no-unknown`** override on the Vite **`main.tsx`** if it imports global CSS.
- [ ] `vitest.config.ts` mirrors aliases (`~` to `src`, `#` to `test`) and includes `test/**/*.test.ts`.
- [ ] `pnpm install` from root; Turbo sees the new package tasks.
