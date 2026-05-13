# Orb Template


[![CircleCI Build Status](https://circleci.com/gh/chiubaka/circleci-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/chiubaka/circleci-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/chiubaka/circleci-orb.svg)](https://circleci.com/orbs/registry/orb/chiubaka/circleci-orb) [![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://raw.githubusercontent.com/chiubaka/circleci-orb/master/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)



A project template for Orbs.

This repository is designed to be automatically ingested and modified by the CircleCI CLI's `orb init` command.

_**Edit this area to include a custom title and description.**_

---

## Migration Notes

### v0.16.0

`v0.16.0` includes a Codecov upgrade and a breaking API change for monorepo coverage uploads.

- Upgraded Codecov orb from `codecov/codecov@3.2.3` to `codecov/codecov@5.4.3`.
- Migrated `upload-monorepo-coverage` to direct Codecov CLI v5 mechanics with explicit options, preserving per-package monorepo upload behavior.

`upload-monorepo-coverage` parameter migration:

- Removed: `validate`, `version`, `xtra_args`
- Added: `fail-on-error`, `verbose`, `disable-search`, `files`, `flags`

Before:

```yaml
- chiubaka/upload-monorepo-coverage:
    app-dir: .
    monorepo-root: .
    coverage-dir: reports/coverage
    validate: true
    version: latest
    xtra_args: "-v -Z"
```

After:

```yaml
- chiubaka/upload-monorepo-coverage:
    app-dir: .
    monorepo-root: .
    coverage-dir: reports/coverage
    fail-on-error: true
    verbose: true
    disable-search: true
    files: "coverage.xml,coverage-final.json"
    flags: "unit,monorepo"
```

## Resources

[CircleCI Orb Registry Page](https://circleci.com/orbs/registry/orb/chiubaka/circleci-orb) - The official registry page of this orb for all versions, executors, commands, and jobs described.

[CircleCI Orb Docs](https://circleci.com/docs/2.0/orb-intro/#section=configuration) - Docs for using, creating, and publishing CircleCI Orbs.

### How to Contribute

We welcome [issues](https://github.com/chiubaka/circleci-orb/issues) to and [pull requests](https://github.com/chiubaka/circleci-orb/pulls) against this repository!

### How to Publish An Update

1. Land changes on `master` (squash-and-merge is recommended; use [Conventional Commits](https://conventionalcommits.org/) where helpful).
2. When [Changesets](https://github.com/changesets/changesets) has pending entries, CI opens a release PR (`changesets-release-pr`). **Squash-merge** that PR using the default title prefix `chore(release): version packages` so `changesets-gated-publish` can assert the merge.
3. The gated publish job runs `changeset publish` (or this repo’s `release:orb` script), pushes the orb semver tag `vX.Y.Z` for registry consumers, then **by default** creates a **GitHub Release** whose title is the UTC train id `YYYY.MM.DD.N`, a matching git tag `release/YYYY.MM.DD.N`, and release notes built from the merged `CHANGELOG.md` diff. Set `create-github-release: false` on `chiubaka/changesets-gated-publish` if a repo opts out.
4. Production orb registry releases still follow the `orb-tools/publish` workflow on semver tags `vX.Y.Z` (see [CircleCI orb registry](https://circleci.com/orbs/registry/orb/chiubaka/circleci-orb)); train tags do not replace that contract.

## Development

### Project Setup
1. Clone this repository
2. Run `yarn install` in the project root
3. Install `yamllint` on the system for linting support