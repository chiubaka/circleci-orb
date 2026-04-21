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
- Migrated `upload-monorepo-coverage` to native `codecov/upload` mechanics with explicit Codecov options.

`upload-monorepo-coverage` parameter migration:

- Removed: `validate`, `version`, `xtra_args`
- Added: `codecov-cli-version`, `fail-on-error`, `verbose`, `disable-search`, `files`, `flags`

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
    codecov-cli-version: latest
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
1. Merge pull requests with desired changes to the main branch.
    - For the best experience, squash-and-merge and use [Conventional Commit Messages](https://conventionalcommits.org/).
2. Find the current version of the orb.
    - You can run `circleci orb info chiubaka/circleci-orb | grep "Latest"` to see the current version.
3. Create a [new Release](https://github.com/chiubaka/circleci-orb/releases/new) on GitHub.
    - Click "Choose a tag" and _create_ a new [semantically versioned](http://semver.org/) tag. (ex: v1.0.0)
      - We will have an opportunity to change this before we publish if needed after the next step.
4.  Click _"+ Auto-generate release notes"_.
    - This will create a summary of all of the merged pull requests since the previous release.
    - If you have used _[Conventional Commit Messages](https://conventionalcommits.org/)_ it will be easy to determine what types of changes were made, allowing you to ensure the correct version tag is being published.
5. Now ensure the version tag selected is semantically accurate based on the changes included.
6. Click _"Publish Release"_.
    - This will push a new tag and trigger your publishing pipeline on CircleCI.

## Development

### Project Setup
1. Clone this repository
2. Run `yarn install` in the project root
3. Install `yamllint` on the system for linting support