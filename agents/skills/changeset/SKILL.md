---
name: changeset
description: >-
  Authors Changesets-compatible markdown files for @changesets/cli: semver intent
  in frontmatter, required category prefix on every summary, and changelog voice
  matched to monorepo type (library vs deployable app). Treats the open PR / branch
  merge delta (base…HEAD) as the unit of truth—not individual commits. Reconcile by
  rewriting single-headline notes for net consumer impact; never amalgamate task
  diaries into one multi-prefix file. Use when adding, editing, or reconciling
  changesets, preparing a release-impacting PR, or when the user mentions
  changesets, .changeset/, or package version bumps.
---

# Changesets (@changesets/cli)

## Purpose

A changeset file declares **which packages** bump and **how the change reads in the changelog**. It is the source of truth for release notes in this org’s Changesets workflow (see [ADR 0024](../../../docs/adr/0024-use-changesets-for-library-monorepos.md), [ADR 0026](../../../docs/adr/0026-use-changesets-for-application-releases.md), and related ADRs).

Release automation groups published changelogs by **category** (Features, Improvements, Bug Fixes, and related sections). Every changeset summary **must** start with a category prefix so grouping works. **Voice** (technical vs product language) still depends on monorepo type — prefix and voice are independent.

## Unit of truth: PR / branch merge delta

A changeset describes **consumer-visible difference between the merge base and the branch tip** (what lands when the PR merges), **not** what happened in the latest commit or agent task.

**Ask before authoring or keeping a changeset:**

> Relative to the PR base (usually `main` / `master`), what will users / consumers experience differently after this PR merges?

If the answer is “nothing” for a given note, that changeset should not exist—even if this commit fixed a bug, reverted WIP, or repaired a regression **introduced earlier on this same branch**.

**Default timing:** drafting or updating a changeset mid-task is fine, but **reconcile against base…HEAD before handoff** (review skill / PR ready). Do not treat “I completed a task” as automatic justification for a new changeset file.

**Holistic means judgment, not concatenation:** Re-read the full PR and decide what release notes (if any) should exist for the finished consumer outcome. It does **not** mean keep every intermediate note, and it does **not** mean paste many `Feature:` / `Fix:` / `Improvement:` lines into one `.changeset/*.md` file.

### Commit-shaped vs merge-shaped (anti-patterns)

| Anti-pattern                                                                                            | Why it’s wrong                                                                 | Correct behavior                                                                                               |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| Add `Fix:` because this commit fixed a bug **this branch introduced**                                   | Changelog readers never saw the broken intermediate state                      | **No new Fix changeset**; **rewrite** or leave the original Feature/Improvement **headline** if still accurate |
| Add a second changeset for the same package describing a refinement of work already noted on the branch | Redundant / fragmented release notes                                           | **Rewrite** the existing branch changeset’s **single** headline so it describes the finished story             |
| Stack many category-prefixed lines (`Feature:` / `Fix:` / …) in **one** changeset file                  | Invalid shape for category grouping; diary amalgamation disguised as reconcile | **One** prefixed headline per file. Collapse to the net consumer story, or use **separate files** sparingly    |
| One changeset per agent task / commit by default                                                        | Release notes become a diary of implementation                                 | As few single-headline notes as needed for the **whole** merge delta                                           |
| Leave stale branch changesets after scope shrunk                                                        | Notes describe work that no longer ships                                       | **Delete or rewrite** so the set matches final base…HEAD                                                       |

### When a Fix _is_ appropriate on a feature branch

Use `Fix:` only when the bug (or incorrect behavior) exists on the **merge base** / already-released line—i.e. consumers would hit it **without** this PR. Fixing a regression you introduced earlier in the same unreleased PR is usually **not** a Fix.

### Merge-delta examples

**Bad — commit-shaped Fix on the same branch**

Branch already has:

```markdown
Feature: Add CSV export on the reports page
```

A later commit on the same PR fixes a crash in that new export. Agent adds:

```markdown
Fix: Prevent crash when exporting empty report ranges
```

**Wrong:** empty-range crash never shipped; consumers only see the finished feature.

**Right:** keep or **rewrite** a single `Feature:` headline for CSV export; no `Fix:`.

**Good — Fix against already-shipped behavior**

PR only changes error handling for an export that already exists on the base branch:

```markdown
Fix: Prevent crash when exporting empty report ranges
```

**Good — reconcile after scope change**

Branch had Feature + Improvement notes as **separate files**; final diff vs base only ships the feature. Delete the Improvement changeset. If the Feature headline is still accurate, leave it; otherwise **rewrite that one line**—do not append the Improvement text under it.

**Bad — amalgamation (many prefixes in one file)**

Branch work produced many task notes. Agent “reconciles” by concatenating them into a single changeset body:

```markdown
---
"@acme/ui": minor
---

Feature: Add portable form controls with web and native adapters.

Feature: Expose SelectContent `position`.

Fix: Own uncontrolled checked state in native Checkbox.

Fix: Honor Select `disabled` on the native trigger.

Improvement: Align checked Checkbox checkmark weight across platforms.
```

**Wrong:** multiple category-prefixed headlines in one file; most lines are branch WIP, not distinct base…HEAD release stories. Category tooling expects **one** summary per changeset file.

**Right:** decide the net consumer impact vs base, then **rewrite** to one headline (drop branch-only polish). Example:

```markdown
---
"@acme/ui": minor
---

Feature: Add portable form controls (Label, Input, Textarea, Checkbox, Switch, RadioGroup, Select, Field, InputGroup) with web and native adapters.
```

Add a **second changeset file** only when base…HEAD also includes an **independent** consumer-visible delta (for example a `Fix:` for a bug that already existed on the merge base).

### When multiple changeset files are appropriate

**Default:** one changeset per affected package (or lockstep group) covering the PR’s primary release story.

**Use additional files** only when the merge delta has **independent** consumer-visible outcomes that belong in different categories or need separate semver intent (for example new API + fix for a pre-existing bug in the same PR).

**Do not** use one file per agent task, or one file that lists every task as prefixed bullets.

## When not to author a changeset

For **ADR-only** or **agent-guidance-only** PRs (no changes to shipped packages, orb/scripts, or consumer-facing artifact behavior), **do not** add a `.changeset` file. Use `org/agents/skills/changesets-hygiene/SKILL.md` for the full exception list.

Also do **not** add a changeset solely to document fixing, reverting, or polishing behavior that **never existed on the merge base** (unreleased WIP on this branch).

## Authoring order (always follow this sequence)

1. **Confirm the repo uses Changesets** (`.changeset/config.json`, `@changesets/cli`).
2. **Establish merge context** — identify the base branch / open PR (`git merge-base`, `gh pr view`). Reason about **base…HEAD**, not only files touched in the latest commit.
3. **Inventory `.changeset/*.md` changed vs base** — every path **added, modified, or deleted** relative to the merge base (not only files new on the branch). Prefer **rewriting or removing** those files over adding another.
4. **Decide net release intent** from the full merge delta (consumer-visible pre- vs post-merge state).
5. **Determine monorepo type** for the packages in the frontmatter (library, app/deployable, or hybrid). This sets **voice** only.
6. **Choose a category prefix** from the taxonomy below. Prefixes are **required in all org repos** — not optional for library monorepos.
7. **Write or rewrite one headline** after the prefix using the voice for that monorepo type — **replace** the prior summary; do not append another prefixed line to the same file.
8. **Set semver** in frontmatter independently of category (a bug fix can be `major` if breaking; a feature can be `patch` if additive and non-breaking).
9. **Reconcile before handoff** — re-read all branch changesets against base…HEAD; delete no-ops; **rewrite** overlapping stories into as few single-headline files as needed; if any file lists multiple category-prefixed lines, treat that as a **failed reconcile** and collapse it.

**Anti-patterns**

- Do **not** pick a prefix because the _work_ mentions “features” (for example, building category-prefix support ≠ automatically `Feature:` — classify by **consumer impact**).
- Do **not** omit a prefix expecting silent fallback — use **`Other:`** explicitly when no other category fits.
- Do **not** conflate prefix with voice: library repos use prefixes too; the text after the prefix stays **technical**.
- Do **not** author changesets as a per-commit or per-task diary; classify by **merge delta**.
- Do **not** “reconcile” by concatenating task notes into one multi-prefix body; **rewrite** the net consumer story instead.

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
- **Headline** — **Exactly one** category-prefixed summary line after the closing `---`. Never stack multiple `Feature:` / `Fix:` / `Improvement:` (etc.) lines in the same file.
- **Body** — **Omit by default.** Most changesets are **only** frontmatter plus that one headline. Add paragraphs below only when the audience needs information that cannot fit in that line (see [Optional body](#optional-body-use-sparingly)). Optional body is migration or must-know prose — **not** more category-prefixed changelog bullets.
- **Multiple packages** — Add more keys in the same block (see [Changesets docs](https://github.com/changesets/changesets/blob/main/docs/adding-a-changeset.md)).

## Changelog text — library monorepos

**Audience:** technical consumers of published packages.

**The first line after the closing `---` is the changelog headline** — prefix plus summary. Release tooling strips the prefix token when rendering grouped changelogs; author with the prefix in the changeset file.

- **Prefix required** — start with an accepted category token (see [Full taxonomy](#full-taxonomy)).
- **One short line** — clear, scannable, **like a release note bullet**, not a paragraph.
- **Self-contained** — the headline (after prefix) should stand alone. Do not rely on a body paragraph.
- **Impact over implementation** — state what consumers must know (new option, stricter validation, removed export), not how the code was refactored. Technical terms are fine when they are the consumer-facing contract (API names, config keys, breaking types).
- **Do not** pack extra sentences into the headline. If the change is straightforward, **stop after that line**.
- **No ADR leakage** — do not cite `ADR NNNN`, ADR paths, or “per ADR …” in the headline or optional body. Changelog readers lack that context; state the consumer-visible change itself. Also do not use ADR-local comparison labels (for example “Model B”, “Option 1”)—name the concept directly and succinctly.

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

### Bad example — library (ADR leakage)

```markdown
---
"@acme/auth-client": minor
---

Improvement: Align session handling with Model B (ADR 0032).
```

Fix: drop the ADR id and nickname; state the consumer-visible behavior (for example `Improvement: Keep session refresh on the client; server endpoints re-authorize every request.`).

## Changelog text — app-based deployable monorepos

**Audience:** ordinary users of the deployed product — **not** engineers.

**The first line after the closing `---` is the release note headline** — prefix plus product-oriented summary.

- **Prefix required** — same taxonomy as library repos.
- **Product language** — describe what users see, can do, or no longer struggle with.
- **No technical concepts** — avoid API routes, database tables, package names, refactors, “backend/frontend,” framework names, and other implementation vocabulary unless it is the **user-visible product name** (for example, a branded integration users recognize).
- **No ADR leakage** — same as library monorepos: no ADR identifiers, paths, or ADR-local nicknames in the headline or body.
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

Do **not** add a body for implementation rationale, internal refactor context, ADR citations, or restating the headline.

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

- [ ] Judged against **base…HEAD** (open PR / branch), not the latest commit alone.
- [ ] Reviewed **all** `.changeset/*` paths **added, modified, or deleted** vs base; **rewritten** or deleted instead of stacking redundant notes when possible.
- [ ] No changeset describes fixing/reverting behavior **only introduced on this branch**.
- [ ] Remaining set is **non-redundant**: as few notes as needed for the **net** pre- vs post-merge consumer impact (judgment, not a concatenated diary).
- [ ] Each branch changeset has **exactly one** category-prefixed headline (no multi-prefix amalgamation).
- [ ] Identified **monorepo type** (library, app/deployable, or hybrid) and matched **voice** for text after the prefix.
- [ ] **Category prefix** present and appropriate (`Breaking:`, `Feature:`, `Fix:`, `Other:`, etc.).
- [ ] Frontmatter lists every affected **published package or deployable artifact** with the right **semver** bump (independent of category).
- [ ] **First line** after `---` is prefix + crisp, self-contained summary.
- [ ] No `ADR NNNN`, ADR paths, or ADR-local shorthands (“Model B”, “Option 1”, etc.) in the headline or body—describe the concept or consumer impact directly.
- [ ] **No body** unless the audience needs migration or must-know steps that cannot fit in the headline alone.
- [ ] File is saved under `.changeset/` with a unique name (the CLI usually generates this).

## Tooling note

Category prefixes are parsed by shared release automation (Chiubaka CircleCI orb: `changesetCategoryPrefixes.mjs`, `release-notes-grouping: category`, `require-changeset-category-prefix`). Keep prefix tokens aligned with that module when it changes. Repos should enable category grouping and prefix verification in CI — see orb examples and ADRs.
