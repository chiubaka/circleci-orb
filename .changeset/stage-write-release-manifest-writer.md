---
"@chiubaka/circleci-orb": patch
---

Fix: Stage writeReleaseManifest.mjs for changesets-release-pr when create-release-manifest is enabled.

CircleCI consumers no longer fail with "writeReleaseManifest.mjs not found" because the orb materializes the manifest writer to /tmp and sets WRITE_RELEASE_MANIFEST_SCRIPT, matching the verify-release-manifest staging pattern.
