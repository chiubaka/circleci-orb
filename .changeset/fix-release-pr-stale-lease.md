---
"@chiubaka/circleci-orb": patch
---

Fix release PR push when branch lease is stale.

Updates the release PR script to recover from stale
`--force-with-lease` push failures by re-fetching and retrying safely.
Adds Bats coverage for lease argument construction when remote release
branches exist or are absent.
