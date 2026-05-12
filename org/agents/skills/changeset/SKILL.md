---
name: changeset
description: >-
  Authors Changesets-compatible markdown files for @changesets/cli: semver intent
  in frontmatter and user-facing changelog text. Use when adding or editing a
  changeset, preparing a release-impacting PR, or when the user mentions
  changesets, .changeset/, or package version bumps (major, minor, patch).
---

# Changesets (@changesets/cli)

## Purpose

A changeset file declares **which packages** bump and **how the change reads in the changelog**. It is the source of truth for release notes in this org’s Changesets workflow (see [ADR 0024](../../../docs/adr/0024-use-changesets-for-library-monorepos.md) and related ADRs).

## When not to author a changeset

For **ADR-only** or **agent-guidance-only** PRs (no changes to shipped packages, orb/scripts, or consumer-facing artifact behavior), **do not** add a `.changeset` file. Use `org/agents/skills/changesets-hygiene/SKILL.md` for the full exception list.

## Where files live

- Add markdown files under **`.changeset/`** at the repo root (or the configured changeset directory).
- Prefer **`pnpm changeset`**, **`yarn changeset`**, or **`npx changeset`** so the tool can prompt for packages and bump levels; then **edit the generated body** to match the rules below. You may author the file by hand if the workflow requires it.

## File shape

```markdown
---
"<package-name>": patch
---

<changelog summary — single line>

<optional body: context, rationale, migration notes — paragraphs below>
```

- **Frontmatter** — YAML between the first pair of `---` lines. Keys are **package names** (quoted if needed); values are **`major`**, **`minor`**, or **`patch`**.
- **Multiple packages** — Add more keys in the same block (see [Changesets docs](https://github.com/changesets/changesets/blob/main/docs/adding-a-changeset.md)).

## Changelog text (critical)

**The first line after the closing `---` is the changelog entry headline** — how the change appears under each package in generated `CHANGELOG` files.

- **One short line** — clear, scannable, **like a release note bullet**, not a paragraph.
- **Do not** pack extra sentences, long explanations, or “because …” clauses into that line. Put those in the **body** (blank line, then paragraphs).
- Imperative or neutral phrasing is fine; **clarity and brevity** beat completeness on the first line.

### Good example

```markdown
---
"@chiubaka/eslint-config-react": patch
---

Disable `react/react-in-jsx-scope` in the default React preset.

Modern bundlers use the automatic JSX runtime, so `React` does not need to be in scope for JSX.
```

### Bad example (first line too long / two ideas glued together)

```markdown
---
"@chiubaka/eslint-config-react": patch
---

Turn off `react/react-in-jsx-scope` in the default React preset. The automatic JSX runtime used by current bundlers does not require `React` to be in scope.
```

Fix: keep the **first** sentence only on line one; move the bundler rationale to the body (as in the good example).

## Checklist before finishing

- [ ] Frontmatter lists every affected **published** package that should release with this change, with the right **semver** bump.
- [ ] **First line** after `---` is a crisp changelog summary; **details** are only below it.
- [ ] File is saved under `.changeset/` with a unique name (the CLI usually generates this).
