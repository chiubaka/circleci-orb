---
name: update-agent-guidance
description: >-
  Updates agent guidance by routing org-wide changes to org guidance files and
  repo-specific changes to local overrides, then re-syncing managed outputs.
---

# Update agent guidance

## Goal

Make agent-guidance edits in the correct ownership boundary:

- **Org-level guidance** for defaults shared across repositories.
- **Repo-level guidance** for local behavior and implementation details.
- **AGENTS.org.md streamlining** delegated to `agents-org-md-streamline`.

## When to use this skill

Use this skill when asked to add, move, split, or refactor guidance in:

- `AGENTS.md`
- `REVIEW-CHECKLIST.md`
- `org/agents/AGENTS.org.md`
- agent-guidance related docs or prompts

Use `agents-org-md-streamline` for `org/agents/AGENTS.org.md` streamlining and rule classification. This skill is the routing/sync coordinator.

## Ownership dichotomy (required)

Decide scope before editing:

1. **Org-level** if guidance is portable and should apply across repositories.
2. **Repo-level** if guidance depends on this repository's package names, paths, scripts, lint config, or workflows.

If uncertain, choose repo-level first, then promote to org-level only when portable.

## Where edits belong

- **Org-level defaults:** `org/agents/AGENTS.org.md`
- **Repo-level overrides:** local `AGENTS.md` inside `<!-- REPO_OVERRIDES_START -->` and `<!-- REPO_OVERRIDES_END -->`
- **Repo review prompts/polish checks:** local `REVIEW-CHECKLIST.md`
- **Durable architectural decisions:** ADRs at the appropriate scope (`org/docs/adr/`, `docs/adr/`, or `<package>/docs/adr/`)

## Critical rules

- **Guidance and ADRs without a Changeset:** Edits that are **only** to agent guidance, org skills, or ADRs do **not** require a `.changeset/*` file. Do not add one by default—see `org/agents/skills/changesets-hygiene/SKILL.md` (**When not to add a Changeset**).
- On repositories that use **Changesets**, when shipping **releasable** work (not guidance-only), do **not** add release version bumps to `package.json` or new sections to `CHANGELOG.md` in the same PR; add or update a **`.changeset/*`** file instead, per `org/agents/skills/changesets-hygiene/SKILL.md`, then run the normal release or `changeset version` flow. Hand-editing only belongs to fixing Changesets or changelog tooling in isolation.
- Org-level guidance must not depend on repo-specific files or conventions as normative requirements.
- Keep root `AGENTS.md` bootstrap-compatible:
  - preserve `<!-- ORG_GUIDANCE_START --> ... <!-- ORG_GUIDANCE_END -->`
  - preserve `<!-- REPO_OVERRIDES_START --> ... <!-- REPO_OVERRIDES_END -->`
- Keep repo overrides minimal.

## Required sync steps

After org-level guidance edits (including AGENTS.org.md streamlining), run:

- `org/agents/scripts/bootstrap-agents-md.sh`

Then verify sync:

- `org/agents/scripts/bootstrap-agents-md.sh --check`

If you created or renamed an org-level skill as part of the same task, also run:

- `org/agents/scripts/bootstrap-skills.sh`

## Practical workflow

1. Classify each requested guidance change as org-level or repo-level.
2. Apply direct edits to the right source file(s):
   - org defaults -> `org/agents/AGENTS.org.md`
   - repo-local behavior -> root `AGENTS.md` repo overrides and/or `REVIEW-CHECKLIST.md`
3. If org AGENTS guidance content was reorganized, run `agents-org-md-streamline`.
4. Run the bootstrap sync command(s) and validate with `--check`.

## Quick examples

- "Apply this naming convention across all repos" -> org-level -> edit `org/agents/AGENTS.org.md`, run `agents-org-md-streamline`, then run bootstrap sync.
- "Mention this repository's lint config file path" -> repo-level -> put it in root `AGENTS.md` overrides or `REVIEW-CHECKLIST.md`.
- "Split org AGENTS generation rules vs review rules" -> use `agents-org-md-streamline`, then bootstrap sync from `org/agents/AGENTS.org.md`.
