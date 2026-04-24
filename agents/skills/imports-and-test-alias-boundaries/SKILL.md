---
name: imports-and-test-alias-boundaries
description: >-
  Applies org import conventions so production, test, and cross-package imports
  remain explicit and boundary-safe (`~/`, `#/`, and package public APIs).
---

# Imports and test alias boundaries

## Goal

Keep import intent unambiguous:

- `~/` for package-local production source.
- `#/` for package-local test code.
- `@scope/pkg` (or equivalent package names) for cross-package public APIs.

## Relevant org ADRs

- `org/docs/adr/0010-import-specifier-conventions-for-monorepo-packages.md`
- `org/docs/adr/0011-test-import-alias-hash-root.md`
- `org/docs/adr/0008-barrel-files-public-api-boundaries.md`
- `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`

## When to use this skill

Use this skill when:

- Adding or refactoring imports after file moves.
- Setting up package alias config for new or migrated packages.
- Fixing test imports and source/test boundary violations.
- Reviewing deep imports across features/packages.

## Rules to enforce

1. Use `~/...` only for package-local production source imports.
2. Use `#/...` only for package-local test imports.
3. Do not import `#/...` from production `src/` code.
4. Use package public APIs for cross-package imports; avoid deep subpath imports unless explicitly allowed.
5. Avoid deep relative traversal when alias imports provide a clearer boundary.

## Configuration parity checklist

- [ ] TypeScript paths map `~/*` and `#/*` to the intended roots.
- [ ] Test runner alias resolution matches TypeScript behavior.
- [ ] Lint rules enforce production/test boundary constraints.
- [ ] Source code does not depend on test-only modules.

## Common mistakes to avoid

- Using `~/` to import test helpers.
- Importing another package internals via deep subpaths.
- Keeping stale relative imports after moving files.
- Letting test convenience imports leak into production modules.

## Illustrative import examples

```ts
// Production file
import { createUser } from "~/application/CreateUser";
import { UsersApi } from "@scope/users-api";

// Test file
import { userFixture } from "#/helpers/userFixture";
import { createUser } from "~/application/CreateUser";
```
