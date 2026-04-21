---
"@chiubaka/circleci-orb": patch
---

Require verify-changesets PR branches to touch a changeset markdown file.

The default `verify-changesets` path now checks for `.changeset/*.md` changes against
the configured primary branch before running `changeset status`, preventing false
passes on branches that only inherit pending changesets from their base.
