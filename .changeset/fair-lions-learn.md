---
"@chiubaka/circleci-orb": patch
---

Harden Codecov CLI installation when Python environments do not include the pip module.

The monorepo coverage upload command now tries `python3 -m pip`, then `python3 -m ensurepip`, and finally `pip3` before failing with an actionable error. This avoids failing immediately on images that provide Python but omit `python3 -m pip`.
