---
status: accepted
date: 2026-06-08
decision-makers: Midana engineering
---

# Domain temporal values as canonical ISO strings

## Context and Problem Statement

Domain entities and value objects often carry calendar dates and instants (issue dates, audit timestamps, redemption events, draw-period boundaries). Runtime types such as `Date`, epoch numbers, and ORM/driver timestamps are convenient for manipulation but are poor canonical domain representations: they are mutable or ambiguous, do not round-trip through JSON unchanged, and tempt persistence or transport concerns to leak into `domain/` and shared cross-stack types.

How should repositories model temporal fields on domain entities while still supporting comparison, normalization, and calendar-aware business rules?

## Decision Drivers

- Keep **domain** and shared cross-stack types **serialization-stable** and free of environment-specific runtime objects.
- Preserve a clear boundary between **ubiquitous language** (domain) and **wire contracts** (HTTP/GraphQL payloads) per ADR 0032.
- Support **comparison and ordering** without scattering ad hoc parsing in application services.
- Allow **infrastructure mappers** to convert from database/driver types at explicit boundaries.
- Keep temporal validation at **trust boundaries** (Zod or equivalent) per ADR 0002.

## Considered Options

- `Date` (or equivalent runtime instant objects) on domain entity fields
- Epoch `number` (milliseconds or seconds) on domain entity fields
- **Canonical ISO string aliases** on domain entity fields, with shared helpers for manipulation
- Rich immutable value-object classes wrapping an internal representation (for example Temporal or a calendar library type)

## Decision Outcome

Chosen option: **canonical ISO string aliases on domain entity fields, with shared helpers for manipulation**.

Justification: ISO strings are the natural serialized form for JSON and common RPC `DateTime` scalars, remain portable across backend and client packages, and avoid mutability and timezone surprises from runtime date objects in domain typings. Comparison and calendar logic belong in small, testable helper modules that parse to a convenient internal representation, operate, and serialize back to the canonical form when needed.

### Consequences

- Good, because domain types stay stable across persistence, GraphQL/REST JSON, logs, and tests.
- Good, because infrastructure adapters own `Date`/driver conversions in `toDomain` / `fromDomain` mappers rather than exposing them on public entity shapes.
- Good, because lexicographic ordering works when contributors enforce canonical formats (see below).
- Bad, because invalid or non-canonical strings are possible without validation at boundaries.
- Bad, because contributors must use shared helpers for non-trivial calendar math instead of inline `new Date(...)`.

### Confirmation

- Code review checks that new domain temporal fields use the project’s canonical aliases (not `Date` or bare `string` without documented meaning).
- Repository and API boundary code validates and normalizes inbound values before application logic consumes them.
- Temporal helpers that implement draw-period, timezone, or calendar rules have focused unit tests; reviewers treat new ad hoc parsing in services as a smell.

## Pros and Cons of the Options

### `Date` on domain fields

- Good, because comparison and arithmetic are familiar in application code.
- Bad, because objects are mutable and environment-specific.
- Bad, because JSON serialization does not preserve `Date` semantics without extra revival logic.
- Bad, because it blurs domain and ORM/runtime boundaries.

### Epoch `number` on domain fields

- Good, because ordering and storage are compact.
- Bad, because seconds vs milliseconds ambiguity is a recurring footgun.
- Bad, because calendar-date concepts (issue date, period end) lose meaning as plain instants.
- Bad, because wire formats and GraphQL `DateTime` scalars are typically ISO strings, not epochs.

### Canonical ISO string aliases (chosen)

- Good, because values are immutable, JSON-native, and portable across packages.
- Good, because domain stays free of vendor ORM and JavaScript runtime types.
- Good, because mappers normalize once at ingress and egress.
- Neutral, because parsing cost is negligible at typical request and batch sizes when helpers are used judiciously.
- Bad, because teams must define and document canonical formats and supply comparison/normalization helpers.

### Rich value-object classes

- Good, because behavior and invariants can live with the type.
- Good, because representation can be hidden entirely.
- Bad, because heavier to adopt cross-stack and may pull calendar-library dependencies into shared domain packages prematurely.
- Bad, because serialization and mapper boilerplate increase until a clear shared library exists.

## Canonical formats and placement

Repositories adopting this decision should define two portable aliases (names may vary):

| Alias         | Meaning                                                  | Canonical format                                                  |
| ------------- | -------------------------------------------------------- | ----------------------------------------------------------------- |
| **Date-only** | Calendar date without a meaningful time-of-day component | ISO 8601 date: `YYYY-MM-DD`                                       |
| **Date-time** | UTC instant                                              | ISO 8601 UTC with `Z` suffix (for example `2019-12-03T09:54:33Z`) |

**Field choice:** use date-only for business calendar dates (invoice issue date, draw-period end stored as a period boundary); use date-time for audit timestamps and redemption events.

**Where types live:** in shared `domain` or feature-slice `domain/` modules—not in wire-only contract packages.

**Where manipulation lives:** in focused helper modules (feature-local or shared core utilities), not inlined across application services. Helpers may parse to an internal runtime or calendar-library type, perform the operation, and return canonical ISO strings when the result is part of domain state.

**Where validation lives:** at trust boundaries (HTTP/GraphQL resolvers, repository `toDomain`, external API clients) using runtime schemas per ADR 0002.

**Where sorting/filtering at scale belongs:** prefer the database (`ORDER BY`, range predicates) when listing large sets; use in-memory helpers for single-entity normalization or small bounded collections.

## More Information

- Related: ADR 0002 (runtime JSON validation), ADR 0007 (domain vs infrastructure), ADR 0013 (`toDomain` / `fromDomain` naming), ADR 0032 (domain vs contracts).
- Repositories may introduce branded types or Zod schemas atop the aliases when stricter assignability is warranted.
- Value-object wrappers remain a valid follow-up if temporal behavior grows beyond what helpers comfortably express.
