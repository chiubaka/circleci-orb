---
"@chiubaka/circleci-orb": patch
---

Normalize monorepo package-derived Codecov flags to valid Codecov flag names.

Scoped package names now upload with normalized flags (for example `@chiubaka/lint` becomes `chiubaka-lint`) so monorepo coverage uploads do not fail on invalid flag characters. If your `codecov.yml` uses `individual_flags`, update names to the normalized values used by uploads.
