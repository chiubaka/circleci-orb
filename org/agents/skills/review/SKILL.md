---
name: review
description: >-
  Default completion gate: checklist-driven review for regressions, architecture
  boundaries, security, naming, and guidance alignment. Run before handoff unless
  the change is trivial.
---

# Code review checklist

## Goal

Catch quality, consistency, and correctness issues that automated checks miss before marking work complete or requesting merge.

## When to use this skill

Run by default after any non-trivial code change and **before** you tell the user work is complete, request review, or push. Skip only for trivial edits (typo-only, obvious one-liners). If you ran `pnpm lint` / `pnpm test` but skipped this checklist, the handoff is not done—automation does not cover the same items.

## Core findings

- [ ] Enumerate concrete bugs, behavioral regressions, and missing/insufficient tests first.
- [ ] Include file/line references for each finding so fixes are directly actionable.
- [ ] Call out risks not covered by automation (edge cases, concurrency races, integration gaps).

## Verification gate

- [ ] Confirm the final verification suite was run from the repository root: `pnpm build`, `pnpm lint`, `pnpm test`, `pnpm typecheck`.
- [ ] Confirm those root commands passed for the full workspace and all packages, not just the package under review.
- [ ] Treat package-scoped verification as additive only; flag handoff as incomplete if the root suite was skipped.
- [ ] Confirm test layout remains consistent: tests under `test/` alongside `src/`, mirrored structure, and test-only helpers/fixtures/builders kept in `test/`.

## Architecture and boundaries

- [ ] Validate layering and boundary decisions against `AGENTS.md` and relevant ADRs.
- [ ] Confirm composition/wiring remains at composition roots and does not leak into domain/application internals.
- [ ] Confirm import boundaries and barrel usage remain intentional for the touched feature area.

## Security and reliability

- [ ] Check untrusted content handling, boundary validation, and unsafe casts at runtime boundaries.
- [ ] Check async sequencing, atomic scope usage, and ordering assumptions for race or consistency risks.
- [ ] Flag any degraded observability or error handling in changed paths.
- [ ] For `security/detect-object-injection`, prefer refactors over suppressions: use `process.env` dot access for valid keys, prefer `Map.get` or exhaustive `switch` over broad `Record[key]` indexing, and keep any unavoidable suppression one-line with rationale.

## Agent guidance alignment

- [ ] If repeated issues surface, update `AGENTS.md`/`org/agents/AGENTS.org.md` or create/update a focused skill.
- [ ] Keep skill scope narrow; avoid restating broad org conventions when cross-referencing is sufficient.
- [ ] Run guidance sync scripts after org-level guidance or skill changes.
- [ ] On repositories with Changesets, confirm release notes and semver bumps are expressed via a **new or updated** `.changeset/*.md` entry, **not** by editing `package.json` `version` or `CHANGELOG.md` directly, unless a maintainer asked for a hotfix to automation itself (see `org/agents/skills/changesets-hygiene/SKILL.md`).

## Style and naming

- [ ] **Test stand-in naming (review-time):** Prefer **mock** terminology in test code (`createFooMock`, `*TestMocks` modules) over “double” naming (`*Double`, `*TestDoubles`). Reserve *double* for prose when you mean the general testing concept.
- [ ] Prefer full, descriptive names over short abbreviations for variables, parameters, instance fields, and destructured bindings.
- [ ] Apply that preference consistently across all scopes (local variables, function parameters, and class members) unless a conventional short name is more recognizable within the domain.
- [ ] When clarifying the guidance, examples such as `dependencies` over `deps`, `llmService` over `llm`, and `configuration` over `config` are helpful; list exceptions explicitly so reviewers can justify departures.
- [ ] When a module's primary public export is a single PascalCase symbol, prefer matching file basenames (for example `ChatContext.ts`); allow standard exceptions (`index.ts`, tooling/config files, and multi-export modules with no single owner).
- [ ] Favor self-documenting code via clear naming and decomposition; avoid comments or JSDoc used only to compensate for unclear structure.
- [ ] Keep existing JSDoc-related lint expectations stable in routine feature work unless a task explicitly changes lint policy.
- [ ] **UI layout naming (review-time):** Prefer **descriptive** component and hook names over generic **Shell** (`AppLayout`, `RootLayout`, `RouteLayout`, `NavigationDrawer`, `MainContent`, or React Router’s `Layout` / `<Outlet />` vocabulary) unless **Shell** is unavoidable (for example, matching a documented industry term in prose such as PWA “app shell,” not as a default component basename). Generic `Shell` / `AppShell` / `NavigationShell` tends to blur scope and invite junk-drawer components; flag it when a more specific name would clarify what is fixed versus what swaps per route.
- [ ] **React component decomposition (review-time):** Prefer **single responsibility** per component: one cohesive UI slice or behavior, **one primary reason to change**—similar in spirit to narrow application services. Avoid **monolith** components that cram multiple unrelated concerns into one file (for example mixing route/param resolution, app-wide layout chrome, several unrelated data domains, and large feature markup without seams). Prefer a thin **container** or **layout** that composes hooks and passes narrow props, plus **leaf** presentational components (lists, panels, forms, headers) with explicit names. Flag new or expanded “god” screen components; if an exception is warranted, the review should state why decomposition was deferred.

## API design and repository consistency

- [ ] For small closed discriminant sets, prefer `enum` or const-object-plus-derived-type over open string unions unless openness is intentional.
- [ ] Disallow default exports in production modules; prefer named exports to keep API surfaces explicit and refactor-safe.

## Repository naming and mapping review

- [ ] Confirm repository queries follow read-style `find*` naming and mutation methods use operation verbs such as `create`, `update`, `delete`, `upsert`, and `append`.
- [ ] Confirm repository/adapter translation methods prefer `toDomain` and `fromDomain` over ad hoc mapper names when converting between persistence and domain types.
- [ ] In class-owned repository/adapter modules, confirm mapping helpers remain class-owned (`private static` by default) unless they are genuinely shared utilities.

## Constructor options review

- [ ] For constructors that accept small option bags, prefer named instance fields for used options rather than broad `this.options` retention.
- [ ] Allow `this.options` retention when the options bag is large and the reduced boilerplate improves readability.
- [ ] Flag constructor examples or prose-heavy style guidance that belongs in review-time checks rather than generation-time org guidance.

## Related skills

- Use `test-driven-development` to verify test layout conventions (`src/` mirrored under `test/`, with test-only helpers kept under `test/`).
