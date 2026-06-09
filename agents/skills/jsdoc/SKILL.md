---
name: jsdoc
description: >-
  Writing and reviewing JSDoc and related comment blocks: preservation, lint
  satisfaction, substantive descriptions, {@link} placement, and TypeScript
  type-tag conventions. Use when adding, editing, or reviewing JSDoc.
---

# JSDoc

## Goal

Keep JSDoc and related documentation **substantive**, **accurate**, and **tooling-friendly**—aligned with code-first clarity (ADR 0004) and org ESLint JSDoc rules—without scattering the same rules across `AGENTS.md` and the review skill.

## Related ADR

- `org/docs/adr/0004-self-documenting-code-and-documentation-expectations.md` — code-first, purposeful docs; stable ESLint JSDoc policy.

## When to use this skill

Use this skill when you:

- Add or edit JSDoc on exports or other lint-required surfaces.
- Fix `jsdoc/*` lint findings.
- Review a diff that adds, removes, or rewrites `/**` blocks or documentation driven by JSDoc lint.
- Choose how to document types, exceptions, parameters, or cross-references with `{@link}` and `{type}` braces.

Run the **Review checklist** section before handoff when the change touches JSDoc. The default `review` skill delegates here instead of duplicating JSDoc items.

## Principles

- Prefer **self-documenting** names and decomposition; do not add JSDoc only to paper over unclear structure.
- JSDoc should add **behavior**, **domain meaning**, **preconditions**, or **hazards** that types and signatures do not carry.
- Satisfying `jsdoc/require-jsdoc` means **adding or improving** docs on required surfaces—not deleting substantive docs elsewhere to “clean up.”

## Preservation and edits

- Preserve existing block comments, line comments, and JSDoc by default. Updating for clarity, correctness, or formatting is encouraged.
- Do not remove comments or JSDoc that carry meaningful context—especially integration quirks, security notes, attribution, or overloaded semantics lint does not require you to keep on every surface.
- When touching documented code, treat existing docs as part of the contract. **Fix forward** (add `@param` / `@returns`, correct descriptions) rather than deleting blocks without replacement.
- Remove documentation only when it is **wrong**, **obsolete** after your change, or **pure redundancy** (restates signature/types with no behavior, domain, or hazard context). Never leave a blank gap where a substantive block was removed.

## Authoring quality

Before writing or rewriting JSDoc, read the **implementation**, surrounding module context, and **call sites** (including tests).

Never add generic or useless JSDoc:

- Placeholder parameter names (`@param param0`).
- Empty type echoes (`@param foo - foo`).
- Vacuous returns (`@returns the return`, `@returns return value`).

When prose names another type, port, enum, or documented concept in the codebase, link it with `{@link SymbolName}` (or the appropriate module-qualified link) so hover and navigation resolve.

### `{@link}` and the type slot

Many block tags use a **`[{type}]` then description** shape (per JSDoc syntax). The **first** `{…}` after the tag name is parsed as a **type** (or type-like namepath), **not** as an inline `{@link}` tag. Highlighters and doc generators treat that position differently from description prose—whether the tag is `@returns`, `@throws`, `@yields`, or others.

**Rule:** Put `{@link Symbol}` in the tag’s **description** (text after the type and any required name tokens). Do **not** put `{@link …}` as the first braced group after the tag.

#### Tags that commonly have a type-first `{…}` slot

| Tag                      | Typical shape                        | First `{…}` is                    |
| ------------------------ | ------------------------------------ | --------------------------------- |
| `@returns` / `@return`   | `@returns {type} description`        | Return type                       |
| `@throws` / `@exception` | `@throws {type} description`         | Exception type                    |
| `@yields`                | `@yields {type} description`         | Yielded type (generators)         |
| `@param`                 | `@param {type} name description`     | Parameter type                    |
| `@property`              | `@property {type} name description`  | Property type (typedefs, objects) |
| `@type`                  | `@type {type}`                       | Documented type of a symbol       |
| `@typedef`               | `@typedef {type} Name`               | Underlying type                   |
| `@callback`              | `@callback Name` / with type variant | Type when `{type}` is present     |
| `@augments` / `@extends` | `@extends {Type}`                    | Parent type                       |
| `@implements`            | `@implements {Type}`                 | Interface type                    |

Same rule applies anywhere the grammar treats the first braces as **type**, not narrative: e.g. `@throws {@link MyError} when …` is wrong; `@throws Thrown when {@link MyError} …` or `@throws {Error} when {@link MyError} …` (only if `{Error}` adds meaning) is better.

#### `@param`: always use `name - description`

**Standard (TypeScript, description-only):** `@param name - description`

**With optional `{type}` braces:** `@param {Type} name - description` — first `{…}` is the type slot; `{@link}` must not occupy it.

Always put a **hyphen and space** (`-`) between the parameter **name** and the description. IDEs may render `@param` similarly with or without the hyphen, but the hyphen is required org-wide because it stays clear in plain text, diffs, and viewers **without** JSDoc syntax highlighting.

| Pattern                                                     | Verdict                              |
| ----------------------------------------------------------- | ------------------------------------ |
| `@param action - Async function to retry.`                  | **Good** — org default               |
| `@param {string} id - {@link UserId} reference`             | **Good**                             |
| `@param action Async function to retry.`                    | **Avoid** — missing hyphen           |
| `@param {@link VpcInfo} vpc`                                | **Avoid** — `{@link}` in type slot   |
| `@returns {@link Foo} metadata`                             | **Avoid** — `{@link}` in type slot   |
| `@throws {@link AuthError} on failure`                      | **Avoid**                            |
| `@property {@link Config} options`                          | **Avoid** (first `{…}` read as type) |
| `@returns Object containing {@link Foo} metadata`           | **Good**                             |
| `@throws Rejects with {@link AuthError} when token expires` | **Good**                             |

When unsure, use `@param name -` before `{@link}` or prose; for non-`@param` tags use plain words (“Object containing …”, “Thrown when …”) so `{@link}` sits in description text.

### No leading `-` on `@returns` (and similar tags)

**Do not** write `@returns - description`. TypeScript-aware editors (VS Code, Cursor) already render tag descriptions with a separator (em dash) between the tag and prose. A manual hyphen produces a redundant `— -` in hovers and Quick Info.

| Pattern                             | Verdict                                                                                                                                      |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `@returns - \`true\` if …`          | **Avoid** — double separator in IDE                                                                                                          |
| `@returns \`true\` if …`            | **Good**                                                                                                                                     |
| `@param error - The error received` | **Good** — `@param` uses name-then-description; hyphen is conventional and pairs with `require-hyphen-before-param-description` when enabled |

Apply the same **no leading hyphen** rule to other description-only tags that do not include a name token before the prose—commonly `@throws`, `@yields`, and `@exception`—when the IDE shows the same doubled separator.

```ts
/** @throws When the lock is already held. */
/** @throws {MaximumConcurrencyExceededError} When the lock is already held. */
```

That is distinct from **`@param name - description`**, which stays required.

#### ESLint enforcement (hyphen policy)

Use one rule for both sides of the policy: **`jsdoc/require-hyphen-before-param-description`** (fixable).

```js
"jsdoc/require-hyphen-before-param-description": [
  "error",
  "always", // require `name - description` on @param (and @property when applicable)
  {
    tags: {
      returns: "never",
      throws: "never",
      yields: "never",
    },
  },
],
```

| Setting                                    | Effect                                                                                                                           |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| First option `"always"`                    | **Requires** hyphen before `@param` (and default `@property`) descriptions — enforces `@param foo - …`, autofix can insert `- `. |
| `returns` / `throws` / `yields`: `"never"` | **Forbids** leading `-` on those tags — fixes `@returns - …` double-separator in IDE.                                            |

There is no separate “require param hyphen only” rule; the rule name is historical but supports both **require on `@param`** and **forbid on `@returns`** via `tags`.

**`@param` without hyphen:** caught when the first option is `"always"` (message: must have hyphen before `@param` description).

**`@returns - …`:** caught by `returns: "never"` (message: must have no hyphen before `@returns` description).

**Alternative** for returns-only: `jsdoc/match-description` with `tags.returns: '^[^-].*'` — weaker; prefer the hyphen rule above.

Org `@chiubaka/eslint-config` does not enable this rule yet; see the eslint-config change spec to add it to the shared preset.

### TypeScript and `{type}` braces

Org ESLint disables `jsdoc/require-returns-type` and `jsdoc/require-param-type`. For TypeScript, **do not** add `{type}` braces on block tags that only repeat what the signature already states—commonly `@returns`, `@param`, and `@throws` when the thrown type is obvious from implementation.

Prefer **description-only** tags when the signature already states the type:

```ts
/** @returns Public endpoint metadata for the provisioned microservice. */
function createService(): EInvoicePlatformMicroserviceInfo { … }
```

Use `{type}` on those tags only when JSDoc adds information the signature cannot (typedef-only symbols, documented narrowings, intentionally loose signatures such as `unknown`, union throws not expressed in types, or non-TypeScript doc consumers).

### Open string unions documented in JSDoc

When fixing `@typescript-eslint/no-redundant-type-constituents` on intentionally open strings, prefer `as const` + derived built-in type + `Type | (string & {})` (or a genuinely closed union)—not bare `string` with a partial JSDoc “for example” list.

If allowed values move into JSDoc prose, list **all** known values; partial lists are worse than the prior union.

## Review checklist

Run when the diff touches comments or JSDoc (including before handoff when `review` delegates here):

- [ ] Existing comments and JSDoc were not removed wholesale without a clear reason (obsolete, incorrect, or pure signature/type duplication with no lost behavior or domain context).
- [ ] JSDoc edits fix or add documentation to satisfy lint; they do not delete substantive blocks on `private`, local, or legacy code merely because those surfaces are outside `require-jsdoc` contexts.
- [ ] New or edited JSDoc adds real behavior or domain context—not placeholders, signature-only restatement, or vacuous `@returns` lines.
- [ ] Descriptions match the implementation and call-site expectations; when the diff alone is ambiguous, spot-check usages and tests.
- [ ] Related symbols use `{@link …}` in **description** text, not in the first `{…}` type slot (`@returns`, `@throws`, `@yields`, `@param {type} …`, `@property`, etc.).
- [ ] Every `@param` uses `name - description` (hyphen required), including when `{@link}` appears in the description.
- [ ] `@returns`, `@throws`, and `@yields` descriptions do **not** start with `-` (avoids `— -` in IDE hovers).
- [ ] `{type}` braces on `@returns`, `@param`, `@throws`, and similar tags do not repeat TypeScript-only information without added meaning.
- [ ] Scan the diff for deleted `/**` or important line-comment hunks; flag unexpected removals before handoff.
- [ ] No **new** comments or JSDoc were added only to compensate for unclear structure (distinct from keeping valuable existing docs).
- [ ] JSDoc-related lint policy was not changed in routine feature work unless the task explicitly targets lint policy.

## Related skills

- `review` — default completion gate; defers JSDoc checks to this skill.
- `test-driven-development` — call sites and tests inform accurate JSDoc.
