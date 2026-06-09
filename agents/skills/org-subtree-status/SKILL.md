---
name: org-subtree-status
description: >-
  Compare the embedded org subtree prefix to the upstream org repository and
  summarize whether material exists to pull, push, or both. Use before org sync,
  export, or when asked if org/ is up to date.
---

# Org subtree status (pull / push check)

## Goal

Produce a **plain-language summary** of how the consuming repository's embedded org prefix compares to the upstream org repository — so contributors and agents know whether to pull, export, or do nothing.

## When to use this skill

Use this skill when:

- Asked "is org up to date?", "do we have org changes to push?", or "should we subtree pull?"
- Before `org-subtree-sync` or `org-subtree-export`.
- After an org PR merges (confirm whether a pull is still needed locally).
- At the start of a session that may touch files under the org prefix.

## Prerequisites

- The repository embeds org standards via git subtree under a fixed prefix (see ADR 0015).
- A git remote for the org repository (conventionally `org`).
- You know the upstream default branch (conventionally `master` or `main`).

Replace `<org-remote>`, `<org-branch>`, and `<org-prefix>` with your repository's values.

## Status check workflow

### 1. Fetch and confirm refs

```bash
git fetch <org-remote>
git branch --show-current
UPSTREAM=<org-remote>/<org-branch>
PREFIX=<org-prefix>
```

Ensure `HEAD:<prefix>` and `$UPSTREAM` both resolve. If the prefix path is wrong or the remote is missing, stop and report setup issues.

### 2. Compare file trees

Run from the repository root:

```bash
UPSTREAM=<org-remote>/<org-branch>
PREFIX=<org-prefix>

UPSTREAM_LIST=$(git ls-tree -r --name-only "$UPSTREAM" | sort)
LOCAL_LIST=$(git ls-tree -r --name-only "HEAD:$PREFIX" | sed "s|^$PREFIX/||" | sort)

echo "=== ONLY UPSTREAM (pull candidates) ==="
comm -23 <(echo "$UPSTREAM_LIST") <(echo "$LOCAL_LIST")

echo "=== ONLY LOCAL (export candidates) ==="
comm -13 <(echo "$UPSTREAM_LIST") <(echo "$LOCAL_LIST")

echo "=== MODIFIED (both sides, content differs) ==="
for f in $(comm -12 <(echo "$UPSTREAM_LIST") <(echo "$LOCAL_LIST")); do
  git diff --quiet "$UPSTREAM:$f" "HEAD:$PREFIX/$f" 2>/dev/null || echo "$f"
done
```

**Interpretation:**

| Bucket            | Meaning                                                                                                    |
| ----------------- | ---------------------------------------------------------------------------------------------------------- |
| **Only upstream** | Upstream has paths your embedded prefix lacks — **material to pull**.                                      |
| **Only local**    | Your prefix has new paths upstream lacks — **material to push** (export).                                  |
| **Modified**      | Same path, different content — **material to push** after reconciliation (or pull if upstream should win). |

Also check for **uncommitted** edits under the prefix (not visible to the tree comparison above):

```bash
git status --short -- "$PREFIX/"
```

Uncommitted changes are **local work in progress**; include them in the push summary when reporting to the user.

### 3. Summarize for the user

Always report using this structure:

```markdown
## Org subtree status

**Upstream:** `<org-remote>/<org-branch>` @ `<short-sha>` — `<remote-url or name>`
**Local prefix:** `<org-prefix>/` on branch `<current-branch>` @ `<short-sha>`

### Verdict

<one line: IN SYNC | PULL needed | PUSH needed | PULL and PUSH needed (diverged)>

### Recommended next step

<one concrete action with skill link>

### Pull candidates (N files)

<bulleted list or "none">

### Export candidates (N files)

<bulleted list grouped: new files, then modified — or "none">

### Uncommitted local edits

<list from git status or "none">
```

### 4. Verdict rules

Apply in order:

1. **IN SYNC** — all three buckets empty **and** no uncommitted changes under the prefix.
   - Next step: none; safe to edit org/ or proceed with repo work.

2. **PULL needed** — only-upstream bucket non-empty, only-local and modified empty.
   - Next step: run `org-subtree-sync`, then re-run this check.

3. **PUSH needed** — only-local and/or modified non-empty, only-upstream empty.
   - Next step: run `org-subtree-export` (net-diff PR or subtree push).

4. **PULL and PUSH needed (diverged)** — only-upstream **and** (only-local or modified) both non-empty.
   - Next step: **pull first** (`org-subtree-sync`), resolve conflicts, re-run this check, then export.
   - Explain clearly: exporting before pulling risks duplicate or conflicting upstream PRs.

When lists are long, show the **first 10 paths** plus a count of the remainder (for example "+ 14 more"). Always include counts in headings.

### 5. Optional — group paths for readability

When summarizing, group by top-level area when helpful:

- `docs/adr/` — ADR additions or edits
- `agents/skills/` — skill additions or edits
- `agents/AGENTS.org.md`, `agents/scripts/` — agent guidance
- Root config (`package.json`, eslint config, CI) — tooling

Example verdict line:

> **PULL and PUSH needed (diverged)** — upstream has 2 files you lack; you have 1 new file and 8 modified files to export.

## Example summary (illustrative)

```markdown
## Org subtree status

**Upstream:** `org/master` @ `a510893` — chiubaka/org
**Local prefix:** `org/` on branch `feat/my-feature` @ `b67153f`

### Verdict

PULL and PUSH needed (diverged)

### Recommended next step

Run `org-subtree-sync` first, resolve conflicts, re-check status, then `org-subtree-export`.

### Pull candidates (2 files)

- `agents/skills/changeset/SKILL.md`
- `eslint.config.mjs`

### Export candidates (9 files)

**New (2):**

- `docs/adr/0037-domain-temporal-values-as-canonical-iso-strings.md`
- `agents/skills/jsdoc/SKILL.md`

**Modified (7):**

- `docs/adr/README.md`
- `agents/skills/review/SKILL.md`
- … +5 more under `docs/adr/` and `agents/`

### Uncommitted local edits

none
```

## Common mistakes

- **Comparing without fetch** — stale verdict; always `git fetch <org-remote>` first.
- **Ignoring only-upstream files while exporting** — creates conflicting org PRs; pull first when diverged.
- **Treating working-tree edits as synced** — `HEAD:<prefix>` ignores uncommitted changes; always run `git status -- <prefix>/`.
- **Using path diff across repos incorrectly** — compare `UPSTREAM:path` to `HEAD:<prefix>/path`, not `git diff org/master -- org/` (prefix mismatch).

## Related

- ADR 0015 — subtree and projection model.
- `org-subtree-sync` — pull when only-upstream (or diverged) paths exist.
- `org-subtree-export` — export when only-local or modified paths exist after sync.
