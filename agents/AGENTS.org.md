Org-level guidance in this section is the default baseline for all repositories.
Repository-specific guidance in the local override section of `AGENTS.md` takes precedence on conflicts.

## Architecture and recorded decisions (ADRs)

- Use `org/docs/adr/` for long-lived architecture and engineering conventions.
- Prefer adding or updating an ADR for durable structural or convention changes.
- Keep `AGENTS.md` short; ADRs hold detailed rationale and decision history.
- ADR references:
  - `org/docs/adr/0012-classes-as-primary-responsibility-boundaries.md`
  - `org/docs/adr/0013-use-of-classes-vs-module-level-functions-and-interfaces.md`
  - `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`
  - `org/docs/adr/0008-barrel-files-public-api-boundaries.md`
  - `org/docs/adr/0009-prefer-small-focused-files.md`
  - `org/docs/adr/0010-import-specifier-conventions-for-monorepo-packages.md`
  - `org/docs/adr/0011-test-import-alias-hash-root.md`
  - `org/docs/adr/0004-self-documenting-code-and-documentation-expectations.md`
  - `org/docs/adr/0005-composition-roots-and-wiring-boundaries.md`
  - `org/docs/adr/0006-consistency-and-extension-for-new-features.md`
  - `org/docs/adr/0001-hexagonal-architecture-with-ddd-naming.md` (superseded for layout; retained for history)

## Naming note: L-3XO vs Lex

- In code and internal developer docs, use canonical `L-3XO` / `l3xo` naming.
- Reserve `Lex` for intentional user-facing product copy only.

## Self-documenting code and documentation

- Prioritize clarity through names, structure, and decomposition.
- Do not use comments or JSDoc to compensate for confusing code when refactoring would clarify intent.
- Use JSDoc/comments where they add IDE-visible value or context types cannot express.
- Keep existing ESLint JSDoc expectations; do not relax or tighten them in routine feature work.

## Composition, wiring, and extending features

- Keep assembly (DI registration, env-to-config wiring, HTTP mapping) in composition roots at system edges.
- Keep domain and application code free from framework/container wiring except at explicit boundaries.
- When composition grows, prefer named steps or sectioned helpers so wiring remains scannable.
- Choose feature layers deliberately (`domain` / `application` / `infrastructure`) and align names/options with neighboring code.
- Default to classes for orchestration-heavy or domain-driven behavior; keep class-specific helpers private.
- Prefer module-level functions for pure transformations and interfaces only when substitutability is real.
- For class-named modules (for example, `*Service.ts`, `*Evaluator.ts`), treat the class as the default boundary.
- Do not export production helpers solely for tests; test class internals through public APIs unless helpers are genuinely shared utilities.
- If ADR 0012 and ADR 0013 both seem applicable, prefer ADR 0012 defaults for class-owned orchestration modules.

## Test-driven development

- For behavior changes, prefer TDD: write failing tests first, then implement to green.

## Test layout convention

- Keep tests under a `test/` directory alongside `src/`.
- Mirror `src/` structure inside `test/`.
- Keep test-only helpers/fixtures/builders under `test/`, not `src/`.
- Naming convention:
  - Source: `<package>/src/<path>.ts`
  - Test: `<package>/test/<path>.test.ts`
- Example:
  - `packages/example/src/index.ts` -> `packages/example/test/index.test.ts`

## Barrel files (`index.ts`)

- Treat each barrel as an intentional public API boundary, not a complete subtree catalog.
- Apply this at package, feature, layer (`domain` / `application` / `infrastructure`), and immediate `infrastructure/<category>/` scopes.
- In tests, prefer imports from concrete modules unless explicitly testing a barrel surface.
- Add exports only when there is a real consumer for the barrel surface.
- If barrel constraints expose cycles, refactor first (extract shared types/logic, invert dependency via ports) before considering narrow lint exceptions.

## ESLint: `security/detect-object-injection`

- Prefer small refactors over suppressions when computed object access is flagged.
- `process.env`: prefer dot access for valid identifier keys; keep unavoidable bracket access localized.
- Typed key lookups: prefer `Map.get` or exhaustive `switch` over `Record[key]` access.
- Arrays with variable indices: prefer `array.at(index)` or iteration methods where practical.
- If suppression is necessary, keep it one-line and document rationale briefly.

## Final verification after meaningful changes

- Run all three commands before finishing meaningful code changes:
  - `pnpm build`
  - `pnpm lint`
  - `pnpm test`
- Treat IDE diagnostics as additive, not a replacement for command runs.
- If lint behavior may be affected (config/rules/task wiring), run `pnpm lint -- --no-cache`.
- Complete a review pass using the repository's review checklist to catch quality and consistency issues automation misses.

## TypeScript API design: closed vocabularies

- For small closed discriminant sets (for example log levels or stable role labels), prefer `enum` or a const-object-plus-derived-type over open string unions.
- Use stronger enforcement only when recurring issues justify the extra rigidity.

## Skills and portability

- Treat `org/agents/skills` as the shared org skill source intended for subtree distribution.
- Local repositories may add repo-specific skills under `.agents/skills` without changing org-shared skill sources.
