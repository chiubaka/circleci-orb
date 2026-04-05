---
name: review
description: >-
  Checklist-driven code review focused on regressions, architecture boundaries,
  security, and guidance alignment.
---

# Code review checklist

## Goal

Catch quality, consistency, and correctness issues that automated checks miss before marking work complete or requesting merge.

## When to use this skill

Use after finishing a meaningful code change and before pushing or asking for human review.

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

## Style and naming

- [ ] Prefer full, descriptive names over short abbreviations for variables, parameters, instance fields, and destructured bindings.
- [ ] Apply that preference consistently across all scopes (local variables, function parameters, and class members) unless a conventional short name is more recognizable within the domain.
- [ ] When clarifying the guidance, examples such as `dependencies` over `deps`, `llmService` over `llm`, and `configuration` over `config` are helpful; list exceptions explicitly so reviewers can justify departures.
- [ ] When a module's primary public export is a single PascalCase symbol, prefer matching file basenames (for example `ChatContext.ts`); allow standard exceptions (`index.ts`, tooling/config files, and multi-export modules with no single owner).
- [ ] Favor self-documenting code via clear naming and decomposition; avoid comments or JSDoc used only to compensate for unclear structure.
- [ ] Keep existing JSDoc-related lint expectations stable in routine feature work unless a task explicitly changes lint policy.

## API design and repository consistency

- [ ] For small closed discriminant sets, prefer `enum` or const-object-plus-derived-type over open string unions unless openness is intentional.

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
