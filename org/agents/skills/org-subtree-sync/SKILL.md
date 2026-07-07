---
name: org-subtree-sync
description: >-
  Pull the latest org standards subtree from the upstream org repository into a
  consuming monorepo. Use before editing org/ content or before exporting local
  org changes upstream.
---

# Org subtree sync (pull)

## Goal

Bring the embedded org standards prefix (typically `org/`) up to date with the upstream org repository **before** making or exporting org changes.

## When to use this skill

Use this skill when:

- Starting work that may touch files under the org subtree prefix.
- A contributor reports org content is stale compared to the org repository.
- Before exporting local org changes upstream (run `org-subtree-status` first, then `org-subtree-export`).
- After an org pull request merges on the upstream org repository.

## Prerequisites

- The consuming repository embeds org standards via git subtree under a fixed prefix (see ADR 0015).
- A git remote points at the org repository (conventionally named `org`).
- You know the upstream default branch (conventionally `master` or `main`).

Replace `<org-remote>`, `<org-branch>`, and `<org-prefix>` below with your repository's values.

**Default branch rule:** run the subtree pull on the consuming repository's **default branch** (usually `master` or `main`) unless the user or task explicitly directs otherwise. Syncing on a feature branch is error-prone — it duplicates sync commits across branches and makes export status harder to reason about. After syncing on the default branch, bring the update into feature work via merge or rebase.

**Squash rule:** always pass **`--squash`** on subtree pull (and on post-export subtree pull in `org-subtree-export`). This is the org standard for consuming repositories — one squash commit per upstream sync keeps client project history readable. Do not omit `--squash` because a repository previously used non-squash subtree commands; standardize on squash going forward.

**Squash commit path model:** `git subtree pull --squash` records changed paths **without** the `<org-prefix>/` prefix (for example `docs/adr/README.md`, `agents/AGENTS.org.md`). Git subtree maps those under `<org-prefix>/` during a **merge**. **Rebase**, **cherry-pick**, and **interactive rebase** replay the patch at the **repository root** instead. Repos with overlapping shapes at root and under the prefix — common examples: `docs/adr/` (repo ADRs) vs `org/docs/adr/` (org ADRs), projected `AGENTS.md` vs `org/agents/AGENTS.org.md` — are especially vulnerable.

**Integration history rule:** after an org sync squash commit exists on the default branch, integrate remote default-branch updates with **merge**, not rebase:

- Use `git pull --no-rebase origin <default-branch>` or `git merge origin/<default-branch>`.
- Do **not** `git pull --rebase`, `git rebase origin/<default-branch>`, or replay org sync squash commits onto another base — that corrupts paths outside `<org-prefix>/`.
- When `pull.rebase` is configured globally, pass **`--no-rebase`** explicitly for steps that update the default branch before or after subtree pull.

## Sync workflow

### 0. Check status (recommended)

Run **`org-subtree-status`** first. Note **modified** paths under `<org-prefix>/` — those are the likely conflict sites during pull. If the verdict is **diverged**, plan to reconcile local forks (export after pull) rather than blindly taking one side.

### 1. Confirm remotes and check out the default branch

```bash
git remote -v
git fetch <org-remote>
git fetch origin

# Use the repository default branch (adjust if yours differs)
git checkout master   # or: git checkout main
git pull --no-rebase origin master
git branch --show-current
```

Stay on the default branch for steps 2–5 unless the user or task explicitly names a different branch for the sync.

### 2. Pull the subtree

Always use **`--squash`**:

```bash
git subtree pull --prefix=<org-prefix> <org-remote> <org-branch> --squash
```

Example with conventional names:

```bash
git subtree pull --prefix=org org master --squash
```

The squash commit message should summarize the upstream range integrated (git subtree usually proposes one). Edit it if the default message is unclear.

### 3. Resolve conflicts

Subtree pulls can conflict when the consuming repository has local org edits that overlap upstream changes. For each conflict:

- **Upstream-only changes** — keep upstream unless the local edit is an intentional fork.
- **Local-only improvements** — preserve and plan to export upstream (see `org-subtree-export`).
- **Same file, different intent** — reconcile explicitly (do not blindly take one side).

**Expected conflict scope:** only paths under `<org-prefix>/`.

**Stop and diagnose** if conflicts appear **outside** `<org-prefix>/` (for example repo-root `docs/adr/README.md` filled with org ADR index content, or new `agents/` / `docs/adr/00xx-*.md` at the repository root). That pattern means a squash subtree commit was **replayed** (rebase or cherry-pick), not merged. Abort the replay (`git rebase --abort` or `git cherry-pick --abort`), return to the default branch, and integrate with **merge** instead (see **Integration history rule** above). A correct `git subtree pull --squash` does not stage org content at repo-root paths that mirror the prefix.

After resolving:

```bash
git add <org-prefix>/
git commit   # completes the subtree merge or documents conflict resolution
```

### 4. Re-run projection scripts

After the pull, run the repository's org bootstrap scripts so projected outputs match the updated source (for example root `AGENTS.md` and linked skills). Use the scripts under `<org-prefix>/agents/scripts/` and any repository wrapper documented locally.

Refresh projections first (default mode writes; `--check` validates only):

```bash
# Example — use the script names your repository ships
<org-prefix>/agents/scripts/bootstrap-agents-md.sh
<org-prefix>/agents/scripts/bootstrap-skills.sh   # when org skills changed upstream
```

If scripts updated projected files, fold those changes into the subtree sync squash commit so history stays **one squash commit per upstream sync**:

```bash
git add AGENTS.md .agents/   # and any other paths your bootstrap scripts update
git commit --amend --no-edit
```

Then validate:

```bash
<org-prefix>/agents/scripts/bootstrap-agents-md.sh --check
```

### 5. Verify the result

Compare the embedded prefix to upstream when unsure:

```bash
git fetch <org-remote>
# List files only in upstream (may indicate a incomplete sync)
comm -23 \
  <(git ls-tree -r --name-only <org-remote>/<org-branch> | sort) \
  <(git ls-tree -r --name-only HEAD:<org-prefix> | sed "s|^<org-prefix>/||" | sort)
```

An empty result (no lines) for "only in upstream" means the file tree under the prefix matches upstream paths.

### 6. Propagate to feature branches (if needed)

If active work lives on a non-default branch, use the integration rules in **`org-subtree-export`** (Prepare for export):

- **Default:** rebase the feature branch onto the updated default branch (replays **feature** commits only; the org sync squash commit stays in default-branch history).
- **Exception:** when a full rebase would pull in unrelated repo-wide work the branch is not ready to absorb, **merge** default into the feature branch instead (`git merge <default-branch>`). Do **not** cherry-pick the org sync squash commit — squash commits use prefix-less paths and will land org files at the repository root.

Resolve any conflicts under `<org-prefix>/` using the same rules as step 3.

## Common mistakes

- **Syncing on a feature branch by default** — prefer the repository default branch; merge or rebase into feature work afterward.
- **Rebasing default branch after org sync** — `pull.rebase=true` or `git rebase origin/<default-branch>` replays squash commits at repo root; use **`git pull --no-rebase`** or **`git merge`**.
- **Cherry-picking org sync squash commits** — same path corruption as rebase; merge default into the feature branch or rebase the feature branch onto default.
- **Editing org/ while behind upstream** — causes painful merge conflicts on export.
- **Omitting `--squash` on subtree pull** — always squash; non-squash pulls clutter client project history.
- **Skipping projection scripts** — root `AGENTS.md` and skill links drift from `AGENTS.org.md` source.
- **Deleting and re-adding the org prefix** — avoid unless explicitly reinitializing subtree (see AGENTS.md org subtree safety guidance).

## Related

- ADR 0015 — subtree and projection model.
- `org-subtree-status` — compare local prefix to upstream before deciding to pull or push.
- `org-subtree-export` — push local org changes upstream after sync and reconciliation.
