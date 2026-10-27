---
name: session-learning
description: >-
  Capture session lessons as atomic instincts with confidence scoring, apply
  them in later work, and evolve high-confidence clusters into versioned org or
  repo guidance. Use when the user asks to learn from a session, extract
  patterns, evolve instincts into skills, or when review finds the same issue
  repeating across sessions.
---

# Session learning (instinct capture)

Adapted from ECC continuous-learning-v2 for this org: **agent-driven**,
**human-gated promotion**, and **no required hooks**. This does not fine-tune
the model. It turns corrections and repeated workflows into small reusable
instructions, then promotes durable ones into skills or `AGENTS` guidance.

## Goal

1. Record **atomic instincts** (one trigger → one action) with evidence and confidence.
2. Reuse instincts in later sessions without inventing conflicting one-off rules.
3. **Evolve** only high-value, repeated instincts into versioned guidance via
   `create-skill` / `update-agent-guidance` — not by silently rewriting org standards.

## When to use / when not

**Use when:**

- The user asks to learn from this session, extract patterns, or evolve instincts.
- The same correction or failure mode has appeared **twice or more** in this session
  (or across recent sessions with evidence).
- `review` flags repeated guidance gaps (“if repeated issues surface…”).

**Skip when:**

- One-off typos, ambient preference noise, or secrets/PII in the lesson.
- The lesson is already covered by an org skill, rule, or ADR — prefer citing that
  over creating a duplicate instinct.
- You would only invent speculative “for later” habits (coding-discipline).

## Instinct model

An instinct is a small learned behavior stored as markdown with YAML frontmatter.
Use the template at `org/agents/skills/session-learning/instinct-template.md`.

| Field           | Meaning                                                                                                                           |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `id`            | kebab-case stable id (for example `grep-before-edit`)                                                                             |
| `trigger`       | When this applies                                                                                                                 |
| `action`        | What to do (one concrete behavior)                                                                                                |
| `confidence`    | `0.3` tentative → `0.9` near-certain                                                                                              |
| `domain`        | `code-style` \| `testing` \| `git` \| `debugging` \| `workflow` \| `architecture` \| `security` \| other short tag                |
| `scope`         | `repo` (default) or `org` (portable across repositories)                                                                          |
| `status`        | `pending` \| `active` \| `superseded` \| `rejected`                                                                               |
| `evidence`      | YAML list in frontmatter: observation strings (dates, what happened) — no secrets. Canonical; do not duplicate as a body section. |
| `superseded_by` | Path to the replacement skill, guidance, or ADR when `status: superseded`; required then, omit otherwise.                         |

**Atomicity:** one trigger, one action. Split compound lessons into multiple instincts.

## Storage layout

In the **target repository** (not under `org/agents/` as durable standards):

```text
.agents/instincts/
  pending/     # newly captured; not yet trusted
  active/      # accepted for reuse in this repo
  archive/     # superseded or rejected (keep evidence)
```

- Prefer **repo-local** instincts under `.agents/instincts/`.
- Do **not** treat instincts as a substitute for org skills or ADRs.
- Whether to commit instincts is a **repo choice**. Default recommendation:
  commit team-shared `active/` instincts if useful; keep noisy personal drafts
  out of shared history (gitignore or leave untracked).
- Never store API keys, tokens, customer data, or full confidential transcripts
  in instinct files — summarize the pattern only.

In the org repository itself, `.agents/` may be gitignored; still write instincts
there for local reuse, and promote portable lessons into `org/agents/skills/` or
`org/agents/AGENTS.org.md` through the promote path below.

## Workflow

### 1. Capture (mid-session or after a meaningful slice)

1. Scan the session for: user corrections, repeated failed approaches, error
   resolutions that generalize, and workflows the user explicitly endorsed.
2. Deduplicate against existing `.agents/instincts/**` and against **safe skill
   metadata only** (directory `name` plus YAML `name` / `description` from
   skill frontmatter — not peer `SKILL.md` bodies or full `AGENTS.md` text).
   When metadata already covers the lesson, **link** to that skill instead of
   copying its instructions into an instinct.
3. For each new lesson, write one file:
   `.agents/instincts/pending/<id>.md` using the template.
4. Start confidence at **0.3** (single observation) or **0.5** (clear repeated
   pattern in-session). Do not start above **0.7** without multi-session evidence.
5. Show the user a short list of proposed instincts; adjust or drop on feedback.

### 2. Reinforce or decay

When the same instinct would apply again:

| Event                                          | Confidence delta                                                          |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| Pattern observed again / user does not correct | +0.1 (cap 0.9)                                                            |
| User endorses explicitly                       | +0.2 (cap 0.9)                                                            |
| User corrects or contradicts                   | −0.2 (floor 0.3); if contradicted twice → `rejected` + move to `archive/` |
| Unused for a long time with no reinforcement   | leave as-is; do not auto-delete                                           |

Move `pending/` → `active/` when confidence ≥ **0.6** and the user has not objected
(or when the user asks to activate).

### 3. Apply during work

Before non-trivial implementation in a repo that has `.agents/instincts/active/`:

1. Skim active instincts whose `trigger` matches the task.
2. Apply those with confidence ≥ **0.5** when they do not conflict with higher-
   precedence guidance.
3. On conflict, ignore the instinct and flag it for revision or rejection.
   **Precedence (highest first):** explicit user instructions → repository
   `AGENTS.md` (including overrides) and repo-local skills → org skills / ADRs /
   coding-discipline → instincts.

### 4. Evolve (cluster → versioned guidance)

When **two or more** related `active/` instincts share a domain and average
confidence ≥ **0.7**, or when the user asks to evolve:

1. Cluster by domain / overlapping triggers.
2. Propose one of (do **not** write yet):
   - **Repo skill** — `.agents/skills/<name>/SKILL.md` via `create-skill` (repo-level).
   - **Org skill** — `org/agents/skills/<name>/SKILL.md` when portable across repos.
   - **AGENTS pointer / override** — short generation-time pointer only; detail stays in a skill.
   - **ADR** — only for durable architectural decisions (`create-adr`); never phrase
     ADRs as agent runbooks.
3. Get **user confirmation** before writing any promotion artifacts.
4. After confirmation, apply edits with `create-skill` / `update-agent-guidance` /
   `create-adr` as appropriate (never treat direct `AGENTS` or skill edits as an
   automatic path that skips propose-and-confirm).
5. After promotion: set `status: superseded`, set required `superseded_by` to the
   replacement skill, guidance, or ADR path, and move files to `archive/`.
6. Run bootstrap when org skills or `AGENTS.org.md` change (`update-agent-guidance`).

### 5. Scope: repo vs org

| Instinct content                              | Scope  | Promote to                                 |
| --------------------------------------------- | ------ | ------------------------------------------ |
| Package paths, local scripts, app-specific UI | `repo` | Repo skill or `AGENTS.md` overrides        |
| Portable architecture/workflow habits         | `org`  | Org skill or short `AGENTS.org.md` pointer |
| One durable structural decision               | —      | ADR (human-facing), not an instinct        |

When unsure, keep `scope: repo` first; promote to org only when the same lesson
holds in a second repository or the user confirms portability.

## Commands (agent procedures)

There is no separate CLI. When the user asks, run the matching procedure:

| Ask                       | Do                                                                |
| ------------------------- | ----------------------------------------------------------------- |
| Learn / extract / capture | Capture workflow → write `pending/` instincts → summarize         |
| Instinct status           | List `pending/` + `active/` with id, confidence, scope, domain    |
| Evolve                    | Evolve workflow → propose skill/guidance diff → wait for approval |
| Promote (repo → org)      | Re-check portability → `create-skill` / `update-agent-guidance`   |
| Reject / prune            | Set `status: rejected` or `superseded`; move to `archive/`        |

## Anti-patterns

- Auto-writing org skills or ADRs without user confirmation.
- Capturing secrets, credentials, or raw confidential chat logs into instincts.
- Duplicating an existing org skill as an instinct instead of linking to it.
- Using instincts to justify drive-by refactors or scope expansion (coding-discipline).
- Requiring Claude Code / Cursor hooks for this skill to work — hooks are optional
  and **repo-local** only; do not add hook installs to the org subtree.

## Optional hooks (consuming repos only)

ECC relies on PreToolUse/PostToolUse hooks for 100% observation. This org skill
does **not** ship hooks. A consuming repo may later add local hooks that append
observation notes for a human or agent to turn into instincts — keep that outside
`org/` and never as a substitute for the promote path into versioned guidance.

## Related

- `review` — repeated issues → capture instinct or update guidance
- `create-skill` — promote clusters into skills
- `update-agent-guidance` — route org vs repo guidance edits + bootstrap
- `coding-discipline` — do not let learning invent speculative process
- `search-first` — check existing skills/ADRs before new instincts
