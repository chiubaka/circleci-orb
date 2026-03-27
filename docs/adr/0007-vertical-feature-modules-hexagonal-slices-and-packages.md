---
status: accepted
date: 2026-03-26
decision-makers: Daniel Chiu
---

# ADR 0007: Vertical feature modules, hexagonal slices, packages, and core

## Context and Problem Statement

As the codebase grows, a **single** horizontal layout (one global `domain/`, `application/`, `infrastructure/`) makes related code harder to find and encourages large “catch-all” folders. We want:

- **Vertical slicing** by **feature** (bounded areas of capability), each shaped like its own **module**—**similar to how NestJS organizes modules** (feature-scoped colocation), with boundaries expressed in this repo via **folders and barrels** (see below), not via a requirement to use any particular framework.
- A **clear public surface** per module so internals stay private.
- **Per-slice hexagonal layering** and **DDD-friendly naming** (see historical [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md)): dependency direction remains obvious inside each slice.
- **Transport-agnostic** modeling so the core product logic does not assume an HTTP server, while still shipping a server app.
- A **minimal shared kernel** for vocabulary that truly spans the whole application.
- **Acyclic dependencies** between modules; no deep imports of another module’s internals.

This ADR **supersedes** [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md) for **how and where** layers are laid out in the repo. The **substantive** outcomes of ADR 0001—hexagonal dependency direction, DDD naming (`*Service`, `*Repository`, …)—remain in force; what changes is **decomposition**: layers are **per feature module**, and **packages** express major boundaries.

## Decision Drivers

- **Locality:** Everything for one capability should be easy to locate and evolve together.
- **Encapsulation:** Only a deliberate **public API** crosses module boundaries; everything else is private to the slice.
- **Enforceability:** Prefer **lint** (or equivalent) to enforce import rules, not convention alone.
- **Hexagonal direction:** `domain/` does not depend on `infrastructure/`; application orchestration depends on **abstractions**, not concrete adapters.
- **Deployment vs. model:** Modeling and use cases should not assume HTTP; server/framework code stays at the **edges**.
- **Shared kernel discipline:** Avoid a growing “misc” shared folder; only place stable, ubiquitous model elements in `core` when need is obvious.
- **Pragmatism:** Do not over-engineer cross-slice orchestration until real workflows force a design.

## Considered Options

- **Retain only horizontal layers** at app or single-package root (status quo before this ADR).
- **Vertical slices without packages:** feature folders inside one package only.
- **Vertical slices + package boundaries:** transport-agnostic backend package (and optional tiny `core` package), thin server host app for HTTP and composition.
- **Framework-owned modular structure** (e.g. NestJS `@Module()` as the single source of truth for slice boundaries).

## Decision Outcome

**Chosen option: vertical feature modules (organization **analogous to NestJS feature modules** for familiarity), per-slice `domain/` / `application/` / `infrastructure/`, **barrel public APIs at the feature root and within each layer**, infrastructure subdirectories by implementation category, sparing `core`, backend vs. server app packages, composition at the server edge.**

**Justification:** It preserves hexagonal intent and DDD naming while scaling structure with product complexity. Packages make “no server assumptions” real; `core` stays small if we gate membership strictly. Slice boundaries are **explicit in the codebase** (directories + exports + lint), which fits transport-agnostic packages and keeps the layout easy to compare—for those who know Nest—to **feature modules** without requiring Nest as the runtime structure.

### Module shape (feature slice)

Each **feature module** is a directory tree with:

- **`domain/`** — entities, value objects, invariants, and **pure** operations on them where appropriate. No orchestration of external systems; no imports from `infrastructure/`.
- **`application/`** — use cases and workflows that **orchestrate** domain constructs and **ports** (interfaces / abstractions implemented elsewhere). Concrete **application services** live here when they compose only domain + these abstractions—not concrete vendor types.
- **`infrastructure/`** — **implementations** of `application/` contracts (and adapter-specific types). Organize with **one subdirectory per implementation category**. **Vendor** is one axis (e.g. `openAi/`, `drizzle/`); other categories include **non-vendor** buckets such as `stub/`, in-memory fakes, or `dev/`—whatever keeps the tree honest and reviewable.

**Layer barrels (within each feature module):** `domain/`, `application/`, and `infrastructure/` each have their own **`index.ts`** barrel. Each barrel re-exports **only** that layer’s **public** surface; everything else in that directory tree is **private** to the layer.

- **Consumption rule:** A **sibling layer** (or the feature root) should depend on a layer **through that layer’s barrel** (e.g. `application/` imports from the `domain/` barrel—not from deep paths under `domain/…`) wherever dependency rules allow. **Files inside the same layer** may still use direct relative imports between **private** implementation files; barrels gate what is **visible across layers** (and the feature root aggregates what leaves the feature). **Prefer lint rules** to block **cross-layer** deep imports that skip a layer barrel, in addition to enforcing hexagonal direction (e.g. `domain/` must not import `application/` or `infrastructure/`).
- The **feature** still has a **root** `index.ts` that re-exports **only** what **other** features, `core`, or the app host may import (facades, stable types, port interfaces when another compilation unit must supply an implementation).

Treat all non-exported files in any layer as **private**. **Prefer lint** (e.g. `eslint-plugin-boundaries`, `import/no-restricted-paths`, or Nx-style tags if adopted) so:

- consumers outside the feature cannot reach into `**/my-feature/...` internals without going through the **feature barrel**; and
- callers do not bypass **layer** barrels inside the feature without a deliberate exception.

**Required barrels under `infrastructure/<category>/`:** Every immediate subdirectory under `infrastructure/` (for example `openAi/`, `drizzle/`, `stub/`, `llm/`) defines its own **`index.ts`** barrel. This keeps adapter categories explicit and gives a stable import boundary for callers and tests. **Non-exported** files in that category stay **private** to the category subtree. Keep each barrel’s exports **small** so the boundary stays honest. See [ADR 0008](0008-barrel-files-public-api-boundaries.md) for the cross-cutting rule.

**Cross-module imports:** Depend on another feature **only** through its **barrel** (or through a shared **`core`** export). Maintain a **directed acyclic graph** of module dependencies; cycles are not allowed.

**Cross-slice orchestration** (workflows that stitch multiple features): **deferred** until a concrete case appears. When it does, prefer a dedicated integration story that uses **only** peer barrels (or document a narrow exception). Do not reach into two modules’ internals from ad hoc glue code.

### Clarification: top-level feature boundaries

When a service contract or adapter grows into a distinct capability area, prefer promoting it to its **own top-level feature module** instead of expanding `shared/` folders.

Within a feature:

- Put business/request/value shapes in `domain/` (for example `chat/domain/ChatRequest`).
- Keep `application/` focused on use-case orchestration and explicit abstractions (for example a narrow `ConceptExtractor` port file).
- Group related adapter implementations under one technology bucket when that improves scanability (for example `masteryEvaluation/infrastructure/llm/...` with subfolders by concern).

### `core` (shared domain kernel)

Use a dedicated **`core`** area (name reserved for this role) for the **smallest** set of **shared domain model** pieces that the **entire** application needs (e.g. ubiquitous vocabulary, IDs, stable value objects). **Most** code does **not** live here until it is **obvious** that multiple feature modules require the same concept and duplication would be wrong.

`core` is **not** a dumping ground for helpers or convenience types.

### Packages and server app

- **Transport-agnostic product logic** (feature modules, integration/orchestration that is not HTTP-specific) should live in a **workspace package** (exact package name may vary; the decision is the **boundary**). That code **must not** assume it runs inside an HTTP server.
- A **server host app** (or equivalent) remains a **thin** host: composition, env/config wiring, HTTP stack, and mapping requests to calls into the backend package’s **public** API.
- Any HTTP framework is an **infrastructure/detail** of the server app and is **not** a dependency of the transport-agnostic backend package.

A **separate** tiny package (for example `@scope/core`) is **optional** but recommended when **`core`** should stay minimal and **backend** would otherwise mix “kernel” with “features.” If both exist: the core package holds only the kernel; the backend package holds feature modules and may depend on core. The server app depends on backend (and core if needed); backend/core packages must not depend on the server app.

### Relationship to NestJS-style layout

For readers familiar with NestJS, **feature modules** here are organized in a **similar** way: capability grouped in one place with a clear boundary. In this repository, those boundaries are made concrete with **directory layout**, **layer and feature barrels**, and **lint** (where configured)—rather than prescribing NestJS itself for that grouping.

### Consequences

- Good, because **feature work** is **local** and review diffs stay scoped.
- Good, because **hexagonal rules** apply **per slice**, reducing “infrastructure junk drawers” at a single global level.
- Good, because **packages** make **transport-agnostic** modeling and testing easier.
- Good, because **`core`** stays **small** if we enforce a **high bar** for inclusion.
- Bad, because **lint/tooling** for module boundaries requires setup and ongoing maintenance.
- Bad, because **shared** concepts need **explicit** home (`core`) or **duplicate** until the second use case is clear—judgment required.
- Bad, because **cross-feature** stories need **care** once orchestration appears (intentionally unprescribed until then).

### Confirmation

- **Review:** PRs check import direction within a slice (`domain` → no `infrastructure`; `application` → no concrete `infrastructure` vendor imports for orchestration), **intra-feature** imports that respect **layer barrels**, and **cross-feature** imports **only** from feature barrels or `core`.
- **Automation:** Add or extend ESLint (or monorepo boundary tooling) to enforce **public vs. private** surfaces at **feature**, **layer**, and (where adopted) **infrastructure category** scope; track gaps in review if rules are not yet in place.
- **Build health:** Continue `pnpm build`, `pnpm lint`, `pnpm test` for regressions.
- **Checklist:** local review guidance should stay aligned with this ADR’s boundaries.

## Pros and Cons of the Options

### Horizontal layers only

- Good, because one global map of “all domain” is simple at small size.
- Bad, because it does not scale as features and infrastructure variants multiply.

### Vertical slices, single package

- Good, because locality improves without package ceremony.
- Bad, because **server vs. model** boundaries are easier to violate without a package wall.

### Vertical slices + packages + `core` (chosen)

- Good, because it matches **hexagonal + DDD** intent with enforceable **edges**.
- Bad, because more **moving parts** (feature + **layer** barrels, `package.json`, lint graphs).

### Framework-owned modular structure (e.g. Nest `@Module()` as sole boundary definition)

- Good, because tooling and docs are mature for teams already all-in on that stack.
- Bad, because this repo standardizes **transport-agnostic** packages and **explicit** folder/barrel boundaries independent of a single web framework’s module graph.

## More Information

- [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md) — **superseded** by this ADR for layout; retained for history and for the original DDD naming rationale.
- [ADR 0005](0005-composition-roots-and-wiring-boundaries.md) — composition roots at **edges**; applies to server host apps wiring backend packages to HTTP adapters.
- [ADR 0006](0006-consistency-and-extension-for-new-features.md) — extend features by **matching idioms** within this structure unless an exception is documented.
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — barrel files as **public API** at package, feature, layer, and optional nested scopes.
- Repository-local examples: `org/docs/adr/examples/feature-module-layout-example.md` and `org/docs/adr/examples/composition-root-example.md`.
