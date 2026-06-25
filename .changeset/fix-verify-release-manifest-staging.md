---
"@chiubaka/circleci-orb": patch
---

Fix `verify-release-manifest` by staging `validateReleaseManifest.mjs` to `/tmp` before the PR check runs, matching the `verify-changesets` pattern. Repos without `.releases/` manifests now skip cleanly; repos with manifests validate via `VALIDATE_RELEASE_MANIFEST_SCRIPT`.
