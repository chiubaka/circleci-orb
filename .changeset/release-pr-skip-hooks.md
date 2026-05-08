---
"@chiubaka/circleci-orb": patch
---

Skip git hooks for Changesets release PR commits so CI can commit without system tools like yamllint.

Release automation runs `git commit` on a minimal Node image; Husky pre-commit previously invoked `pnpm lint`, which failed when `yamllint` was not installed.
