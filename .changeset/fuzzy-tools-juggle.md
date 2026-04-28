---
"@chiubaka/circleci-orb": patch
---

Normalize monorepo package-derived Codecov flags to valid Codecov flag names.

Scoped package names now default to the post-scope segment for Codecov flags (for example `@chiubaka/lint` becomes `lint`) so monorepo coverage uploads align with package identities. When unscoped names collide, uploads fall back to a scope-prefixed flag only if it resolves the collision; unresolved collisions now fail loudly so you can fix naming deterministically.
