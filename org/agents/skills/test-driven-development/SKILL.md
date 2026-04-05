---
name: test-driven-development
description: >-
  Test-first workflow for behavior changes, including test layout conventions,
  test-boundary checks, and verification expectations.
---

# Test-driven development checklist

## Goal

Keep behavior changes safe by writing failing tests first, implementing the smallest fix to green, then hardening with focused edge-case coverage.

## When to use this skill

Use whenever code behavior changes or a bug/regression is being fixed. Pair this with `review` before merge.

## TDD loop

1. Write or update a failing test that captures the intended behavior change.
2. Implement the minimal production change required to pass that test.
3. Refactor only after green, keeping behavior stable.
4. Add targeted edge-case tests where regressions are plausible.

## Test placement and boundaries

- [ ] Keep tests under a `test/` directory alongside `src/`.
- [ ] Mirror `src/` structure within `test/`.
- [ ] Keep test-only helpers/fixtures/builders in `test/`, not `src/`.
- [ ] Import concrete modules in tests unless explicitly validating a barrel surface.

## Test quality checks

- [ ] Assertions cover externally visible behavior, not implementation noise.
- [ ] Failure messages and test names make expected behavior clear.
- [ ] Changed branches and error paths are covered.
- [ ] `vi.stubGlobal(...)` calls are restored with `afterEach(() => vi.unstubAllGlobals())` at suite scope.

## Verification

- [ ] Run affected package test suites while iterating.
- [ ] Before handoff, run repository-required verification commands from `AGENTS.md`.
