---
name: agents-org-md-streamline
description: Streamline org/agents/AGENTS.org.md by keeping generation-time rules in org guidance, moving review-time guidance to the review skill or ADRs, and syncing AGENTS.md via bootstrap-agents-md.sh.
---

# AGENTS.org.md Streamline Skill

## Objective

Streamline `org/agents/AGENTS.org.md` so that:

- `org/agents/AGENTS.org.md` keeps only generation-time guidance
- `org/agents/skills/review/SKILL.md` holds review-time checks and polish guidance
- ADRs hold longer rationale and durable tradeoff documentation

This skill targets `org/agents/AGENTS.org.md` refactors only.

- Do not directly refactor root `AGENTS.md` as a primary source.
- Root `AGENTS.md` is updated indirectly by bootstrap sync from `org/agents/AGENTS.org.md`.

Do NOT introduce new rules. Only move, trim, and reorganize existing content.

---

## Source of truth and sync boundary (required)

- `org/agents/AGENTS.org.md` is the canonical org-level guidance source.
- Root `AGENTS.md` remains bootstrap-managed and must not be the primary refactor target.
- After changing `org/agents/AGENTS.org.md`, always run:
  - `org/agents/scripts/bootstrap-agents-md.sh`
  - `org/agents/scripts/bootstrap-agents-md.sh --check`

If you created or renamed org skills as part of the same task, also run:

- `org/agents/scripts/bootstrap-skills.sh`

---

## Step 0 — Ensure required files exist

Ensure the following file exists:

```
org/agents/skills/review/SKILL.md
```

If it does not exist, create it.

---

## Step 1 — Process org guidance incrementally

Process `org/agents/AGENTS.org.md` section-by-section.

For each section or bullet group, evaluate each rule independently.

---

## Step 2 — Classification rules (strict order)

For each rule, apply the following tests in order.

---

### TEST 1 — Structural correctness

Question:
If this rule is ignored during initial code generation, will the result be structurally incorrect or require significant refactoring?

- YES -> KEEP in `org/agents/AGENTS.org.md`
- NO -> continue

Examples of YES:

- Architecture boundaries (domain/application/infrastructure)
- Composition-root boundaries
- Module and file ownership boundaries
- Import-boundary rules

---

### TEST 2 — First-pass usefulness

Question:
Does knowing this rule before writing code significantly improve first implementation quality?

- YES -> KEEP in `org/agents/AGENTS.org.md`
- NO -> continue

Examples:

- Barrel boundary constraints
- Import-boundary conventions

---

### TEST 3 — Frequent failure prevention

Question:
Does this rule prevent a common or costly agent failure?

- YES -> KEEP in `org/agents/AGENTS.org.md`
- NO -> continue

Examples:

- Barrel misuse that leaks internals
- Cross-layer dependency violations
- Misplaced infrastructure logic

---

### TEST 4 — Style or readability preference

Question:
Is this rule primarily style, readability, or naming polish?

- YES -> MOVE to `org/agents/skills/review/SKILL.md`
- NO -> continue

---

### TEST 5 — Post-hoc validation suitability

Question:
Can this rule be checked after code is written without architectural fallout?

- YES -> MOVE to `org/agents/skills/review/SKILL.md`
- NO -> continue

Guidance:

- If a rule can be reliably checked from a finished diff (naming consistency, constructor option handling shape, mapper/helper placement), treat it as post-hoc and move it to review unless removing it would break structure.

Common post-hoc categories (move to review skill by default):

- Source-file basename preferences
- Test layout conventions
- Repository naming polish
- Constructor options style consistency
- TypeScript closed-vocabulary preference (`enum` vs string union)

---

### TEST 6 — Verbosity and edge-case density

Question:
Is this guidance long, nuanced, or mostly edge-case handling?

- YES -> MOVE to review skill or ADR
- NO -> continue

---

### TEST 7 — Rationale versus instruction

Question:
Is this content mostly rationale ("why") instead of direct instruction ("what to do")?

- YES -> MOVE to ADR
- NO -> KEEP in `org/agents/AGENTS.org.md`

---

## Step 2.5 — Explicit relocation map (required)

When any of the following appear in `org/agents/AGENTS.org.md`, move them out unless a concrete structural invariant is being preserved:

- Long ADR reference catalogs -> replace with a short ADR pointer and reference only ADRs that directly back a retained rule.
- Self-documenting-code/readability guidance -> move to `org/agents/skills/review/SKILL.md`.
- Tool-specific lint workaround policy (for example `security/detect-object-injection`) -> move to review skill.
- Test layout conventions -> move to review skill (or TDD skill), not org generation rules.
- Repository API naming consistency -> move to review skill.
- Constructor options style preferences -> move to review skill.
- Closed-vocabulary TypeScript preference -> move to review skill.
- TDD methodology guidance -> remove from org guidance and rely on `test-driven-development` skill.
- Final verification workflow details -> keep in review skill; org guidance should only require a post-implementation review pass.

If uncertain, prefer moving to review skill and leaving a short org-level handoff pointer.

---

## Step 3 — Apply transformations

### KEEP in `org/agents/AGENTS.org.md`

- Keep rules concise and actionable
- Condense long guidance to 1-3 bullets where possible
- Remove explanatory prose that belongs in review skill or ADRs
- For sections that mix one structural invariant with multiple style/examples/exceptions, keep only the invariant and move the rest.
- Avoid broad ADR inventories; keep only targeted ADR references that directly support retained structural instructions.

### MOVE to review skill

Append to:

```
org/agents/skills/review/SKILL.md
```

Keep entries short, testable, and review-oriented.

When migrating style-heavy sections:

- Preserve intent by adding checklist items that are directly checkable in code review.
- Move examples, exceptions, and “why this is readable” prose out of `org/agents/AGENTS.org.md`.

### MOVE to ADR (when needed)

Use ADRs when content is rationale-heavy, includes tradeoffs, or carries durable context.

Preferred scope:

- `org/docs/adr/` for org-portable guidance rationale
- repo/package ADRs only when guidance is intentionally local

---

## Step 4 — Streamline quality checks

After processing all rules:

- Remove duplicate or overlapping guidance
- Keep sections concise and skimmable
- Keep instructions explicit and unambiguous

---

## Step 5 — Validate result boundaries

`org/agents/AGENTS.org.md` should contain:

- generation-time architecture and structure constraints
- naming and boundary conventions only when they materially affect first-pass structural correctness
- high-impact failure prevention rules
- a concise handoff to review/TDD skills for post-generation quality and workflow checks

`org/agents/AGENTS.org.md` should not contain:

- style-only preferences
- readability polish guidance better suited for review
- long rationale and edge-case narratives
- lint-rule-specific workaround policy and other tool-specific tactical guidance
- verification command runbooks and test layout details that are enforceable post-generation

---

## Step 6 — Preserve review handoff

Ensure org guidance still includes explicit handoff to the review skill for post-generation quality checks.

---

## Step 7 — Required sync and final checks

Before finishing:

- run `org/agents/scripts/bootstrap-agents-md.sh`
- run `org/agents/scripts/bootstrap-agents-md.sh --check`
- run `org/agents/scripts/bootstrap-skills.sh` if org skills were added/renamed
- confirm no duplicate guidance was introduced

---

## Default decision rule

When uncertain:

- Structural and generation-time constraints -> `org/agents/AGENTS.org.md`
- Style and review-time checks -> `org/agents/skills/review/SKILL.md`
- Rationale and tradeoffs -> ADR
