---
name: changesets-hygiene
description: >-
  Prevents hand-edited semver and changelog in Changesets-driven repos. Use
  .changeset entries and changeset add/version flows instead; never bump
  package.json version or CHANGELOG.md to ship features in those repos. Skips
  ADRs and agent-guidance-only edits (see When not to add a Changeset).
---

# Changesets hygiene (agents)

## Goal

Keep version bumps and consumer-facing `CHANGELOG` entries **sourced from Changesets**, not from agent or maintainer hand-edits to `package.json` and `CHANGELOG.md` in the same PR that delivers product work.

## When to use

Use in any repository with:

- `.changeset/config.json` (or equivalent) and
- `@changesets/cli` (or a documented `pnpm changeset` / `changeset` workflow) for release notes.

## When not to add a Changeset

**Do not** create `.changeset/*` entries when the PR only affects:

- **ADRs** or other durable decision docs under `**/docs/adr/**` or `org/docs/adr/**`
- **Agent/contributor guidance** that does not change runtime or published APIs (for example `AGENTS.md`, `org/agents/AGENTS.org.md`, `REVIEW-CHECKLIST.md`, `org/agents/skills/**`, repo-local `.agents/skills/**`, or tooling-only docs that mirror those)

Those changes are recorded in git and in the docs themselves; they are **not** consumer-facing package releases. If a task mixes guidance-only edits with **releasable** code or config for a published package, add a changeset **only** for the releasable portion.

## Required behavior

1. **Do not** set or bump the root or workspace package `version` field in `package.json` to reflect a new release, unless the task is explicitly to repair Changesets, release scripts, or automation—never to “include” a feature release the user just built.
2. **Do not** add or edit `CHANGELOG.md` sections to describe a change you want to ship when Changesets is the authority for that file.
3. **Do** add a new file under **`.changeset/`** (or run `changeset add` and commit the result) with:
   - the correct `patch` / `minor` / `major` (and package scoping) in the YAML frontmatter, and
   - a summary headline per `org/agents/skills/changeset/SKILL.md` (required category prefix, voice by monorepo type; optional body only when migration or must-know detail is needed).
4. When the user asks to “bump the version” or “update the changelog” for a changeset-driven repo, interpret that as **create or update a changeset** unless they explicitly want to run `changeset version` (consumer merge to main / release train).
5. **Do not** hand-edit tooling-owned release cycle artifacts under `.releases/<cycle-id>/`: `cycle.yml` (`openedAt`, `promotedAt`), `rc<n>/notes.md`, or `release-notes.md` (org ADR 0041). Manifest pins in `rc<n>/manifest.yml` are also tooling-owned at version time.

## Rationale

Manual `version` + `CHANGELOG` edits desynchronize from Changeset metadata, break release PRs, and duplicate or overwrite entries when `changeset version` runs.

## Related

- `org/agents/AGENTS.org.md` — **Versioning and changelog (Changesets)**
- `org/agents/skills/review/SKILL.md` — review gate for this rule
