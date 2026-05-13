# @chiubaka/circleci-orb

## 0.17.0

### Minor Changes

- e16d1b2: `changesets-gated-publish` now defaults to creating a GitHub Release after publish: UTC train id `YYYY.MM.DD.N` as the release title, git tag `release/YYYY.MM.DD.N` by default, and notes from merged `CHANGELOG.md` diffs. Repos can set `create-github-release: false` to opt out.

## 0.16.2

### Patch Changes

- 97feada: Fix monorepo Codecov CLI install and upload invocation on minimal CI images.

  Replaces pip with the official `codecov` binary from `https://cli.codecov.io`, matching codecov/wrapper download and validate behavior (GPG + SHA256 unless `CODECOV_SKIP_VALIDATION` is set). `upload-monorepo-coverage` adds `codecov-version`, `skip-codecov-cli-validation`, and `codecov-cli-base-url`; `fail-on-error` defaults to `true`.

  Fixes two regressions encountered after switching to the binary: `sha256sum`/`shasum -c` printed `codecov: OK` to stdout, which Bash command substitution mixed into the resolved CLI path so the shell tried to run `codecov: OK`; checksum verification now silences stdout. Also passes verbosity as global `codecov -v` because `upload-coverage` on that binary does not accept `--verbose` (unlike older `codecovcli` usage).

- 90a926d: Skip git hooks for Changesets release PR commits so CI can commit without system tools like yamllint.

  Release automation runs `git commit` on a minimal Node image; Husky pre-commit previously invoked `pnpm lint`, which failed when `yamllint` was not installed.

## 0.16.1

### Patch Changes

- 164958d: Normalize monorepo package-derived Codecov flags to valid Codecov flag names.

  Scoped package names now default to the post-scope segment for Codecov flags (for example `@chiubaka/lint` becomes `lint`) so monorepo coverage uploads align with package identities. When unscoped names collide, uploads fall back to a scope-prefixed flag only if it resolves the collision; unresolved collisions now fail loudly so you can fix naming deterministically.

- 626eef6: Fail Codecov monorepo uploads loudly by default when uploads fail or do not happen.

  `upload-monorepo-coverage` now defaults `fail-on-error` and `verbose` to `true`, and adds `require-uploads` (default `true`) so CI fails when no per-package coverage uploads occur. Set `require-uploads: false` only for workflows where empty uploads are expected.

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
