---
"@chiubaka/circleci-orb": minor
---

Add release manifest and coordinated deploy surface for application monorepos: shared UTC train id module, opt-in `create-release-manifest` on changesets release PR, `verify-release-manifest`, `coordinated-deploy` (commit-primary), and optional `promotion-tag-prefix` on gated publish. Library consumers keep prior defaults with no required config changes.
