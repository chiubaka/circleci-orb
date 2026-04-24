# Composition Root Example

Illustrative shape for ADR 0005 (composition roots at the edges):

```text
apps/server/src/
  index.ts
  composition/
    installServices.ts
    installRoutes.ts
  infrastructure/http/
    createHttpApp.ts
```

Typical flow:

1. `index.ts` reads environment/config and calls `installServices`.
2. `installServices` wires concrete adapters and facades.
3. `installRoutes` maps HTTP requests to application-facing calls.
4. Domain and application modules remain free of HTTP and container framework APIs.
