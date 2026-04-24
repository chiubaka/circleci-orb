---
status: accepted
date: 2026-03-28
decision-makers: Daniel Chiu
---

# ADR 0015: Centralized org-level agent standards via Git subtree and projection scripts

## Context and Problem Statement

We maintain multiple monorepos within one organization and want consistent, reusable standards for ADRs, agent guidance (`AGENTS.md`), and agent skills. These standards should be centrally defined, locally editable where appropriate, and consumable by various coding agents (Cursor, Claude Code, Codex, and others).

The challenge is to design a system that:

- avoids duplication and drift across repositories
- allows local improvements to propagate upstream when appropriate
- works across multiple agent providers without vendor lock-in
- ensures agent tooling reliably discovers skills and guidance in tool-native locations

## Decision Drivers

- Centralized source of truth for org-level standards
- Ability to propagate local improvements upstream
- Compatibility across multiple agent providers (no vendor lock-in)
- Reliable discovery of agent skills using tool-native locations
- Minimal cognitive and operational overhead (simple Git workflows)
- Clear separation between org-level and repository-specific customization

## Considered Options

- Git submodules for shared standards
- Copy or sync scripts from a central repository without subtree history
- A single shared directory with symlinks into tool-specific locations only
- A custom org directory with prompt-based discovery instead of native paths
- Git subtree with projection (copy or symlink) into native locations

## Decision Outcome

Chosen option: **Git subtree with projection scripts into tool-native locations**.

**Justification:** This approach provides a centralized, versioned source of truth while materializing files where each tool expects them. It supports bidirectional updates (local edits to org content can be pushed upstream with subtree workflows) and avoids the reliability and UX issues of submodules and symlink-only strategies for every surface, while keeping workflows Git-native.

### Consequences

- Good, because org-level standards are centralized and version-controlled
- Good, because local edits to subtree content can be pushed upstream using standard subtree commands
- Good, because agent tools reliably discover skills and rules via native file locations after projection
- Good, because repository-specific overrides can coexist cleanly with org defaults (for example marker-based sections in `AGENTS.md`)
- Bad, because a projection or install step is required to apply org sources locally
- Bad, because some duplication exists between subtree source trees and generated or linked outputs
- Bad, because discipline is required to run install or check scripts after subtree updates

### Confirmation

- CI or local checks can run the AGENTS projection script in read-only validation mode to detect drift between root `AGENTS.md` and `org/agents/AGENTS.org.md`; a wrapper may run that check together with skills projection checks
- Code review should treat durable changes to org-level standards as changes under the `org/` subtree (or equivalent prefix) and verify projection scripts still match intent
- Subtree sync operations (`pull` / `push` for the org prefix) should be part of the standard developer workflow for repositories that embed org standards
- Installed or generated outputs (for example under `.cursor/rules` where used) should match the org source and scripts that define them; where checks exist, they should be run in CI or pre-merge hooks as appropriate

## Pros and Cons of the Options

### Git submodules

- Good, because it preserves strict separation of the shared repository
- Good, because explicit version pinning of shared content
- Bad, because it requires special clone and initialization steps
- Bad, because poor ergonomics in CI, cloud agents, and local development
- Bad, because agent tools may not traverse submodules reliably

### Copy or sync scripts without subtree

- Good, because the mental model is simple
- Good, because results are normal files in the consuming repository
- Bad, because there is no built-in mechanism to propagate changes upstream with full history
- Bad, because local edits can easily diverge from the stated source of truth

### Symlink-only approach for all surfaces

- Good, because it avoids duplicating file bytes
- Good, because a single source can appear in multiple paths
- Bad, because support and behavior differ across tools and environments (including Cursor and CI)
- Bad, because failures can be subtle and hard to debug
- Bad, because symlink semantics differ across operating systems and sandboxes

### Custom org directory with prompt-based discovery

- Good, because structure can stay simple (`org/agents/skills`, and so on)
- Good, because no projection step is strictly required for agents that follow custom instructions
- Bad, because it relies on prompt behavior instead of each tool’s native discovery
- Bad, because reliability varies across tools and versions
- Bad, because it increases cognitive load for humans and agents

### Git subtree with projection scripts (chosen)

- Good, because subtree workflows are Git-native and support bidirectional sync for the embedded prefix
- Good, because history for ADRs and standards can be preserved in the org repository
- Good, because files can be materialized or linked into tool-native locations
- Good, because submodule and pure-symlink pitfalls are reduced for the full standards surface
- Neutral, because a projection or install step is unavoidable for some outputs
- Bad, because some duplication exists between subtree sources and installed outputs
- Bad, because contributors must remember to run sync and check scripts after updates

## More Information

### Repository structure (illustrative)

A shared org standards repository may contain a layout such as:

```text
agents/
  skills/
  scripts/
docs/
  adr/
```

Consuming monorepos typically embed that content under a fixed prefix (for example `org/`) using subtree workflows, for example:

```bash
git subtree add --prefix=org <remote> <branch>
git subtree pull --prefix=org <remote> <branch>
git subtree push --prefix=org <remote> <branch>
```

Exact remote names and branches are a repository concern; the prefix and subtree discipline are the portable convention.

### Projection strategy

- Org skills are linked or installed into `.agents/skills` (and related tool paths) so org-shared and repository-local skills can coexist; see [ADR 0003](0003-agent-skills-canonical-location-and-symlinks.md) for canonical layout and bootstrap responsibilities.

#### Syncing root `AGENTS.md` with `org/agents/AGENTS.org.md`

Org guidance is split between a subtree-held **authoring source** and a repository-root **consumption file** that agents and editors typically open. Projection from source to root is performed by a **bootstrap script** (name and flags are implementation details; they must satisfy the contract below).

| Role                                | Path                                                                                 |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| Org source of truth                 | `org/agents/AGENTS.org.md`                                                           |
| Repo-facing file (what agents read) | `AGENTS.md` at repository root                                                       |
| Projection entrypoint               | A script under `org/agents/scripts/` that applies org guidance into root `AGENTS.md` |

**Ownership (marker boundaries):**

- Org-level defaults are authored only in `AGENTS.org.md`. The script projects that body into the org-managed region of root `AGENTS.md`.
- Repository-specific content lives only between the repo override markers in root `AGENTS.md` (see below). That region is never overwritten by the script.

**Markers in root `AGENTS.md`:**

- Org-managed block (replaced on each successful bootstrap):
  - `<!-- ORG_GUIDANCE_START -->`
  - `<!-- ORG_GUIDANCE_END -->`
- Repository override block (preserved byte-for-byte across runs):
  - `<!-- REPO_OVERRIDES_START -->`
  - `<!-- REPO_OVERRIDES_END -->`

**Behavior:**

- If `AGENTS.md` is missing, write mode creates it with a root title, the org-managed block filled from `AGENTS.org.md`, and a starter repo override block containing a short placeholder line (edit real overrides there). In `--check` mode, a missing `AGENTS.md` is reported and the command exits with failure.
- If all four markers appear exactly once and pairing is valid, only the org-managed section is replaced with the current `AGENTS.org.md` contents; the repo override section is copied through unchanged.
- If markers are missing, duplicated, or otherwise invalid, write mode backs up the existing file, migrates prior body text into the repo override section (with a migration banner line), and rewrites `AGENTS.md`; `--check` reports the marker error and exits without writing.

**Operator workflow (conceptual):**

- After changing `AGENTS.org.md`, run the AGENTS projection script in write mode so root `AGENTS.md` picks up the org block.
- Repositories may ship a single entrypoint that runs skills projection and AGENTS projection in one invocation.
- Run the same scripts in read-only validation mode before merge or in CI to fail on drift or invalid markers.

Together, this yields consistent org guidance in a tool-visible root file, preserved local overrides, and detectable drift when validation mode is used.

### Design principles

- Centralize authorship; localize consumption
- Prefer tool-native discovery over ad hoc conventions where practical
- Keep workflows simple and Git-native
- Avoid reliance on fragile cross-environment behavior unless scoped and documented (for example symlink caveats in [ADR 0003](0003-agent-skills-canonical-location-and-symlinks.md))
- Make ownership boundaries explicit (org versus repository)

### Future considerations

- Automation to run install scripts after subtree pulls
- Stronger CI enforcement of sync correctness for projected outputs
- Expansion of agent skill taxonomy and structure
- Revisit symlink versus copy trade-offs if tool support for links becomes uniformly reliable

### Related decisions

- [ADR 0003](0003-agent-skills-canonical-location-and-symlinks.md) — canonical skill locations by scope and per-tool links (bootstrap-managed links and coexistence with repo-local skills)
