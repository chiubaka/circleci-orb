---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
---

# ADR 0033: Frontend package split as an application of ADR 0032 and ADR 0016

## Context and Problem Statement

[ADR 0032](0032-monorepo-package-taxonomy-naming-and-domain-contracts.md) standardizes **monorepo package roles**, including **`packages/frontend/core`**, **`packages/frontend/react`** (and optional **`packages/frontend/plugins/*`**), **`packages/domain`**, **`packages/contracts/*`**, and thin **`apps/*`** hosts.

[ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md) standardizes **layer semantics and placement** inside a **single** client codebase: responsibility areas with per-slice **`domain/`**, **`application/`**, **`infrastructure/`**, **`presentation/`**, plus **`app/`** and **`core/`**.

When a repo adopts the **0032** frontend split, much of what ADR 0016 previously expressed **only through directory structure** is expressed **first by package boundaries**:

- **`packages/frontend/core`** is, in practice, **mostly** the **non-presentation** slice stack: **domain**, **application**, and **infrastructure** for vertical responsibility areas (aligned with [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) inside that package).
- **`packages/frontend/react`** is, in practice, **mostly** **presentation** for **parallel** vertical slices (screens, components, hooks, providers, interaction state—framework-bound).
- **`apps/*`** remain **thin** composition and integration hosts (routing, shell, wiring **core** + **react** + env), consistent with ADR 0032’s “deployable wrapper” role.

The **principles** of ADR 0016—ownership by reason to change, barrels, thin **`app/`**, high bar for **`core/`**, presentation consuming application APIs—**still apply**. What changes is that **the primary architectural seam** is often **between packages** (`core` ↔ `react` ↔ `apps`), not only **between folders** inside one `src/` tree.

**Question:** How do we apply ADR 0032 to the frontend **without** losing ADR 0016’s intent, and how should engineers and agents **navigate** repos where **package split** and **slice layers** combine?

## Relationship to ADR 0016 and ADR 0032

This ADR **extends** [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md). It does **not** replace it.

- **ADR 0032** defines **which packages exist** and **what each package is for** (taxonomy and naming).
- **ADR 0016** defines **how to layer and name code inside a client** (responsibility areas, layer roles, barrels, `app/`, `core/`, placement rules).
- **This ADR** connects the two: **where** ADR 0016’s layers live when the monorepo uses **`packages/frontend/core`** and **`packages/frontend/react`**, and **how** dependency direction and public surfaces work **across** those packages.

ADR 0016 remains the **reference for layer meaning, rules, and examples** in **monolithic** client packages. For **split** layouts, use **this ADR** plus ADR 0016 **together**: same **semantics**, **mapped** onto **core** vs **react** vs **apps**.

Related: [ADR 0008](0008-barrel-files-public-api-boundaries.md), [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md), [ADR 0018](0018-index-barrels-re-export-only.md), [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md), [ADR 0013](0013-use-of-classes-vs-module-level-functions-and-interfaces.md), [ADR 0009](0009-prefer-small-focused-files.md), [ADR 0005](0005-composition-roots-and-wiring-boundaries.md).

## Two modes of frontend layout

Repositories may use either mode; choose explicitly rather than mixing ad hoc.

### Mode A — Monolithic client package (ADR 0016 as written)

A **single** package (for example `apps/web` or `packages/web`) contains **all** layers under one `src/`: responsibility areas with **`domain/`** through **`presentation/`**, plus **`app/`** and **`core/`** as in ADR 0016.

Use when a **0032-style** `frontend/core` / `frontend/react` split is **not** needed (smaller product, or everything ships in one deployable without reusable frontend libraries).

### Mode B — Split frontend packages (ADR 0032 + ADR 0016 inside each package)

- **`packages/frontend/core`:** vertical **responsibility areas** with **`domain/`**, **`application/`**, **`infrastructure/`** (and **feature root** + **layer barrels** per ADR 0007/0016). Shared **`@<scope>/domain`** types are consumed here; **orchestration** and **ports** live here.
- **`packages/frontend/react`:** **parallel** areas with **`presentation/`** (and the same **barrel** discipline). Imports **`@scope/frontend`** (core) **through public APIs**, not deep paths—same **cross-module** rule as ADR 0016, now **across packages**.
- **`apps/*`:** **`app/`**-style composition—routes, top-level providers, shell screens, thin cross-area glue—per ADR 0016’s **`app/`** rules, adapted to the **app** being a **host** that wires published **`core`** + **`react`** packages.

**Optional `packages/frontend/plugins/*`** implement concrete **infrastructure** or client ports (for example REST) per ADR 0032; they sit at **adapters**, not in **`presentation/`**.

In **Mode B**, ADR 0016 is **not** irrelevant: it governs **folder and barrel structure inside** **`core`** and **`react`**. The **additional** seam is **package boundaries**, which often **carries** the same separation **0016** used to express **only** with directories in Mode A.

## Decision Drivers

- Apply ADR 0032 **consistently** on the frontend without inventing a second taxonomy.
- Preserve ADR 0016 **ownership**, **layer meaning**, and **export discipline** in **both** modes.
- Make **dependency direction** obvious: **`react` → `core` → shared `domain`**, not the reverse; **apps** compose published surfaces.
- Avoid duplicating **domain** or **presentation** logic across packages without clear boundaries.

## Considered Options

- **Drop slice folders** inside `frontend/core` / `frontend/react` and use flat technical folders — rejected: loses ADR 0007/0016 locality and barrels.
- **Treat ADR 0016 as obsolete** whenever ADR 0032 exists — rejected: principles remain; only **placement** changes.
- **Chosen:** **Mode A** or **Mode B** per repo; in **Mode B**, **repeat responsibility-area slices** in **`core`** (non-UI layers) and **`react`** (presentation), with **apps** as thin hosts.

## Decision Outcome

**Chosen option:** Standardize **Mode B** as **ADR 0032 frontend packages** carrying **ADR 0016 / ADR 0007 slice structure inside** `packages/frontend/core` and `packages/frontend/react`, with **`apps/*`** as the **`app/`**-style composition layer. Use **Mode A** when a single client package is sufficient.

**Justification:** Package boundaries express **presentation vs non-presentation** and **reusable client API vs React binding** at build and publish granularity; slice folders inside each package preserve **feature ownership** and **barrel-gated** visibility without contradicting ADR 0016.

### Consequences

- Good, because **architectural intent** is visible in **`package.json`** graphs as well as **folders**.
- Good, because **core** can be tested and reused with **different** presentation packages later (for example another renderer) per ADR 0032.
- Good, because ADR 0016 **rules** (barrels, `app/` thinness, `core/` bar) still apply **within** and **at the edges** of each package.
- Bad, because **two** structural axes (package **and** slice) require clear naming and review so areas stay **aligned** between **`core`** and **`react`**.
- Bad, because **cross-package** refactors are slightly heavier than moving files inside one package.

### Confirmation

- **Review:** **`presentation/`** code does not import **`@scope/contracts/*`** directly; **`core`** infrastructure (or **frontend plugins**) owns wire validation—details per ADR 0032 and ADR 0016’s **infrastructure** role.
- **Review:** **`react`** depends on **`core`** only through **documented** public exports (feature barrels / package entry), mirroring ADR 0016’s cross-module rules.
- **Lint (where configured):** Enforce allowed dependency edges **`apps` → `react` → `core`**, and **`contracts`** only under **`infrastructure`** / plugins.

## Mapping ADR 0016 concepts in Mode B (concise)

| ADR 0016 idea                 | Mode A (single package)       | Mode B (0032 split)                                                                                                                                |
| ----------------------------- | ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Responsibility area           | Top-level folder under `src/` | **Same area name** under `packages/frontend/core/src/` **and** `packages/frontend/react/src/` (presentation-only in `react`)                       |
| `domain/` … `infrastructure/` | Under each area               | **Primarily** in **`frontend/core`** (plus shared **`@<scope>/domain`** per ADR 0032)                                                              |
| `presentation/`               | Under each area               | **Primarily** in **`frontend/react`**                                                                                                              |
| `app/` host                   | `src/app/`                    | **`apps/<name>/`** (thin host: routes, global providers, cross-area shell)                                                                         |
| `core/` cross-cutting         | `src/core/`                   | **Either** a subtree of **`apps/*`**, a small shared package, or **`frontend/react`** shared presentation primitives—same **high bar** as ADR 0016 |

This table is **guidance**, not a mandate to duplicate every area in **`react`** if an area has **no** UI yet—skip **`presentation/`** until needed, consistent with ADR 0016’s judgment-based placement.

## Shared packages (`@<scope>/domain`, `@<scope>/contracts/*`)

ADR 0032 owns **what** belongs in shared **domain** vs **contracts** and **naming**. On the frontend, **`frontend/core`** is the usual home for **depending on** **`@<scope>/domain`** and for **infrastructure** that performs I/O. **`@<scope>/contracts/*`** are used at **trust boundaries** (for example HTTP clients in **`infrastructure/`**), not as the **primary** vocabulary for **`presentation/`** components—that remains **domain**-shaped data flowing through **`application`** hooks and services, per ADR 0016. **No** need to duplicate ADR 0032’s full rules here.

## More information

- Monorepo taxonomy and **`packages/frontend/*`**: [ADR 0032](0032-monorepo-package-taxonomy-naming-and-domain-contracts.md).
- Layer rules, **`app/`**, **`core/`**, and detailed examples in a **single** package: [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md).
- Vertical slices on the server: [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md).
