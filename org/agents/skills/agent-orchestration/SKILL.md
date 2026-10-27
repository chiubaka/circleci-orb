---
name: agent-orchestration
description: >-
  When and how to use subagents / parallel exploration so context is gathered
  efficiently without over-delegation. Use for complex multi-area exploration,
  parallel independent investigations, spawning explore/generalPurpose-style
  subagents, or when context is missing for a subagent handoff.
---

# Agent orchestration

## Goal

Gather codebase context efficiently with subagents or parallel explore tasks when the work spans multiple areas—without dumping noise into the parent context or expanding scope.

Keep harness-agnostic: use the subagent / Task / explore tool exposed by the active harness. Do not hardcode harness-specific agent catalog names.

## When to delegate

**Delegate** for:

- Broad codebase discovery across many packages or directories.
- Independent parallel reviews or surveys.
- Long read-only exploration where the parent should stay focused on synthesis.

**Prefer direct Grep/Read** for narrow needle queries (a known symbol, one file, a specific string).

## Parallelism

Launch independent explore tasks together. Do not serialize when there is no dependency between investigations.

## Iterative retrieval (lite, max 3 cycles)

1. **DISPATCH** — Broad keywords / path globs for the question.
2. **EVALUATE** — Rank hits by relevance to the need; discard noise.
3. **REFINE** — Tighten terms, add excludes, or narrow paths.
4. **LOOP or stop** — Stop when 2–3 high-relevance files suffice; otherwise repeat (max 3 cycles total).

Do not paste long pseudocode into prompts; treat this as agent procedure.

## Handoff

The parent summarizes findings for the next step. Do not dump entire file trees or raw subagent transcripts into the following prompt.

## Coding-discipline guard

Orchestration is for **discovery**, not an excuse to expand scope, refactor adjacent code, or invent abstractions. Pair with `search-first` before building new capabilities.

## Related

- `search-first`
- `worktree-workflow`
- `adopt-worktree-branch`
- `review`
