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

**Single commit rule:** the org sync squash commit must include **both** the subtree pull **and** any bootstrap/projection outputs (for example updated root `AGENTS.md`, `CLAUDE.md` when created by bootstrap, new org skill links under `.agents/skills/`, and tool-facing skill symlinks). Do not leave bootstrap changes unstaged or in a follow-up commit.

## Sync workflow

### 1. Confirm remotes and check out the default branch

```bash
git remote -v
git fetch <org-remote>
git fetch origin

# Use the repository default branch (adjust if yours differs)
git checkout master   # or: git checkout main
git pull origin master
git branch --show-current
```

Stay on the default branch for steps 2–6 unless the user or task explicitly names a different branch for the sync.

### 2. Pull the subtree

Always use **`--squash`**:

```bash
git subtree pull --prefix=<org-prefix> <org-remote> <org-branch> --squash
```

Example with conventional names:

```bash
git subtree pull --prefix=org org master --squash
```

Do **not** treat the sync as finished when this command succeeds. Subtree pull may auto-commit under `<org-prefix>/` only; bootstrap outputs are added in steps 4–5.

### 3. Resolve conflicts

Subtree pulls can conflict when the consuming repository has local org edits that overlap upstream changes. For each conflict:

- **Upstream-only changes** — keep upstream unless the local edit is an intentional fork.
- **Local-only improvements** — preserve and plan to export upstream (see `org-subtree-export`).
- **Same file, different intent** — reconcile explicitly (do not blindly take one side).

After resolving, stage the prefix only — do not commit yet:

```bash
git add <org-prefix>/
```

If the pull completed without conflicts and git already created a squash commit, continue to step 4; you will amend that commit in step 5.

### 4. Run projection scripts

Run the repository's org bootstrap scripts so projected outputs match the updated source (for example root `AGENTS.md` and linked skills). Use the scripts under `<org-prefix>/agents/scripts/` and any repository wrapper documented locally.

```bash
# Example — use the script names your repository ships
<org-prefix>/agents/scripts/bootstrap.sh
```

Bootstrap may create or update files **outside** `<org-prefix>/` (for example `AGENTS.md`, `CLAUDE.md`, `.agents/skills/<skill-name>/`, and tool-facing skill symlinks). Stage every bootstrap-managed path your repository uses before finalizing the sync commit:

```bash
git add AGENTS.md CLAUDE.md .agents/skills/
# Add other bootstrap-managed paths when your repo uses them (for example .cursor/skills, .claude/skills)
```

If the repository provides a validation mode, run it after staging:

```bash
<org-prefix>/agents/scripts/bootstrap.sh --check
```

### 5. Finalize the sync commit

Create **one** conventional squash commit (see `commit-message`) that includes the subtree pull and all bootstrap changes from step 4.

Use a subject like:

```text
chore(org): sync latest org documentation and guidance
```

Keep git subtree's default body line (for example `Merge commit '…'`) in the message body below the subject.

**If subtree pull auto-committed** (no conflict resolution commit in step 3):

```bash
git commit --amend -m "chore(org): sync latest org documentation and guidance" -m "$(git log -1 --format=%b)"
```

**If the pull left a merge in progress or you staged `<org-prefix>/` in step 3 without committing:**

```bash
git commit
```

Open the editor. Set the conventional subject and move git subtree's default `Merge commit '…'` text into the body.

### 6. Verify the result

Compare the embedded prefix to upstream when unsure:

```bash
git fetch <org-remote>
# List files only in upstream (may indicate a incomplete sync)
comm -23 \
  <(git ls-tree -r --name-only <org-remote>/<org-branch> | sort) \
  <(git ls-tree -r --name-only HEAD:<org-prefix> | sed "s|^<org-prefix>/||" | sort)
```

An empty result (no lines) for "only in upstream" means the file tree under the prefix matches upstream paths.

### 7. Propagate to feature branches (if needed)

If active work lives on a non-default branch, use the integration rules in **`org-subtree-export`** (Prepare for export):

- **Default:** rebase the feature branch onto the updated default branch.
- **Exception:** cherry-pick only the org sync squash commit when a full rebase would pull in unrelated repo-wide work the branch is not ready to absorb.

Resolve any conflicts under `<org-prefix>/` using the same rules as step 3.

## Common mistakes

- **Syncing on a feature branch by default** — prefer the repository default branch; merge or rebase into feature work afterward.
- **Editing org/ while behind upstream** — causes painful merge conflicts on export.
- **Omitting `--squash` on subtree pull** — always squash; non-squash pulls clutter client project history.
- **Skipping projection scripts** — root `AGENTS.md` and skill links drift from `AGENTS.org.md` source.
- **Separate bootstrap commit** — stage bootstrap outputs and amend or commit with the sync squash so one commit carries subtree + projection changes.
- **Deleting and re-adding the org prefix** — avoid unless explicitly reinitializing subtree (see AGENTS.md org subtree safety guidance).

## Related

- ADR 0015 — subtree and projection model.
- `org-subtree-status` — compare local prefix to upstream before deciding to pull or push.
- `org-subtree-export` — push local org changes upstream after sync and reconciliation.
- `commit-message` — Conventional Commits format for org sync squash commits.
