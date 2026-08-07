---
"@chiubaka/circleci-orb": patch
---

Fix: Forward `primary-branch` from `promote-prod-release` into nested `setup` so Turbo SCM base uses the configured primary branch instead of defaulting to `master`.
