---
"@chiubaka/circleci-orb": patch
---

Fix: Emit markdownlint-compliant blank lines around changelog headings after category rewrite.

`rewriteChangelogCategories` now joins rewritten version blocks with blank lines before and after `##` and `###` headings so generated `CHANGELOG.md` files pass `markdown/blanks-around-headings` (MD022) under `@chiubaka/eslint-config`.
