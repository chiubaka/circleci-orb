---
"@chiubaka/circleci-orb": minor
---

Fix: Stop finalize commits from re-opening gated publish and promote-prod via split continuation parameters.

`compute-changesets-publish-parameters` now emits `run-changesets-publish` only for version-packages release merges (path signal + subject) and adds `offer-promote-prod` when that merge’s tip-commit release cycle (same highest `.releases/<cycle-id>/rc<n>` resolution as `promote-prod-release`) still has no non-empty `promotedAt`. Gate `promote-prod` on `offer-promote-prod`, not the publish flag alone.
