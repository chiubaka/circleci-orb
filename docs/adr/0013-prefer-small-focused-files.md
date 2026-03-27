---
status: accepted
date: 2026-03-26
decision-makers: Daniel Chiu
---

# ADR 0013: Prefer small, focused files by default

## Context and Problem Statement

In `@l3xo/backend`, we want module internals to stay easy to scan from the file tree while reducing unnecessary coupling between unrelated contracts and types. A recurring question is when to keep multiple exports in one file versus splitting them into dedicated files.

Without a shared default, file organization drifts toward either oversized files (harder targeted edits, noisier diffs) or over-fragmentation (extra import/barrel churn). We need a clear preference with explicit exceptions.

## Decision Drivers

- **Scanability:** the file tree should communicate module structure and responsibilities quickly.
- **Change isolation:** unrelated changes should avoid colliding in the same file.
- **Review clarity:** diffs should be narrow and map to one main concept.
- **Pragmatism:** avoid splitting artifacts that are strongly coupled and expected to evolve together.
- **Consistency:** naming and file layout should stay predictable across features.

## Considered Options

- Keep broader multi-export files by default and split only when pain appears.
- Split by default into small focused files with explicit "change together" exceptions.
- Enforce one-file-per-symbol in all cases.

## Decision Outcome

Chosen option: "Split by default into small focused files with explicit `change together` exceptions."

Justification: This preserves tree-level discoverability and better isolates changes while avoiding rigid fragmentation. It aligns with our feature/layer structure and barrel boundary guidance by encouraging focused implementation units and intentional public surfaces.

### Rules

1. **Default granularity:** prefer smaller, focused files that center on one primary export or responsibility.
2. **Contract interfaces (abstractions):** when a file exports many interfaces that define abstraction contracts, prefer one file per interface.
3. **Typing interfaces/types:** for interfaces or type aliases used as data typings, prefer one file per typing.
4. **Exception (change together):** keep multiple contracts/types in one file when they are strongly interdependent and likely to change together.
5. **Naming:** file names should reflect the main export (for example, `UsersService.ts`, `ChatRequest.ts`, `User.ts`).
6. **Not absolutist:** do not split purely to satisfy a count-based rule; choose boundaries that improve cohesion and reviewability.

### Consequences

- Good, because modules are easier to inspect quickly via the file tree.
- Good, because unrelated changes produce narrower diffs and fewer merge conflicts.
- Good, because agent/tool retrieval can more often load only relevant context.
- Bad, because more files can increase barrel and import maintenance.
- Bad, because teams must apply judgment for the "change together" exception.

### Confirmation

- **Review:** PR review checks that new contracts/types follow this default unless a clear "change together" rationale exists.
- **Conventions:** barrel updates stay intentional per [ADR 0012](0012-barrel-files-public-api-boundaries.md), avoiding broad re-export catalogs.
- **Consistency:** naming follows main-export alignment in new files and touched refactors.

## Pros and Cons of the Options

### Keep broader multi-export files by default

- Good, because it minimizes file count and import churn initially.
- Bad, because unrelated edits accumulate in shared files over time.
- Bad, because tree-level scanability degrades as files become mixed-responsibility.

### Split by default with "change together" exception (chosen)

- Good, because it balances discoverability with practical coupling.
- Good, because it supports cleaner ownership and targeted review.
- Bad, because it introduces light overhead when adding exports and barrels.

### One-file-per-symbol always

- Good, because the rule is simple and uniform.
- Bad, because it over-fragments tightly coupled models and can create mechanical churn.

## More Information

- [ADR 0011](0011-vertical-feature-modules-hexagonal-slices-and-packages.md) — feature/layer decomposition in `@l3xo/backend`.
- [ADR 0012](0012-barrel-files-public-api-boundaries.md) — barrel files as public API boundaries.
- [`AGENTS.md`](../../../AGENTS.md) — short operational pointers to ADRs.
