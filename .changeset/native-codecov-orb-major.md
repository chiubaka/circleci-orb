---
"@chiubaka/circleci-orb": minor
---

Switch monorepo coverage upload to native `codecov/upload` mechanics from the Codecov v5 orb.

**BREAKING CHANGE**: Replace custom uploader scripts and legacy passthrough parameters with explicit `codecov/upload` options (`codecov-cli-version`, `fail-on-error`, `verbose`, `disable-search`, `files`, `flags`). Tokenless mode is supported when `CODECOV_TOKEN` is unset.
See `README.md` Migration Notes (`v0.16.0`) for parameter mapping and before/after examples.
