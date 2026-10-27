---
"@chiubaka/circleci-orb": minor
---

Improvement: Prefer `GITHUB_PACKAGES_READ_TOKEN` for GitHub Packages install auth; when `registry-access` is `publish`, prefer write-capable `GITHUB_PACKAGES_TOKEN` / `GITHUB_TOKEN` so a read-only install token does not block publish.

Expose `GITHUB_PACKAGES_READ_TOKEN` from the `github-packages-read` CircleCI context. `mint-github-token` preserves a pre-mint packages-read credential under the new name (and the deprecated alias) so install still works after App mint.
