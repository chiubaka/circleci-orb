# Org Agent Guidance

This folder contains org-managed agent guidance sources and sync tooling.

## Structure

- `AGENTS.org.md`: org baseline guidance content (structural/generation-time; short pointers only for always-on behavior).
- `rules/<name>.md`: org-managed always-on behavioral rules projected into tool-native paths.
- `skills/<skill-name>/SKILL.md`: org-managed skills intended for distribution.
- `scripts/bootstrap-agents-md.sh`: syncs org guidance into root `AGENTS.md`.
- `scripts/bootstrap-skills.sh`: links org skills into `.agents/skills`.
- `scripts/bootstrap-rules.sh`: projects org rules into `.cursor/rules` and `.claude/rules`.
- `scripts/bootstrap-worktrees.sh`: ensures in-repo `.worktrees/` ignore and IDE exclude entries.
- `scripts/bootstrap.sh`: wrapper that runs skills, AGENTS, rules, and worktrees bootstrap steps.

## Ownership boundaries

- Org-level defaults belong in `AGENTS.org.md`.
- Always-on meta-behavior belongs in `rules/` (full text) with a short pointer from `AGENTS.org.md`.
- On-demand workflows belong in `skills/`.
- Repo-specific requirements belong in root `AGENTS.md` repo overrides:
  `<!-- REPO_OVERRIDES_START --> ... <!-- REPO_OVERRIDES_END -->`.
- Keep org-level guidance portable; avoid repository-path or package-specific mandates.
- Do not author under `.cursor/` or `.claude/` in the **org repository**; those paths are projection targets in consuming repos.

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

## How rules sync works

`bootstrap-rules.sh` scans `org/agents/rules/*.md` (or `agents/rules/*.md` in the org repo itself) and projects each file into:

- `.cursor/rules/<name>.mdc` — Cursor always-apply rule (`alwaysApply: true` + body)
- `.claude/rules/<name>.md` — Claude Code always-on rule (body)

Behavior:

- Creates missing projections in write mode.
- Leaves matching projections unchanged.
- Reports conflicts when a target exists with different content (does not overwrite).
- Leaves unrelated local rule files untouched.

Codex and tools without a rules directory follow the short pointer in `AGENTS.md` to the org rules source file.

## How worktrees layout sync works

`bootstrap-worktrees.sh` ensures the repository is ready for in-repo git worktrees under `.worktrees/`:

- Adds `.worktrees/` to root `.gitignore` when missing.
- Merges `**/.worktrees` into `.vscode/settings.json` `files.exclude` and `search.exclude` without wiping other settings.
- Does **not** add `.worktrees/` to `.cursorignore` (and fails `--check` if that path is ignored there).

See org ADR 0047 for rationale. Day-to-day create/operate flows live in the `worktree-workflow` skill.

## Typical workflow

1. Edit org-level guidance in `AGENTS.org.md`, org rules under `rules/`, and/or org skills under `skills/`.
2. Run `org/agents/scripts/bootstrap.sh`.
3. Validate clean sync with `org/agents/scripts/bootstrap.sh --check`.

If only AGENTS guidance changed, you can run only:

- `org/agents/scripts/bootstrap-agents-md.sh`
- `org/agents/scripts/bootstrap-agents-md.sh --check`

If skills were added or renamed, also run:

- `org/agents/scripts/bootstrap-skills.sh`
- `org/agents/scripts/bootstrap-skills.sh --check`

If rules were added or edited, also run:

- `org/agents/scripts/bootstrap-rules.sh`
- `org/agents/scripts/bootstrap-rules.sh --check`

If only worktree ignore/exclude layout needs refresh:

- `org/agents/scripts/bootstrap-worktrees.sh`
- `org/agents/scripts/bootstrap-worktrees.sh --check`
