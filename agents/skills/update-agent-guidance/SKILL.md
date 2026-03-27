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

## When to use this skill

Use this skill when asked to add, move, split, or refactor guidance in:

- `AGENTS.md`
- `REVIEW-CHECKLIST.md`
- `org/agents/AGENTS.org.md`
- agent-guidance related docs or prompts

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

- Org-level guidance must not depend on repo-specific files or conventions as normative requirements.
- Keep root `AGENTS.md` bootstrap-compatible:
  - preserve `<!-- ORG_GUIDANCE_START --> ... <!-- ORG_GUIDANCE_END -->`
  - preserve `<!-- REPO_OVERRIDES_START --> ... <!-- REPO_OVERRIDES_END -->`
- Keep repo overrides minimal; remove local duplication already covered by org guidance or commonly triggered skills/docs.

## Required sync step for org-level guidance updates

After any change to `org/agents/AGENTS.org.md`, run:

- `org/agents/scripts/bootstrap-agents-md.sh`

Then verify sync:

- `org/agents/scripts/bootstrap-agents-md.sh --check`

If you created or renamed an org-level skill as part of the same task, also run:

- `org/agents/scripts/bootstrap-skills.sh`

## Practical workflow

1. Classify each requested guidance change as org-level or repo-level.
2. Move portable defaults into `org/agents/AGENTS.org.md`.
3. Keep only truly local requirements in root `AGENTS.md` repo overrides.
4. Update `REVIEW-CHECKLIST.md` only for repo-specific review guidance.
5. Run the bootstrap sync command(s) and validate with `--check`.

## Quick examples

- "Apply this naming convention across all repos" -> org-level -> edit `org/agents/AGENTS.org.md`, then run bootstrap sync.
- "Mention this repository's lint config file path" -> repo-level -> put it in root `AGENTS.md` overrides or `REVIEW-CHECKLIST.md`.
- "This checklist item repeats org defaults already in skills" -> remove from repo overrides unless local behavior would break without it.
