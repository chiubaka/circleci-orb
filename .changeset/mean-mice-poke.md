---
"@chiubaka/circleci-orb": patch
---

Fail Codecov monorepo uploads loudly by default when uploads fail or do not happen.

`upload-monorepo-coverage` now defaults `fail-on-error` and `verbose` to `true`, and adds `require-uploads` (default `true`) so CI fails when no per-package coverage uploads occur. Set `require-uploads: false` only for workflows where empty uploads are expected.
