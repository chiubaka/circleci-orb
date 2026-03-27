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
