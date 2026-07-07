---
status: accepted
date: 2026-07-07
decision-makers: Daniel Chiu
---

# Release train review artifacts for deployable applications

## Context and Problem Statement

Deployable application monorepos that use Changesets, release manifests, and environment promotion ([ADR 0026](0026-use-changesets-for-application-releases.md), [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md), [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)) need **multiple reviewer-facing changelog artifacts** during a single **release cycle**—not one notes surface at the wrong time.

Typical needs:

1. **Initial cut (rc1):** What is new in this release since the **last production release**, to support review before the first coordinated deploy (staging or prod)?
2. **Later cuts (rc2+):** What changed **since the previous cut** on the same cycle (staging soak or rare pre-prod patch)?
3. **Production promotion:** A **combined** user-facing changelog for everything that shipped on the cycle—including all cuts—since the last production release.

Release **cycle** identity, RC naming, calendar date semantics, and manifest directory layout are defined in [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md). This ADR defines **what review artifacts exist**, where they live on disk, and **when** the canonical GitHub Release is published.

## Decision Drivers

- **Explicit release intent** remains in `.changeset/` files at PR time ([ADR 0026](0026-use-changesets-for-application-releases.md)).
- **Three distinct review moments** (rc1, rcₙ vs rcₙ₋₁, prod full cycle) each need a clear, auditable artifact.
- **Snapshot at version time:** capture formatted notes when `changeset version` runs; do not reconstruct later from git history.
- **Environment compatibility:** same on-disk artifacts and review model across supported deployment topologies ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)); library-only repos unchanged.
- **RC-first-class:** per-RC notes files align with `-rc<n>` staging promotion tags ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).

## Considered Options

- **Publish GitHub Release at staging/publish merge only** (status quo per ADR 0038 for batched publishes)
- **Reconstruct aggregate notes at prod by parsing git history across `CHANGELOG.md`**
- **Release PR bodies only; no durable per-cycle artifacts**
- **Per-RC notes files under cycle directory + prod rollup; deferred canonical GitHub Release** (chosen)

## Decision Outcome

Chosen option: **Per-RC notes snapshots under `.releases/<cycle-id>/rc<n>/notes.md`, cycle-level `release-notes.md` rollup at prod, deferred canonical publication for deployable applications.**

### Scope

- **In scope:** application deployment monorepos using `.releases/<cycle-id>/` directories ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).
- **Out of scope / unchanged:** library-only monorepos without manifests publish GitHub Releases at gated publish merge per [ADR 0038](0038-release-train-identifiers-and-github-releases.md).

### Authoring and transformation (unchanged)

1. Releasable changes include `.changeset/` entries with category-prefixed summaries.
2. `changeset version` consumes pending changesets, bumps deployable semvers, writes per-package `CHANGELOG.md`.
3. Category rewrite and batch formatting run immediately after version (existing orb behavior).

Changesets remains the **authoring** system of record. Presentation tooling reads `CHANGELOG.md` **at version time** for each RC cut.

### On-disk artifacts (per cycle)

Every release cycle uses a directory ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md))—including single-cut two-environment releases:

```text
.releases/<cycle-id>/
  cycle.yml
  rc1/
    manifest.yml
    notes.md          # artifact 1 (and only RC notes for simple 2-env cuts)
  rc2/                # when soak requires another cut
    manifest.yml
    notes.md          # artifact 2 for this cut
  release-notes.md    # artifact 3 rollup (tooling-owned)
```

**On each `changeset version` cut**, release automation MUST:

1. Format the **newly written top version block** from each affected deployable `CHANGELOG.md` (same batch formatter as release-PR bodies).
2. Write **`rc<n>/notes.md`** for that cut only (overwrite on re-run of the same RC is forbidden; each RC directory is created once).
3. Update **`rc<n>/manifest.yml`** pins and **`cutAt`** (ISO-8601 UTC) for that cut.
4. Leave **`release-notes.md`** to be generated or refreshed at prod promotion (rollup of all `rc*/notes.md` in order). Section headings in the rollup MUST use the full **RC promotion id** (`<cycle-id>-rc<n>`, for example `2026.07.01.1-rc1`), not bare `rc1` / `rc2`.

All notes files are **tooling-owned**; do not hand-edit ([agents/skills/changesets-hygiene/SKILL.md](../../agents/skills/changesets-hygiene/SKILL.md)).

### Three review artifacts

| #     | Review moment        | Question answered                    | Primary artifact                                                       |
| ----- | -------------------- | ------------------------------------ | ---------------------------------------------------------------------- |
| **1** | First cut (`rc1`)    | What is new since last prod?         | Release PR body; **`.releases/<cycle-id>/rc1/notes.md`**               |
| **2** | Later cut (`rc2+`)   | What changed since the previous cut? | **`.releases/<cycle-id>/rc<n>/notes.md`** for the latest cut only      |
| **3** | Production promotion | Full cycle since last prod           | **`.releases/<cycle-id>/release-notes.md`** → canonical GitHub Release |

**Artifact 1:** Release PR body remains the primary review surface at cut time; `rc1/notes.md` mirrors it for durability. In topology C (dev + gated prod), review happens at the release PR before prod deploy—there may be no staging promotion.

**Artifact 2:** Applies when a cycle has more than one cut—typically staging soak (topologies A, B). Each cut gets its own `rc<n>/notes.md`. Optional CI SHOULD surface the latest RC notes when deploying `staging-<cycle-id>-rc<n>`.

**Artifact 3:** `release-notes.md` concatenates (or regenerates from) all `rc*/notes.md` in order, with each section headed by the full RC promotion id (`<cycle-id>-rc<n>`). Published at **`prod-<cycle-id>`** as the GitHub Release body. The GitHub Release title uses the cycle id only (no `-rc` suffix) ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).

### Publication timing

- **Gated publish merge:** `changeset publish`, artifact builds. MAY push `staging-<cycle-id>-rc<n>` when staging is a coordinated target (topologies A, B). MUST NOT create the **canonical** GitHub Release before prod.
- **Staging promotion** (topologies A, B): deploy only; notes for review (artifacts 1 or 2). Optional GitHub **pre-release** MUST NOT replace artifact 3.
- **Production promotion** (all topologies): coordinated deploy + canonical GitHub Release titled **`cycle-id`**, body from **`release-notes.md`**. Tooling MUST set **`promotedAt`** on `cycle.yml` on the prod promotion commit ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).

### Deployment topologies

Review artifacts and on-disk layout are **the same** across supported topologies; only **which promotion tags fire** differs. See [ADR 0042 — Deployment topologies](0042-release-cycles-rc-identifiers-and-manifest-directories.md#deployment-topologies).

| Topology                     | Summary                                            | Artifact 2 usual?               |
| ---------------------------- | -------------------------------------------------- | ------------------------------- |
| **A — Dev + staging + prod** | Dev continuous; staging RC soak; gated prod        | Yes, when soak adds rc2+        |
| **B — Staging + prod**       | No deployed dev; same staging RC flow as A         | Yes, when soak adds rc2+        |
| **C — Dev + prod**           | Dev continuous; gated prod; often single `rc1` cut | Rare (second pre-prod cut only) |

Topology **C** still uses `rc1/` and `release-notes.md` with heading `## <cycle-id>-rc1`; it does not require staging promotion tags.

### Soak iteration rules

1. Fixes merge with new `.changeset/` entries.
2. Patch **release PR** adds **`rc<n+1>/`** under the **same cycle id** ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)); do not allocate a new cycle id.
3. Promote staging with `staging-<cycle-id>-rc<n+1>`.
4. Prod promotes **`prod-<cycle-id>`** on the final validated commit; `release-notes.md` includes all RCs.

### Hotfix releases

Production hotfixes are **new release cycles**, not soak iterations ([ADR 0042 — Hotfix releases](0042-release-cycles-rc-identifiers-and-manifest-directories.md#hotfix-releases)). The same on-disk layout and review-artifact model apply:

| Artifact                                    | Hotfix behavior                                                                   |
| ------------------------------------------- | --------------------------------------------------------------------------------- |
| **1** (`rc1/notes.md`)                      | Hotfix-only batch since last prod (release PR body mirrors this)                  |
| **2**                                       | Typically absent (single `rc1` cut)                                               |
| **3** (`release-notes.md` → GitHub Release) | Full hotfix cycle at `prod-<new-cycle-id>`; often one section `## <cycle-id>-rc1` |

Staging promotion for hotfixes is optional per repository policy; canonical GitHub Release timing and `promotedAt` rules are unchanged.

### Illustrative example

Cycle `2026.07.01.1` (cycle open date 2026-07-01; rc2 cut on 2026-07-03 stays on this cycle id per [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)):

**Directory after rc2:**

```text
.releases/2026.07.01.1/
  cycle.yml
  rc1/manifest.yml
  rc1/notes.md
  rc2/manifest.yml
  rc2/notes.md
  release-notes.md
```

**`cycle.yml`** at rc2 (staging soak; not yet promoted to prod):

```yaml
release: 2026.07.01.1
openedAt: 2026-07-01T14:32:00Z
```

**`cycle.yml`** after `prod-2026.07.01.1` ( **`promotedAt` required** ):

```yaml
release: 2026.07.01.1
openedAt: 2026-07-01T14:32:00Z
promotedAt: 2026-07-15T16:00:00Z
```

`openedAt` is set at **rc1** and anchors the cycle id calendar date. `promotedAt` MUST be set when production promotion completes; it records **when the cycle shipped to prod**, which can be days or weeks after `openedAt` ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).

**`rc2/manifest.yml`:**

```yaml
release: 2026.07.01.1
rc: 2
cutAt: 2026-07-03T09:15:00Z

artifacts:
  server: server-v5.2.1
  web: web-v2.4.0
```

**`rc2/notes.md`** (artifact 2 — this cut only):

```markdown
### Bug Fixes

- **@chiubaka/server**
  - Fix null handling when export queue is empty
```

**`release-notes.md`** (artifact 3 — excerpt):

```markdown
## 2026.07.01.1-rc1

### Features

…

## 2026.07.01.1-rc2

### Bug Fixes

…
```

**Promotion tags:** `staging-2026.07.01.1-rc1`, `staging-2026.07.01.1-rc2`, `prod-2026.07.01.1`.

See [examples/release-train-review-artifacts.md](examples/release-train-review-artifacts.md) for a full walkthrough.

### Consequences

- Good, because three review moments have **explicit, path-stable artifacts**.
- Good, because **per-RC notes** match `-rc<n>` staging tags.
- Good, because **one directory schema** for 2-env and 3-env cycles.
- Bad, because tooling must write and validate directory trees and rollups.
- Bad, because [ADR 0038](0038-release-train-identifiers-and-github-releases.md) publish-time GitHub Release defaults do not apply verbatim to deployable app repos.

### Confirmation

- Every application release cycle has `.releases/<cycle-id>/` with at least `rc1/`.
- Each `rc<n>/manifest.yml` includes **`cutAt`**; `cycle.yml` includes **`promotedAt`** after prod ship.
- Canonical GitHub Releases for deployable apps are created at **`prod-<cycle-id>`** with body from **`release-notes.md`**; `cycle.yml` on that commit MUST include **`promotedAt`**.
- Hotfix cycles use the same artifact paths; `rc1/notes.md` documents the hotfix-only batch since last prod.
- Library repos without manifests are unaffected.

## Related ADRs

- [ADR 0026](0026-use-changesets-for-application-releases.md) — application release intent via Changesets
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — promotion tags with RC suffix
- [ADR 0038](0038-release-train-identifiers-and-github-releases.md) — cycle-open calendar date semantics
- [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) — pin-only manifest fields
- [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md) — release cycles, RC ids, directory layout
