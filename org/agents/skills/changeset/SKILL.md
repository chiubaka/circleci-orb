---
name: changeset
description: >-
  Authors Changesets-compatible markdown files for @changesets/cli: semver intent
  in frontmatter, required category prefix on every summary, and changelog voice
  matched to monorepo type (library vs deployable app). Use when adding or editing
  a changeset, preparing a release-impacting PR, or when the user mentions
  changesets, .changeset/, or package version bumps (major, minor, patch).
---

# Changesets (@changesets/cli)

## Purpose

A changeset file declares **which packages** bump and **how the change reads in the changelog**. It is the source of truth for release notes in this org’s Changesets workflow (see [ADR 0024](../../../docs/adr/0024-use-changesets-for-library-monorepos.md), [ADR 0026](../../../docs/adr/0026-use-changesets-for-application-releases.md), and related ADRs).

Release automation groups published changelogs by **category** (Features, Improvements, Bug Fixes, and related sections). Every changeset summary **must** start with a category prefix so grouping works. **Voice** (technical vs product language) still depends on monorepo type — prefix and voice are independent.

## When not to author a changeset

For **ADR-only** or **agent-guidance-only** PRs (no changes to shipped packages, orb/scripts, or consumer-facing artifact behavior), **do not** add a `.changeset` file. Use `org/agents/skills/changesets-hygiene/SKILL.md` for the full exception list.

## Authoring order (always follow this sequence)

1. **Confirm the repo uses Changesets** (`.changeset/config.json`, `@changesets/cli`).
2. **Determine monorepo type** for the packages in the frontmatter (library, app/deployable, or hybrid). This sets **voice** only.
3. **Choose a category prefix** from the taxonomy below. Prefixes are **required in all org repos** — not optional for library monorepos.
4. **Write the headline** after the prefix using the voice for that monorepo type.
5. **Set semver** in frontmatter independently of category (a bug fix can be `major` if breaking; a feature can be `patch` if additive and non-breaking).

**Anti-patterns**

- Do **not** pick a prefix because the _work_ mentions “features” (for example, building category-prefix support ≠ automatically `Feature:` — classify by **consumer impact**).
- Do **not** omit a prefix expecting silent fallback — use **`Other:`** explicitly when no other category fits.
- Do **not** conflate prefix with voice: library repos use prefixes too; the text after the prefix stays **technical**.

## Monorepo type (choose the right voice)

| Type                              | Typical repos                                                 | Audience                                               | Summary style (after prefix)                                                                                   |
| --------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| **Library monorepo**              | Hyperdrive, circleci-orb, other publishable-package monorepos | Technical — library consumers and integrators          | Explain what **technically changed** that consumers need to know; prefer **impact** over implementation detail |
| **App-based deployable monorepo** | Midana, L-3XO, and other deployable-artifact monorepos        | Non-technical — ordinary users of the deployed product | Describe **product-oriented user experience**; no implementation details, internals, or technical concepts     |

**How to tell which type applies**

- **Library** — the latest changeset keys are **published npm (or equivalent) packages** consumed as dependencies. See [ADR 0024](../../../docs/adr/0024-use-changesets-for-library-monorepos.md) and [ADR 0023](../../../docs/adr/0023-lockstep-versioning-for-related-package-groups.md).
- **App / deployable** — keys are **deployable artifacts** (web app, mobile app, backend service, etc.), often under `apps/*`, with internal packages usually **not** versioned. See [ADR 0026](../../../docs/adr/0026-use-changesets-for-application-releases.md) and [ADR 0028](../../../docs/adr/0028-version-only-deployable-artifacts-by-default.md).
- **Hybrid monorepo** — one `.changeset/` directory; if a single changeset bumps both library packages and deployable artifacts, write for the **primary release surface** (usually end users when a deployable artifact is included). See [ADR 0027](../../../docs/adr/0027-use-single-changesets-workflow-in-hybrid-monorepos.md).

When a change spans internal packages and a deployable artifact, version the **deployable artifact** and write the summary for **end users**, not for internal module structure.

## Category prefix (required everywhere)

Every summary line **must** start with one of the accepted category prefixes below (for example `Breaking:` or `Fix:`), followed by a colon, space, and the summary. Matching is case-insensitive. The prefix is **presentation metadata** for changelog grouping; semver stays in frontmatter. CI (`verify-changesets` with `require-changeset-category-prefix: true`) should enforce this in every org repo.

Canonical section headings in generated changelogs and batch release notes: **Breaking Changes**, **Security**, **Features**, **Improvements**, **Bug Fixes**, **Deprecations**, **Other Changes** (display order may vary by tooling).

### Full taxonomy

| Section              | Accepted prefixes                          | When to use                                                                                                                               |
| -------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Breaking Changes** | `Breaking:`, `Breaking Change:`            | Consumers must change code, config, or usage to upgrade — removed or incompatible APIs, behavior, or options (usually pairs with `major`) |
| **Security**         | `Security:`                                | Security-relevant fix or hardening consumers or operators should know about                                                               |
| **Features**         | `Feature:`, `Features:`                    | New capability that did not exist before (new API, export, option, screen, workflow)                                                      |
| **Improvements**     | `Improvement:`, `Improvements:`            | Enhancement to existing behavior without a wholly new capability (UX polish, performance, clearer errors)                                 |
| **Bug Fixes**        | `Fix:`, `Fixes:`, `Bug Fix:`, `Bug Fixes:` | Correction of incorrect, broken, or regressed behavior                                                                                    |
| **Deprecations**     | `Deprecation:`, `Deprecated:`              | Existing surface marked for future removal; still works today with a documented migration path                                            |
| **Other Changes**    | `Other:`, `Other Changes:`                 | Release-note-worthy work that is not covered above (dependency-only maintenance, tooling, ops). **Required** — do not omit the prefix     |

### Classification rules

- **Breaking vs Feature:** if adopters must change code or config, use **`Breaking:`** even when the release also adds functionality. Semver bump and category are independent.
- **Deprecation vs Breaking:** still works but scheduled for removal → **`Deprecation:`**; already removed or incompatible → **`Breaking:`**.
- **Improvement vs Feature:** extends existing behavior without a new capability → **`Improvement:`**.
- **Other is explicit:** untagged headlines are invalid — use **`Other:`** when nothing else fits.

### Prefix appropriateness by monorepo type

All prefixes are **valid syntax** in every repo. Prefer prefixes that match **what the reader cares about**:

| Prefix                                      | Library monorepos                                    | App / deployable monorepos                                                       |
| ------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------------------------------- |
| **Breaking**, **Deprecation**, **Security** | Common — integrators need contract and safety signal | Use when users or operators must act; otherwise prefer Fix / Improvement / Other |
| **Feature**, **Improvement**, **Fix**       | Common — describe API and behavior impact            | Common — describe product experience (non-technical wording)                     |
| **Other**                                   | Tooling, CI, dependency bumps in published packages  | Ops or maintenance users should know about                                       |

App monorepos still use **`Breaking:`** or **`Deprecation:`** when users must change behavior or migration steps are required. Use **`Improvement:`**, **`Fix:`**, or **`Other:`** for non-breaking user-facing changes; keep migration detail in the optional body.

## When not to author a changeset

For **ADR-only** or **agent-guidance-only** PRs (no changes to shipped packages, orb/scripts, or consumer-facing artifact behavior), **do not** add a `.changeset` file. Use `org/agents/skills/changesets-hygiene/SKILL.md` for the full exception list.

## Where files live

- Add markdown files under **`.changeset/`** at the repo root (or the configured changeset directory).
- Prefer **`pnpm changeset`**, **`yarn changeset`**, or **`npx changeset`** so the tool can prompt for packages and bump levels; then **edit the generated summary** to match the rules below (trim any default body the CLI adds). You may author the file by hand if the workflow requires it.

## File shape

```markdown
---
"<package-name>": patch
---

<Category: changelog summary — single line>
```

- **Frontmatter** — YAML between the first pair of `---` lines. Keys are **package names** (quoted if needed); values are **`major`**, **`minor`**, or **`patch`**.
- **Body** — **Omit by default.** Most changesets are **only** frontmatter plus one prefixed summary line. Add paragraphs below only when the audience needs information that cannot fit in that line (see [Optional body](#optional-body-use-sparingly)).
- **Multiple packages** — Add more keys in the same block (see [Changesets docs](https://github.com/changesets/changesets/blob/main/docs/adding-a-changeset.md)).

## Changelog text — library monorepos

**Audience:** technical consumers of published packages.

**The first line after the closing `---` is the changelog headline** — prefix plus summary. Release tooling strips the prefix token when rendering grouped changelogs; author with the prefix in the changeset file.

- **Prefix required** — start with an accepted category token (see [Full taxonomy](#full-taxonomy)).
- **One short line** — clear, scannable, **like a release note bullet**, not a paragraph.
- **Self-contained** — the headline (after prefix) should stand alone. Do not rely on a body paragraph.
- **Impact over implementation** — state what consumers must know (new option, stricter validation, removed export), not how the code was refactored. Technical terms are fine when they are the consumer-facing contract (API names, config keys, breaking types).
- **Do not** pack extra sentences into the headline. If the change is straightforward, **stop after that line**.

### Good example — library (typical)

```markdown
---
"@chiubaka/eslint-config-react": patch
---

Improvement: Disable `react/react-in-jsx-scope` in the default React preset.
```

### Good example — library (breaking)

```markdown
---
"@acme/auth-client": major
---

Breaking: Require `AuthClientOptions.region` and remove the deprecated `apiHost` option.
```

### Good example — library (new capability)

```markdown
---
"@chiubaka/circleci-orb": minor
---

Feature: Add opt-in category-based release note grouping for application monorepos.
```

### Bad example — library (missing prefix)

```markdown
---
"@chiubaka/eslint-config-react": patch
---

Disable `react/react-in-jsx-scope` in the default React preset.
```

Fix: add a category prefix, for example `Improvement: Disable …`.

### Bad example — library (first line too long)

```markdown
---
"@chiubaka/eslint-config-react": patch
---

Improvement: Turn off `react/react-in-jsx-scope` in the default React preset. The automatic JSX runtime used by current bundlers does not require `React` to be in scope.
```

Fix: keep a **single** crisp sentence after the prefix; put migration detail in an optional body if needed.

## Changelog text — app-based deployable monorepos

**Audience:** ordinary users of the deployed product — **not** engineers.

**The first line after the closing `---` is the release note headline** — prefix plus product-oriented summary.

- **Prefix required** — same taxonomy as library repos.
- **Product language** — describe what users see, can do, or no longer struggle with.
- **No technical concepts** — avoid API routes, database tables, package names, refactors, “backend/frontend,” framework names, and other implementation vocabulary unless it is the **user-visible product name** (for example, a branded integration users recognize).
- **One short line** — same brevity rules as library monorepos.

### Good example — app (feature)

```markdown
---
"@snowday/directus": minor
---

Feature: Add a location-input interface backed by Google Places
```

### Good example — app (improvement)

```markdown
---
"@acme/web": patch
---

Improvement: Sign-in completes faster on slow connections
```

### Bad example — app (technical / no prefix)

```markdown
---
"@acme/web": patch
---

Refactor auth middleware to use Redis session store
```

Fix: use product language and a category prefix, for example `Improvement: Stay signed in more reliably when switching devices`.

### Bad example — app (missing prefix)

```markdown
---
"@acme/web": minor
---

Add export to CSV on the reports page
```

Fix: `Feature: Export reports to CSV from the reports page`.

## Optional body (use sparingly)

**Default: no body.** Accumulated changesets feed release PRs and package `CHANGELOG` files; extra paragraphs add noise.

Add a body **only** when omitting it would leave the **intended audience** without something they **must** know to adopt or use the release safely:

- **Library monorepos** — migration paths (rename map, config key moves, required commands), operational caveats.
- **App monorepos** — user-facing steps that cannot fit in one line. Keep language non-technical.

Do **not** add a body for implementation rationale, internal refactor context, or restating the headline.

When a body is warranted, keep it **short** — a few sentences or bullets.

### Good example (body warranted — library breaking change + migration)

```markdown
---
"@acme/auth-client": major
---

Breaking: Require `AuthClientOptions.region` and remove the deprecated `apiHost` option.

**Migration:** replace `apiHost: "https://api.example.com"` with `region: "us-east-1"`. The client derives the host from `region`. Configurations without `region` fail at construction time.
```

## Checklist before finishing

- [ ] Identified **monorepo type** (library, app/deployable, or hybrid) and matched **voice** for text after the prefix.
- [ ] **Category prefix** present and appropriate (`Breaking:`, `Feature:`, `Fix:`, `Other:`, etc.).
- [ ] Frontmatter lists every affected **published package or deployable artifact** with the right **semver** bump (independent of category).
- [ ] **First line** after `---` is prefix + crisp, self-contained summary.
- [ ] **No body** unless the audience needs migration or must-know steps that cannot fit in the headline alone.
- [ ] File is saved under `.changeset/` with a unique name (the CLI usually generates this).

## Tooling note

Category prefixes are parsed by shared release automation (Chiubaka CircleCI orb: `changesetCategoryPrefixes.mjs`, `release-notes-grouping: category`, `require-changeset-category-prefix`). Keep prefix tokens aligned with that module when it changes. Repos should enable category grouping and prefix verification in CI — see orb examples and ADRs.
