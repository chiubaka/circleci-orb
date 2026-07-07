# Example: release train review artifacts (ADR 0041, ADR 0042)

Illustrative walkthrough for a three-environment application monorepo. Not normative; see [ADR 0041](../0041-release-train-review-artifacts-for-deployable-applications.md) and [ADR 0042](../0042-release-cycles-rc-identifiers-and-manifest-directories.md).

## Setup

- Deployables: `server`, `web`
- Last production cycle: `2026.06.01.1`
- New cycle: `2026.07.01.1` (cycle **open date** 2026-07-01 UTC; rc2 cut on 2026-07-03 remains on this cycle id)
- Environments: topology **A** — dev (continuous from `main`), staging (`staging-*-rc<n>`), prod (`prod-<cycle-id>`)

## rc1 — initial staging cut

1. Feature PRs on `main` accumulate `.changeset/` files.
2. `changesets-release-pr` allocates cycle `2026.07.01.1`, creates:

```
.releases/2026.07.01.1/
  cycle.yml
  rc1/manifest.yml    # server-v5.2.0, web-v2.4.0
  rc1/notes.md
```

3. Release PR body shows the rc1 batch (**artifact 1**).
4. Merge → gated publish → `staging-2026.07.01.1-rc1` → staging deploy.

## rc2 — soak patch (2026-07-03)

1. Staging QA finds a bug; fix PR adds a `.changeset/` with `Fix: …`.
2. Follow-up release PR adds **`rc2/`** under the **same** cycle (no new cycle id):

```
.releases/2026.07.01.1/
  …
  rc2/manifest.yml    # server-v5.2.1, web-v2.4.0
  rc2/notes.md        # artifact 2 — this cut only
```

3. Patch release PR body shows only the fix.
4. Merge → `staging-2026.07.01.1-rc2` → staging deploy.

## Production promotion

1. Staging sign-off on commit with final `rc2/manifest.yml`.
2. Maintainer pushes **`prod-2026.07.01.1`** (cycle id only; no `-rc` suffix).
3. Coordinated deploy; tooling sets **`promotedAt`** on `cycle.yml` and writes **`release-notes.md`** (rollup with section headings `2026.07.01.1-rc1`, `2026.07.01.1-rc2`).
4. GitHub Release **`2026.07.01.1`** with **`release-notes.md`** body (**artifact 3**).

## Two-environment variant (topology C — dev + gated prod)

Same directory layout. Only `rc1/` before prod; dev deploys continuously from `main` (out of band):

```
.releases/2026.07.01.1/
  cycle.yml
  rc1/manifest.yml
  rc1/notes.md
  release-notes.md   # single section ## 2026.07.01.1-rc1
```

Promotion: `prod-2026.07.01.1` after merge (no staging promotion tags).

## Staging + prod variant (topology B)

Same RC flow as the main example (rc1, rc2, staging tags), but **no deployed dev environment**—validation is local or in CI before `staging-*-rc<n>`.

## Hotfix (production)

Prod is live on `2026.07.01.1`. An urgent defect is found; `main` may already have an unrelated in-flight cycle on a release PR. This is **not** an `rc2` soak patch—the shipped cycle is closed.

1. Branch from the commit tagged **`prod-2026.07.01.1`**.
2. Fix PR adds a `.changeset/` entry; version cut allocates **new** cycle `2026.07.07.1`:

```
.releases/2026.07.07.1/
  cycle.yml              # openedAt; predecessorCycle: 2026.07.01.1
  rc1/manifest.yml
  rc1/notes.md           # artifact 1 — hotfix only
  release-notes.md       # artifact 3 — written at prod promotion
```

3. Expedited path: merge → gated publish → optional `staging-2026.07.07.1-rc1` → **`prod-2026.07.07.1`**.
4. GitHub Release **`2026.07.07.1`** with `release-notes.md` body; `cycle.yml` gains **`promotedAt`**.
5. **Merge hotfix back to `main`** before the next regular production cycle ships.

Concurrent: an open `.releases/2026.07.20.1/` on `main` is unaffected; hotfix uses its own cycle id and directory.
