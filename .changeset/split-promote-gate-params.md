---
"@chiubaka/circleci-orb": minor
---

Fix: Stop finalize commits from re-opening gated publish and promote-prod via split continuation parameters.

`compute-changesets-publish-parameters` now emits `run-changesets-publish` only for version-packages release merges (path signal + subject) and adds `offer-promote-prod` when that merge still has an open `.releases/<cycle-id>` cycle (no `promotedAt`). Gate `promote-prod` on `offer-promote-prod`, not the publish flag alone.
