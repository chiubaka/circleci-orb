---
name: coding-discipline
description: >-
  Behavioral guidelines for writing, reviewing, or refactoring code: clarify
  assumptions before implementing, prefer simplicity, keep diffs surgical, and
  define verifiable success criteria. Use when coding, fixing bugs, refactoring,
  or when work risks overcomplication, drive-by edits, or hidden assumptions.
---

# Coding discipline

Expanded guidance for the always-on baseline in `org/agents/rules/coding-discipline.md` (bootstrapped into `.cursor/rules/` and `.claude/rules/` in consuming repos). Derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls; see also [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills).

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks (typo-only, obvious one-liners), use judgment—not every change needs the full rigor.

This skill is **not** a substitute for the always-on rules file. Use it for detail, examples, and judgment calls.

## Precedence

- **Surgical default:** Touch only what the request requires.
- **Architecture when needed:** Org architecture skills and ADRs apply when the task requires structural change (new feature module layout, deliberate class-boundary refactor, barrel curation, and similar). Do not expand structure by default.

## 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them—do not pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what is confusing. Ask.

## 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that was not requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask: would a senior engineer say this is overcomplicated? If yes, simplify.

## 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Do not improve adjacent code, comments, or formatting.
- Do not refactor things that are not broken.
- Match existing style, even if you would do it differently.
- If you notice unrelated dead code, mention it—do not delete it.

When your changes create orphans:

- Remove imports/variables/functions that **your** changes made unused.
- Do not remove pre-existing dead code unless asked.

**Test:** every changed line should trace directly to the user's request.

## 4. Goal-driven execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

| Instead of…      | Prefer…                                             |
| ---------------- | --------------------------------------------------- |
| "Add validation" | Write tests for invalid inputs, then make them pass |
| "Fix the bug"    | Write a test that reproduces it, then make it pass  |
| "Refactor X"     | Ensure tests pass before and after                  |

For multi-step work, state a brief plan:

```text
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

For behavior changes, pair with `test-driven-development`. For handoff, pair with `review`. For new capabilities (utilities, dependencies, integrations), pair with `search-first` before build.

## Short examples

**Clarify first:** User says "fix auth." If that could mean session expiry, password reset, or OAuth callback failure, present the interpretations and ask—do not silently pick one.

**Simplicity:** Asked to add a boolean flag check—do not introduce a strategy registry, plugin system, or config schema "for later."

**Surgical:** Fixing a null check in one function—do not reformat neighboring functions, rename unrelated locals, or delete pre-existing unused imports in the same file.

**Goal-driven:** "Make retries more reliable" → define success (for example: flaky network test passes three times; retry budget and backoff match existing client patterns) before large rewrites.

## When these guidelines are working

- Fewer unnecessary changes in diffs
- Fewer rewrites due to overcomplication
- Clarifying questions come before implementation rather than after mistakes
