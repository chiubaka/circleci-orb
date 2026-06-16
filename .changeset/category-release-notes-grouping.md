---
"@chiubaka/circleci-orb": minor
---

Feature: Add opt-in category-based release note grouping for application monorepos.

Introduces `release-notes-grouping: category` on changesets release PR and GitHub release train commands, a post-version changelog rewriter, and category-aware batch note formatting (Features / Improvements / Bug Fixes / Other Changes). Adds `require-changeset-category-prefix` on verify-changesets for application monorepos. Default bump-type (Major / Minor / Patch) behavior is unchanged.
