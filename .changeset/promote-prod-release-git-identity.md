---
"@chiubaka/circleci-orb": patch
---

Fix: Configure git user identity in `promote-prod-release` so finalize commits and annotated prod tags succeed on CircleCI Docker executors without a consumer pre-step.
