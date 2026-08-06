# Example: release train review artifacts (ADR 0041, ADR 0042, ADR 0043)

Illustrative walkthrough for a three-environment application monorepo. Not normative; see [ADR 0041](../0041-release-train-review-artifacts-for-deployable-applications.md), [ADR 0042](../0042-release-cycles-rc-identifiers-and-manifest-directories.md), and [ADR 0043](../0043-prerelease-until-production-for-application-release-cycles.md).

## Setup

- Deployables: `server`, `web`
- Last production cycle: `2026.06.01.1`
- New cycle: `2026.07.01.1` (cycle **open date** 2026-07-01 UTC; rc2 cut on 2026-07-03 remains on this cycle id)
- Environments: topology **A** — dev (continuous from `main`), staging (`staging-*-rc<n>`), prod (`prod-<cycle-id>`)
- Normal cycles use Changesets **prerelease** until production finalization ([ADR 0043](../0043-prerelease-until-production-for-application-release-cycles.md))

## rc1 — initial staging cut

1. Feature PRs on `main` accumulate `.changeset/` files.
2. `changesets-release-pr` enters prerelease mode (`changeset pre enter rc`), versions packages (for example `server@5.2.0-rc.0`, `web@2.4.0-rc.0`), allocates cycle `2026.07.01.1`, creates:

   ```text
   .releases/2026.07.01.1/
     cycle.yml
     rc1/manifest.yml    # server-v5.2.0-rc.0, web-v2.4.0-rc.0
     rc1/notes.md
   ```

3. Release PR body shows the rc1 batch (**artifact 1**).
4. Merge → gated publish (prerelease artifact tags) → `staging-2026.07.01.1-rc1` → staging deploy.

## rc2 — soak patch (2026-07-03)

1. Staging QA finds a bug; fix PR adds a `.changeset/` with `Fix: …`.
2. Follow-up release PR stays in prerelease mode and adds **`rc2/`** under the **same** cycle (no new cycle id):

   ```text
   .releases/2026.07.01.1/
     …
     rc2/manifest.yml    # server-v5.2.1-rc.1, web-v2.4.0-rc.0
     rc2/notes.md        # artifact 2 — this cut only
   ```

3. Patch release PR body shows only the fix.
4. Merge → `staging-2026.07.01.1-rc2` → staging deploy.

## Production promotion

1. Staging sign-off on commit with final `rc2/manifest.yml` (still prerelease pins).
2. `promote-prod-release` exits prerelease, versions to stable (`server@5.2.1`, `web@2.4.0`), refreshes `rc2/manifest.yml` pins, sets **`promotedAt`**, writes **`release-notes.md`**, pushes finalize commit, then **`prod-2026.07.01.1`**.
3. Coordinated deploy uses stable pins on the finalize commit.
4. GitHub Release **`2026.07.01.1`** with **`release-notes.md`** body (**artifact 3**).

## Two-environment variant (topology C — dev + gated prod)

Same directory layout and prerelease-at-rc1 rule. Only `rc1/` before prod; if no soak issues, prod finalization is still what exits pre and cuts stable:

```text
.releases/2026.07.01.1/
  cycle.yml
  rc1/manifest.yml
  rc1/notes.md
  release-notes.md   # single section ## 2026.07.01.1-rc1
```

Promotion: `prod-2026.07.01.1` after finalize (no staging promotion tags).

## Staging + prod variant (topology B)

Same RC flow as the main example (rc1, rc2, staging tags), but **no deployed dev environment**—validation is local or in CI before `staging-*-rc<n>`.

## Hotfix (production)

Prod is live on `2026.07.01.1`. An urgent defect is found; `main` may already have an unrelated in-flight cycle on a release PR. This is **not** an `rc2` soak patch—the shipped cycle is closed.

1. Branch from the commit tagged **`prod-2026.07.01.1`**.
2. Fix PR adds a `.changeset/` entry; version cut allocates **new** cycle `2026.07.07.1` with **hotfix** automation (skips prerelease; versions to stable at cut):

   ```text
   .releases/2026.07.07.1/
     cycle.yml              # openedAt; predecessorCycle: 2026.07.01.1
     rc1/manifest.yml       # stable pins (e.g. server-v5.2.2)
     rc1/notes.md           # artifact 1 — hotfix only
     release-notes.md       # artifact 3 — written at prod promotion
   ```

3. Expedited path: merge → gated publish → optional `staging-2026.07.07.1-rc1` → **`prod-2026.07.07.1`** (no pre-exit version step).
4. GitHub Release **`2026.07.07.1`** with `release-notes.md` body; `cycle.yml` gains **`promotedAt`**.
5. **Merge hotfix back to `main`** before the next regular production cycle ships.

Concurrent: an open `.releases/2026.07.20.1/` on `main` is unaffected; hotfix uses its own cycle id and directory.
