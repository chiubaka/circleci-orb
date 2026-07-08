---
"@chiubaka/circleci-orb": patch
---

Fix: Materialize release-cycle scripts via embedded heredocs in `stageReleaseCycleWriter.sh` so CircleCI consumers no longer fail with `cp: cannot stat '/bin/lib/releaseCycle.mjs'` when orb commands inline the staging step. Stage manifest validator scripts for `coordinated-deploy` and inline promotion-tag parsing so commit-primary deploy workflows work without sibling files on disk.
