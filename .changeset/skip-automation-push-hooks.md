---
"@chiubaka/circleci-orb": patch
---

Fix: Skip git hooks on automation `git push` so consumer pre-push hooks do not run during release jobs.
