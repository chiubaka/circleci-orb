---
status: accepted
date: 2026-07-28
decision-makers: Daniel Chiu
---

# Prerelease until production for application release cycles

## Context and Problem Statement

Deployable application monorepos use Changesets for version bumps and release intent ([ADR 0026](0026-use-changesets-for-application-releases.md)), release cycles with RC cuts for staging soak ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)), and deferred canonical GitHub Releases at production promotion ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md)).

Under the prior model, each RC cut ran a normal `changeset version` to a **stable** semver (for example `0.8.0`, then `0.8.1` on a soak patch). That meant package versions looked “released” long before production promotion, and a single production cycle could consume multiple stable versions of the same deployable.

The problem is: how should application release cycles express package semver so that **stable versions mean production-ready (or production-shipped) artifacts**, while still supporting immutable RC candidates during soak?

## Decision Drivers

- Stable semver should not imply a production ship that has not happened yet
- RC cuts still need immutable, pin-able artifact identities for staging
- Prefer Changesets’ built-in prerelease mode over bespoke version schemes
- Keep calendar release-cycle ids and promotion tags unchanged ([ADR 0038](0038-release-train-identifiers-and-github-releases.md), [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md))
- Hotfixes need a fast path that can skip soak-oriented prerelease ceremony
- Scope the policy to coordinated application release cycles, not library-only publish batches

## Considered Options

- Keep stable semver on every RC cut (status quo)
- Changesets prerelease mode for the duration of an open application release cycle; exit to stable at production finalization (chosen)
- Defer all `changeset version` until production (SHA or digest pins during soak)
- Independently managed product/marketing version on `cycle.yml` unrelated to package semver

## Decision Outcome

Chosen option: **Use Changesets prerelease mode for normal application release cycles; cut stable semver only when finalizing production promotion.**

### Scope

- **In scope:** deployable application monorepos that use coordinated release cycles and `.releases/<cycle-id>/` manifests ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md))—typically opted in via release automation such as `create-release-manifest`.
- **Out of scope / unchanged:** library-only monorepos without application release cycles continue to version and publish stable batches as today ([ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0038](0038-release-train-identifiers-and-github-releases.md)). Calendar train ids, promotion tag shapes, and the absence of a separate independently managed “platform version” field on `cycle.yml` are unchanged.

### Normal (non-hotfix) cycle flow

1. **Enter prerelease** when allocating the first RC (`rc1`) of a new open cycle: `changeset pre enter rc` (or equivalent automation). The Changesets prerelease tag is `rc`, producing versions such as `1.2.3-rc.0`.
2. **Each RC cut** (including `rc1` and any soak `rc2+`) runs `changeset version` while still in prerelease mode, advancing the prerelease counter as needed (`1.2.3-rc.1`, …). Manifest pins and per-RC notes snapshot that cut ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md)).
3. **Staging** deploys prerelease artifact tags (for example `server-v1.2.3-rc.0`). Artifact tag parsers MUST accept prerelease semver suffixes.
4. **Production finalization** (promote-to-prod automation), on the validated soaked commit:
   - `changeset pre exit` (if still in pre mode)
   - `changeset version` to strip prerelease suffixes and produce stable versions (for example `1.2.3`)
   - refresh the highest `rc*/manifest.yml` pins to those stable versions
   - build/publish/tag stable artifacts as required by the repository
   - set `promotedAt`, write `release-notes.md`, push the finalize commit, and apply `prod-<cycle-id>` ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md), [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md))

Soak validates **content** on prerelease artifacts. Production ships **new stable artifact tags** for that same content lineage after the version ceremony. Production promotion tags continue to target the finalize commit by default when finalization rewrites versions and pins.

### Single-cut cycles

Operators cannot know ahead of time whether soak will require `rc2+`. Therefore **every normal application cycle enters prerelease at `rc1`**. If `rc1` is promoted to production with no further cuts, production finalization is still the step that exits prerelease and cuts stable semver. There is no separate “skip prerelease because this will be a single cut” path.

### Hotfix cycles

Production hotfixes remain **new release cycles** cut from the current production baseline ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md#hotfix-releases)). Hotfix cycles **MAY skip Changesets prerelease mode** and version directly to stable at their (typically single) cut, so urgent production fixes are not forced through enter/exit ceremony.

Skipping prerelease is an **explicit** hotfix signal in release automation (for example a `hotfix` / `release-is-hotfix` parameter). It MUST NOT be inferred solely from `predecessorCycle` on `cycle.yml`—tooling may set `predecessorCycle` for audit on regular cycles as well as hotfixes.

When a hotfix skips prerelease, production finalization does not need a pre-exit version step; it finalizes notes and `promotedAt` against the already-stable cut.

### Workspace-wide prerelease (hybrid monorepos)

Changesets prerelease mode is **repository-wide**: while an application cycle is in pre mode, **any** package versioned by Changesets in that workspace (including publishable libraries in a hybrid monorepo) receives prerelease versions and, if published, the corresponding npm dist-tag (for example `rc`) until the cycle exits pre at production finalization ([ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md)).

Consequences for hybrids:

- Pending library changesets that ride the same version cuts as the application cycle publish as prereleases until prod exit.
- Teams SHOULD avoid mixing unrelated library releases into an open application soak cycle when they need those libraries on the `latest` dist-tag sooner.
- Hotfix cycles that skip prerelease also version affected libraries to stable immediately.

### Relationship to release-cycle and review-artifact ADRs

- An **RC** remains one version cut and pin set within a cycle ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)), but for normal cycles that cut yields **prerelease** package semver until production finalization.
- Per-RC `rc<n>/release-notes.md` still snapshots the batch at each cut; production `release-notes.md` remains the **collated** cycle rollup published at `prod-<cycle-id>` ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md)). Stable changelog sections produced at pre-exit belong with the production finalize commit and MUST be reflected in the production review story (collated rollup and/or highest-RC notes refresh as implemented by tooling).

### Consequences

- Good, because stable package versions align with production finalization rather than early soak cuts.
- Good, because staging retains immutable prerelease pins and RC directories.
- Good, because calendar cycle ids and promotion tags stay stable across soak.
- Good, because hotfixes can skip prerelease when speed matters.
- Bad, because production finalization must perform an additional version cut, refresh manifests, and publish stable artifacts—not merely tag the soaked commit.
- Bad, because hybrid monorepos share one pre mode for the whole workspace during an open cycle.
- Bad, because artifact tag and deploy tooling must accept prerelease semver in pins and tags.

### Confirmation

- Normal application cycles with `create-release-manifest` (or equivalent) enter Changesets pre mode at `rc1` and remain in pre mode across soak cuts until production finalization.
- Staging manifests pin `*-rc.*` (or equivalent) versions; production finalize refreshes the highest RC manifest to stable versions before `prod-<cycle-id>`.
- Hotfix release automation can opt out of pre mode and version to stable at cut time.
- Library-only repos without application release-cycle manifests are unaffected.
- Review of `.releases/` and package versions on a soaked staging commit shows prerelease semver for packages cut in that cycle; after promote-prod finalization, those packages show stable semver.

## Pros and Cons of the Options

### Stable semver on every RC cut (status quo)

- Good, because production can redeploy the exact artifact tags validated in staging without a final version ceremony.
- Bad, because package versions read as released before production promotion.
- Bad, because one production cycle can burn multiple stable semvers for soak-only fixes.

### Changesets prerelease until production (chosen)

- Good, because stable semver matches the production boundary operators care about.
- Good, because it uses Changesets’ supported pre enter / pre exit workflow.
- Bad, because prod ships newly tagged stable artifacts after soak, not the prerelease tags themselves.
- Bad, because pre mode is workspace-wide.

### Defer versioning until production

- Good, because exactly one semver bump per cycle.
- Bad, because it abandons Changesets’ natural cut-time changelog snapshots and forces SHA/digest pin schemes during soak.
- Bad, because it fights the existing RC-per-cut release-PR model.

### Independently managed platform version on `cycle.yml`

- Good, because it can name a product ship without changing package semver.
- Bad, because an independently managed number reintroduces the ambiguity semver was meant to resolve unless it is derived from clear package rules.
- Rejected for this decision; package prerelease/stable semantics address the core discomfort without a parallel version field.

## More Information

**Implementation note (Chiubaka orb):** release-PR automation enters pre when creating application release-cycle cuts (unless hotfix); promote-prod automation exits pre, versions to stable, refreshes pins, and finalizes the cycle. Exact parameters and scripts live with the orb; this ADR is the normative policy.

**Illustration:** update [examples/release-train-review-artifacts.md](examples/release-train-review-artifacts.md) for prerelease pins during soak and stable pins after prod finalization.

## Related ADRs

- [ADR 0026](0026-use-changesets-for-application-releases.md) — Changesets for application release intent
- [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) — single Changesets workflow; workspace-wide pre mode
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — artifact vs promotion tags
- [ADR 0038](0038-release-train-identifiers-and-github-releases.md) — calendar train ids unchanged
- [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) — pin-only manifests
- [ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md) — review artifacts; prod publication timing
- [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md) — release cycles, RCs, hotfixes
