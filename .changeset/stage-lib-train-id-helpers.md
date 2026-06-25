---
"@chiubaka/circleci-orb": patch
---

Fix: Stage lib/trainId.sh for github-release-train and unblock push-promotion-tag in CircleCI consumers.

Stage UTC train id bash helpers to /tmp (TRAIN_ID_SCRIPT) for github-release-train, and remove an unused fatal trainId source from push-promotion-tag so promotion-tag-prefix works when orb scripts are inlined without lib/ on disk.
