---
name: external-api-integration
description: >-
  Separates low-level HTTP/API clients from domain services when integrating
  third-party or internal HTTP APIs. Use when adding/refactoring API
  integrations, SDK wrappers, fetch-based clients, webhooks, or any code that
  calls a remote API from application logic in an org-standard architecture.
---

# External API integration

## Goal

Keep **transport and wire-format concerns** in a dedicated **API client** layer, and **domain or port adapters** in a **service** (or use-case) layer that translates between your app’s abstractions and the client.

## Relevant org ADRs

- `org/docs/adr/0005-composition-roots-and-wiring-boundaries.md`:
  keep wiring and assembly at composition roots; keep domain/application behavior transport-agnostic.
- `org/docs/adr/0006-consistency-and-extension-for-new-features.md`:
  prefer extending existing integration idioms instead of inventing new one-off patterns.
- `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`:
  place client implementations in `infrastructure/` and orchestration/ports in `application/`.
- `org/docs/adr/0012-classes-as-primary-responsibility-boundaries.md` and
  `org/docs/adr/0013-use-of-classes-vs-module-level-functions-and-interfaces.md`:
  use classes for orchestration-heavy ownership boundaries; keep pure transforms as module-level helpers.
- `org/docs/adr/0009-prefer-small-focused-files.md`:
  keep API client and service files focused with one primary export where practical.

## API client layer

**Owns:**

- Base URL, auth headers, timeouts, retries (if any), injectable `fetch` (or HTTP library).
- One method per meaningful remote operation, with **request/response shapes that mirror the provider’s API** (names and nesting aligned with official docs where practical).
- JSON serialization/deserialization of **raw API bodies**; small **response helpers** that extract stable fields from parsed JSON (e.g. assistant text from a chat-completions response).
- Mapping HTTP failures and malformed bodies to clear errors **without** leaking secrets (tokens) into messages or logs.

**Avoids:**

- Business rules, Zod validation of *application* DTOs, or mapping from domain models **unless** that mapping is purely “API DTO ↔ JSON” for that provider.

## Service / adapter layer

**Owns:**

- Implementing ports (`LlmService`, repository interfaces, etc.).
- Translating **your** types (`LlmResponseRequest`, domain commands) into **client request bodies**, and interpreting client results (e.g. Zod `parse` for structured outputs, empty-content checks with domain-appropriate errors).
- Logging at the application boundary (paths, models, correlation ids)—**not** API keys.

Thin adapters are fine: if the port maps 1:1 to one client call, the service may delegate with minimal glue.

## Ergonomics vs fidelity

- Prefer **types and method names** that match the vendor’s API so diffs and docs stay comparable.
- Add **small conveniences** only when they reduce duplication without hiding important request fields (e.g. shared `postJson` with consistent error handling).

## Tests

- **Client tests:** mock `fetch`; assert URL, method, headers shape, and JSON body; assert parsing helpers on fixed JSON fixtures.
- **Service tests:** mock the **client** or `fetch` at the boundary you care about; assert domain behavior (validation, mapping, error messages).

## Illustrative portable example

```ts
// infrastructure/vendor/VendorApiClient.ts
export class VendorApiClient {
  constructor(private readonly fetchImpl: typeof fetch, private readonly baseUrl: string) {}

  async createWidget(request: { title: string }): Promise<{ id: string; title: string }> {
    const response = await this.fetchImpl(`${this.baseUrl}/widgets`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      throw new Error(`Vendor API createWidget failed with status ${response.status}`);
    }

    const json = (await response.json()) as { id: string; title: string };
    return { id: json.id, title: json.title };
  }
}

// application/WidgetService.ts
export class WidgetService {
  constructor(private readonly vendorClient: VendorApiClient) {}

  async create(command: { name: string }): Promise<{ widgetId: string; displayName: string }> {
    const apiResult = await this.vendorClient.createWidget({ title: command.name });
    return { widgetId: apiResult.id, displayName: apiResult.title };
  }
}
```

The point of the split:
- `VendorApiClient` owns HTTP details and raw provider DTO shape.
- `WidgetService` owns app-level command/result shape and business-facing mapping.
