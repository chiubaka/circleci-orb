---
"@chiubaka/circleci-orb": patch
---

Fix: Stage orb helper scripts for CircleCI consumers (release manifest writer and train id helpers).

- Stage writeReleaseManifest.mjs for changesets-release-pr when create-release-manifest is enabled (WRITE_RELEASE_MANIFEST_SCRIPT).
- Stage lib/trainId.sh for github-release-train (TRAIN_ID_SCRIPT).
- Remove unused fatal trainId source from push-promotion-tag so promotion tags work when the script is inlined without lib/ on disk.
