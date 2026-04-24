# Org ADR Documentation

This subtree stores org-level architecture and engineering conventions that may be mirrored into multiple repositories.

## ADR locations and scope

- Org-level ADRs live here: `org/docs/adr/`.
- Repo-level ADRs live in each repository under `docs/adr/`.
- Package-level ADRs live in the package itself (for example, `<package>/docs/adr/`).

Keep each decision at the narrowest level that still reflects who should follow it.

## Current org-level ADR set in this repo

- `0001-hexagonal-architecture-with-ddd-naming.md` (historical/superseded context for layout evolution)
- `0002-zod-for-runtime-json-validation.md`
- `0003-agent-skills-canonical-location-and-symlinks.md`
- `0004-self-documenting-code-and-documentation-expectations.md`
- `0005-composition-roots-and-wiring-boundaries.md`
- `0006-consistency-and-extension-for-new-features.md`
- `0007-vertical-feature-modules-hexagonal-slices-and-packages.md`
- `0008-barrel-files-public-api-boundaries.md`
- `0009-prefer-small-focused-files.md`
- `0010-import-specifier-conventions-for-monorepo-packages.md`
- `0011-test-import-alias-hash-root.md`
- `0012-classes-as-primary-responsibility-boundaries.md`
- `0013-use-of-classes-vs-module-level-functions-and-interfaces.md`
- `0014-stable-facade-construction-and-centralized-composition.md`
- `0015-centralized-org-agent-standards-git-subtree-projection.md`
- `0016-frontend-responsibility-areas-and-layered-boundaries.md`
- `0017-workspace-library-dist-boundary-and-dev-watch.md`
- `0018-index-barrels-re-export-only.md`
- `0019-vendor-specific-infrastructure-slices.md`
- `0020-run-production-database-migrations-as-a-separate-deployment-step.md`
- `0021-code-first-drizzle-schema-and-migrations.md`
- `0022-standardize-monorepos-to-pnpm-turbo.md`
- `0023-lockstep-versioning-for-related-package-groups.md`
- `0024-use-changesets-for-library-monorepos.md`
- `0025-versioning-plugins-vs-core.md`
- `0026-use-changesets-for-application-releases.md`
- `0027-use-single-changesets-workflow-in-hybrid-monorepos.md`
- `0028-version-only-deployable-artifacts-by-default.md`
- `0029-standardize-on-pnpm.md`
- `0030-coordinated-release-model-release-manifests-and-promotion-tags.md`
- `0031-separation-of-artifact-tags-and-environment-promotion-tags.md`
- `0032-monorepo-package-taxonomy-naming-and-domain-contracts.md`
- `0033-frontend-package-split-application-of-adr-0032-and-adr-0016.md`
- `0034-use-github-packages-with-single-chiubaka-scope-for-private-package-distribution.md`
- `0035-trial-adoption-of-conventional-commits.md`
- `0036-standardize-package-naming-under-chiubaka-scope-with-ecosystem-prefixes.md`

If your repository has a contributor or agent guide, link it to this ADR set for concise day-to-day pointers.

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
5. If the ADR needs concrete pattern demonstration, add a small illustrative example under `org/docs/adr/examples/` and reference it from the ADR.
6. Keep org-level ADR references portable: do not point to repo-local files, paths, or implementation patterns that may be missing when this org ADR set is bootstrapped into another repository.
