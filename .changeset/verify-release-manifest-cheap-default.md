---
"@chiubaka/circleci-orb": patch
---

Fix: Run verify-release-manifest without a full pnpm install by default, and only validate .releases cycles that changed vs the primary-branch merge base.
