---
"@chiubaka/circleci-orb": patch
---

Fix: Skip empty, stub, and zero-hit monorepo coverage reports in `upload-monorepo-coverage` so Codecov carryforward flags are not poisoned by stale sibling uploads.
