# Agent notes (repo conventions)

<!-- ORG_GUIDANCE_START -->

Org-level guidance in this section is the default baseline for all repositories.
Repository-specific guidance in the local override section of `AGENTS.md` takes precedence on conflicts.

## Architecture and recorded decisions (ADRs)

- Use `org/docs/adr/` for long-lived architecture and engineering conventions.
- Prefer adding or updating an ADR for durable structural or convention changes.
- Keep `AGENTS.md` short; ADRs hold detailed rationale and decision history.
- **ADR audience (generation-time):** ADRs are written for **human** readers (contributors, reviewers, future maintainers)—not as agent runbooks. Record the decision, drivers, and consequences in clear prose; do not phrase ADRs as instructions to an AI or link to agent skills as normative requirements. Operational detail for agents belongs in skills or contributor guides; ADRs may note that repositories often mirror principles elsewhere without making those paths part of the decision record. When creating or editing ADRs, use `org/agents/skills/create-adr/SKILL.md`.

## Composition, wiring, and extending features

- Keep assembly (DI registration, env-to-config wiring, HTTP mapping) in composition roots at system edges.
- Keep domain and application code free from framework/container wiring except at explicit boundaries.
- When composition grows, prefer named steps or sectioned helpers so wiring remains scannable.
- Choose feature layers deliberately (`domain` / `application` / `infrastructure`) and align names/options with neighboring code.
- For pure helpers and decoders inside a feature module, use the **Placement decision procedure** in `org/docs/adr/0016-frontend-responsibility-areas-and-layered-boundaries.md` (module **`lib/`** for cross-layer domain-agnostic helpers; role-named **`domain/`** for selectors/predicates/policies; **`infrastructure/`** for adapter/wire mappers). Do not use generic catch-all names (`helpers.ts`, `values.ts`, `utils/`).
- When shared infrastructure is concrete and vendor-specific, prefer `infrastructure/<vendor>` over generic names such as `persistence`; do not imply an abstraction that the code does not actually provide.
- Default to classes for orchestration-heavy or domain-driven behavior; keep class-specific helpers private.
- Prefer module-level functions for pure transformations and interfaces only when substitutability is real.
- For class-named modules (for example, `*Service.ts`, `*Evaluator.ts`), treat the class as the default boundary.
- Do not export production helpers solely for tests; test class internals through public APIs unless helpers are genuinely shared utilities.
- If ADR 0012 and ADR 0013 both seem applicable, prefer ADR 0012 defaults for class-owned orchestration modules.

## Linting and ESLint

- Do not add wholesale lint rule disables (for example `rules: { "some-rule": "off" }` scoped to broad file globs, entire packages, or workspace-wide config blocks) unless explicitly approved by a maintainer.
- Prefer fixing violations or adjusting code to satisfy the rule.
- When a rule truly cannot be satisfied, use a **line- or next-line** disable only (`eslint-disable-next-line` / `eslint-disable-line` with the specific rule id). Document the reason on the same line or immediately above the disable.
- Do not use file-level `eslint-disable` without maintainer approval.
- Do not turn off `reportUnusedDisableDirectives` or similar linter hygiene options to hide stale disables.

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

## Versioning and changelog (Changesets)

- When a repository uses **Atlassian Changesets** (a `.changeset/` config and `@changesets/cli` in the workspace), **do not** hand-edit the root or package `version` fields in `package.json` to release user-facing changes, and **do not** hand-edit `CHANGELOG.md` to add release notes for those changes. Release automation applies those updates when maintainers run `changeset version` (or the organization’s release pipeline does).
- Use **`pnpm changeset` / `changeset add`**, or add a new tracked markdown file under **`.changeset/`** with the correct `patch` / `minor` / `major` frontmatter, so the intended semver bump and changelog line are generated at release time.
- Follow `org/agents/skills/changesets-hygiene/SKILL.md` when introducing or changing releasable work, and `org/agents/skills/changeset/SKILL.md` when authoring `.changeset/*.md` summaries (required category prefix, voice by monorepo type).
- **Exceptions — no Changeset:** Do **not** add a `.changeset/` entry for **documentation-only** work that does not alter shipped package behavior, including **new or updated ADRs** (`**/docs/adr/**/*.md`, `org/docs/adr/**/*.md`) and **agent or contributor guidance** (for example `AGENTS.md`, `org/agents/AGENTS.org.md`, `REVIEW-CHECKLIST.md`, `org/agents/skills/**/*.md`, `.agents/skills/**`, Cursor rules/skills mirroring those). Ship those edits without a semver bump driven by Changesets unless the repository owner explicitly asks to version a doc-only policy as a patch.

## Org subtree safety

- Treat `org/` as a `git subtree`-managed prefix; do not remove and recreate `org/` unless the user explicitly requests subtree reinitialization.
- For `org/` updates, use subtree workflows (`git subtree pull` / `git subtree push`) rather than ad hoc delete-and-copy workflows.
- Keep subtree strategy consistent for a given repository: if `--squash` is used for subtree add or pull, keep using `--squash` for later subtree sync commands.
- Do not rewrite away subtree ancestry on active branches (for example via history surgery that drops prior subtree integration commits) unless explicitly requested.
- If subtree sync fails with unrelated history, prefer non-destructive recovery steps first (verify remote/branch/prefix consistency and subtree history markers) before reinitializing.

## Style and readability

- **Documentation (generation-time):** Follow `org/docs/adr/0004-self-documenting-code-and-documentation-expectations.md` (code-first, purposeful docs). When adding, editing, or reviewing JSDoc—or satisfying JSDoc lint—use `org/agents/skills/jsdoc/SKILL.md`.
- **Open string unions (`@typescript-eslint/no-redundant-type-constituents`):** Do not “fix” `literal | string` by widening to plain `string`—that erases documented allowed values with no type benefit (`literal | string` already collapses to `string`). For intentionally open domains (built-ins plus arbitrary names), use `as const` + derived built-in type + `Type | (string & {})`, or a closed union only when the set is actually closed.
- Keep `org/agents/AGENTS.org.md` focused on structural and generation-time constraints.
- **Review before handoff (mandatory default):** Before concluding work, telling the user a task is finished, opening a PR, or pushing, run the checklist in `org/agents/skills/review/SKILL.md` unless the change is trivial (for example typo-only or a single obvious one-line fix). Treat it as part of the same completion bar as repo-root verification—lint and tests do not replace it. Run it after each meaningful slice of implementation, not only at the end of large tasks or when explicitly asked.
- During planning for major behavior changes, consult `org/agents/skills/test-driven-development/SKILL.md` to drive a test-first implementation loop.
<!-- ORG_GUIDANCE_END -->

<!-- REPO_OVERRIDES_START -->
_Repository-specific overrides go here. These take precedence over org defaults._

## Repo release-notes policy

- Do not maintain a running migration log, release notes ledger, or shadow changelog in `README.md`.
- Record normal release-facing changes through `.changeset/*.md`; generated changelog output is the canonical release history.
- Add README migration guidance only for large, breaking transitions that require durable operator context not appropriate for a single changeset entry.
- When such README migration guidance is necessary, keep it focused on actionable migration steps and remove it after it is no longer needed.
<!-- REPO_OVERRIDES_END -->
