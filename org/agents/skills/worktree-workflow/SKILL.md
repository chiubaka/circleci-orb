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

## Default location

- Create new worktrees under the directory that contains the repository root:
  `.worktrees/<repo>/<worktree-name>`.
- Resolve `<repo>` from the main repository directory name.
- Keep this location consistent so parallel worktrees are discoverable and easy to clean up.

Example:

```bash
# From <parent>/<repo>
mkdir -p "../.worktrees/$(basename "$(pwd)")"
git worktree add "../.worktrees/$(basename "$(pwd)")/<worktree-name>" -b "<branch-name>"
```

## Secret-file strategy

- Treat the main repository as the source of truth for local secrets.
- In each new worktree, symlink required secret/config files from the main repo
  instead of copying them.
- At minimum, link `.env` when present. Also link other local secret files
  required by the repository (for example local credentials files, private keys,
  or service-account files used for development).
- Never commit secret files from any worktree.

Example:

```bash
main_repo="/path/to/repo"
worktree="/path/to/.worktrees/<repo>/<worktree-name>"

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

- Before starting services, confirm no conflicting ports or container names are in use.
- Prefer deterministic naming (`<repo>_<worktree>_*`) for easy debugging and cleanup.
- Keep worktree-specific overrides local and untracked unless the repository has
  an approved pattern for checked-in non-secret environment templates.
- When done, stop worktree-local services before removing the worktree.
