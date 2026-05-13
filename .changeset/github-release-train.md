---
"@chiubaka/circleci-orb": minor
---

`changesets-gated-publish` now defaults to creating a GitHub Release after publish: UTC train id `YYYY.MM.DD.N` as the release title, git tag `release/YYYY.MM.DD.N` by default, and notes from merged `CHANGELOG.md` diffs. Repos can set `create-github-release: false` to opt out.
