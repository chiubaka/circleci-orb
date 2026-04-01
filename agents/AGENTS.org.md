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
  - `org/docs/adr/0017-workspace-library-dist-boundary-and-dev-watch.md`
  - `org/docs/adr/0018-index-barrels-re-export-only.md`
  - `org/docs/adr/0019-vendor-specific-infrastructure-slices.md`
  - `org/docs/adr/0020-run-production-database-migrations-as-a-separate-deployment-step.md`
  - `org/docs/adr/0016-frontend-responsibility-areas-and-layered-boundaries.md`
  - `org/docs/adr/0004-self-documenting-code-and-documentation-expectations.md`
  - `org/docs/adr/0005-composition-roots-and-wiring-boundaries.md`
  - `org/docs/adr/0006-consistency-and-extension-for-new-features.md`
  - `org/docs/adr/0001-hexagonal-architecture-with-ddd-naming.md` (superseded for layout; retained for history)

## Naming note: L-3XO vs Lex

- In code and internal developer docs, use canonical `L-3XO` / `l3xo` naming.
- Reserve `Lex` for intentional user-facing product copy only.

## Source file basenames (TypeScript / TSX)

- When the module’s **primary** public surface is a single PascalCase binding (class, React component, context object, and similar), name the file **`ThatName.ts`** / **`ThatName.tsx`** to match that symbol—not a camelCase basename that diverges from it (for example `ChatContext.ts`, not `chatContext.ts`).
- **Exceptions:** barrels (`index.ts`), tooling/config files (`*.config.ts`, etc.), and modules with several co-equal exports where no one symbol clearly owns the module; align with neighboring files and feature-layer conventions instead of forcing a match.

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
- When shared infrastructure is concrete and vendor-specific, prefer `infrastructure/<vendor>` over generic names such as `persistence`; do not imply an abstraction that the code does not actually provide.
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

## Barrel files (`index.ts` / `index.tsx`)

- Treat each barrel as an intentional public API boundary, not a complete subtree catalog.
- Apply this at package, feature, layer (`domain` / `application` / `infrastructure` / `presentation` when those directories exist), **first-class slice** directories under a module root (including composition hosts such as `app/`—for example `presentation/`, `navigation/`, `lib/` when they are deliberate slices), and immediate `infrastructure/<category>/` scopes. See `org/docs/adr/0008-barrel-files-public-api-boundaries.md`.
- Per `org/docs/adr/0018-index-barrels-re-export-only.md` where enforced (for example `apps/web` via ESLint), `index` files must be **re-export-only**—put implementation in named modules under the slice (for example `…/presentation/App.tsx`) and re-export from that slice’s `index.ts`, then from the module root if needed.
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

- Run all four commands from the repository root before finishing meaningful code changes:
  - `pnpm build`
  - `pnpm lint`
  - `pnpm test`
  - `pnpm typecheck`
- Treat completion as blocked until those root commands succeed for the full workspace and all packages in scope, not just the package you touched directly.
- Package-scoped checks may be useful during iteration, but they do not replace the required final root verification pass.
- Treat IDE diagnostics as additive, not a replacement for command runs.
- If lint behavior may be affected (config/rules/task wiring), run `pnpm lint --force`.
- Complete a review pass using the `review` skill to catch quality and consistency issues automation misses.

## Context-efficiency and iteration discipline

- Keep strict quality gates while minimizing repeated context expansion during iteration.
- During exploration, prefer narrow discovery first:
  - Start with filename/symbol queries (`rg` files_with_matches or targeted globs) before pulling large slices of file content.
  - Read only the specific files or segments needed for the current change; avoid broad full-file reads unless diagnostics require it.
  - Skip large terminal or command-output dumps unless they directly help diagnose the current issue.
- During implementation, lean on scoped verification loops:
  - Re-run only the checks impacted by the files you touched.
  - Use package-scoped/type-scoped commands while iterating; defer full repo verification until the final pre-handoff pass.
- Preserve strictness at completion:
  - The final root verification commands (build/lint/test/typecheck) still must run before handoff for any meaningful code change.
  - Do not replace the required final pass with earlier scoped checks alone.

## TypeScript API design: closed vocabularies

- For small closed discriminant sets (for example log levels or stable role labels), prefer `enum` or a const-object-plus-derived-type over open string unions.
- Use stronger enforcement only when recurring issues justify the extra rigidity.

## Repository naming conventions

- Repository query methods that look up one or more records by a field should be named `find*` (for example `findById`, `findByConversationId`). This aligns with Prisma's naming conventions and distinguishes read-only lookups from write operations.
- Mutation methods follow the operation: `create`, `update`, `delete`, `upsert`, `append`, etc.
- When a repository or adapter maps between persistence/infrastructure records and domain types, prefer `toDomain` and `fromDomain` for those translation methods instead of ad hoc names such as `mapProfile`.
- In class-owned repository or adapter modules (for example `*Repository.ts`), keep persistence-to-domain mapping helpers on the neighboring class as `private static` methods by default unless the mapper is a true shared utility used across multiple classes.

## Naming: clarity over concision

- Prefer full, descriptive names over short abbreviations for variables, parameters, and instance variables.
- **Examples of preferred names:**
  - `dependencies` over `deps`
  - `llmService` over `llm`
  - `configuration` over `config` (when referring to a resolved config object, not a type name)
- Apply this at all scopes: local variables, function parameters, class instance variables, and destructured names.
- Exception: conventional short names in their own domain (e.g., `i` for loop indices, `e` for event parameters in callbacks, `c` for Hono context in route handlers) are acceptable.

## Constructor options: prefer destructured instance variables

- When a class constructor accepts an options object, prefer saving each option as its own named instance variable rather than storing the whole options object as `this.options`.
- This improves readability: callers see exactly which pieces of the options dict the class actually uses.
- **Exception:** when the options object has many keys (roughly 5 or more), storing the whole object as an instance variable is acceptable for conciseness.
- **Example (preferred for small options objects):**
  ```ts
  // Options interface
  export interface MyServiceOptions {
    model?: string;
    logger: Logger;
  }

  // Class
  export class MyService {
    private readonly model: string | undefined;
    private readonly logger: Logger;

    public constructor(dependency: Dependency, options: MyServiceOptions) {
      this.model = options.model;
      this.logger = options.logger;
    }
  }
  ```

## Skills and portability

- Treat `org/agents/skills` as the shared org skill source intended for subtree distribution.
- Local repositories may add repo-specific skills under `.agents/skills` without changing org-shared skill sources.
- Keep org-level guidance source in `org/agents/AGENTS.org.md`; sync root `AGENTS.md` via `org/agents/scripts/bootstrap-agents-md.sh`.
- Validate guidance sync drift with `org/agents/scripts/bootstrap-agents-md.sh --check`.

## Org subtree safety

- Treat `org/` as a `git subtree`-managed prefix; do not remove and recreate `org/` unless the user explicitly requests subtree reinitialization.
- For `org/` updates, use subtree workflows (`git subtree pull` / `git subtree push`) rather than ad hoc delete-and-copy workflows.
- Keep subtree strategy consistent for a given repository: if `--squash` is used for subtree add or pull, keep using `--squash` for later subtree sync commands.
- Do not rewrite away subtree ancestry on active branches (for example via history surgery that drops prior subtree integration commits) unless explicitly requested.
- If subtree sync fails with unrelated history, prefer non-destructive recovery steps first (verify remote/branch/prefix consistency and subtree history markers) before reinitializing.
