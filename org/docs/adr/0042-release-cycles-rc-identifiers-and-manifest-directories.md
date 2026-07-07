---
status: accepted
date: 2026-07-07
decision-makers: Daniel Chiu
---

# Release cycles, RC identifiers, and manifest directory layout

## Context and Problem Statement

Deployable application monorepos use calendar train identifiers (`YYYY.MM.DD.N`) for coordinated releases ([ADR 0038](0038-release-train-identifiers-and-github-releases.md)), pin-only manifests under `.releases/` ([ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md)), and environment promotion tags ([ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)).

**Three-environment** workflows (dev → staging → prod) commonly include **release candidates (RCs)**: an initial staging cut, optional soak iterations with follow-up version cuts, then production promotion. Prior ADRs did not define:

- what the **calendar date** in a train id represents when soak spans multiple days;
- how **RC iterations** relate to train ids and promotion tags;
- whether manifest paths stay flat files or use a structured layout.

Flat manifests (`.releases/2026.07.01.1.yml`) and incrementing promotion-tag `N` for “second staging deploy” conflate **release cycles**, **RC cuts**, and **re-deployments**. That breaks down once soak adds new semver pins per RC.

This ADR defines **release cycle** identity, **RC** identity, **cycle-open date semantics** for calendar ids, and a **directory layout** that applies to all coordinated release cycles—including single-cut two-environment flows.

## Decision Drivers

- **Honest calendar semantics:** train ids must not be read as “production ship date” when soak can span days or weeks.
- **RC as first-class:** staging candidates need explicit identifiers (`-rc1`, `-rc2`, …) distinct from cycle ids and from package semver.
- **One layout convention:** avoid parallel flat-file and directory schemas; two-environment repos should not use a different on-disk shape than three-environment repos.
- **Compose with Changesets:** cycle and RC cuts still originate from `changeset version`; package semver remains the compatibility surface ([ADR 0026](0026-use-changesets-for-application-releases.md)).
- **Stable prod-facing name:** production promotion and canonical GitHub Releases use the **cycle id** without an RC suffix, even when multiple RCs preceded prod.

## Considered Options

- **Flat manifest per cycle** with in-place pin refresh and append-only notes (superseded approach in early [ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md) drafts)
- **New cycle id per RC cut** (`2026.07.01.2`, `2026.07.03.1`) with predecessor linking for prod rollup
- **Stable cycle id + `-rcN` suffix on staging promotions + per-RC directory layout** (chosen)

## Decision Outcome

Chosen option: **Stable cycle id + RC suffix + mandatory directory layout for all application release cycles.**

### Release cycle

A **release cycle** is one coordinated product release from first version cut through production promotion—a single “thing we intend to ship,” including staging soak.

- **Cycle id:** `YYYY.MM.DD.N` (for example `2026.07.01.1`).
- **Calendar portion (`YYYY.MM.DD`):** the **cycle open date**—the UTC calendar date when the **first RC** (`rc1`) version cut is allocated. It is **not** the production ship date, last soak date, or last validation date.
- **`N` in the cycle id:** the **nth release cycle opened on that UTC calendar day** (`1` for the first cycle that day, then `2`, …). It does **not** count RC iterations within a cycle.

**Why cycle open date (not prod ship date):** Calendar train ids exist to coordinate manifests and promotion without inventing monorepo-level semver ([ADR 0038](0038-release-train-identifiers-and-github-releases.md)). The id names **when the release cycle began**, not when users received it. Production ship time belongs in GitHub Release metadata, optional manifest fields, and deployment audit logs—not in the coordination id. Anchoring to cycle open date keeps the id **stable across soak**, makes RC re-cuts on later calendar days part of the **same** cycle, and avoids renumbering the external release at prod time.

**Why not monorepo semver for cycles:** Independent package versions already express compatibility; a root semver is easy to misread and does not summarize heterogeneous batch bumps honestly ([ADR 0038](0038-release-train-identifiers-and-github-releases.md)).

### Release candidate (RC)

An **RC** is one `changeset version` cut within a cycle—one pin set and one reviewer-facing notes snapshot.

- **RC index:** `rc1`, `rc2`, `rc3`, … assigned sequentially within the cycle (`rc1` always exists—the first **version cut**, whether or not a staging environment deploys that cut).
- **RC promotion id (staging promotions):** `<cycle-id>-rc<n>` (for example `2026.07.01.1-rc2`). Used when **staging** is a coordinated promotion target.
- **RC cuts on later calendar days** remain under the **same cycle id** (for example `rc2` cut on 2026-07-03 still belongs to cycle `2026.07.01.1`).

The `rc<n>` directory name is a **cut index**, not shorthand for “staging exists.” Repos without staging still use `rc1/` for the sole version cut before prod.

### Deployment topologies

Release **cycles**, directory layout, and review artifacts ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md)) are independent of how many named environments exist. What varies is **which environments use continuous deploy from `main`** versus **coordinated promotion** (manifest + tags) per [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md).

| Topology                     | Environments                                | Continuous deploy from `main` | Coordinated promotion | Typical staging tags       | Typical prod tag  |
| ---------------------------- | ------------------------------------------- | ----------------------------- | --------------------- | -------------------------- | ----------------- |
| **A — Dev + staging + prod** | dev, staging, prod                          | dev                           | staging + prod        | `staging-<cycle-id>-rc<n>` | `prod-<cycle-id>` |
| **B — Staging + prod**       | staging, prod (local/dev machine test only) | none                          | staging + prod        | `staging-<cycle-id>-rc<n>` | `prod-<cycle-id>` |
| **C — Dev + prod**           | dev, prod                                   | dev                           | prod only             | none (no staging deploys)  | `prod-<cycle-id>` |

**Notes:**

- **Topology A** is the classic three-environment flow: dev auto-deploy, staging RC soak, gated prod.
- **Topology B** is a supported **two-environment** pattern: same RC and staging promotion mechanics as A, without a deployed dev environment. Validation happens locally or in CI before staging promotion.
- **Topology C** is a supported **two-environment** pattern: dev auto-deploy for integration, **gated prod** via release trains. Usually a **single cut** (`rc1/` only) before `prod-<cycle-id>`; a second cut before prod (without staging) is rare but uses the same `rc2/` machinery.
- **Continuous production deploy from `main`** is out of scope for this coordinated model; production is **gated** via `prod-*` promotion tags in all topologies above.
- **Library-only repos** without `.releases/` manifests are unchanged ([ADR 0038](0038-release-train-identifiers-and-github-releases.md)).

### Promotion tags

Promotion tags prepend an environment prefix to a **promotion id** parsed by deploy automation:

| Target                      | Promotion id pattern        | Example                    |
| --------------------------- | --------------------------- | -------------------------- |
| Staging (topologies A, B)   | `<cycle-id>-rc<n>`          | `staging-2026.07.01.1-rc2` |
| Production (all topologies) | `<cycle-id>` (no RC suffix) | `prod-2026.07.01.1`        |

**Rules:**

- When **staging** is a coordinated deploy target, staging tags MUST include `-rc<n>` matching the RC directory being deployed.
- Production tags MUST use the cycle id only—the canonical external release name for the whole cycle.
- Topology **C** (dev + gated prod) typically has **no staging promotion tags**; prod still deploys from the highest `rc*/manifest.yml` on the tagged commit.
- `N` in the **cycle id** and `n` in **`-rc<n>`** are independent: `2026.07.01.2-rc1` is the first RC of the **second cycle** opened on 2026-07-01, not “RC2 of cycle …1”.

### Repository layout (all cycles use directories)

**Every** coordinated release cycle for deployable applications MUST use a directory under `.releases/`, including single-cut topology C releases. There is no parallel flat-file convention (`.releases/<id>.yml`).

### Manifest and cycle YAML key naming

All keys in `cycle.yml`, `rc<n>/manifest.yml`, and tooling-owned fields in this schema MUST use **`camelCase`** (for example `cutAt`, `predecessorCycle`, `openedAt`, `promotedAt`). Deployable keys under `artifacts:` remain short lowercase names chosen per repository (for example `server`, `web`).

**Rationale:** Release manifests are generated and consumed by TypeScript release tooling in application monorepos. `camelCase` aligns with JSON and TypeScript conventions in those repos, avoids rename layers when parsing into types, and matches adjacent config (for example Changesets `config.json`). These files remain human-audited in git; `camelCase` is equally readable in diffs.

```text
.releases/
  <cycle-id>/                 # e.g. 2026.07.01.1
    cycle.yml                 # cycle metadata (required)
    rc1/
      manifest.yml            # pin set for this RC cut
      notes.md                # reviewer notes for this cut only (tooling-owned)
    rc2/                      # present when a soak patch cut exists
      manifest.yml
      notes.md
    release-notes.md          # rollup for prod / artifact 3 (tooling-owned)
```

**`cycle.yml`** (required):

At **rc1** cut, tooling MUST create `cycle.yml` with:

```yaml
release: 2026.07.01.1
openedAt: 2026-07-01T14:32:00Z # ISO-8601 UTC; SHOULD match cycle open date semantics
```

- `release` MUST equal the cycle id (directory name).
- `openedAt` MUST be set when `rc1` is cut. It records the **cycle open date** and SHOULD fall on the UTC calendar day encoded in the cycle id.

At **production promotion**, tooling MUST set `promotedAt` on the same commit that receives `prod-<cycle-id>`:

```yaml
release: 2026.07.01.1
openedAt: 2026-07-01T14:32:00Z
promotedAt: 2026-07-15T16:00:00Z # ISO-8601 UTC; production ship time
```

- `promotedAt` MUST be present before a cycle is considered **shipped to production**. It is the authoritative **production ship timestamp**; it is **not** encoded in the cycle id ([ADR 0038](0038-release-train-identifiers-and-github-releases.md)).
- Cycles in staging soak (not yet promoted to prod) correctly omit `promotedAt` until production promotion completes.

Optional keys: `predecessorCycle` (prior cycle id for audit; **SHOULD** be set for [hotfix](#hotfix-releases) cycles).

**`rc<n>/manifest.yml`** — pin-only schema per [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md):

```yaml
release: 2026.07.01.1
rc: 1
cutAt: 2026-07-01T14:32:00Z

artifacts:
  server: server-v5.2.0
  web: web-v2.4.0
```

- `release` MUST equal the parent cycle id.
- `rc` MUST match the directory name (`rc1` → `rc: 1`).
- `cutAt` MUST be set when the manifest is written at that RC’s `changeset version` cut. ISO-8601 UTC; records when this candidate’s pins were produced (audit trail per RC, distinct from `cycle.yml` `openedAt` / `promotedAt`).

**Deploy resolution:** coordinated deploy for promotion tag `staging-2026.07.01.1-rc2` reads `.releases/2026.07.01.1/rc2/manifest.yml`. For `prod-2026.07.01.1`, automation MUST use the **highest-numbered `rc*/manifest.yml` present on the tagged commit** (the validated final RC).

**`release-notes.md`:** tooling-generated rollup of all `rc*/notes.md` in order; canonical GitHub Release body at prod ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md)). Each rollup section MUST be headed with the full RC promotion id (`<cycle-id>-rc<n>`, for example `## 2026.07.01.1-rc1`), matching staging promotion tag stems. Per-RC `rc<n>/notes.md` files contain only that cut’s formatted batch (no section heading required in the leaf file). For a single-cut cycle, the rollup MAY contain one section (`<cycle-id>-rc1`) identical in body to `rc1/notes.md`.

### Single-cut cycles (topology C and simple paths)

A cycle with only one version cut before prod still uses the full directory shape:

```text
.releases/2026.07.01.1/
  cycle.yml
  rc1/
    manifest.yml
    notes.md
  release-notes.md
```

Promotion: `prod-2026.07.01.1`. Topology B may use `staging-2026.07.01.1-rc1` before prod. **No special-case flat files.**

### Cycle and RC allocation

1. **New cycle:** when starting a new coordinated release after the prior production cycle, or when opening a [hotfix](#hotfix-releases) cycle, allocate the next `YYYY.MM.DD.N` using UTC **today** as the calendar portion (same allocator rules as [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) for `N` per day). Create `.releases/<cycle-id>/cycle.yml` and `rc1/`.
2. **New RC within cycle:** on soak patch release PR, add `rc<n+1>/` under the **existing** cycle directory; do not allocate a new cycle id. Applies only while the cycle is **not yet promoted** to production (`promotedAt` absent).
3. **New cycle on same day:** after a prior cycle on that UTC date already exists (for example `2026.07.01.1` promoted to prod), the next cycle is `2026.07.01.2` with its own `rc1/`.

### Hotfix releases

A **hotfix** is an urgent fix shipped to production while a prior cycle is already live (`promotedAt` set on that cycle). Hotfixes use the **same** release-cycle machinery as regular releases—no separate id suffix, no bypass of Changesets, manifests, or promotion tags.

**Definition:** A hotfix is a **new release cycle** cut from the **current production promotion commit** (the commit tagged `prod-<prior-cycle-id>`), not a new RC under the prior cycle. Once a cycle has `promotedAt`, it is **closed**; production defects MUST NOT be addressed by adding `rc<n+1>/` to a shipped cycle.

**Distinction from soak patches:**

| Situation                                                                        | Model                                                                                                                                             |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Defect found **before** production promotion (staging soak, pre-prod validation) | Same cycle; add `rc<n+1>/` ([ADR 0041 — Soak iteration](0041-release-train-review-artifacts-for-deployable-applications.md#soak-iteration-rules)) |
| Defect found **in production** after `promotedAt` on the live cycle              | **New cycle**; single `rc1/` (typical); `predecessorCycle` SHOULD reference the cycle in prod                                                     |

**Workflow:**

1. Branch from the production promotion commit (or equivalent documented prod baseline)—not from arbitrary `main` tip when `main` contains unreleased work.
2. Fix PR(s) include `.changeset/` entries as usual ([ADR 0026](0026-use-changesets-for-application-releases.md)).
3. Version cut allocates a **new** `YYYY.MM.DD.N` (UTC **today**; same `N` per-day rules) and creates `.releases/<cycle-id>/cycle.yml` with `openedAt`, plus `rc1/` (`manifest.yml`, `notes.md`).
4. **`predecessorCycle` SHOULD** be set on `cycle.yml` to the cycle id currently in production (audit lineage only; prod promotion still uses `prod-<new-cycle-id>`).
5. **Staging (optional):** repositories MAY skip staging or run a single abbreviated `staging-<cycle-id>-rc1` promotion (topology C–style fast path). Production remains gated via `prod-<cycle-id>`.
6. Push **`prod-<new-cycle-id>`** on the validated commit; tooling sets **`promotedAt`** and writes **`release-notes.md`** ([ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md)).
7. **Merge-back to `main` is REQUIRED** after production promotion, with Changesets discipline, so the next regular release does not omit the fix or double-bump versions.

**Concurrent cycles:** An in-flight regular release on `main` (open release PR with its own `.releases/<other-cycle-id>/`) does **not** block a hotfix. Hotfix and regular cycles are independent ids and directories. A hotfix branch MUST NOT reuse or extend another cycle’s directory.

**Hybrid monorepos:** If the hotfix touches publishable libraries ([ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md)), gated `changeset publish` for libraries and deployable manifest pins in the hotfix cycle’s final `rc*/manifest.yml` MUST be consistent before `prod-<cycle-id>` promotion.

**Illustration:** [examples/release-train-review-artifacts.md — Hotfix](examples/release-train-review-artifacts.md#hotfix-production).

### Consequences

- Good, because **calendar id semantics are explicit** (cycle open, not prod ship).
- Good, because **RCs are visible** in tags, paths, and manifests.
- **Topology flexibility:** same cycle and RC model supports dev+staging+prod, staging+prod, and dev+gated-prod ([Deployment topologies](#deployment-topologies)).
- Good, because **prod-facing names stay stable** across multi-day soak.
- Bad, because deploy tooling must parse `-rc<n>` and directory paths (breaking change from flat `.releases/<id>.yml`).
- Bad, because cycle open date in the id can be **weeks before prod**—`promotedAt` in `cycle.yml` MUST record actual ship time for audit and external narrative.
- Good, because **hotfixes reuse the same cycle model**—new prod release, full changelog path, no special-case ids.

### Confirmation

- Application deployment monorepos using coordinated promotion adopt `.releases/<cycle-id>/` directories for every cycle.
- Staging promotion tags in three-environment repos include `-rc<n>`; production tags do not.
- `cycle.yml` documents `openedAt` in UTC at rc1; calendar portion of cycle id matches that date’s UTC day.
- `cycle.yml` documents `promotedAt` in UTC when production promotion completes; a shipped cycle MUST NOT lack `promotedAt`.
- Each `rc<n>/manifest.yml` documents `cutAt` in UTC when that RC cut is versioned.
- Production hotfixes allocate a **new** cycle from the prod promotion commit; shipped cycles are not extended with additional RC directories.
- Hotfix `cycle.yml` **SHOULD** include `predecessorCycle`; hotfix changes **MUST** merge back to `main` after prod promotion.
- Library-only monorepos without manifests are unaffected.

## Pros and Cons of the Options

### Flat manifest + in-place refresh

- Good, because minimal path churn.
- Bad, because RC identity is implicit; conflicts with orb behavior that allocates new ids per cut; blurs cycle vs RC.

### New cycle id per RC cut

- Good, because matches naive per-cut train allocation.
- Bad, because prod needs predecessor chains; external release name unstable; cross-day soak looks like unrelated releases.

### Stable cycle id + RC suffix + directories (chosen)

- Good, because first-class RCs and stable prod id; explicit date semantics.
- Good, because single layout for all cycles.
- Bad, because migration from flat manifests and tag parsers required.

## More Information

**Supersedes for application repos:** flat `.releases/<release-id>.yml` paths described in [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) remain historical; deployable application monorepos MUST follow this ADR’s directory layout. Library repos without manifests are unchanged.

**Relationship to [ADR 0038](0038-release-train-identifiers-and-github-releases.md):** `YYYY.MM.DD.N` grammar is unchanged; this ADR defines what the calendar portion **means** (cycle open date) and adds `-rc<n>` to **staging** promotion ids only.

**Illustration:** [examples/release-train-review-artifacts.md](examples/release-train-review-artifacts.md).

## Related ADRs

- [ADR 0026](0026-use-changesets-for-application-releases.md) — application release intent via Changesets
- [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) — hybrid monorepos; library publish vs app deploy
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — promotion tags; updated for RC suffix
- [ADR 0038](0038-release-train-identifiers-and-github-releases.md) — calendar train identifiers; cycle-open semantics
- [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) — pin-only manifest fields; directory layout deferred to this ADR
- [ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md) — reviewer-facing notes artifacts per RC and prod rollup
