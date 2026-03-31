---
status: accepted
date: 2026-03-26
decision-makers: Daniel Chiu
---

# ADR 0008: Barrel files (`index.ts`) as public API boundaries

## Context and Problem Statement

We use **`index.ts` barrels** to mark **public** surfaces: symbols **re-exported** from a barrel are part of that scope’s API; non-exported files are **private** unless a documented exception applies. Without a shared rule, barrels drift into **export catalogs**, deep imports bypass encapsulation, or teams avoid barrels entirely and lose a cheap enforcement lever for lint.

This ADR records **when** and **at what depth** barrels are appropriate—including required barrels under `infrastructure/<category>/`—so guidance stays consistent with [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) without repeating all structural context.

## Decision Drivers

- **Encapsulation:** Prefer **explicit** public vs. private over convention alone (“please don’t import that file”).
- **Lint-friendly boundaries:** A barrel gives import rules a clear **choke point** (`no-restricted-paths`, `eslint-plugin-boundaries`, …).
- **Pragmatism:** Avoid **barrel fatigue**: not every directory needs its own `index.ts` when there is no real boundary to protect.
- **Alignment:** Feature modules, layers, and packages share one **mental model** for what a barrel means.

## Considered Options

- **Barrels only at package or feature root:** simplest tree, but weaker hiding inside large `infrastructure/<vendor>/` trees.
- **Barrels at every directory:** consistent but noisy; many barrels only re-export one file.
- **Barrel on any justified public/private boundary:** add `index.ts` when a subtree has a **small public** surface and **private** helpers; skip when the folder is trivial.

## Decision Outcome

**Chosen option:** barrels are required at package/feature/layer scope, and required for each immediate `infrastructure/<category>/` subdirectory; keep exports intentionally small so these remain meaningful public/private boundaries.

**Justification:** It matches how we treat feature and layer barrels in ADR 0007 while making infrastructure category boundaries explicit and consistent across features.

### Rules

1. **Meaning of a barrel:** An `index.ts` in a given folder defines that scope’s **intentional exports**. Do not turn it into a complete re-export list of every symbol in the subtree; export **only** what other code **may** depend on per scope.

2. **Scopes we use:**
   - **Workspace package** root barrel (when the package has one)—public API of the package.
   - **Feature module** root barrel—what other features, `core`, or the app host may import.
   - **Layer barrels** (`domain/`, `application/`, `infrastructure/`, and **`presentation/`** when that layer exists)—what sibling layers / the feature root may import **across** layer boundaries, per [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and (for frontend) [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md).
   - **First-class slice directories** under a **module root** (a vertical feature **or** a thin composition host such as `app/` in ADR 0016): When a subdirectory is a deliberate responsibility slice—not a throwaway folder of helpers—it defines **`index.ts`** as that slice’s curated public surface, using the **same** discipline as layer barrels. Cross-slice callers import **through** that barrel. A module may omit entire hexagonal layers (for example a host that has no `domain/`); **any slice the module defines must still be barrel-gated.** In frontend layouts, **`presentation/`** is the standard UI-facing slice: if a module contains `presentation/`, it **must** include **`presentation/index.ts`**.
   - **Nested barrels** under each immediate `infrastructure/<category>/` subdirectory (e.g. `openAi/`, `drizzle/`, `stub/`)—**required**. Every such category directory defines `index.ts` and is treated as a public/private boundary for that adapter category.

3. **Within-layer imports:** Files in the same layer may import **private** siblings via relative paths without going through every intermediate barrel; barrels primarily govern **cross-layer** and **cross-feature** (and **cross-package**) visibility, per ADR 0007.

4. **Tests:** Prefer importing **concrete modules** in tests (`…/application/Foo`, `…/domain/types`, …) unless the test is **explicitly** asserting the barrel surface. That keeps dependency graphs honest and prevents barrels from becoming discovery indexes.

5. **Healthy public surfaces:** If a barrel (any level) exports a **large** grab-bag of symbols, the boundary is weak—prefer **narrowing** what is public or **splitting** responsibilities before adding more re-exports.

### Consequences

- Good, because **nested infrastructure** can hide vendor cruft while keeping adapters/factories discoverable.
- Good, because the **same rule** applies at every level: public vs. private, not “barrels everywhere” or “never.”
- Bad, because **judgment** is required for “reasonable boundary”; reviewers use PR discussion when unclear.
- Bad, because **deep barrel chains** can complicate navigation—mitigate by keeping exports **small** and using **go to definition** on the concrete implementation.

### Confirmation

- **Review:** PRs respect barrel intent (no gratuitous exports; cross-layer/cross-feature imports go through the right barrel).
- **Automation:** Where ESLint boundary rules exist, they should align with this ADR and [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md).
- **Checklist:** local review guidance stays aligned.

## Pros and Cons of the Options

### Barrels only at package/feature root

- Good, because the tree stays flat.
- Bad, because large vendor folders lose **internal** encapsulation unless lint substitutes for barrels.

### Barrels everywhere

- Good, because every folder looks the same.
- Bad, because **empty or pass-through** barrels add noise for small trees.

### Boundary-based barrels (chosen)

- Good, because **depth matches actual encapsulation** needs.
- Bad, because it requires **consistent judgment**.

## More Information

- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — feature modules, layer barrels, infrastructure categories.
- [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md) — frontend responsibility areas, `presentation/`, and composition hosts (`app/`) with non-hexagonal slice sets.
- Repository-local illustration: `org/docs/adr/examples/feature-module-layout-example.md`.
