---
name: barrel-surface-curation
description: >-
  Keeps `index.ts` barrels as intentional public API boundaries at package,
  feature, layer, and adapter-category scope rather than broad re-export
  catalogs.
---

# Barrel surface curation

## Goal

Treat each `index.ts` barrel as a deliberate public API boundary and keep exported surfaces small, stable, and meaningful.

## Relevant org ADRs

- `org/docs/adr/0008-barrel-files-public-api-boundaries.md`
- `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`
- `org/docs/adr/0009-prefer-small-focused-files.md`

## When to use this skill

Use this skill when:

- Adding a new export to any `index.ts`.
- Creating a new feature/layer boundary.
- Introducing `infrastructure/<category>/` adapter subdirectories.
- Resolving deep-import pressure or accidental boundary leaks.

## Curation rules

1. Export only what callers are intended to depend on.
2. Keep internal helpers/private implementation files out of barrels.
3. Require barrels at:
   - Package public API (where applicable),
   - Feature root,
   - Layer roots (`domain/`, `application/`, `infrastructure/`),
   - Immediate `infrastructure/<category>/` directories.
4. Prefer concrete imports in tests unless validating the barrel surface itself.
5. If a barrel grows into a broad catalog, split responsibilities or reduce surface.

## Review questions

- Is this export needed by a real consumer at this boundary?
- Would a direct internal import violate intended encapsulation?
- Does this barrel still represent one coherent API surface?
- Is the export stable enough for cross-module/package use?

## Common mistakes to avoid

- Re-exporting everything "for convenience."
- Using barrels to bypass layer or feature boundaries.
- Forgetting `index.ts` in newly added adapter categories.
- Exposing test-only or temporary migration helpers as public API.

## Illustrative portable pattern

```text
payments/
  index.ts                  # feature public API
  domain/
    index.ts                # domain layer API
    Payment.ts
  application/
    index.ts                # use-case and port API
    ProcessPayment.ts
  infrastructure/
    index.ts                # infrastructure layer API
    stripe/
      index.ts              # adapter-category API
      StripePaymentsClient.ts
```
