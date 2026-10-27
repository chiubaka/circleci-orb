---
name: search-first
description: >-
  Research before inventing utilities, dependencies, or net-new abstractions.
  Use when adding a new feature, utility/helper, dependency, or library/API
  integration, or before writing custom code that might already exist in-repo
  or in org guidance.
---

# Search first

## Goal

Avoid reinventing. Prefer **adopt / extend / compose / build** as an explicit decision after searching the repo, org ADRs/skills, and (when needed) external sources.

## When to use / when not

**Use** for any new capability, shared helper, dependency, or integration.

**Skip** for typo-only or single-line fixes where the change target is already located.

## Workflow (ordered)

1. **Need analysis** — In 1–3 sentences, state what capability is required and what success looks like.
2. **Repo search first** — Use `rg` / Glob (or equivalent) for existing modules, helpers, ADRs, and skills in the target repository.
3. **Org pattern check** — Search `org/docs/adr/` and `org/agents/skills/` for established decisions and playbooks.
4. **External search when still needed** — Package registries and `gh search` / web when repo + org do not cover the need. Report skipped channels honestly (for example: no network, registry unavailable).
5. **Decide** — Choose one: **Adopt** | **Extend** | **Compose** | **Build**. One-line rationale required.
6. **Implement the minimal path** — Pair with coding-discipline; do not invent speculative wrappers or abstractions.

## Anti-patterns

- Jump-to-code before searching.
- Silent “nothing found” when a search channel was unavailable or skipped.
- Wrapping a library into oblivion (thin re-exports or indirection with no real domain value).

## Related

- `coding-discipline` / `org/agents/rules/coding-discipline.md`
- `feature-module-change-playbook`
- `external-api-integration`
