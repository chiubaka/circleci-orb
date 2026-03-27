---
status: accepted
date: 2026-03-21
decision-makers: Daniel Chiu
---

# ADR 0003: Canonical agent skills directory (`.agents/skills`) and per-tool symlinks

## Context and Problem Statement

Multiple AI coding agents (Codex, Claude Code, Cursor, and others) support **project-local skills** (instruction bundles such as `SKILL.md` plus optional resources), but each ecosystem expects skills under **its own conventional path** (for example `.cursor/skills`, `.claude/skills`, or `.agents/skills`).

Maintaining **duplicate copies** of the same skill in several folders causes drift, noisy diffs, and unclear ownership. We want **one canonical tree** in this repository while still satisfying each tool’s documented layout.

## Decision Drivers

- **Single source of truth:** One directory to edit, review in PRs, and document.
- **Tool compatibility:** Each agent continues to read from its normal location without custom per-developer setup beyond `git clone`.
- **Simplicity:** Prefer a boring filesystem pattern over bespoke sync scripts unless we outgrow it.
- **Git friendliness:** Layout should work for typical Linux/macOS workflows; document caveats for environments where symlinks are awkward.

## Considered Options

- **Duplicate skills per tool** — Copy the same content into `.cursor/skills`, `.claude/skills`, etc.
- **Canonical `.agents/skills` + relative symlinks** — Store real files under `.agents/skills`; symlink `.claude/skills` and `.cursor/skills` to that tree. Codex already uses `.agents/skills`, so no extra link is required there.
- **CLI or script sync** — A command that copies or hardlinks from a canonical folder on demand (e.g. after pull).

## Decision Outcome

**Chosen option: canonical `.agents/skills` + relative symlinks for tools that use other paths.**

**Justification:** Symlinks preserve a single on-disk tree, keep agent-specific paths stable for documentation and tooling, and avoid running a sync step after every clone or pull. Codex consuming `.agents/skills` directly avoids an unnecessary indirection.

### Consequences

- Good, because PRs touch one tree; reviewers see one authoritative change.
- Good, because new skills are added under `.agents/skills/<skill-name>/` following common `SKILL.md` conventions.
- Good, because relative symlinks (`../.agents/skills` from within `.claude/` or `.cursor/`) travel with the repo on Unix-like systems.
- Bad, because **Windows** checkouts may not materialize real symlinks depending on Git and OS settings; contributors on Windows may need `core.symlinks` and Developer Mode or an documented workaround.
- Bad, because rare tools might ignore symlinks; if that happens, revisit with a sync script or documented copy step.

### Confirmation

- **Implementation:** The repo contains **real** skill content only under **`.agents/skills/`**. **`.claude/skills`** and **`.cursor/skills`** are **symbolic links** to **`../.agents/skills`** (paths relative to the link location). Codex continues to use **`.agents/skills`** with no symlink.
- **Review:** Structural changes to skills layout should reference this ADR; code review checks that new skills land under `.agents/skills` and that compatibility links remain valid.
- **Revisit:** If symlink friction on a target platform becomes common, consider ADR supplement: sync script, Git LFS, or documented “copy on clone” for that platform only.

## Pros and Cons of the Options

### Duplicate skills per tool

- Good, because every file is a plain file on all OSes.
- Bad, because duplication and drift; easy to update one copy and forget another.

### Canonical `.agents/skills` + symlinks

- Good, because one edit surface and clear ownership.
- Bad, because symlink portability on Windows requires care.

### CLI or script sync

- Good, because could work everywhere without symlinks.
- Bad, because extra step and tooling to maintain; easy to forget to run.

## More Information

- Symlink targets use **relative** paths so clones and moves of the repository root remain stable.
