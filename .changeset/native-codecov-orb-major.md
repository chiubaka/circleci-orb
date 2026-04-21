---
"@chiubaka/circleci-orb": minor
---

Switch monorepo coverage upload to direct Codecov CLI v5 mechanics while preserving per-package monorepo uploads.

**BREAKING CHANGE**: Replace legacy passthrough parameters with explicit Codecov options (`fail-on-error`, `verbose`, `disable-search`, `files`, `flags`) for per-package uploads. Tokenless mode is supported when `CODECOV_TOKEN` is unset.
See `README.md` Migration Notes (`v0.16.0`) for parameter mapping and before/after examples.
