---
"@chiubaka/circleci-orb": patch
---

Fix: Keep production GitHub Release notes as a rollup of RC snapshots and only rewrite Published versions to stable semver, so internal workspace packages and nested dependency lines are not added at finalize.
