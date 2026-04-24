# Org Agent Guidance

This folder contains org-managed agent guidance sources and sync tooling.

## Structure

- `AGENTS.org.md`: org baseline guidance content.
- `skills/<skill-name>/SKILL.md`: org-managed skills intended for distribution.
- `scripts/bootstrap-agents-md.sh`: syncs org guidance into root `AGENTS.md`.
- `scripts/bootstrap-skills.sh`: links org skills into `.agents/skills`.
- `scripts/bootstrap.sh`: wrapper that runs both bootstrap steps.

## Ownership boundaries

- Org-level defaults belong in `AGENTS.org.md`.
- Repo-specific requirements belong in root `AGENTS.md` repo overrides:
  `<!-- REPO_OVERRIDES_START --> ... <!-- REPO_OVERRIDES_END -->`.
- Keep org-level guidance portable; avoid repository-path or package-specific mandates.

## How `AGENTS.md` sync works

`bootstrap-agents-md.sh` manages marker-based sections in root `AGENTS.md`:

- Managed markers:
  - `<!-- ORG_GUIDANCE_START -->`
  - `<!-- ORG_GUIDANCE_END -->`
- Repo override markers:
  - `<!-- REPO_OVERRIDES_START -->`
  - `<!-- REPO_OVERRIDES_END -->`

Behavior:

- If `AGENTS.md` is missing, the script creates it with both sections.
- If markers exist, only the org-managed section is refreshed.
- Repo overrides are preserved exactly.
- In malformed-marker scenarios, default mode migrates prior content to repo overrides and creates a backup.

## How skills sync works

`bootstrap-skills.sh` scans `org/agents/skills/*` and ensures corresponding entries in
`.agents/skills/*` are symlinks to org-managed skill directories.

- It creates missing links.
- It leaves non-org local skills untouched.
- It reports conflicts when a target exists but is not the expected link.

## Typical workflow

1. Edit org-level guidance in `AGENTS.org.md` and/or org skills under `skills/`.
2. Run `org/agents/scripts/bootstrap.sh`.
3. Validate clean sync with `org/agents/scripts/bootstrap.sh --check`.

If only AGENTS guidance changed, you can run only:

- `org/agents/scripts/bootstrap-agents-md.sh`
- `org/agents/scripts/bootstrap-agents-md.sh --check`

If skills were added or renamed, also run:

- `org/agents/scripts/bootstrap-skills.sh`
- `org/agents/scripts/bootstrap-skills.sh --check`
