---
name: changesets-hygiene
description: >-
  Prevents hand-edited semver and changelog in Changesets-driven repos. Use
  .changeset entries and changeset add/version flows instead; never bump
  package.json version or CHANGELOG.md to ship features in those repos. Prefer
  reconciling branch changesets against the PR merge delta over stacking
  commit-shaped notes or amalgamating task diaries into one file. Skips ADRs
  and agent-guidance-only edits (see When not to add a Changeset).
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
- **Agent/contributor guidance** that does not change runtime or published APIs (for example `AGENTS.md`, `org/agents/AGENTS.org.md`, `REVIEW-CHECKLIST.md`, `org/agents/skills/**`, `org/agents/rules/**`, repo-local `.agents/skills/**`, or tooling-only docs that mirror those)

Those changes are recorded in git and in the docs themselves; they are **not** consumer-facing package releases. If a task mixes guidance-only edits with **releasable** code or config for a published package, add a changeset **only** for the releasable portion.

Also do **not** add a changeset solely to document fixing, reverting, or polishing behavior that **never existed on the merge base** (unreleased WIP on this branch). See `org/agents/skills/changeset/SKILL.md` (**Unit of truth: PR / branch merge delta**).

## Required behavior

1. **Do not** set or bump the root or workspace package `version` field in `package.json` to reflect a new release, unless the task is explicitly to repair Changesets, release scripts, or automation—never to “include” a feature release the user just built.
2. **Do not** add or edit `CHANGELOG.md` sections to describe a change you want to ship when Changesets is the authority for that file.
3. **Do** add a new file under **`.changeset/`** (or run `changeset add` and commit the result) with:
   - the correct `patch` / `minor` / `major` (and package scoping) in the YAML frontmatter, and
   - a summary headline per `org/agents/skills/changeset/SKILL.md` (required category prefix, voice by monorepo type; optional body only when migration or must-know detail is needed).
4. When the user asks to “bump the version” or “update the changelog” for a changeset-driven repo, interpret that as **create or update a changeset** unless they explicitly want to run `changeset version` (consumer merge to main / release train).
5. **Prefer reconcile over accumulate.** Before finishing releasable work on a branch with an open PR (or that will open one):
   - List every `.changeset/*.md` path **added, modified, or deleted** relative to the base (not only files present on the branch but absent from base).
   - For each remaining file: keep only if it still describes a consumer-visible delta vs base.
   - Prefer **rewriting the single headline** of an existing branch changeset when the new work is the same release story; **delete** notes that became no-ops (for example, fixed a bug this branch introduced).
   - Do **not** append another category-prefixed line to an existing file. Do **not** concatenate task notes into a multi-`Feature:`/`Fix:` body — that is a failed reconcile; collapse to the net story.
   - Do **not** treat “I completed a task” as automatic justification for a new changeset file.
6. Authoring detail (prefixes, voice, merge-delta rules, one-headline shape): `org/agents/skills/changeset/SKILL.md`.

## Rationale

Manual `version` + `CHANGELOG` edits desynchronize from Changeset metadata, break release PRs, and duplicate or overwrite entries when `changeset version` runs. Commit-shaped stacking and multi-prefix amalgamation produce redundant or misleading release notes that do not match the PR’s pre- vs post-merge state.

## Related

- `org/agents/AGENTS.org.md` — **Versioning and changelog (Changesets)**
- `org/agents/skills/changeset/SKILL.md` — authoring + merge-delta reconciliation
- `org/agents/skills/review/SKILL.md` — review gate for this rule
