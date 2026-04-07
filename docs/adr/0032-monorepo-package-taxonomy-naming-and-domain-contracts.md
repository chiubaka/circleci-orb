---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
consulted: -
informed: -
---

# ADR 0032: Monorepo package taxonomy, naming, and domain vs contract packages

## Context and Problem Statement

Multi-package monorepos need a **repeatable standard** for:

- **Where** major concerns live (backend API surface, plugins, integrations, shared domain, wire contracts, frontend core, presentation bindings).
- **How** those packages are **named** so dependencies read clearly in `package.json` and import graphs.
- **When** to use the **full** library-oriented split versus a **collapsed** layout common in product application repos.

A recurring tension drove much of this work: a single package named `schemas` (or similar) holding **all** Zod schemas and inferred types. That blurs questions that actually matter:

- Are these schemas **domain** concepts or **transport** contracts?
- Should the frontend depend on a package whose name implies “everything serialized,” including API-only DTOs?
- How do we avoid mixing **ubiquitous language** with **wire formats**?

**Questions this ADR answers:**

1. What **directory layout** and **npm package naming** should we standardize for **library** monorepos (reusable platform or SDK style) and how do **application** monorepos simplify that?
2. What belongs in **`@<scope>/domain`** versus **`@<scope>/contracts/*`**, and how does that replace ambiguous **`schemas`** packages?

Exact scope strings (`@protectiva/…`, `@l3xo/…`) are **illustrative**; the **invariants** are roles, dependency direction, and naming patterns.

## Relationship to existing org ADRs

- **Per-feature layout** in [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md) uses **slice-local** `domain/`, `application/`, `infrastructure/` (and `presentation/` on the client). Workspace packages in **this ADR** are the **cross-cutting** mirror: shared **`packages/domain`** aligns in **role** with slice **`domain/`** (ubiquitous concepts), but lives at **repo** scope when multiple deployables need the same vocabulary.
- **Feature-local `core/`** in ADR 0007 (the small shared kernel **inside** a package) is **not** the same thing as **`packages/backend/core`** below—the latter names a **publishable** “main backend API” library for SDK-style repos.
- **Zod** at trust boundaries stays the org choice per [ADR 0002](0002-zod-for-runtime-json-validation.md); **contracts** and **domain** may both use Zod—**which package owns the schema** follows the rules in this ADR.
- **Imports and barrels:** [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md), [ADR 0008](0008-barrel-files-public-api-boundaries.md), [ADR 0018](0018-index-barrels-re-export-only.md).
- **Orchestration:** [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md), [ADR 0013](0013-use-of-classes-vs-module-level-functions-and-interfaces.md).
- **Frontend layout** (`frontend/core` vs `frontend/react`) and relationship to ADR 0016: [ADR 0033](0033-frontend-package-split-application-of-adr-0032-and-adr-0016.md).
- **Monorepo tooling** (pnpm, Turborepo): [ADR 0022](0022-standardize-monorepos-to-pnpm-turbo.md).

### Alignment with ADR 0007 (feature `domain/` vs workspace packages)

Feature **`domain/`** holds **transport-agnostic** shapes for that slice. **HTTP/RPC-only** DTOs belong in **`@<scope>/contracts/*`**, not in slice **`domain/`**, per the clarification in ADR 0007 that references this ADR.

## Decision Drivers

- One **mental model** for library SDK repos and for product app repos (with documented **collapse** rules).
- **Clear names** that signal intent (`domain`, `contracts`, `plugin`, `integration`, `frontend`, `react`).
- **Separation** of environment-agnostic APIs from **plugins** (specific infra) and **integrations** (specific host/framework glue).
- **Thin** shared **domain** package: full-stack shared **vocabulary**, without smuggling backend-only or frontend-only concerns across the boundary.
- **Contracts** own **wire** shapes (including REST builders such as **ts-rest**), ending the “single `schemas` package” anti-pattern.
- Compatibility with **vertical slices** and **hexagonal** direction from ADR 0007/0016.

## Standard taxonomy: library-oriented monorepos

Library-oriented monorepos ship **reusable** backends and frontends (for example a platform other products integrate). Use **distinct packages** for each role below unless a documented exception collapses them (see **Application-oriented simplifications**).

### Backend

| Path (illustrative) | Role | Typical npm name (illustrative) |
|---------------------|------|--------------------------------|
| `packages/backend/core` | **Core backend API** — ports, facades, and behavior **agnostic** of deployment environment (web server vs CLI) and **agnostic** of specific databases or vendors. | `@<product>/<product>` (e.g. `@protectiva/protectiva`) |
| `packages/backend/plugins/*` | **Plugins** — implementations of core ports for **specific** infrastructure choices (Drizzle + Postgres, SuperTokens, …). | `@<scope>/plugin-<name>` (e.g. `@protectiva/plugin-drizzle-postgres`, `@protectiva/plugin-supertokens`) |
| `packages/backend/integrations/*` | **Integrations** — **wiring** for a **specific backend environment or framework** (not “a database,” but “how this API is exposed in Hono,” etc.). | `@<scope>/<integration-name>` (e.g. `@protectiva/hono-rest`) |

**Dependency direction (intended):** integrations and plugins **depend on** core (and often on **contracts** where the integration exposes HTTP). Core **must not** depend on plugins or integrations.

### Shared cross-stack

| Path | Role | Typical npm name |
|------|------|------------------|
| `packages/domain` | **Shared domain** — core **typings and concepts** used by **both** frontend and backend. **Intentionally thin.** Mirrors the **semantic role** of slice **`domain/`** in ADR 0007/0016, but for **cross-cutting** concepts that are not owned by a single vertical slice. **No** API-only or transport-only DTOs; **no** dumping ground for “backend types the frontend should not see” or the reverse—leave room for each side to extend in its own packages. | `@<scope>/domain` |
| `packages/contracts/*` | **Contracts** — how data and remote APIs are expressed **on the wire** (REST with **ts-rest**, GraphQL shapes validated at boundaries, etc.). Owns **transport-specific** DTOs, request/response envelopes, pagination, and endpoint-scoped payloads. | `@<scope>/<contract-name>` (e.g. `@protectiva/rest-api`) |

This split is the **canonical answer** to replacing a monolithic **`schemas`** package: **domain vocabulary** vs **wire contracts**, not “types vs schemas.”

### Frontend

| Path | Role | Typical npm name |
|------|------|------------------|
| `packages/frontend/core` | **Core frontend API** — environment- and presentation-agnostic **client** surface (ports, facades, orchestration entry points). Often **parallels** the backend core API in spirit but **must not** over-assume REST vs local storage vs other transports at the type level. | `@<scope>/frontend` (e.g. `@protectiva/frontend`) |
| `packages/frontend/plugins/*` | **Plugins** — concrete implementations of frontend core ports (Expo Secure Store, REST client bindings, …). | `@<scope>/frontend-plugin-<name>` (e.g. `@protectiva/frontend-plugin-expo-secure-store`, `@protectiva/frontend-plugin-rest`) |
| `packages/frontend/react` | **React binding** — components, hooks, providers, and wrappers making the **frontend core** idiomatic in **React**. | `@<scope>/react` (e.g. `@protectiva/react`) |

**Future (optional, same pattern):** `packages/frontend/react-native`, `packages/frontend/react-web` for integration that does not belong in the shared `react` package.

**Dependency direction:** `react` → `frontend` core → `domain` (types) as needed; **contracts** only where the client implements a **network** boundary (often via a **plugin**).

### Apps (all monorepo flavors)

| Path | Role |
|------|------|
| `apps/*` | **Deployable, thin** compositions: wire env/config, pick plugins, mount integrations. Examples: `apps/web` (`@l3xo/web`), `apps/server` (`@l3xo/server`). |

Apps **should stay thin**: they integrate **packages**, not duplicate **domain** or **contract** ownership.

## Application-oriented simplifications

Product repos that ship **one** known stack often **collapse** the library taxonomy—**by design**, not by accident.

### Backend

- The split **`packages/backend/core`** vs **`packages/backend/plugins/*`** vs **`packages/backend/integrations/*`** is often **unnecessary** when the product picks **one** database, **one** auth stack, and **one** server framework.
- **Common pattern:** a single **`packages/backend`** (or similarly named) exports the **default** composition: feature modules per ADR 0007, **internal** adapter swap points (composition root) without publishing every adapter as a separate npm package for external consumers.
- **Integration** code that would live in **`packages/backend/integrations/hono-rest`** in a library repo often moves to **`apps/server`** (or equivalent): the **app** is the Hono (or Express, etc.) **host** that wires the backend package to HTTP.

### Frontend

- **`packages/frontend/core`** usually **remains** distinct from **`packages/frontend/react`** (presentation-agnostic client API vs React bindings) — that separation stays valuable.
- **`packages/frontend/plugins/*`** may **collapse** into **`packages/frontend/core`** or **`packages/frontend/react`** when there is no need to ship **swappable** client adapters as separate published packages.

### What rarely collapses

- **`packages/domain`** and **`packages/contracts/*`** remain valuable **even in app repos** whenever web and server share types and the team wants a **hard** boundary between **ubiquitous language** and **wire** shapes.

## Domain package: content rules

**Purpose:** Cross-stack **ubiquitous** concepts (entities, value objects, enums, primitives) that **mean the same thing** in UI and model.

**Allowed:**

- Types and, where useful, Zod schemas for **true domain** concepts with `z.infer` per ADR 0002.
- Shared **vocabulary** that is not inherently tied to HTTP or a particular client store.

**Disallowed:**

- Request/response-only shapes, pagination envelopes, and endpoint-specific DTOs → **`contracts`**.
- Backend-only persistence DTOs or frontend-only view models → **keep** in the relevant **slice** or **`backend`/`frontend`** packages, not in **`@<scope>/domain`**, unless promoted deliberately as shared language.

**Key rule:**

> Put a schema in **`@<scope>/domain`** only if the concept exists **independently** of any API or transport.

## Contracts packages: content rules

**Purpose:** **Wire** and **API** contracts—how bits cross the network or process boundary.

**Owns:**

- REST/GraphQL/ts-rest (or equivalent) **route contracts**, request and response bodies, error envelopes, and validation schemas for those payloads.
- External integration message shapes.

**Key rule:**

> If a schema exists **because** of an API or message format, it belongs in **`contracts`**, not **`domain`**.

Contracts may **compose** domain types (for example `z.array(ConversationSchema)` imported from `@<scope>/domain`).

## Considered Options

- **Flat `packages/*`** without backend/frontend/domain roles — rejected: poor discoverability for large platforms.
- **Single `schemas` package** for all Zod — rejected: mixes domain and transport (see Context).
- **Separate `types` and `schemas` packages** — rejected: wrong axis; the split is **domain vs contract**, not static vs runtime.
- **Library taxonomy + optional app collapse + explicit `domain` / `contracts`** (chosen).

## Decision Outcome

**Chosen option:** Standardize the **library-oriented** package taxonomy (**backend core**, **backend plugins**, **backend integrations**, **`domain`**, **`contracts/*`**, **frontend core**, **frontend plugins**, **frontend/react**), use **application-oriented collapses** where publishable boundaries are unnecessary, place **deployables** in **`apps/*`**, and **canonicalize** **`@<scope>/domain`** vs **`@<scope>/contracts/*`** as the replacement for ambiguous **`schemas`** packages.

**Justification:** One org-wide pattern scales from SDK-style repos to single-product monorepos, keeps hexagonal intent visible at **package** granularity, and makes dependency graphs self-explanatory.

### Consequences

- Good, because engineers and agents can **map** a repo to a **known** shape quickly.
- Good, because **plugins** vs **integrations** vs **core** responsibilities stay distinct.
- Good, because **domain** vs **contracts** ends the **`schemas`** ambiguity.
- Bad, because **more packages** in library repos mean more `package.json` and versioning ceremony ([ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) may apply).
- Bad, because **collapse** decisions need explicit judgment so app repos do not accidentally mix **wire** into **domain**.

### Confirmation

- **Review:** New wire-only DTOs land under **`contracts`**; ubiquitous concepts land under **`domain`** or slice **`domain/`** when not shared.
- **Naming:** Package names match **role** (e.g. `plugin-*`, `frontend-plugin-*`, or documented repo convention).
- **Apps:** `apps/*` remain **thin** relative to `packages/*`.

## Illustrative end-to-end sketch

**Domain (shared):**

```ts
// packages/domain/conversation/Conversation.ts
export const ConversationSchema = z.object({
  id: z.string(),
  language: z.string(),
  createdAt: z.string(),
});
export type Conversation = z.infer<typeof ConversationSchema>;
```

**Contracts (REST):**

```ts
// packages/contracts/rest-api/conversation/ListConversationsResponse.ts
import { ConversationSchema } from "@scope/domain/conversation/Conversation";

export const ListConversationsResponseSchema = z.object({
  conversations: z.array(ConversationSchema),
  nextCursor: z.string().nullable(),
});
```

**Backend core** returns **domain** objects from use cases; **integrations** map to/from **contract** shapes at the HTTP edge.

**Frontend:** Prefer **`@scope/domain`** types in UI; **`@scope/contracts/*`** only inside **infrastructure** / **plugin** code that performs HTTP—aligned with ADR 0016’s infrastructure role and [ADR 0033](0033-frontend-package-split-application-of-adr-0032-and-adr-0016.md).

## Pros and Cons of the Options

### Monolithic `schemas` (rejected)

- Bad, because domain and API concerns mix; frontend dependency semantics are wrong.

### Library taxonomy with explicit roles (chosen)

- Good, because aligns with hexagonal and multi-package scaling.
- Neutral, because requires discipline when **collapsing** for app repos.

## More information

- Frontend package split + ADR 0016: [ADR 0033](0033-frontend-package-split-application-of-adr-0032-and-adr-0016.md).
- Feature module layout example: `org/docs/adr/examples/feature-module-layout-example.md`.
