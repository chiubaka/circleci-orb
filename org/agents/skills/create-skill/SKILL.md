---
name: create-skill
description: >-
  Guide for creating new AI agent skills with clear org-level vs repo-level
  placement rules, portability constraints, and practical examples.
---

# Create a new skill

## Goal

Create skills that are easy to discover, correctly scoped, and maintainable over time by choosing the right level:

- **Org-level skill**: reusable across many repositories.
- **Repo-level skill**: intentionally specific to one repository.

## Decide scope first: org-level or repo-level

Use this decision rule before writing content:

- Choose **org-level** when guidance is broadly reusable across teams/repositories and does not depend on one repo’s structure, package names, scripts, or private conventions.
- Choose **repo-level** when guidance depends on repository-specific paths, architecture choices, tooling defaults, scripts, or local team workflow.

If in doubt, start by asking:

1. Would this still be correct if copied into a different repo?
2. Does this require repo-specific file paths or naming?
3. Does this depend on local scripts/config not guaranteed elsewhere?

If answers are mostly “yes” to portability, use org-level. If mostly “yes” to local dependency, use repo-level.

## Where to create the skill

- **Org-level skill location:** `org/agents/skills/<skill-name>/SKILL.md`
- **Repo-level skill location:** `.agents/skills/<skill-name>/SKILL.md`

Use kebab-case for `<skill-name>` and keep names action-oriented (for example, `create-skill`, `external-api-integration`).

## Required portability rule for org-level skills

Org-level skills must avoid hard dependencies on a single repository.

For org-level skills:

- Do not require repo-specific paths, package names, branch names, or scripts.
- Do not assume one monorepo layout unless presented as an **illustrative** pattern.
- Prefer portable wording such as “in your repository” or “in the target package.”
- Include short, self-contained examples directly in the skill so users do not need local context to understand intent.
- Keep references to standards generic unless they are truly org-wide and portable.

When a repo-specific detail is useful, show it as an explicit example pattern, not a requirement.

## Illustrative examples: choosing the level

### Example A (should be org-level)

Skill idea: “How to separate API client transport concerns from domain service orchestration.”

Why org-level:

- Architectural pattern is reusable across repositories.
- Guidance can be taught with generic interfaces and example folders.
- No dependency on one repo’s package names.

Where to create it:

- `org/agents/skills/external-api-integration/SKILL.md`

### Example B (should be repo-level)

Skill idea: “How to add a new feature module in this repository with its exact folder layout, lint rules, and task commands.”

Why repo-level:

- Depends on this repository’s specific structure and commands.
- May reference local ADR files, package names, and workspace scripts.
- Would not transfer cleanly to a different codebase.

Where to create it:

- `.agents/skills/<repo-specific-feature-skill>/SKILL.md`

## Post-create sync step (org skills)

After creating a new org-level skill, re-sync org skills into the repository copy:

- Run `org/agents/scripts/bootstrap-skills.sh`
- Confirm the corresponding skill appears under `.agents/skills/<skill-name>/SKILL.md`

## Recommended authoring checklist

- [ ] Scope chosen (org vs repo) before drafting content.
- [ ] Path matches scope (`org/agents/skills` or `.agents/skills`).
- [ ] Frontmatter includes `name` and `description`.
- [ ] Instructions are actionable and ordered.
- [ ] At least one illustrative example is included.
- [ ] For org-level: no mandatory repo-specific references.
- [ ] For org-level skills in this org workflow: `org/agents/scripts/bootstrap-skills.sh` has been run to sync into `.agents/skills`.
- [ ] For repo-level: repo assumptions are explicit and concrete.
