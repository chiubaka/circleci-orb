---
"@chiubaka/circleci-orb": minor
---

Feature: Add category-based release note grouping with expanded prefix taxonomy for all Changesets monorepos.

Introduces `release-notes-grouping: category` (now the default) on changesets release PR and GitHub release train commands, a post-version changelog rewriter, and category-aware batch note formatting under Breaking Changes / Security / Features / Improvements / Bug Fixes / Deprecations / Other Changes. Adds `require-changeset-category-prefix: true` (now the default) on verify-changesets. Set `release-notes-grouping: bump-type` and `require-changeset-category-prefix: false` to retain legacy Major / Minor / Patch behavior.
