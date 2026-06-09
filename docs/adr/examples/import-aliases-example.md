# Import Aliases Example

Illustrative usage for ADR 0010 and ADR 0011:

```ts
// package-local production code
import { User } from "~/users/domain/User";

// package-local test helper
import { makeUserFixture } from "#/users/helpers/makeUserFixture";

// cross-package public API
import { createBackend } from "@scope/backend";
```

Interpretation:

- `~/` resolves to `src/*`.
- `#/` resolves to `test/*`.
- `@scope/pkg` imports cross package boundaries through public APIs.

## Rejected alternatives (do not use)

These patterns were discussed and **rejected**; see [ADR 0010](../0010-import-specifier-conventions-for-monorepo-packages.md), [ADR 0011](../0011-test-import-alias-hash-root.md), and [ADR 0017](../0017-workspace-library-dist-boundary-and-dev-watch.md).

| Tempting pattern                                                 | Why we avoid it                                                                                                                                                  |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@scope/pkg/internal/...` inside `@scope/pkg` instead of `~/...` | Looks like a real cross-package import; blurs `exports`; does not fix merged graphs or ESLint program size when consumers map to `src/`.                         |
| `@scope/pkg/test/...` instead of `#/...`                         | Looks like a published subpath of `@scope/pkg`.                                                                                                                  |
| Consumer `paths`: `@scope/pkg` → sibling `src/`                  | Merges transitive dependency source into the consumer TS graph; breaks `~/` unless you add foreign alias shims; types can run ahead of stale `dist/` at runtime. |

Use **`dist/` + library `dev` watch** for cross-package iteration, not package-scoped internals or consumer `paths` into dependency `src/`.
