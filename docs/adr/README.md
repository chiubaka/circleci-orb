# Org ADR Documentation

This subtree stores org-level architecture and engineering conventions that may be mirrored into multiple repositories.

## ADR locations and scope

- Org-level ADRs live here: `org/docs/adr/`.
- Repo-level ADRs live in each repository under `docs/adr/`.
- Package-level ADRs live in the package itself (for example, `<package>/docs/adr/`).

Keep each decision at the narrowest level that still reflects who should follow it.

## Current org-level ADR set in this repo

- `0001-hexagonal-architecture-with-ddd-naming.md` (historical/superseded context for layout evolution)
- `0006-zod-for-runtime-json-validation.md`
- `0007-agent-skills-canonical-location-and-symlinks.md`
- `0008-self-documenting-code-and-documentation-expectations.md`
- `0009-composition-roots-and-wiring-boundaries.md`
- `0010-consistency-and-extension-for-new-features.md`
- `0011-vertical-feature-modules-hexagonal-slices-and-packages.md`
- `0012-barrel-files-public-api-boundaries.md`
- `0013-prefer-small-focused-files.md`
- `0014-import-specifier-conventions-for-monorepo-packages.md`
- `0015-test-import-alias-hash-root.md`
- `0016-classes-as-primary-responsibility-boundaries.md`
- `0017-use-of-classes-vs-module-level-functions-and-interfaces.md`

See [`AGENTS.md`](../../../AGENTS.md) for concise agent-facing pointers to these ADRs.

## ADR template

Copy `org/docs/adr/template.md` into a new numbered file and fill in the placeholders.

At minimum, an ADR should include:

- `status`
- `Context and Problem Statement`
- `Decision Drivers`
- `Considered Options`
- `Decision Outcome`
- `Consequences`

## Guidance for updates

Before adding a new ADR:

1. Check whether a similar org-level decision already exists in `org/docs/adr/`.
2. If the decision is repository-specific, place it in that repo’s `docs/adr/`.
3. If the decision is package-specific, place it in that package’s `docs/adr/`.
4. Copy the template and keep the scope tight: one decision per ADR.

