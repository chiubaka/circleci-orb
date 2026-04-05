---
status: accepted
date: 2026-03-20
decision-makers: Daniel Chiu
---

# ADR 0002: Zod for runtime JSON validation (including LLM structured output)

## Context and Problem Statement

We need to turn **untrusted JSON-shaped text** (starting with LLM responses for **concept extraction**) into **typed, validated data** at runtime. TypeScript alone does not validate data at boundaries; `JSON.parse` returns `any`-ish values until we assert shape and constraints.

We want one **clear, team-wide choice** for this pattern so new features (API payloads, tool outputs, config) do not sprawl across ad-hoc guards or competing libraries.

## Decision Drivers

- **Correctness at boundaries:** Reject or surface structured errors when input does not match the expected contract.
- **TypeScript alignment:** Inferred types from validators should stay in sync with domain types (`enum`s, `ExtractedConcept`-like shapes).
- **Ecosystem fit:** Documentation, Stack Overflow answers, and third-party examples should apply without translation.
- **Maintainability:** A single dialect for validators in the monorepo beats mixing multiple schema systems.
- **Operational context:** Primary first consumer is a **Node server package**; extreme edge-bundle size is not the first constraint.

## Considered Options

- **Zod** — Schema-first runtime validation with `z.infer`, widespread adoption in TS backends and LLM tooling examples.
- **Valibot** — Modular design and smaller bundles; different API; not schema-compatible with Zod.
- **Ajv (+ JSON Schema)** — Fast validation against JSON Schema; strong when JSON Schema isAlready the source of truth (e.g. some OpenAPI workflows); more ceremony for TS-first, enum-heavy code unless codegen is introduced.
- **TypeBox** — JSON Schema generation from TS-like definitions; excellent for performance-sensitive and codegen scenarios; steeper curve for quick one-off LLM payload schemas.
- **ArkType** — Concise syntax and strong performance story; smaller ecosystem and fewer copy-paste examples than Zod.
- **io-ts** — Mature FP-oriented decoding; less common in new greenfield TS services than Zod.

## Decision Outcome

**Chosen option: Zod.**

**Justification:** Zod best satisfies the decision drivers for a server-heavy monorepo: it pairs directly with TypeScript enums and interfaces, appears constantly in ecosystem examples (including LLM “parse then validate” flows), and gives us one validator dialect to standardize on. Bundle size is a secondary concern here compared with interoperability and team familiarity.

### Consequences

- Good, because new contributors and integrations can follow widely available Zod patterns.
- Good, because `safeParse` / error shaping gives a consistent pattern for logging and handling failures at trust boundaries.
- Good, because we avoid splitting validation idioms across Zod, Valibot, and JSON Schema in the same codebase unless a future ADR explicitly introduces a second system.
- Bad, because dependency weight and parse cost are higher than the lightest validators (e.g. tiny hand-rolled guards or minimal libraries)—acceptable until measured otherwise on hot paths.
- Bad, because Zod major upgrades may require occasional schema migration work (mitigated by pinning semver and reading changelogs).

### Confirmation

- **Implementation:** The server/runtime package declares a `zod` dependency; structured LLM output goes through **`LlmService#promptJson`**, which **binds the caller’s `ZodType<T>` to the provider’s structured-output contract** when the adapter supports it, then parses the response and validates with the same schema before returning **`T`**. Other untrusted JSON entry points follow the same parse-then-validate pattern.
- **Review:** Code review checks that new external/untrusted JSON entry points use Zod (or reference a shared schema module) rather than unchecked casts.
- **Revisit:** If profiling shows validation as a bottleneck, or if JSON Schema becomes the org-wide contract for APIs, consider a follow-up ADR to widen or split strategies (without duplicating validators ad hoc).

## Pros and Cons of the Options

### Zod

Widely used TypeScript-first schema library; typical flow `JSON.parse` → `schema.safeParse(parsed)`.

- Good, because large ecosystem, tutorials, and library examples assume Zod.
- Good, because `z.infer<typeof schema>` keeps runtime and compile-time types aligned.
- Good, because `z.nativeEnum` / `z.enum` integrate cleanly with existing string enums in the domain layer.
- Neutral, because it is not the smallest possible library on disk or at startup.
- Bad, because schemas are not portable to Valibot without rewrite (standardize on Zod in this repo to avoid two dialects).

### Valibot

Designed for tree-shaking and modular imports; API differs from Zod.

- Good, because smaller bundles can matter for edge and browser-heavy bundles.
- Good, because validation ergonomics are strong for teams that commit to it everywhere.
- Bad, because fewer third-party snippets and tool integrations target Valibot first.
- Bad, because choosing Valibot alongside a Zod-heavy ecosystem splits validator dialects across projects or examples.

### Ajv (+ JSON Schema)

Validate against JSON Schema documents; very fast; ubiquitous in OpenAPI tooling.

- Good, because excellent performance and standards-based schemas.
- Good, because JSON Schema may already exist for HTTP APIs.
- Bad, because TS-first maintenance often duplicates effort unless codegen links schema and types.
- Bad, because ergonomics for small LLM payloads are heavier than a single Zod schema module.

### TypeBox

Build JSON Schema from TypeScript-like constructors; strong for codegen and performance.

- Good, because aligns schema with JSON Schema and fast validators.
- Bad, because setup cost for occasional LLM JSON is higher than dropping in Zod.

### ArkType

Modern, terse validation with competitive performance.

- Good, because DX and speed are compelling for greenfield adopters.
- Bad, because community size and example surface are smaller than Zod’s.

### io-ts

Decoder combinators; fits FP pipelines.

- Good, because precise error paths and composition.
- Bad, because it is less common in new backend codebases than Zod, raising onboarding friction.

## More Information

- `LlmService` uses a **single `prompt: string`** argument for both `prompt` and `promptJson` (one-shot tasks); role splits or richer request shapes stay a future revision if needed. For **`promptJson`**, the prompt carries **task semantics**; **output shape is defined by `schema`** at the provider and validated with Zod on the return path—callers should not duplicate JSON field lists in the prompt.
- First use case: `LlmConceptExtractor` calls `LlmService#promptJson` with a Zod schema for the LLM payload (e.g. concepts with `canonicalForm`, `type`, `language`).
- Related: [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) (boundaries and where validation runs—infrastructure / application edges as appropriate within a feature slice).
