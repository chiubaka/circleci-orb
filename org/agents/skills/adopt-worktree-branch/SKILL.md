---
name: adopt-worktree-branch
description: >-
  Brings a branch from a git worktree into the current IDE workspace checkout
  by preserving loose work, removing the worktree, and checking out the branch
  locally. Use when the user wants a worktree branch in the current IDE window—
  including bring branch into the foreground, switch/check out this window to a
  worktree branch, adopt/open/use background worktree work here, or test/iterate
  on worktree changes in the main window—or when deleting a worktree so the
  primary checkout can use that branch. Match intent; do not require the word
  “foreground”.
---

# Adopt worktree branch into the current IDE

## Goal

Move a branch that is checked out in another worktree into the **current
workspace** (the primary repo checkout open in the IDE) so the user can test or
iterate on it there.

Git will not allow the same branch to be checked out in two worktrees. The
worktree that holds the branch must be removed before the current checkout can
switch to it.

## When to use

Use whenever the user wants a worktree-held branch available in this IDE
checkout—intent matters more than exact wording. Common phrasings include:

- “Bring branch `<name>` into the foreground in this IDE window”
- “Switch this window to `<name>`” / “check out `<name>` here”
- “Adopt / open / use the worktree branch in this window”
- “I want to test / iterate on `<name>` in the main IDE”

Do not require the word “foreground”; treat equivalent requests the same.

## Preconditions

- The current workspace should be the **primary repository checkout**, not the
  worktree directory itself. If the IDE is already open on the worktree path,
  open the primary repo folder in this window (or a new one) and run this flow
  from there.
- Prefer the worktree layout from `worktree-workflow`
  (`.worktrees/<worktree-name>` inside the repo), but discover via
  `git worktree list` rather than assuming paths.

## Procedure

Copy this checklist and complete it in order:

```text
Adopt progress:
- [ ] 1. Resolve target branch
- [ ] 2. Detect worktree holding that branch
- [ ] 3. Preserve loose work (commit + push) in the worktree
- [ ] 4. Stop worktree-local services if any
- [ ] 5. Preflight primary checkout (no checkout blockers)
- [ ] 6. Preserve local-only leftovers, then remove the worktree
- [ ] 7. Check out the branch in the current workspace
- [ ] 8. Confirm status
```

### 1. Resolve the target branch

- Use the branch the user named.
- If they named a worktree path or folder instead, resolve its checked-out
  branch with `git -C <worktree-path> branch --show-current` (or porcelain
  worktree list output).

### 2. Detect whether that branch is in a worktree

From the primary checkout:

```bash
git worktree list --porcelain
```

Find a worktree whose `branch refs/heads/<target-branch>` is set (or whose
path is the named worktree).

- **No other worktree holds the branch** → skip to step 7 (checkout in the
  current workspace). Still push only if the user asked to publish; do not
  invent a worktree cleanup.
- **Current workspace already has that branch checked out** → stop; report
  that the IDE is already on the branch.
- **Another worktree holds the branch** → continue with steps 3–6, then 7.

### 3. Preserve all loose work in that worktree

Operate **inside the worktree path** (`git -C <worktree-path> …` or a subshell
with that cwd).

1. Inspect status and diff (`status`, staged/unstaged, untracked).
2. Do **not** commit secrets (`.env`, credentials, keys, etc.). Leave secret
   and machine-local files untracked; they are often symlinks per
   `worktree-workflow`.
3. For non-secret dirty state (staged, unstaged, or untracked that belongs in
   the repo):
   - Stage and commit only changes that are **clearly in scope** for this
     branch / adopt request.
   - If ownership or task relevance is **unclear**, stop and ask before
     staging; leave unrelated edits untouched (same bar as
     `partial-commits`).
   - In a dedicated single-task worktree where remaining non-secret changes
     are obviously that task’s work, commit them without extra confirmation.
   - Use `commit-message` for the message.
4. **Push** the branch to its configured upstream (`git push` / set upstream
   if needed). Resolve **push** and **fetch** remotes **independently**—do
   **not** assume a single `<remote>` or hard-code `origin`:
   - `push_remote`: `branch.<target-branch>.pushRemote`, then
     `remote.pushDefault`, then `branch.<target-branch>.remote`
   - `fetch_remote`: `branch.<target-branch>.remote` (fallback only if unset
     after the push/upstream setup above)
   - If the branch **already has an upstream**, push with
     `git push <push_remote> <target-branch>` (**no** `-u`) so you do not
     rewrite tracking (e.g. fetch from `upstream`, push to `origin`).
   - Use `git push -u <push_remote> <target-branch>` **only** when no
     upstream exists; then record the upstream that push established.
   - Keep using the resolved `push_remote` / `fetch_remote` for later steps.
   - Do not skip push: the point is to land background work safely before
     deleting the worktree
5. If the worktree is already clean (aside from expected secret/local
   leftovers) and the branch is already pushed, skip commit/push and continue.

If commit or push fails, **stop**. Do not remove the worktree until the branch
is committed and pushed (or the user explicitly waives push after you explain
the risk).

### 4. Stop worktree-local services

Before removal, stop services that belong to that worktree (dev servers,
compose projects, extra DBs) when they are running, per `worktree-workflow`.
Do not tear down unrelated primary-checkout services.

### 5. Preflight the primary checkout

**Before** removing the source worktree, confirm the primary checkout can
switch to `<target-branch>`:

1. In the primary workspace, **fetch the target first** with `fetch_remote`
   from step 3:
   `git fetch <fetch_remote> <target-branch>`.
2. Check whether `git checkout <target-branch>` would conflict with **tracked
   or untracked** local changes (paths that checkout would overwrite or
   refuse)—not merely whether commits merge cleanly. Commit-only checks such
   as `git merge-tree` are insufficient on their own.
3. If anything would block checkout, **stop**, explain the conflict, and ask
   how to proceed. Do **not** stash, reset, discard, or remove the worktree
   yet.

Only continue to step 6 when this preflight succeeds (or the primary tree is
already clean relative to the target).

### 6. Preserve local-only leftovers, then remove the worktree

After step 3, remaining untracked files are often secrets or machine-local
config (frequently symlinks into the primary checkout per
`worktree-workflow`).

1. List leftover untracked / ignored files in the worktree.
2. For each leftover:
   - **Confirmed-safe symlink** into the primary checkout (or another durable
     location)—**unlink the symlink** in the worktree only (do not delete the
     symlink target). Normal `git worktree remove` rejects unclean trees, and
     these symlinks count as untracked.
   - **Non-symlink** secret or machine-local file—copy or relocate it
     somewhere durable **outside** the worktree path, or confirm with the
     user that it is disposable.
3. If preservation cannot be confirmed for non-symlink leftovers, **abort**—
   do not remove the worktree.

Then, from the primary checkout:

```bash
git worktree remove <worktree-path>
```

- Prefer a normal remove. Git refuses unclean worktrees by default.
- **Do not** use `git worktree remove --force` while untracked secret or
  machine-local files remain in the worktree—`--force` can delete them.
- Only use `--force` after leftovers are unlinked/relocated/confirmed
  disposable and nothing valuable remains that step 3 did not already commit.
- Run `git worktree prune` only if a stale registration remains after a
  successful remove.

### 7. Check out the branch in the current workspace

In the primary checkout (current IDE workspace), use `fetch_remote` from
step 3 (fetch may already be done in step 5):

```bash
git fetch <fetch_remote> <target-branch>   # if still needed
git checkout <target-branch>
```

- If checkout is blocked by **local dirty files in the primary checkout**, do
  **not** stash, reset, or discard them. Explain the conflict and ask how to
  proceed (step 5 should have caught this; stop if it still fails).
- Prefer updating to match the just-pushed tip when the primary clone was
  behind (`git pull --ff-only` from the appropriate upstream, or equivalent)
  so the IDE matches the preserved worktree work.

### 8. Confirm

Report briefly:

- Worktree path removed (or that none existed)
- Commit(s) created and push result (or “already clean”)
- `push_remote` and `fetch_remote` used (and any upstream only if newly set
  by `git push -u`)
- Current branch in this workspace (`git branch --show-current` / `git status -sb`)

## Do not

- Delete a worktree that still has uncommitted non-secret work.
- `git checkout` the target branch in the primary repo **before** removing the
  worktree that holds it (git will reject this).
- Remove the source worktree while primary-checkout dirty state would block
  the target checkout.
- Use `git worktree remove --force` in a way that deletes untracked secrets or
  machine-local files.
- Leave confirmed-safe secret symlinks in place and expect a normal
  `git worktree remove` to succeed—unlink those symlinks first.
- Discard or stash primary-checkout dirty state to force the switch.
- Commit secret or local-only env files from the worktree.
- Hard-code `origin`, or reuse one remote for both push and fetch when
  `pushRemote` / `pushDefault` and `branch.*.remote` differ.
- Use `git push -u` when an upstream already exists (that rewrites tracking).

## Example

Equivalent asks (same flow):

- “Please bring branch `feat/checkout-flow` into the foreground in this IDE window.”
- “Switch this window to `feat/checkout-flow` so I can poke at the UI.”

1. `git worktree list --porcelain` shows that branch at
   `.worktrees/feat-checkout-flow`.
2. In that worktree: commit clearly in-scope changes, resolve `push_remote` /
   `fetch_remote` from branch config, then push with
   `git push <push_remote> feat/checkout-flow` (or `git push -u …` only if
   the branch has no upstream yet).
3. Stop the worktree’s compose project if running.
4. `git fetch <fetch_remote> feat/checkout-flow`, then preflight: primary
   checkout has no conflicting dirty or untracked files for the target.
5. Unlink the leftover `.env` symlink (target stays in the primary repo),
   then `git worktree remove .worktrees/feat-checkout-flow`.
6. In the IDE workspace: `git checkout feat/checkout-flow`, and confirm
   `git status -sb`.
