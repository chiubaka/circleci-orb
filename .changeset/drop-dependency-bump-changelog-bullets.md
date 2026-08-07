---
"@chiubaka/circleci-orb": patch
---

Fix: Drop Changesets dependency-bump changelog bullets (`Updated dependencies` and bare `pkg@version`) during category rewrite so `promote-prod-release` no longer fails on internal workspace bumps.
