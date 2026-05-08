---
"@chiubaka/circleci-orb": patch
---

Fix monorepo Codecov CLI install and upload invocation on minimal CI images.

Replaces pip with the official `codecov` binary from `https://cli.codecov.io`, matching codecov/wrapper download and validate behavior (GPG + SHA256 unless `CODECOV_SKIP_VALIDATION` is set). `upload-monorepo-coverage` adds `codecov-version`, `skip-codecov-cli-validation`, and `codecov-cli-base-url`; `fail-on-error` defaults to `true`.

Fixes two regressions encountered after switching to the binary: `sha256sum`/`shasum -c` printed `codecov: OK` to stdout, which Bash command substitution mixed into the resolved CLI path so the shell tried to run `codecov: OK`; checksum verification now silences stdout. Also passes verbosity as global `codecov -v` because `upload-coverage` on that binary does not accept `--verbose` (unlike older `codecovcli` usage).
