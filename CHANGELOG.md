# @chiubaka/circleci-orb

## 0.16.0

### Minor Changes

- ab4752f: Switch monorepo coverage upload to direct Codecov CLI v5 mechanics while preserving per-package monorepo uploads.

  **BREAKING CHANGE**: Replace legacy passthrough parameters with explicit Codecov options (`fail-on-error`, `verbose`, `disable-search`, `files`, `flags`) for per-package uploads. Tokenless mode is supported when `CODECOV_TOKEN` is unset.
  See `README.md` Migration Notes (`v0.16.0`) for parameter mapping and before/after examples.

### Patch Changes

- 0b7fbd9: Skip pnpm workspace root in `upload_monorepo_coverage` Codecov uploads

  The `uploadMonorepoCoverageWithCodecovCli` script no longer passes the entire coverage
  root to Codecov under the workspace root package name, avoiding duplicate per-package
  uploads and collisions with path-scoped Codecov `flags` that reuse that name. Each leaf
  package still uploads when `reports/coverage/<relpath>` exists. Tests and the orb command
  description were updated to match.

## 0.15.0

### Minor Changes

- 76ca761: Add reusable Changesets changelog CI workflow.

  Includes dynamic CircleCI continuation and the
  `compute-changesets-publish-parameters` command for reuse across repositories.

### Patch Changes

- 343d1fa: Fix release PR push when branch lease is stale.

  Updates the release PR script to recover from stale
  `--force-with-lease` push failures by re-fetching and retrying safely.
  Adds Bats coverage for lease argument construction when remote release
  branches exist or are absent.

- d63f6a1: Include excerpts from newly added CHANGELOG files in release PR bodies.

  Fixes release PR body generation so changelog excerpts are collected from both tracked diffs and untracked files created by `changeset version`.

- 0442bd4: Require verify-changesets PR branches to touch a changeset markdown file.

  The default `verify-changesets` path now checks for `.changeset/*.md` changes against
  the configured primary branch before running `changeset status`, preventing false
  passes on branches that only inherit pending changesets from their base.
