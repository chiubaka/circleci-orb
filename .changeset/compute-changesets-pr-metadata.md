---
"@chiubaka/circleci-orb": minor
---

Feature: Add optional `include-pr-metadata` for PR continuation parameters.

CircleCI setup workflows do not propagate `CIRCLE_PULL_REQUEST` / `CIRCLE_PR_NUMBER` into continuation pipelines; opt in when downstream jobs (for example Codecov PR association) need that context.
