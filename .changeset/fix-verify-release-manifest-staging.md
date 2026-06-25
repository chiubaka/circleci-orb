---
"@chiubaka/circleci-orb": patch
---

Fix: Stage `validateReleaseManifest.mjs` for `verify-release-manifest` in CircleCI consumers so sibling `.mjs` files are not required on disk. Repos without `.releases/` manifests skip cleanly; repos with manifests validate via `VALIDATE_RELEASE_MANIFEST_SCRIPT`.
