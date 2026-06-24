---
"@chiubaka/circleci-orb": minor
---

Add optional `include-pr-metadata` on `compute-changesets-publish-parameters` to forward `circle_pull_request` and `circle_pr_number` into continuation pipeline parameters.

CircleCI setup workflows do not propagate `CIRCLE_PULL_REQUEST` / `CIRCLE_PR_NUMBER` into continuation pipelines; opt in when downstream jobs (for example Codecov PR association) need that context.
