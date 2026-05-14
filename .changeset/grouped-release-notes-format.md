---
"@chiubaka/circleci-orb": patch
---

Group GitHub Release train and release PR bodies by Changesets bump category with published versions.

Release notes and PR bodies now use Major / Minor / Patch sections, one package bullet per section with nested change bullets, and a Published versions list. Consumer CircleCI jobs stage the formatter via a dedicated script because orb `include` must be the entire command string.
