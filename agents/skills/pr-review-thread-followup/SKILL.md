---
name: pr-review-thread-followup
description: >-
  Fetches unresolved GitHub PR review threads for the current branch, judges
  each inline comment for validity, implements fixes for valid feedback, and
  posts an in-thread reply on every thread—either how it was resolved or why it
  was not—using a human-delegation prefix only when the authenticated GitHub
  identity is a person’s account (not a native bot/app identity). Use when
  addressing PR review comments, clearing review feedback, replying to inline
  review threads, or when the user asks to resolve or respond to GitHub PR
  comments.
---

# PR review thread follow-up

## Goal

Close the loop on **inline pull request review comments** (code review threads): nothing is silently ignored, and every thread gets a **public in-thread reply** on GitHub.

## When to apply

Use this workflow whenever work includes **GitHub PR review feedback**—especially **unresolved** inline threads—whether or not the user remembered to spell out the steps.

## Use `gh` first

Prefer the **`gh` CLI** for every GitHub operation that it supports: viewing the PR, querying JSON, **GraphQL** (`gh api graphql`), and **REST** (`gh api` with method/path). Use raw `curl` or browser automation only when `gh` cannot do the job.

## Prerequisites

- **`gh` CLI** installed, authenticated, and able to access the repo (`gh auth status`).
- Know **which GitHub identity** will author the comment (see **Commenting identity** below).
- A **pull request** exists for the **current** branch (or identify the correct PR explicitly if not).

## Commenting identity: when to use the reply prefix

GitHub shows each comment under an account. This workflow splits behavior by whether the post is **human delegation** (automation using a **person’s** credentials) or a **native agent identity** (automation posting **as itself**—bot user, GitHub App, or other account meant to represent the agent, not impersonate a human).

**Use the human-delegation prefix** when **all** of these hold:

- The authenticated identity that will create the comment is a **human** account (typical signal: `gh api user --jq .type` is `"User"`, and the account is a real person’s login—not a shared bot service account documented as such), **and**
- The session is acting **on behalf of** that human (for example local `gh` logged in as the PR author or maintainer), so readers could otherwise think the human typed the comment in real time.

**Do not use the human-delegation prefix** when:

- The authenticated identity is a **native automation account**—for example `gh api user --jq .type` is **`"Bot"`**, or the token is a **GitHub App** / installation token, or org docs name a **dedicated agent or bot user** that should speak for itself, **or**
- The user or environment explicitly states that comments are posted under a **non-delegated** agent identity (the comment author **is** the agent account).

In those cases the comment is already attributed correctly; adding “on behalf of @human” would misrepresent authorship. Write the reply body **without** that prefix (plain technical content only), unless separate org/project rules require a different **non-delegation** disclosure.

If identity is ambiguous after `gh api user` and context, **ask once** whether to use human-delegation mode or native-agent mode for this run before posting.

## Reply prefix (human delegation only)

When **Commenting identity** requires it, begin the comment body with this pattern (fill in the bracketed choices):

```text
[<Cursor | Codex | Claude | Something Else> Agent on behalf of @<username>]:
```

- **Tool label** — pick the actual environment (`Cursor`, `Codex`, `Claude`, or another specific name; avoid vague wording).
- **`@<username>`** — the GitHub handle of the **human** on whose behalf you are posting (for example the PR author’s login from `gh pr view --json author` when that is the delegating user).
- The prefix **does not need to be on its own line**; it can be followed immediately by the rest of the message on the same line or wrapped naturally after it.

If the user or project rules define a different **delegation** prefix for human-on-behalf-of cases, use **that** instead for every reply in the run when the prefix applies.

**Do not resolve review threads on GitHub** (no “resolve conversation” / no resolve-thread API). Humans keep control of thread state; your job is triage, code fixes, and **replies only**.

## Workflow

### 1. Bind the PR to the current branch

From the repo root, use `gh`:

- `gh pr view --json number,url,title,state,author` and confirm the PR is open.
- If there is no PR for this branch, stop and ask how to proceed (different base branch, fork, or draft).

Capture `owner`, `repo`, and PR `number` via `gh repo view --json nameWithOwner` / `gh pr view` JSON (or equivalent `gh` output) for subsequent `gh api` calls.

Before drafting any reply text, classify **commenting identity** (see **Commenting identity**)—for example `gh api user --jq '{login,type}'`—so you know whether the human-delegation prefix applies.

### 2. List **unresolved** review threads

Use **`gh api graphql`** with the `reviewThreads` connection so you can filter on **`isResolved: false`**. Avoid hand-rolled HTTP clients when `gh api graphql` works.

For each unresolved thread, collect at least:

- Path and line / diff context.
- **All** comment bodies in chronological order (original review, follow-ups, bots).
- A **REST comment id** (`databaseId` from GraphQL matches the REST **integer** `id` on pull review comments) for **replying** in that thread via `gh api`.

If a first query shape fails, adjust the GraphQL or `gh api` invocation and retry—do not skip threads silently.

### 3. Triage every comment

For **each** thread (not just the first note):

1. **Understand** the request (question, bug, style, nit, duplicate).
2. **Decide validity**: valid / invalid / partially valid / needs product or human call.
3. **Act**:
   - **Valid** — implement the fix (minimal, targeted), run the relevant checks, commit/push as the workflow requires.
   - **Invalid or declined** — do **not** silently ignore; prepare a concise, respectful explanation.
   - **Ambiguous** — prefer a short honest note in-thread over guessing; optionally ask the reviewer in the same reply.

### 4. Reply **in thread** for every thread

For **each** unresolved thread you triaged, post **one** reply on GitHub **in that review thread** using **`gh api`**, not only a single top-level `gh pr comment` unless threading truly requires it.

#### Correct REST path for threaded replies (mandatory)

GitHub creates a **threaded** reply only when you call the reply endpoint that includes the **pull request number** in the URL path.

- **Correct:** `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies`
- **Wrong:** `POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/replies` — this path omits `pulls/{pull_number}`; it does **not** create the in-PR threaded reply you want. Agents have mistaken this before; **never** use it for follow-up.

Use the **top-level** review comment’s numeric `comment_id` (the thread root), not a reply’s id.

**`gh` example** (replace placeholders; capture `pull_number` from `gh pr view` and `comment_id` from GraphQL `databaseId` or REST):

```bash
gh api -X POST "repos/OWNER/REPO/pulls/PULL_NUMBER/comments/COMMENT_ID/replies" \
  -f body='Your reply text (include human-delegation prefix when required).'
```

After posting, confirm the response JSON includes `in_reply_to_id` equal to the root comment id, or spot-check the thread on the **Files changed** tab.

Start the comment body with the **human-delegation prefix** when **Commenting identity** requires it; otherwise start with the substantive text only. The body should make one of these outcomes obvious:

- **Resolved** — what changed (commit pointer, file/summary, or behavior) and, when helpful, where.
- **Not resolved** — clear **why** (e.g. out of scope, incorrect assumption, duplicate of another thread, design constraint, trade-off accepted). Avoid dismissive tone.

If you fixed the issue in code, still **explain** in the thread so reviewers do not need to diff-hunt.

## Quality bar

- **No silent skips** — if a thread is out of scope or wrong, say so in that thread.
- **Thread-local** — replies belong on the **inline** conversation, not only a generic PR comment, unless GitHub mechanics truly prevent threading (then state that limitation once to the user).
- **Concise** — short replies; link to commits or lines when it saves words.

## Related skills

- `review` — internal quality checklist before handoff; use together with this workflow when shipping fixes for review feedback.
