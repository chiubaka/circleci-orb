---
"@chiubaka/circleci-orb": patch
---

Include excerpts from newly added CHANGELOG files in release PR bodies.

Fixes release PR body generation so changelog excerpts are collected from both tracked diffs and untracked files created by `changeset version`.
