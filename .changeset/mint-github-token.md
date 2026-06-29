---
"@chiubaka/circleci-orb": minor
---

Feature: Add mint-github-token command to export GITHUB_TOKEN from a GitHub App or an existing PAT.

When `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, and `GITHUB_APP_INSTALLATION_ID` are set, mints a short-lived installation access token and exports it as `GITHUB_TOKEN` and `GH_TOKEN` (including via `BASH_ENV` for later steps). When those app variables are unset and `GITHUB_TOKEN` is already provided, passes it through unchanged.
