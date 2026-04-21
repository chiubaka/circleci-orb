---
"@chiubaka/circleci-orb": patch
---

Fix release PR push when branch lease is stale.

Updates the release PR script to recover from stale
`--force-with-lease` push failures by re-fetching and retrying safely.
Adds coverage for the retry behavior in the Bats test suite.
