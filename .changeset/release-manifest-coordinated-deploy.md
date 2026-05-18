---
"@chiubaka/circleci-orb": minor
---

Add release manifest support and coordinated deploy for application monorepos.

Introduces a shared UTC train id module, opt-in `create-release-manifest` on the changesets release PR job, `verify-release-manifest`, commit-primary `coordinated-deploy`, and optional `promotion-tag-prefix` on gated publish. Library consumers keep prior defaults with no required config changes.
