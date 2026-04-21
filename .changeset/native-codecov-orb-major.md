---
"@chiubaka/circleci-orb": minor
---

Switch monorepo coverage upload to CircleCI's native Codecov orb workflow.

**BREAKING CHANGE**: Replace custom upload logic with `codecov/upload`, including tokenless mode and explicit orb setup in CI config.
