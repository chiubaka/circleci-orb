---
name: worktree-workflow
description: >-
  Standard workflow for creating and operating git worktrees with predictable
  placement, secret-file symlinking, and isolated runtime resources. Use when
  creating a new worktree, preparing a worktree environment, or running
  parallel agent work in separate worktrees that could contend for ports,
  Docker resources, caches, or other shared infrastructure.
---

# Worktree workflow

## Required location

Use **one** path only: repository-root `.worktrees/<worktree-name>/`.

- Create every new worktree there. Do not invent alternate layouts.
- **Forbidden:** paths outside the repository (including `../.worktrees/…` or
  any sibling of the clone). Those sit outside the IDE workspace and cause
  repeated permission prompts.
- **Forbidden:** paths under `.git/` (including `.git/worktree-checkouts/…`).
  Vite/Vitest and hooks break there.

Example (from the repository root):

```bash
mkdir -p .worktrees
git worktree add .worktrees/<worktree-name> -b "<branch-name>"
```

## Ignore / exclude (do not weaken)

Repositories that run org bootstrap should already have these; if missing, add
them (or re-run `org/agents/scripts/bootstrap.sh` / `bootstrap-worktrees.sh`):

1. **`.gitignore`:** `.worktrees/` — keeps linked checkouts out of main-checkout
   `git status`.
2. **`.vscode/settings.json`:** `files.exclude` and `search.exclude` for
   `**/.worktrees` — keeps Quick Open / search focused on the primary tree.
3. **Do not** add `.worktrees/` to `.cursorignore` — that blocks Agent
   Read/Write/@ from the primary window (terminal and MCP are not gated by
   it). `.gitignore` already excludes `.worktrees/` from Cursor indexing, so
   do not assume indexed discovery or unconditional `@` access; use explicit
   paths and `git worktree list`.
4. Skip stacking vendor-only ignores (for example `.claudeignore`) solely for
   this layout; `.gitignore` covers most indexing exclusions.

Discover worktrees with `git worktree list`, not by browsing the ignored folder
in the UI. Rationale and rejected alternatives: org ADR 0047.

## Secret-file strategy

- Treat the main repository as the source of truth for local secrets.
- In each new worktree, symlink required secret/config files from the main repo
  instead of copying them.
- At minimum, link `.env` when present. Also link other local secret files
  required by the repository (for example local credentials files, private keys,
  or service-account files used for development).
- Never commit secret files from any worktree.
- Run the repository’s install command (for example `pnpm install`) in a new
  worktree before hooks or tests that need `node_modules`.

Example:

```bash
main_repo="$(git rev-parse --show-toplevel)"
worktree="$main_repo/.worktrees/<worktree-name>"

ln -sfn "$main_repo/.env" "$worktree/.env"
# Repeat for additional secret files required by the repository.
```

## Isolate contested resources

- Assume parallel worktrees can conflict on:
  - host ports
  - Docker container names and compose project names
  - local DB/cache names and volumes
  - temp directories and build caches
- Define a short worktree identifier (for example `<worktree-name>` sanitized).
- Apply that identifier consistently to environment variables and runtime config
  so each worktree gets isolated resources.

## Isolation checklist

- Choose unique port offsets per worktree (for app, API, DB admin, etc.).
- Set container namespace variables per worktree (for example compose project).
- Set distinct data/cache names when local services persist state.
- Keep per-worktree override values in untracked local env files.
- Verify startup commands and tests use the worktree-specific env values.

Example env overrides:

```bash
WORKTREE_ID="<worktree-name>"
WORKTREE_ID_SUFFIX="10" # Choose a unique 2-digit suffix per worktree (e.g. 10, 11, 12).
PORT=4010
API_PORT=4011
COMPOSE_PROJECT_NAME="repo_${WORKTREE_ID}"
DATABASE_URL="postgres://localhost:55${WORKTREE_ID_SUFFIX}/app_${WORKTREE_ID}"
REDIS_URL="redis://localhost:63${WORKTREE_ID_SUFFIX}/0"
```

## Operating guidance

- Prefer the primary IDE window with paths like `.worktrees/<name>/…` or
  `git -C .worktrees/<name> …`.
- Before starting services, confirm no conflicting ports or container names are in use.
- Prefer deterministic naming (`<repo>_<worktree>_*`) for easy debugging and cleanup.
- Keep worktree-specific overrides local and untracked unless the repository has
  an approved pattern for checked-in non-secret environment templates.
- When done, stop worktree-local services before removing the worktree.
- To move a worktree branch into the current IDE checkout (commit/push loose work,
  remove the worktree, then check out the branch), use `adopt-worktree-branch`.
