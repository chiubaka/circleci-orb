---
status: accepted
date: 2026-03-29
decision-makers: Daniel Chiu
---

# ADR 0018: `index.ts` / `index.tsx` as re-export-only barrels

## Context and Problem Statement

[ADR 0008](0008-barrel-files-public-api-boundaries.md) treats barrels as intentional public API boundaries. When `index.ts` or `index.tsx` files also contain components, wiring, or other implementation, the boundary blurs: the file is both a catalog of exports and a place where behavior lives, which makes ownership, reviews, and automated checks harder.

**Question:** How should we keep barrel `index` modules aligned with their role as boundaries while leaving room for non-barrel entry files?

## Decision Drivers

- Clear separation between “what this module exports” and “how it is implemented”
- Consistency with curated barrel discipline in ADR 0008
- Predictability for tooling and coding agents (including ESLint)
- Avoiding unnecessary ceremony for files that are not barrels

## Considered Options

- Allow any content in `index` files; rely on review only
- Require re-export-only barrels in some trees, with ESLint where configured
- Ban `index` filenames entirely in favor of explicit entry module names

## Decision Outcome

**Chosen option:** Require **re-export-only** content in `index.ts` / `index.tsx` files that serve as **public barrel boundaries** under configured application `src/` trees (for example `apps/web/src/**/index.ts` and `apps/web/src/**/index.tsx`). Implementation—including root React components such as `App`—lives in **named modules** under the relevant slice (for example `…/presentation/App.tsx`) and is re-exported from that slice’s **`presentation/index.ts`** barrel, then (where applicable) aggregated at the **module root** barrel per [ADR 0008](0008-barrel-files-public-api-boundaries.md).

**Justification:** This keeps barrels as thin, scannable API surfaces, matches ADR 0008’s intent, and allows automated enforcement without ambiguity about “what is the public surface.”

### Consequences

- Good, because barrel files stay easy to read and diff
- Good, because implementation files have concrete names that match their primary symbols
- Good, because ESLint can enforce the rule for matching globs
- Bad, because slice plus module root barrels add files (for example `presentation/App.tsx`, `presentation/index.ts`, and `app/index.ts`)
- Bad, because **not every** `index.ts` in a repository is a barrel (see below); those files are out of scope unless explicitly covered by config

### Confirmation

- **ESLint:** Shared helper `createIndexBarrelOnlyRule` in `@chiubaka/eslint-config` applies `no-restricted-syntax` to configured globs (disallowing `import`, inline `export` declarations, `export default`, and preserving the same `export *` and Zod-related restrictions as the base config for those files).
- **Review:** New barrels under covered trees should contain only `export { … } from "…"` / `export type { … } from "…"` style re-exports.

## Pros and Cons of the Options

### Allow any content in `index` files

- Good, because fewer files
- Bad, because barrels and implementation mix; harder to enforce boundaries

### Re-export-only barrels with optional ESLint (chosen)

- Good, because clear rule and automatable checks where enabled
- Neutral, because root shell components need a named implementation file plus a **slice** barrel before the module root re-exports (see ADR 0008 **first-class slice directories**)

### Ban `index` filenames

- Good, because forces explicit entry names
- Bad, because conflicts with widespread barrel convention and ADR 0008 examples

## More Information

### Relationship to non-barrel `index` files

Some packages use `index.ts` as a **composition root** or **executable entry** (side effects, server bootstrap, ESLint config assembly). Those files are **not** public API barrels in the ADR 0008 sense. This ADR does **not** require them to be re-export-only; enforcement is **glob-based**. Prefer naming non-barrel entry files descriptively (for example `main.ts`) when adding new entrypoints, to avoid confusion.

### Related ADRs

- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — barrels as public API boundaries
- [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md) — frontend `app/` composition and layered structure
