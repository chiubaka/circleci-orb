# @chiubaka/circleci-orb

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
