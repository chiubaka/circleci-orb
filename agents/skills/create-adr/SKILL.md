---
name: create-adr
description: >-
  Guides authors in creating new ADRs at the right scope (org, repo, or
  package), using the org ADR template and preserving org-level portability.
---

# Create a new ADR

## Goal

Create ADRs that are easy to apply at the right ownership level:

- **Org-level ADR** for cross-repo conventions.
- **Repo-level ADR** for one repository's architecture or workflow.
- **Package-level ADR** for one package's boundaries and design choices.

## When to use this skill

Use this skill when you need to add a new ADR, choose ADR scope, or move a draft ADR to the correct location.

## Source of truth

- ADR scope and location baseline: `org/docs/adr/README.md`
- ADR template to copy for new ADRs: `org/docs/adr/template.md`

Always start from the template so section names, decision framing, and consequences stay consistent.

## Decide ADR scope first

Use this decision order before drafting:

1. Is this a durable standard that should apply across multiple repositories?
   - Yes -> **org-level ADR**
2. Is this specific to one repository's layout, tooling, or architecture?
   - Yes -> **repo-level ADR**
3. Is this specific to one package/module inside a repo?
   - Yes -> **package-level ADR**

When in doubt, choose the narrowest scope that still covers all intended adopters.

## ADR locations by scope

- **Org-level:** `org/docs/adr/`
- **Repo-level:** `docs/adr/`
- **Package-level:** `<package>/docs/adr/`

## Org-level ADR portability rule (critical)

Org-level ADRs must be self-contained and portable across repositories.

- Do not include repo-specific paths, package names, scripts, or "this repo only" implementation references as normative requirements.
- If concrete examples help explain the pattern, include them either:
  - directly in the ADR itself, or
  - in `org/docs/adr/examples/` and reference them from the ADR.
- Keep examples illustrative, not mandatory repo-coupled instructions.

## Illustrative scope examples

### Example A: org-level ADR

Decision: "Use a common import alias convention across all TypeScript repositories."

- Scope: org-level (cross-repo consistency)
- Location: `org/docs/adr/`
- Good evidence: portable examples and rationale that apply beyond one repository.

### Example B: repo-level ADR

Decision: "Adopt feature module boundaries and lint entry-point rules for this specific monorepo."

- Scope: repo-level (depends on one repo's folders and tooling setup)
- Location: `docs/adr/`
- Good evidence: references this repository's exact package names and lint config.

### Example C: package-level ADR

Decision: "In `packages/l3xo/backend`, keep evaluation orchestration in application services and adapters in infrastructure."

- Scope: package-level (one package's internals)
- Location: `packages/l3xo/backend/docs/adr/`
- Good evidence: trade-offs tied to one package's domain and dependency graph.

## ADR creation workflow

1. Pick scope (org/repo/package) and target folder.
2. Check for an existing ADR that already covers the decision.
3. Copy `org/docs/adr/template.md` and create the new numbered ADR file in the chosen folder.
4. Fill template sections with one clear decision and explicit consequences.
5. Add concise examples in-ADR or under `org/docs/adr/examples/` when needed.
6. Verify references are valid for the chosen scope (especially org-level portability).

## Author checklist

- [ ] Scope is correct (org vs repo vs package).
- [ ] ADR file is in the correct folder for that scope.
- [ ] ADR is based on `org/docs/adr/template.md`.
- [ ] Decision is singular and durable (not a transient task note).
- [ ] Org-level ADR has no repo-specific normative dependencies.
- [ ] Any concrete examples are in the ADR itself or in `org/docs/adr/examples/`.
