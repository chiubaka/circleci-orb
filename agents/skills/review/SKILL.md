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

## Architecture and boundaries

- [ ] Validate layering and boundary decisions against `AGENTS.md` and relevant ADRs.
- [ ] Confirm composition/wiring remains at composition roots and does not leak into domain/application internals.
- [ ] Confirm import boundaries and barrel usage remain intentional for the touched feature area.

## Security and reliability

- [ ] Check untrusted content handling, boundary validation, and unsafe casts at runtime boundaries.
- [ ] Check async sequencing, atomic scope usage, and ordering assumptions for race or consistency risks.
- [ ] Flag any degraded observability or error handling in changed paths.

## Agent guidance alignment

- [ ] If repeated issues surface, update `AGENTS.md`/`org/agents/AGENTS.org.md` or create/update a focused skill.
- [ ] Keep skill scope narrow; avoid restating broad org conventions when cross-referencing is sufficient.
- [ ] Run guidance sync scripts after org-level guidance or skill changes.

## Related skills

- Use `test-driven-development` for detailed TDD workflow and test-specific review checks.
