---
"@chiubaka/circleci-orb": patch
---

Fix Codecov CLI GPG verification by importing the PGP key from the current keybase account (`codecovsecops`).

The previous keybase account was retired and returned no key, which caused the `test` job coverage upload step to fail GPG signature verification.
