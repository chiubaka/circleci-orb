---
name: partial-commits
description: >-
  Commits only task-relevant changes when multiple agents share a branch,
  using partial staging and preserving unrelated work. Use before any git
  commit, when the user asks to commit, when staging changes, when running
  git add or git commit, or when working changes may include edits from other
  agents (partial commit, multi-agent, shared branch, git add -p, selective
  staging).
---

# Partial commits (multi-agent branches)

## Before every commit

Read and follow this skill **before every git commit** (including when the user asks you to commit):

1. Commit **only** changes relevant to your assigned task.
2. Use partial staging (`git add -p`, `git add --patch`) when a file mixes your work with unrelated edits.
3. If unrelated hunks are already staged, unstage them **without discarding worktree edits** (see **Unstage unrelated staged hunks** below).
4. Leave all unrelated changes **uncommitted and unchanged** in the working tree.
5. Never discard unrelated work (`git restore <path>` on the worktree, `git reset --hard`, `git stash`, `git clean`, etc.) unless the user explicitly requests it.
6. If staging is ambiguous or risky, pause, explain, and ask the user how to proceed.

In consuming repositories, this skill is available under `.agents/skills/partial-commits/` after running `org/agents/scripts/bootstrap-skills.sh` (see ADR 0003).

## When this applies

In cases where multiple agents are running on the same branch, working changes may include changes NOT relevant to the task an agent was instructed to perform.

In these cases, the agent should commit ONLY changes relevant to their work, partially committing files if necessary. All other unrelated changes should remain uncommitted and exactly as they are. The agent should not perform any actions that may result in the loss or deletion of these unrelated changes.

If the situation becomes complex or it is unclear what the agent should do to resolve a particularly tricky situation, the agent should pause, explain the situation to the user, and ask for input.

## Workflow

1. **Inspect the full working tree** (do not assume every change is yours):
   - `git status`
   - `git diff` (unstaged)
   - `git diff --cached` (already staged)

2. **Identify relevant hunks** — only changes tied to your assigned task.

3. **Unstage unrelated staged hunks** (if `git diff --cached` includes work that is not yours):
   - Per hunk: `git restore --staged -p path/to/file` (or `git reset -p HEAD path/to/file` on older Git)
   - Whole file from index only: `git restore --staged path/to/file`
   - These commands adjust the **index only**; they do not remove edits from the working tree.

4. **Stage selectively**:
   - Whole files: `git add -- path/to/relevant/file`
   - Partial files: `git add -p path/to/file` or `git add --patch path/to/file`
   - Review each hunk; stage (`y`) only what belongs in this commit.

5. **Verify before committing**:
   - `git diff --cached` — staged content matches your task only
   - `git status` — unrelated changes remain **unstaged** (or unstaged in the working tree if they were never staged)
   - `git diff` — confirm unrelated hunks still present as before

6. **Commit** staged changes only. For message format, follow the `commit-message` skill when available.

## Forbidden actions (unless the user explicitly asks)

Do **not** use commands that discard, hide, or rewrite unrelated **worktree** changes:

- `git checkout -- <path>` / `git restore <path>` (without `--staged`) — overwrites working-tree edits
- `git reset --hard`
- `git stash` (including `git stash push`, `git stash -u`)
- `git clean`
- Reverting or deleting unrelated hunks in the working tree to "clean up"
- Any action that removes or overwrites changes you did not make for this task

**Allowed:** index-only unstaging such as `git restore --staged -p` or `git restore --staged <path>` — these remove hunks from the commit without discarding working-tree edits.

## When to pause and ask the user

Stop and explain the situation before committing if any of the following apply:

- A file mixes your changes with unrelated edits and partial staging is ambiguous
- You cannot tell whether an unstaged change belongs to your task or another agent
- Staging would require splitting logic across commits in a non-obvious way
- You would need a forbidden action to proceed
- The user asked to commit everything but unrelated changes are present

Offer options (e.g. which hunks to include, whether to commit in multiple commits) and wait for guidance.

## Quick example

```bash
git status
git diff
git diff --cached
git restore --staged -p src/shared.ts   # unstage unrelated hunks already in index
git add -p src/feature.ts               # stage only your hunks
git add docs/my-task.md                 # whole file is yours
git diff --cached                       # final review
git status                              # unrelated files still modified, unstaged
git commit -m "$(cat <<'EOF'
feat(scope): describe only your staged work

EOF
)"
```
