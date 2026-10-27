---
"@chiubaka/circleci-orb": minor
---

Improvement: Prefer `GITHUB_PACKAGES_READ_TOKEN` for GitHub Packages install auth (deprecated `GITHUB_PACKAGES_TOKEN` and legacy `GITHUB_TOKEN` remain fallbacks).

Expose `GITHUB_PACKAGES_READ_TOKEN` from the `github-packages-read` CircleCI context. `mint-github-token` preserves a pre-mint packages-read credential under the new name (and the deprecated alias) so install still works after App mint.
