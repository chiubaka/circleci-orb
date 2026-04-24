---
"@chiubaka/circleci-orb": patch
---

Skip pnpm workspace root in `upload_monorepo_coverage` Codecov uploads

The `uploadMonorepoCoverageWithCodecovCli` script no longer passes the entire coverage
root to Codecov under the workspace root package name, avoiding duplicate per-package
uploads and collisions with path-scoped Codecov `flags` that reuse that name. Each leaf
package still uploads when `reports/coverage/<relpath>` exists. Tests and the orb command
description were updated to match.
