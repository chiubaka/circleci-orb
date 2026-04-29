---
"@chiubaka/circleci-orb": patch
---

Install the Codecov CLI the same way as the official [codecov/codecov](https://circleci.com/orbs/registry/orb/codecov/codecov) orb: download the `codecov` binary from `https://cli.codecov.io` (per [codecov/wrapper](https://github.com/codecov/wrapper) `download.sh`), then verify with GPG and SHA256 (per `validate.sh`) unless `CODECOV_SKIP_VALIDATION` is set. Pip is no longer used.

`upload-monorepo-coverage` accepts `codecov-version`, `skip-codecov-cli-validation`, and an optional `codecov-cli-base-url` (`CODECOV_CLI_URL`). The default for `fail-on-error` is restored to `true`.
