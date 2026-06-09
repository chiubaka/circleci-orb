---
name: org-subtree-export
description: >-
  Export local org subtree changes from a consuming monorepo to the upstream org
  repository. Use after syncing and reconciling, when org/ edits should propagate
  to the centralized org standards repo.
---

# Org subtree export (push / PR)

## Goal

Propagate material changes under the embedded org prefix (typically `org/`) to the upstream org repository with a clean, reviewable result.

## When to use this skill

Use this skill when:

- Local edits under the org subtree prefix should become org-wide standards.
- A feature branch bundled org changes (ADRs, skills, agent guidance) with repository work.
- An agent or contributor asks to "push org changes upstream" or "open an org PR."

## Prerequisites

- Run **`org-subtree-status`** on the exporting branch to confirm there is material to push.
- Complete **prepare for export** below so the embedded prefix reflects current upstream org content plus intentional local deltas.
- A git remote for the org repository (conventionally `org`).
- Write access (or fork workflow) on the upstream org repository.

Replace `<org-remote>`, `<org-branch>`, `<org-prefix>`, and `<default-branch>` below with your repository's values (`<default-branch>` is usually `master` or `main`).

## Prepare for export

Org export should be based on **current upstream org content** integrated through the consuming repository's **default branch**. How you bring that onto the exporting branch depends on how far the branch has drifted from default.

### 1. Assess exporting branch vs default branch

```bash
git fetch origin
git fetch <org-remote>

EXPORT=<exporting-branch>
DEFAULT=<default-branch>

git diff --stat origin/$DEFAULT...$EXPORT
git diff --stat origin/$DEFAULT...$EXPORT -- <org-prefix>/
```

Read both stats:

- **Org-scoped diff** — changes under `<org-prefix>/` between default and the exporting branch.
- **Total diff** — all changes between default and the exporting branch.

Also inspect non-org drift — the main signal for the exception path:

```bash
git diff --name-only origin/$DEFAULT...$EXPORT -- . ":(exclude)<org-prefix>"
```

Use judgment: a rebase is **easy** when non-org drift is small or the branch is already close to default (similar effort to a fast-forward plus org conflict resolution). A rebase is **not easy** when default contains large repo-wide changes outside `<org-prefix>/` that the exporting branch is not yet compatible with (for example a major refactor, migration, or breaking layout change).

### 2. Default path — sync on default, then rebase exporting branch

Use when the exporting branch can be rebased onto default without pulling in substantial unrelated work the branch is not ready to absorb.

1. Run **`org-subtree-sync`** on `<default-branch>` (subtree pull with `--squash` on default — do not sync on the feature branch in this path).
2. Rebase the exporting branch onto updated default:

   ```bash
   git checkout $EXPORT
   git rebase $DEFAULT
   ```

3. Resolve conflicts. Prefer upstream org content under `<org-prefix>/` unless a path is an intentional local fork you still plan to export.
4. Re-run **`org-subtree-status`** on the exporting branch.

### 3. Exception path — do not rebase entire default branch

Use when the **total diff** against default is much larger than the **org-scoped diff** and a full rebase would integrate unrelated default-branch work the exporting branch is not yet compatible with.

**Do not** rebase the exporting branch onto default in this case — that would pull in repo-wide changes beyond org subtree scope.

Instead:

1. Still run **`org-subtree-sync`** on `<default-branch>` so default holds the canonical upstream org snapshot.
2. Bring **only the org sync commit** onto the exporting branch:

   ```bash
   git checkout $DEFAULT
   ORG_SYNC=$(git log -1 --format=%H)   # the new squash commit from org-subtree-sync
   git checkout $EXPORT
   git cherry-pick $ORG_SYNC
   ```

3. Resolve conflicts under `<org-prefix>/` only.
4. Re-run **`org-subtree-status`** on the exporting branch.

If the cherry-pick fails badly or org paths remain diverged, **stop and ask the user** whether to defer export until the branch can rebase, export from the branch as-is with documented divergence, or take another integration path. Do not force a full default-branch rebase without explicit direction.

### 4. Confirm ready to export

After either path, **`org-subtree-status`** on the exporting branch should show:

- **No only-upstream paths** (or explain any intentional gap to the user).
- **Push needed** with the export candidates you intend to upstream.

If the verdict is still **PULL needed** or **diverged**, reconcile before proceeding.

## Decide what to export

Read the **`org-subtree-status`** verdict on the exporting branch:

- **PULL needed** or **diverged** — stop; complete prepare for export above and re-check.
- **PUSH needed** — proceed with the export candidates listed in the status summary.
- **IN SYNC** — nothing to export.

Export **all material deltas** from the status report unless a file is an intentional repository fork.

## Choose an export mechanism

### Option A — Net-diff PR on the org repository (recommended default)

Best when:

- The consuming branch has mixed commit messages (feature + org edits in one commit).
- A subtree merge commit exists in history.
- You want one reviewable PR and a squash merge on upstream.

**Steps:**

1. Clone or use a worktree of the org repository at `<org-branch>`.
2. Create a feature branch.
3. Copy the embedded prefix contents to the org repo root **without touching `.git`**:

   ```bash
   git archive HEAD <org-prefix> | tar -x -C /tmp/org-export
   rsync -av /tmp/org-export/<org-prefix>/ /path/to/org-clone/
   ```

4. Remove files that upstream still has but the export omits (for example a replaced config file):

   ```bash
   comm -23 \
     <(git ls-tree -r --name-only <org-remote>/<org-branch> | sort) \
     <(git ls-tree -r --name-only HEAD:<org-prefix> | sed "s|^<org-prefix>/||" | sort)
   # delete each listed path from the org clone working tree
   ```

5. Commit with a Conventional Commits message (`docs(org): …`, `docs(adr): …`, etc.).
6. Push and open a PR on the org repository; squash merge when approved.

### Option B — Git subtree push

Best when:

- Org changes live in **dedicated org-only commits** with good messages.
- The consuming branch is synced and not heavily diverged.
- You want Git-native bidirectional sync per ADR 0015.

```bash
git subtree push --prefix=<org-prefix> <org-remote> <feature-branch>
```

Then open a PR from `<feature-branch>` on the org repository (or merge directly per team policy).

**Caution:** subtree push replays all unpushed org-prefix commits. Mixed feature commits produce poor upstream messages. Merge commits in history can make split behavior harder to predict — prefer Option A when in doubt.

## After upstream merge

On the consuming repository's **default branch**, run:

```bash
git checkout <default-branch>
git subtree pull --prefix=<org-prefix> <org-remote> <org-branch> --squash
```

Then propagate to feature branches using the same default vs exception rules in **Prepare for export** (rebase when easy; cherry-pick the org sync commit when not).

Re-run projection/bootstrap scripts and validation checks.

## Anti-patterns

- **Export before prepare for export** — duplicates or conflicts with upstream; hard to review.
- **Rebasing onto default when the branch is not compatible** — pulls unrelated repo-wide work; use the exception path (cherry-pick org sync only).
- **Syncing org on a feature branch when default path applies** — duplicates sync commits; sync on default, then rebase or cherry-pick.
- **Subtree push with large unreconciled divergence** — bundles unrelated history and wrong commit subjects.
- **Leaving stale upstream-only files** — when replacing a file (for example `eslint.config.mjs` → `.ts`), delete the old path in the org PR.
- **Exporting repo-local forks** — only export content meant to be org-wide per ADR scope rules.

## Related

- ADR 0015 — subtree and projection model.
- `org-subtree-status` — compare local prefix to upstream and summarize pull/push needs.
- `org-subtree-sync` — pull upstream org onto default branch before export.
- `create-adr` — scope and portability rules for new ADRs in the org prefix.
- `commit-message` — Conventional Commits for org repository commits.
