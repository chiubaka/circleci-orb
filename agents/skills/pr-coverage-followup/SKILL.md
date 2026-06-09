---
name: pr-coverage-followup
description: >-
  Investigates failing Codecov or coverage CI checks on pull requests, analyzes
  uncovered lines, and adds tests only where coverage is meaningful—never
  padding tests just to pass thresholds. Use when a PR fails coverage checks,
  Codecov reports missing lines, patch/project coverage drops, or review feedback
  asks for test coverage.
---

# PR coverage follow-up

## Goal

Resolve failing coverage checks on pull requests by adding **real, behavior-focused tests**—not coverage padding. When gaps are trivial or untestable, document why and pursue an exemption or threshold adjustment instead of fake tests.

## When to apply

- A PR check named like **codecov**, **coverage**, or **test-coverage** is failing.
- Codecov (or similar) comments flag uncovered lines in the diff.
- Review feedback asks for tests on changed code.
- You are running `pr-review-thread-followup` and a thread or CI signal involves coverage.

Pair with `test-driven-development` when writing tests and `review` before handoff.

## Use `gh` first

Prefer **`gh`** for PR context and CI status. Use browser or Codecov UI only when `gh` lacks the detail you need.

### 1. Bind the PR and find failing coverage checks

```bash
gh pr view --json number,url,title,state,statusCheckRollup,headRefOid
gh pr checks
```

Look for checks whose name or description mentions **codecov**, **coverage**, or your repo's coverage job. Note the check URL for logs and report links.

For a specific check:

```bash
gh pr checks --watch   # optional: wait for completion
gh api repos/{owner}/{repo}/commits/{sha}/check-runs --jq '.check_runs[] | select(.name | test("codecov|coverage"; "i")) | {name,conclusion,details_url}'
```

Capture the PR head SHA from `headRefOid` in step 1—Codecov reports are keyed to it.

### 2. Read the coverage report

Use the failing check's **details URL** (Codecov PR comment, GitHub Actions log, or artifact). Collect:

- **Patch coverage** — lines in the PR diff that lack hits.
- **Project coverage** — overall drop (secondary; patch coverage is usually the gate).
- **File paths and line numbers** for uncovered hunks.

In Codecov's PR view, focus on the **Files changed** tab and **uncovered** / **partial** markers on diff lines. Cross-reference with local `git diff` against the PR base branch so you see the exact new or changed code.

If the report is vague, run the repo's coverage command locally (for example `pnpm test --coverage` or the package-scoped equivalent from `AGENTS.md`) and map hits to the flagged lines.

## Triage: meaningful vs trivial gaps

For **each** uncovered region, classify before writing a test:

| Class                                                                                                | Action                                                                   |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **Meaningful behavior** — branches, validation, error paths, state transitions, public API contracts | Add or extend a focused test                                             |
| **Trivial** — simple getters, pass-through delegates, type-only exports, re-exports                  | Usually skip; note in PR reply if challenged                             |
| **Generated / vendored** — codegen, protobuf stubs, lockfile-adjacent output                         | Do not test; exclude via repo config if appropriate                      |
| **Unreachable defensive code** — `default` arms exhaustive switches should never hit, `never` guards | Prefer refactor or documented exemption over contrived tests             |
| **Wiring / composition root** — DI glue with no logic                                                | Integration or e2e test only if behavior is user-visible; otherwise skip |
| **Logging / metrics only** — no behavioral effect                                                    | Skip unless observability is the contract under test                     |

**Rule:** If the only way to cover a line is to assert implementation details with no behavioral claim, **do not add the test**.

When multiple lines share one behavior, **one well-named test** beats several shallow tests.

## When NOT to add tests

Do **not** add tests solely to satisfy Codecov or hit a percentage. Skip or push back when:

- The line is **not reachable** in production without breaking invariants.
- Coverage would require **mocking every collaborator** to assert a one-line delegation.
- The change is **docs-only, types-only, or formatting** with no runtime behavior.
- The uncovered code is **third-party or generated** and should be excluded from coverage scope.
- A test would **duplicate** an existing test at a higher level without adding a new failure mode.
- The reviewer or bot asks for coverage on **trivial accessors**—reply with rationale instead of padding.

If patch coverage cannot reasonably improve without low-value tests, say so in the PR (or review thread) and suggest: threshold exception, `codecov.yml` adjustment for that path, or accepting the gap with justification.

## Adding meaningful tests

1. **Start from behavior** — name the test after the observable outcome (`rejects invalid email`, `retries once on 503`).
2. **Use existing patterns** — mirror `test/` layout, helpers, and runners already in the touched package.
3. **Cover the branch that matters** — inputs that flip the uncovered condition, not every syntactic line.
4. **Prefer unit tests** for isolated logic; **integration tests** when behavior spans modules or I/O boundaries.
5. **Run the smallest verifying command** while iterating, then the repo root suite before handoff (`pnpm test`, `pnpm lint`, etc., per `AGENTS.md`).

Follow `test-driven-development` for placement, naming, and assertion quality.

### Example decisions

**Add a test:** New `parseRetryAfter(header)` branch returns `undefined` for malformed values—test one malformed and one valid header.

**Skip:** Uncovered `return this.id` on a domain entity—getter with no logic; reply that patch coverage gap is acceptable.

**Skip with config:** Uncovered lines in `src/generated/`—point reviewers to coverage exclude rules instead of testing generated output.

## PR workflow integration

### With `pr-review-thread-followup`

When triaging threads **or** when `gh pr checks` shows a failing coverage check:

1. Run this skill **before** claiming the PR is ready.
2. Implement meaningful tests for classified **meaningful** gaps.
3. Reply on coverage-related review threads: what you tested, what you skipped and why, or link to the commit that adds tests.
4. Re-push and confirm the coverage check passes—or document why an exemption is appropriate.

### Handoff checklist

```text
Coverage follow-up:
- [ ] Identified failing check and uncovered lines (Codecov / CI / local report)
- [ ] Classified each gap: meaningful vs trivial vs excluded
- [ ] Added tests only for meaningful behavior
- [ ] Did not add padding tests to game the threshold
- [ ] Re-ran tests (and coverage if available locally)
- [ ] Updated PR / review threads with outcomes
```

## Related skills

- `pr-review-thread-followup` — reply in threads when coverage feedback is part of review.
- `test-driven-development` — test layout and quality bar when adding coverage.
- `review` — final gate before merge.
