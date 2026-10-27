---
status: accepted
date: 2026-09-24
decision-makers: Daniel Chiu
---

# ADR 0047: Keep git worktrees inside the repository under `.worktrees/`

## Context and Problem Statement

Parallel agent and contributor work often needs multiple checkouts of the same repository (feature branches, background agents, isolated runtime ports). Git worktrees are the right tool, but **where** those worktrees live affects day-to-day friction in Cursor and similar IDEs:

- Checkouts **outside** the primary workspace tend to trigger repeated “outside workspace” permission prompts for file and shell tools.
- Checkouts that pollute `git status`, Quick Open, or search make the primary window harder to use.
- Checkouts nested under `.git/` can break common Node/Vite tooling in ways that only appear in that unusual path.

The question is:

**Where should linked worktrees live so they stay reachable from the primary IDE window with minimal approval friction, without polluting the main checkout or breaking package tooling?**

## Decision Drivers

- Reduce Cursor (and similar) approvals caused by paths outside the opened workspace
- Keep the primary checkout’s `git status`, file picker, and search free of worktree noise
- Allow agents in the primary window to read and write worktree paths when needed
- Avoid layout-specific workarounds in package tooling (Vite, Vitest, hooks) that CI on a normal checkout does not need
- Keep setup portable across repositories that embed org standards via subtree + bootstrap

## Considered Options

- Sibling directories outside the repo (for example `../.worktrees/<repo>/<name>/`)
- Nested under `.git/` (for example `.git/worktree-checkouts/<name>/`)
- Repo-root `.worktrees/<name>/` (gitignored + IDE-excluded; not in `.cursorignore`)

## Decision Outcome

Chosen option: **Repo-root `.worktrees/<name>/`**, ignored by git and excluded from the IDE file picker/search, but **not** listed in `.cursorignore`.

Justification: In-repo placement keeps worktrees inside the opened workspace (fewer outside-workspace approvals) while remaining a normal package root for Vite and hooks. Gitignore plus VS Code/Cursor `files.exclude` / `search.exclude` hide the trees from human browsing and from primary-checkout status noise. Omitting `.cursorignore` preserves agent Read/Write (and related IDE file tools) from the primary window; terminal and MCP tools are not gated by `.cursorignore` either. `.gitignore` still excludes these paths from Cursor indexing, so indexed discovery and unconditional `@` access are not guaranteed. Earlier placements either traded approval savings for tooling breakage (under `.git/`) or left worktrees outside the workspace (sibling directories).

### Consequences

- Good, because worktrees stay inside the primary workspace path, which reduces outside-workspace approval prompts
- Good, because `.gitignore` keeps linked checkouts out of main-checkout `git status` noise
- Good, because IDE exclude settings keep Quick Open and search focused on the primary tree
- Good, because agents can still operate on `.worktrees/…` from the primary window when `.cursorignore` is not used for that path
- Good, because package tooling sees a normal repo-root-relative checkout rather than a path under `.git/`
- Neutral, because contributors discover worktrees via `git worktree list` rather than browsing the ignored folder in the UI
- Bad, because each repository must keep ignore/exclude entries in sync (addressed by org bootstrap; see Confirmation)
- Bad, because large worktree trees still consume disk under the repo root and can confuse tools that ignore `.gitignore` poorly

### Confirmation

Compliance is confirmed by:

- New worktrees live only under the repository root at `.worktrees/<worktree-name>/`—not under `.git/`, and not outside the repository (including sibling `../.worktrees/…`)
- Root `.gitignore` containing `.worktrees/`
- Committed `.vscode/settings.json` entries that exclude `**/.worktrees` from `files.exclude` and `search.exclude`
- Absence of `.worktrees/` (or equivalent) from `.cursorignore`
- Org bootstrap applying or validating the ignore/exclude entries when a consuming repository runs the combined bootstrap entrypoint after embedding or updating the org subtree

## Pros and Cons of the Options

### Sibling directories outside the repo (for example `../.worktrees/<repo>/<name>/`)

This was the prior default in org agent guidance: create worktrees under a parent directory that contains the clone, namespaced by repository folder name.

- Good, because the primary checkout’s tree stays clean without relying on ignore rules
- Good, because worktrees never appear under the opened folder in the file tree
- Bad, because paths sit outside the IDE workspace and tend to trigger repeated permission prompts for agents and sandboxed tools
- Bad, because cleanup and discovery span a sibling directory that is easy to forget when deleting clones

**Rule carried forward:** do not place new worktrees outside the repository.

Tried so the checkout would remain inside the workspace while staying out of normal project browsing (because tooling often treats `.git` as special).

- Good, because the path is inside the workspace root for editor path checks
- Good, because humans rarely browse `.git/` in Quick Open
- Bad, because **Vite denies serving from `.git` by default**. With a package root under `.git/…`, Vitest failed with errors such as `Cannot find module '/@vite/env'` and collected zero tests
- Bad, because pre-push and other local hooks that run package tests from that worktree failed the same way, blocking `git push` until the layout was abandoned or Vite filesystem guards were weakened
- Bad, because making Vitest work required permanent product config such as `server.fs.strict: false` (or an allowlist under `.git`)—a footgun that CI on a normal GitHub checkout did not need
- Neutral, because Cursor file tools improved somewhat from being “inside” the workspace, but Shell still often needed broad permissions for unrelated sandbox reasons—so approval savings did not outweigh Vite/hook breakage

**Rule carried forward:** never place worktrees under `.git/`.

### Repo-root `.worktrees/<name>/` (gitignored + IDE-excluded; not in `.cursorignore`)

```bash
mkdir -p .worktrees
git worktree add .worktrees/<worktree-name> -b <branch-name>
```

- Good, because the path is inside the workspace, which reduces outside-workspace approval prompts relative to sibling layouts
- Good, because `.gitignore` keeps the main checkout’s status clean
- Good, because VS Code/Cursor exclude settings keep the file picker and search usable for humans
- Good, because leaving `.cursorignore` alone lets agents in the primary window still touch `.worktrees/…`
- Good, because the checkout is a normal directory for Vite, Vitest, and hooks—no `.git`-path workarounds
- Bad, because repositories must commit ignore/exclude configuration (or receive it via bootstrap) for the layout to stay tidy

## More Information

### Ignore and exclude expectations

1. **`.gitignore` (required):** `.worktrees/`
2. **`.vscode/settings.json` (for human file picker / search):**

   ```json
   {
     "files.exclude": {
       "**/.worktrees": true
     },
     "search.exclude": {
       "**/.worktrees": true
     }
   }
   ```

3. **Do not** add `.worktrees/` to `.cursorignore`. That file blocks Agent Read/Write/@ from the primary window; terminal and MCP tools are not blocked by it. Multi-worktree workflows from one IDE window need Read/Write on those paths. Because `.gitignore` excludes `.worktrees/` from Cursor indexing, do not assume indexed discovery or unconditional `@` access—prefer explicit paths and `git worktree list`. Other ignores (`node_modules/`, secrets, build output) remain fine.
4. Skip a stack of vendor-specific ignore files (for example `.claudeignore`) solely for this layout; `.gitignore` covers most indexing exclusions, and vendor ignores are uneven for Glob.

### Operating notes

- Prefer working from the primary window with paths like `.worktrees/<name>/…` or `git -C .worktrees/<name> …`.
- Symlink secrets (for example `.env`) from the main checkout into each worktree; install dependencies in new worktrees before hooks that need them.
- Discover worktrees with `git worktree list`, not by browsing the ignored folder in the UI.

### Related

- Org agent standards projection and bootstrap entrypoints: [ADR 0015](0015-centralized-org-agent-standards-git-subtree-projection.md)
- Day-to-day create/operate and adopt flows live in contributor/agent guidance (skills), not as normative ADR runbooks
