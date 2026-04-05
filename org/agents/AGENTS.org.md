Org-level guidance in this section is the default baseline for all repositories.
Repository-specific guidance in the local override section of `AGENTS.md` takes precedence on conflicts.

## Architecture and recorded decisions (ADRs)

- Use `org/docs/adr/` for long-lived architecture and engineering conventions.
- Prefer adding or updating an ADR for durable structural or convention changes.
- Keep `AGENTS.md` short; ADRs hold detailed rationale and decision history.

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

## Barrel files (`index.ts` / `index.tsx`)

- Treat each barrel as an intentional public API boundary, not a complete subtree catalog.
- Apply this at package, feature, layer (`domain` / `application` / `infrastructure` / `presentation` when those directories exist), **first-class slice** directories under a module root (including composition hosts such as `app/`—for example `presentation/`, `navigation/`, `lib/` when they are deliberate slices), and immediate `infrastructure/<category>/` scopes. See `org/docs/adr/0008-barrel-files-public-api-boundaries.md`.
- Per `org/docs/adr/0018-index-barrels-re-export-only.md` where enforced (for example `apps/web` via ESLint), `index` files must be **re-export-only**—put implementation in named modules under the slice (for example `…/presentation/App.tsx`) and re-export from that slice’s `index.ts`, then from the module root if needed.
- In tests, prefer imports from concrete modules unless explicitly testing a barrel surface.
- Add exports only when there is a real consumer for the barrel surface.
- If barrel constraints expose cycles, refactor first (extract shared types/logic, invert dependency via ports) before considering narrow lint exceptions.

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

## Style and readability

- Keep `org/agents/AGENTS.org.md` focused on structural and generation-time constraints.
- After completing implementation, run a dedicated review pass with `org/agents/skills/review/SKILL.md` for consistency, lint-policy, naming, and verification checks.
- During planning for major behavior changes, consult `org/agents/skills/test-driven-development/SKILL.md` to drive a test-first implementation loop.
