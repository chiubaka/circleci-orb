Org-level guidance in this section is the default baseline for all repositories.
Repository-specific guidance in the local override section of `AGENTS.md` takes precedence on conflicts.

## Architecture and decisions

- Follow org ADRs in `org/docs/adr/` for long-lived architecture and engineering conventions.
- Keep `AGENTS.md` concise; use ADRs for durable decisions and deeper rationale.

## Skills and portability

- Treat `org/agents/skills` as the shared org skill source intended for subtree distribution.
- Local repositories may add repo-specific skills under `.agents/skills` without changing org-shared skill sources.
