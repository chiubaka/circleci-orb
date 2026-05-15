---
status: accepted
date: 2026-03-31
decision-makers: Daniel Chiu
---

# ADR 0021: Code-first Drizzle schema and migrations

## Context and Problem Statement

Repositories that adopt Drizzle-backed persistence need a consistent way to define schema, generate migrations, and keep ownership aligned with feature adapters. A common failure mode is to centralize all table definitions in a generic persistence area while also maintaining a separate bootstrap SQL path for local setup, which splits the source of truth and weakens feature locality.

## Decision Drivers

- Keep feature-owned schema close to feature-owned Drizzle adapters.
- Maintain one source of truth for database structure.
- Use checked-in, reviewable migrations for local and deployed environments.
- Preserve a simple local development workflow where possible.
- Keep shared Drizzle code concrete and honestly named.

## Considered Options

- Keep a generic top-level persistence slice plus a hand-maintained bootstrap SQL file.
- Keep a top-level Drizzle schema entrypoint but switch setup to Drizzle migrations.
- Split schema into feature-local Drizzle files and manage checked-in migrations with `drizzle-kit`.

## Decision Outcome

Chosen option: split schema into feature-local Drizzle files and manage checked-in migrations with `drizzle-kit`.

Justification: Feature-local schema keeps ownership and review locality aligned with vertical module structure, while `drizzle-kit` provides a code-first workflow with checked-in SQL migrations. This keeps schema and migration history derived from the same codebase instead of maintaining a second manual bootstrap path.

### Consequences

- Good, because each feature keeps its Drizzle schema next to the concrete repositories and adapters that use it.
- Good, because the checked-in migration directory becomes the canonical migration history.
- Good, because local startup and deployed environments can apply the same migration history.
- Good, because duplicate bootstrap SQL workflows can be removed.
- Bad, because migration generation depends on `drizzle-kit` configuration and committed snapshot metadata.
- Bad, because a shared Drizzle slice may still exist and must stay narrow and concrete.

### Confirmation

- Schema files live with the feature adapters that own them, typically under a path such as `src/<feature>/infrastructure/drizzle/schema.ts`.
- Shared Drizzle helpers, connection setup, or common types live under an explicit shared vendor slice such as `src/infrastructure/drizzle/`.
- Migrations are generated and committed from `drizzle-kit`, rather than maintained separately as hand-written bootstrap SQL for routine local setup.
- Local and deployed environments apply the same checked-in migration history.
- Repository reviews confirm the schema source of truth remains code-first and feature-local.

## Pros and Cons of the Options

### Generic persistence slice plus bootstrap SQL

- Good, because it is simple to sketch initially.
- Good, because startup can apply a single SQL file without extra tooling.
- Bad, because it duplicates schema in code and SQL and makes imports read more abstract than they are.
- Bad, because feature-local schema ownership is lost.

### Top-level Drizzle schema entrypoint plus Drizzle migrations

- Good, because it replaces bootstrap SQL with checked-in migrations.
- Good, because there is a single Drizzle schema entrypoint.
- Bad, because schema ownership remains centralized instead of colocated with the feature adapters.

### Feature-local Drizzle schema plus `drizzle-kit` migrations (chosen)

- Good, because the code structure and schema structure line up with feature ownership.
- Good, because the migration workflow is code-first and reviewable.
- Bad, because tooling must read multiple schema files and contributors must learn the repository or package workflow.

## More Information

- [ADR 0019](0019-vendor-specific-infrastructure-slices.md) covers the shared `infrastructure/<vendor>` pattern that Drizzle implementations should follow.
- [ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md) covers production migration execution strategy once migrations are part of the repository.
- [ADR 0038](0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) covers coordinated release pin sets; ordering when migrations and application artifacts roll out together is owned by the repository’s canonical deploy implementation ([ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md)).
