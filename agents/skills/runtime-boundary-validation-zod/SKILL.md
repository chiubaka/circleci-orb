---
name: runtime-boundary-validation-zod
description: >-
  Standardizes parse-then-validate handling for untrusted JSON at runtime using
  Zod, including external API payloads and structured LLM responses.
---

# Runtime boundary validation with Zod

## Goal

Ensure all untrusted JSON crossing system boundaries is validated at runtime before business logic consumes it.

## Relevant org ADRs

- `org/docs/adr/0002-zod-for-runtime-json-validation.md`
- `org/docs/adr/0005-composition-roots-and-wiring-boundaries.md`
- `org/docs/adr/0007-vertical-feature-modules-hexagonal-slices-and-packages.md`

## When to use this skill

Use this skill for:

- External HTTP/API payload parsing.
- LLM structured output handling.
- Runtime config/environment-derived JSON.
- Webhook and tool-output ingestion.

## Core rule

At each trust boundary: parse data, validate with Zod, then pass typed output into application/domain logic.

## Implementation flow

1. Define a focused Zod schema for the boundary payload.
2. Parse the raw payload (JSON/text/object) into an unknown value.
3. Run `safeParse` (or equivalent guarded parse) with the schema.
4. On failure, return/throw a clear boundary error without leaking secrets.
5. On success, pass only validated typed data to downstream logic.

## Placement guidance

- Keep raw transport parsing near infrastructure/adapter boundaries.
- Keep orchestration decisions in application services.
- Avoid pushing unvalidated payloads into domain/application layers.

## Common mistakes to avoid

- Casting (`as SomeType`) untrusted payloads without validation.
- Mixing schema validation with unrelated business rules in one giant function.
- Logging entire raw payloads that may contain secrets or sensitive content.
- Duplicating schema shape in prompt prose when structured interfaces already define output shape.

## Lightweight review checklist

- [ ] New trust boundary has a Zod schema.
- [ ] Runtime validation happens before domain/application consumption.
- [ ] Error handling is explicit and sanitized.
- [ ] Validated data shape, not raw JSON, is passed downstream.
- [ ] Schema scope is focused to one payload contract.

## Illustrative portable snippet

```ts
import { z } from "zod";

const WidgetSchema = z.object({
  id: z.string(),
  title: z.string(),
});

export function parseWidgetPayload(raw: unknown): { id: string; title: string } {
  const parsed = WidgetSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error("Invalid widget payload at API boundary");
  }
  return parsed.data;
}
```
