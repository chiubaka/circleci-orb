---
status: accepted
date: 2026-03-21
decision-makers: Daniel Chiu
---

# ADR 0003: Canonical skill locations by scope and per-tool links

## Context and Problem Statement

Multiple AI coding agents (Codex, Claude Code, Cursor, and others) support **project-local skills** (instruction bundles such as `SKILL.md` plus optional resources), but each ecosystem expects skills under **its own conventional path** (for example `.cursor/skills`, `.claude/skills`, or `.agents/skills`).

Maintaining **duplicate copies** of the same skill in several folders causes drift, noisy diffs, and unclear ownership. We want clear canonical locations by ownership scope while still satisfying each tool’s documented layout.

## Decision Drivers

- **Canonical ownership by scope:** Org-shared and repo-local skills each have one authoritative home.
- **Tool compatibility:** Each agent continues to read from its normal location without custom per-developer setup beyond `git clone`.
- **Simplicity:** Prefer a boring filesystem pattern over bespoke sync scripts unless we outgrow it.
- **Git friendliness:** Layout should work for typical Linux/macOS workflows; document caveats for environments where symlinks are awkward.

## Considered Options

- **Duplicate skills per tool** — Copy the same content into `.cursor/skills`, `.claude/skills`, etc.
- **Canonical by scope + bootstrap-managed links** — Store org-shared skills under `org/agents/skills`; keep repo-local skills under `.agents/skills`; use `bootstrap-skills.sh` to link org-shared skills into `.agents/skills`, with `.cursor/skills` and `.claude/skills` linking to `.agents/skills`.
- **CLI or script sync** — A command that copies or hardlinks from a canonical folder on demand (e.g. after pull).

## Decision Outcome

**Chosen option: canonical-by-scope layout + bootstrap-managed links into tool-facing paths.**

**Justification:** Keeping org-shared content under `org/agents/skills` aligns with org-managed guidance and subtree portability; keeping repo-local skills under `.agents/skills` preserves local autonomy. Bootstrap-managed links make org-shared skills available in tool-facing paths without duplicating content.

### Consequences

- Good, because ownership is explicit: org-shared skills in `org/agents/skills`, repo-local skills in `.agents/skills`.
- Good, because contributors add org-shared skills under `org/agents/skills/<skill-name>/SKILL.md` and then run bootstrap.
- Good, because bootstrap links org-shared skills into `.agents/skills` while preserving non-org local skills.
- Bad, because setup now depends on running bootstrap after clone/pull when org skills are added or renamed.
- Bad, because **Windows** symlink behavior can still require `core.symlinks` and Developer Mode for linked tool paths.

### Confirmation

- **Implementation:** The repo contains **real** org-shared skill content under **`org/agents/skills/`** and **real** repo-local skill content under **`.agents/skills/`** for local-only skills. `org/agents/scripts/bootstrap-skills.sh` creates/validates per-skill symlinks in **`.agents/skills/`** for org-shared skills only. Tool-facing paths such as **`.cursor/skills`** and **`.claude/skills`** remain symlinks to **`../.agents/skills`**.
- **Review:** Structural changes to skills layout should reference this ADR; code review checks that org-shared skills land under `org/agents/skills` and that bootstrap/check commands pass.
- **Revisit:** If bootstrap friction or symlink portability issues become common, consider ADR supplement: copy-mode bootstrap, platform-specific fallback, or alternative distribution strategy.

## Pros and Cons of the Options

### Duplicate skills per tool

- Good, because every file is a plain file on all OSes.
- Bad, because duplication and drift; easy to update one copy and forget another.

### Canonical by scope + bootstrap-managed links

- Good, because org-shared and repo-local skill ownership are explicit and non-overlapping.
- Bad, because contributors must run bootstrap/check when org skill names change.

### CLI or script sync

- Good, because could work everywhere without symlinks.
- Bad, because extra step and tooling to maintain; easy to forget to run.

## More Information

- Symlink targets use **relative** paths so clones and moves of the repository root remain stable.
