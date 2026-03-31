# @chiubaka/org

This directory is the org-level source of truth for shared architecture guidance and
agent guidance used across Chiubaka repositories.

## What lives here

- `org/docs/adr/`: org-wide ADRs and architecture conventions.
- `org/agents/AGENTS.org.md`: org-managed baseline guidance inserted into each repo root `AGENTS.md`.
- `org/agents/skills/`: org-managed agent skills that can be distributed into local agent skill paths.
- `org/agents/scripts/`: bootstrap/sync scripts that propagate org guidance into local repo surfaces.

## Guidance ownership model

- Org-level defaults live in `org/agents/AGENTS.org.md` and should stay portable across repositories.
- Repository-specific requirements stay in each repo's root `AGENTS.md` override section
  (`<!-- REPO_OVERRIDES_START --> ... <!-- REPO_OVERRIDES_END -->`).
- On conflicts, repo overrides take precedence over org defaults.

## Bootstrap and sync

Use org bootstrap scripts from `org/agents/scripts/`:

- `bootstrap-agents-md.sh`: syncs the org-managed section of root `AGENTS.md` from `org/agents/AGENTS.org.md`.
- `bootstrap-skills.sh`: links org-managed skills from `org/agents/skills/` into `.agents/skills/`.
- `bootstrap.sh`: runs both scripts in order.

Run from repository root:

- Apply sync:
  - `org/agents/scripts/bootstrap.sh`
- Validate drift only (no writes):
  - `org/agents/scripts/bootstrap.sh --check`

## Working norms

- Edit org-level guidance in `org/agents/AGENTS.org.md`, then run bootstrap sync.
- Keep repo-specific details out of org-level guidance; place them in repo overrides.
- If org guidance changed, verify with:
  - `org/agents/scripts/bootstrap-agents-md.sh --check`
  - (and for skill additions/renames) `org/agents/scripts/bootstrap-skills.sh --check`

## Bootstrap `org/` into a new repository (`git subtree`)

Use `git subtree` when you want to vendor this `org/` directory into another repository
while keeping a clean upstream sync path.

### One-time setup in target repo

From the target repository root:

- Add the org remote:
  - `git remote add org <ORG_REPO_URL>`
- Fetch org history:
  - `git fetch org`
- Add `org/` as a subtree (use your org default branch name):
  - `git subtree add --prefix=org org <ORG_BRANCH>`
- Run bootstrap to materialize/sync managed outputs:
  - `org/agents/scripts/bootstrap.sh`

### Pull upstream org updates later

- `git fetch org`
- `git subtree pull --prefix=org org <ORG_BRANCH>`
- `org/agents/scripts/bootstrap.sh --check`

### Subtree safety and operational guardrails

- Treat `org/` as subtree-managed; avoid deleting and recreating the directory.
- Keep subtree command style consistent over time for this prefix:
  - If you started with `--squash`, continue using `--squash` for later pulls and pushes.
- Keep remote, branch, and prefix stable (`org`, `<ORG_BRANCH>`, `--prefix=org`) unless intentionally migrating with a documented plan.
- Avoid history rewrites that drop subtree integration ancestry on active branches.

Quick health checks:

- Confirm subtree markers exist in history:
  - `git log --grep="git-subtree-dir: org" --all`
- Confirm the org remote and branch you intend to sync:
  - `git remote -v`
  - `git branch -r | rg "org/"`
- If sync fails, prefer diagnosis and non-destructive recovery before subtree reinitialization.

## Contributing org changes back upstream

If you edit files under `org/` from a consumer repository and want the simplest direct sync:

- Commit your changes in the consumer repository.
- Push the `org/` subtree directly to org remote:
  - `git subtree push --prefix=org org <ORG_BRANCH>`

Then in other consumers:

- `git fetch org`
- `git subtree pull --prefix=org org <ORG_BRANCH>`

For more detail, see `org/agents/README.md`.
