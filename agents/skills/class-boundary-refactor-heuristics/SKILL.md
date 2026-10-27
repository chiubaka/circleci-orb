---
name: class-boundary-refactor-heuristics
description: >-
  Heuristics for choosing classes vs module-level functions vs interfaces, and
  for refactoring orchestration-heavy modules toward explicit responsibility
  boundaries.
---

# Class boundary refactor heuristics

## Goal

Keep ownership and control flow explicit by using classes as the default responsibility boundary for orchestration-heavy logic, while preserving module-level functions for pure transforms that are genuinely shared—not class-local mappers in a class-owned module.

## Relevant org ADRs

- `org/docs/adr/0012-classes-as-primary-responsibility-boundaries.md`
- `org/docs/adr/0013-use-of-classes-vs-module-level-functions-and-interfaces.md`
- `org/docs/adr/0009-prefer-small-focused-files.md`

## When to use this skill

Use this skill when:

- A file named `*Service`, `*Evaluator`, or similar has drifting helper exports.
- You are deciding between class, module-level function, or interface.
- A module has orchestration mixed with low-level utility logic.

## When not to use this skill

Do **not** run a class-boundary refactor by default. Per coding-discipline surgical defaults, leave working module shape alone for localized fixes unless the user asked for a boundary refactor or the change cannot be made correctly without clarifying ownership (for example helpers exported only for tests, or orchestration split across unrelated module-level functions that you are already required to touch).

## Decision heuristic

1. If behavior orchestrates multiple steps/dependencies, prefer a class.
2. If the module’s primary export is already a class (especially `*Repository`, `*Store`, `*Queue`, or an adapter/provider), keep colocated pure helpers—including record↔domain mappers—on that class as `private` / `private static` (`toDomain` / `fromDomain` by default). Do not prefer module-level functions merely because those helpers are pure.
3. If behavior is a pure transformation with no lifecycle/identity concerns **and** it is not class-local support for a single class-owned boundary, prefer module-level function(s).
4. Add an interface only when real substitutability or boundary protection is needed.

## Refactor playbook

1. Identify the primary responsibility and make it the class public API.
2. Move class-local helpers into `private` or `private static` methods (including colocated `toDomain` / `fromDomain` mappers).
3. Keep module-level exports only for truly shared, reusable pure utilities extracted under reuse pressure.
4. Remove exports introduced only for direct unit testing of internal helpers.
5. Split oversized mixed files into focused modules when responsibilities diverge.

## Common mistakes to avoid

- Keeping orchestration split across unrelated module-level functions.
- Leaving class-local record↔domain mappers as module-level functions in a class-named repository/adapter module because they are pure.
- Creating interfaces for speculative future implementations.
- Expanding public API surface just to test internals directly.
- Introducing classes for tiny, one-line pure transforms that gain no clarity (and are not supporting an existing class boundary).

## Lightweight review checklist

- [ ] Class files have one clear owning responsibility.
- [ ] Class-specific helpers are private unless genuinely shared.
- [ ] Colocated repository/adapter mappers are `private static toDomain` / `fromDomain` (or instance `private` when they need `this`).
- [ ] Module-level functions are reserved for pure, reusable transforms—not class-local mappers.
- [ ] Interfaces correspond to real boundaries or multiple implementations.
- [ ] Public exports are minimal and intentional.

## Illustrative portable pattern

```ts
export class OrderEvaluator {
  public evaluate(input: OrderInput): EvaluationResult {
    const normalized = this.normalize(input);
    return this.score(normalized);
  }

  private normalize(input: OrderInput): NormalizedOrder {
    // class-owned orchestration helper
    return { ...input, total: Math.max(0, input.total) };
  }

  private score(order: NormalizedOrder): EvaluationResult {
    return { approved: order.total < 1000 };
  }
}
```

If formatting is reused across multiple responsibilities, extract it to a separate focused utility module (for example, `formatCurrency.ts`) instead of colocating it in the orchestration class file.
