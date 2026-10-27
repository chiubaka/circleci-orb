---
name: pr-review-thread-followup
description: >-
  Fetches unresolved GitHub PR review feedback for the current branch—inline
  review threads and top-level conversation comments (including review
  summaries)—judges each item for validity, implements fixes for valid
  feedback, and posts a public reply on every item: in-thread for inline
  comments, on the PR conversation for top-level comments, using a
  human-delegation prefix only when the authenticated GitHub identity is a
  person's account (not a native bot/app identity). Use when addressing PR
  review comments, clearing review feedback, replying to inline review threads
  or top-level PR comments, or when the user asks to resolve or respond to
  GitHub PR comments.
---

# PR review thread follow-up

## Goal

Close the loop on **all actionable pull request review feedback**—both **inline review threads** (Files changed) and **top-level conversation comments** (Conversation tab, including review summaries and bot reports): nothing is silently ignored, and every item gets a **public reply** on GitHub.

## When to apply

Use this workflow whenever work includes **GitHub PR review feedback**—especially **unresolved** inline threads **or unaddressed top-level comments**—whether or not the user remembered to spell out the steps.

## Use `gh` first

Prefer the **`gh` CLI** for every GitHub operation that it supports: viewing the PR, querying JSON, **GraphQL** (`gh api graphql`), and **REST** (`gh api` with method/path). Use raw `curl` or browser automation only when `gh` cannot do the job.

## Prerequisites

- **`gh` CLI** installed, authenticated, and able to access the repo (`gh auth status`).
- Know **which GitHub identity** will author the comment (see **Commenting identity** below).
- A **pull request** exists for the **current** branch (or identify the correct PR explicitly if not).

## Commenting identity: when to use the reply prefix

GitHub shows each comment under an account. This workflow splits behavior by whether the post is **human delegation** (automation using a **person's** credentials) or a **native agent identity** (automation posting **as itself**—bot user, GitHub App, or other account meant to represent the agent, not impersonate a human).

**Use the human-delegation prefix** when **all** of these hold:

- The authenticated identity that will create the comment is a **human** account (typical signal: `gh api user --jq .type` is `"User"`, and the account is a real person's login—not a shared bot service account documented as such), **and**
- The session is acting **on behalf of** that human (for example local `gh` logged in as the PR author or maintainer), so readers could otherwise think the human typed the comment in real time.

**Do not use the human-delegation prefix** when:

- The authenticated identity is a **native automation account**—for example `gh api user --jq .type` is **`"Bot"`**, or the token is a **GitHub App** / installation token, or org docs name a **dedicated agent or bot user** that should speak for itself, **or**
- The user or environment explicitly states that comments are posted under a **non-delegated** agent identity (the comment author **is** the agent account).

In those cases the comment is already attributed correctly; adding "on behalf of @human" would misrepresent authorship. Write the reply body **without** that prefix (plain technical content only), unless separate org/project rules require a different **non-delegation** disclosure.

If identity is ambiguous after `gh api user` and context, **ask once** whether to use human-delegation mode or native-agent mode for this run before posting.

## Reply prefix (human delegation only)

When **Commenting identity** requires it, begin the comment body with this pattern (fill in the bracketed choices):

```text
[<Cursor | Codex | Claude | Something Else> Agent on behalf of @<username>]:
```

- **Tool label** — pick the actual environment (`Cursor`, `Codex`, `Claude`, or another specific name; avoid vague wording).
- **`@<username>`** — the GitHub handle of the **human** on whose behalf you are posting (for example the PR author's login from `gh pr view --json author` when that is the delegating user).
- The prefix **does not need to be on its own line**; it can be followed immediately by the rest of the message on the same line or wrapped naturally after it.

If the user or project rules define a different **delegation** prefix for human-on-behalf-of cases, use **that** instead for every reply in the run when the prefix applies.

**Do not resolve review threads on GitHub** (no "resolve conversation" / no resolve-thread API). Humans keep control of thread state; your job is triage, code fixes, and **replies only**.

## Workflow

### 1. Bind the PR to the current branch

From the repo root, use `gh`:

- `gh pr view --json number,url,title,state,author` and confirm the PR is open.
- If there is no PR for this branch, stop and ask how to proceed (different base branch, fork, or draft).

Capture `owner`, `repo`, and PR `number` via `gh repo view --json nameWithOwner` / `gh pr view` JSON (or equivalent `gh` output) for subsequent `gh api` calls.

If `gh pr checks` shows a **failing coverage or Codecov check**, read and follow `org/agents/skills/pr-coverage-followup/SKILL.md` as part of this run (triage gaps, add meaningful tests, re-push) before posting replies that claim the PR is ready.

Before drafting any reply text, classify **commenting identity** (see **Commenting identity**)—for example `gh api user --jq '{login,type}'`—so you know whether the human-delegation prefix applies.

### 2. Collect all feedback to triage

Gather **both** inline threads **and** top-level conversation feedback before triaging. Do not stop after inline threads alone.

#### 2a. Inline review threads (unresolved)

Use **`gh api graphql`** with the `reviewThreads` connection so you can filter on **`isResolved: false`**. Avoid hand-rolled HTTP clients when `gh api graphql` works.

For each unresolved thread, collect at least:

- Path and line / diff context.
- **All** comment bodies in chronological order (original review, follow-ups, bots).
- A **REST comment id** (`databaseId` from GraphQL matches the REST **integer** `id` on pull review comments) for **replying** in that thread via `gh api`.

If a first query shape fails, adjust the GraphQL or `gh api` invocation and retry—do not skip threads silently.

#### 2b. Top-level PR conversation comments

Top-level comments live on the PR **Conversation** tab. They are **not** returned by `reviewThreads` and are easy to miss—always fetch them explicitly.

Use **`gh`** to list conversation comments and review summaries, for example:

```bash
gh pr view --json comments,reviews,author
```

Or REST / GraphQL equivalents (`issues/{number}/comments`, pull request `reviews`).

For **each** top-level item worth triaging, collect at least:

- Comment or review **body** (full text).
- **Author** login and timestamp.
- Whether it is an **issue comment** (`comments`) or a **submitted review summary** (`reviews[].body` with non-empty text).
- For issue comments, the REST **`id`** if you need it for reference (not required for replying).

**Include** top-level comments that are actionable feedback, for example:

- Human reviewer questions, change requests, or nits posted on the Conversation tab.
- Bot reports (Codecov, Bugbot, dependency bots, etc.) when they ask for action or report a problem.
- **Review summaries**—the body of a submitted review (`REQUEST_CHANGES`, `COMMENT`, or `APPROVE` with non-empty text)—even when there are no inline threads.

**Skip or deprioritize** only when clearly not feedback to close out, for example:

- Pure approvals with no questions ("LGTM", empty review body).
- Your own prior follow-up replies that already closed the loop.
- Automated noise with no action requested (unless CI/checks still failing—then triage the underlying failure).

**Unaddressed** means: no later reply from the PR author (or agent on their behalf) that clearly answers or resolves the item, and no code change that obviously addresses it. When unsure, triage and reply rather than skip.

If a first query shape fails, adjust and retry—do not skip top-level comments silently.

### 3. Triage every item

For **each** inline thread **and** each top-level comment you collected (not just the first note in a thread):

1. **Understand** the request (question, bug, style, nit, duplicate).
2. **Decide validity**: valid / invalid / partially valid / needs product or human call.
3. **Act**:
   - **Valid** — implement the fix (minimal, targeted), run the relevant checks, commit/push as the workflow requires.
   - **Coverage / Codecov** — when the thread, top-level comment, or CI concerns missing test coverage, read and follow `org/agents/skills/pr-coverage-followup/SKILL.md` before replying; add tests only where coverage is meaningful, never padding to pass thresholds.
   - **Invalid or declined** — do **not** silently ignore; prepare a concise, respectful explanation.
   - **Ambiguous** — prefer a short honest note over guessing; optionally ask the reviewer in the same reply.

### 4. Reply on GitHub for every item

Post **one** reply per triaged inline thread **and** per triaged top-level comment. Use the correct channel for each type.

#### 4a. Inline threads — reply in thread (mandatory)

For **each** unresolved inline thread you triaged, post **one** reply **in that review thread** using **`gh api`**, not a generic PR conversation comment.

GitHub creates a **threaded** reply only when you call the reply endpoint that includes the **pull request number** in the URL path.

- **Correct:** `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments/{comment_id}/replies`
- **Wrong:** `POST /repos/{owner}/{repo}/pulls/comments/{comment_id}/replies` — this path omits `pulls/{pull_number}`; it does **not** create the in-PR threaded reply you want. Agents have mistaken this before; **never** use it for follow-up.

Use the **thread root** review comment's numeric `comment_id` (the top-level comment in that inline thread), not a reply's id.

**`gh` example** (replace placeholders; capture `pull_number` from `gh pr view` and `comment_id` from GraphQL `databaseId` or REST):

```bash
gh api -X POST "repos/OWNER/REPO/pulls/PULL_NUMBER/comments/COMMENT_ID/replies" \
  -f body='Your reply text (include human-delegation prefix when required).'
```

After posting, confirm the response JSON includes `in_reply_to_id` equal to the root comment id, or spot-check the thread on the **Files changed** tab.

#### 4b. Top-level comments — reply on the PR conversation

For **each** top-level comment or review summary you triaged, post **one** reply on the **PR conversation** so the original author sees it in context.

Use **`gh pr comment`** or **`gh api`** on the issue-comments endpoint:

```bash
gh pr comment PULL_NUMBER --body '@[reviewer] Re: <short topic> — your reply (include human-delegation prefix when required).'
```

Or:

```bash
gh api -X POST "repos/OWNER/REPO/issues/PULL_NUMBER/comments" \
  -f body='@[reviewer] Re: <short topic> — your reply.'
```

- **@mention** the original commenter (or reviewer who submitted the summary) so they are notified.
- Quote or summarize the item you are addressing when the conversation is long.
- Do **not** use the inline-thread reply endpoint for conversation-tab comments—it will not attach to the right place.

Start the comment body with the **human-delegation prefix** when **Commenting identity** requires it; otherwise start with the substantive text only. The body should make one of these outcomes obvious:

- **Resolved** — what changed (commit pointer, file/summary, or behavior) and, when helpful, where.
- **Not resolved** — clear **why** (e.g. out of scope, incorrect assumption, duplicate of another thread or comment, design constraint, trade-off accepted). Avoid dismissive tone.

If you fixed the issue in code, still **explain** in the reply so reviewers do not need to diff-hunt.

## Quality bar

- **No silent skips** — if feedback is out of scope or wrong, say so in the appropriate place (inline thread or conversation reply).
- **Right channel** — inline thread replies belong on the **Files changed** conversation; top-level feedback gets a **Conversation** reply with @mention. Do not address top-level review feedback only via inline threads, or vice versa.
- **Concise** — short replies; link to commits or lines when it saves words.

## Related skills

- `pr-coverage-followup` — when CI, top-level bot comments, or review threads involve Codecov or coverage failures; run this skill during the same PR follow-up pass so tests are meaningful, not threshold padding.
- `review` — internal quality checklist before handoff; use together with this workflow when shipping fixes for review feedback.
- `test-driven-development` — test layout and quality when adding coverage for valid review feedback.
