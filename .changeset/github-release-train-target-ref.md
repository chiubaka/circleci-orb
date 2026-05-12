---
"@chiubaka/circleci-orb": patch
---

`runGithubReleaseTrain` only uses `CIRCLE_SHA1` as the release target when that commit exists in the current repository, so Bats fixtures (and other secondary clones) on CircleCI fall back to `HEAD` instead of inheriting the pipeline checkout SHA.
