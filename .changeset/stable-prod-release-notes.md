---
"@chiubaka/circleci-orb": patch
---

Fix: Rebuild production GitHub Release notes from stable changelogs after prerelease exit so Published versions no longer retain RC suffixes.

`promote-prod-release` now passes post-exit CHANGELOG paths to `finalizeReleaseCycle`, which formats cycle `release-notes.md` from stable package versions instead of rolling up RC snapshots that still list `-rc.*` pins.
