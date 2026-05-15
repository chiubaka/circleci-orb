---
status: accepted
date: 2026-05-14
decision-makers: Daniel Chiu
---

# Release manifest pin sets and tooling-owned deploy order

## Context and Problem Statement

Coordinated multi-artifact releases need a **durable, reviewable record** of which **immutable artifact identities** ship together on a given release train, and automation that promotes staging and production without ambiguous “latest” resolution.

Prior art in this ADR set ([ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md), now superseded) additionally encoded **deployment phases and ordering inside the release manifest**. In practice that duplicates ordering already expressed in **checked-in deployment implementations** (for example infrastructure-as-code graphs, monorepo task pipelines with explicit dependencies, or scripted deploy entrypoints). Two sources of truth for the same DAG drift, complicate review, and push **deployment mechanics** toward the manifest instead of the tooling that actually executes deploys.

The problem is: how do we keep **release manifests** focused on **what pins together** while still coordinating multi-artifact deploys deterministically, and where should **artifact-to-artifact deploy order** live?

This decision **supersedes** [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) for normative manifest shape and for ownership of deploy ordering. It continues to assume **promotion tags** and **artifact-tag separation** as specified in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md). It complements artifact versioning and release intent in [ADR 0026](0026-use-changesets-for-application-releases.md) and [ADR 0028](0028-version-only-deployable-artifacts-by-default.md).

## Decision Drivers

- Deterministic, reproducible coordinated releases across environments
- A single, reviewable **composition** of immutable artifact tags per logical release
- Avoid duplicating deploy DAGs in both manifests and deployment tooling
- Support diverse executors (infrastructure-as-code, package scripts, task runners) without encoding their steps in `.releases/`
- Keep manifests at **high-level deployable** granularity (for example server, web), not low-level commands
- Preserve staging → production promotion semantics and logical release identifiers

## Considered Options

- **Phased manifest with CI-driven phases** (previous norm in ADR 0030): manifest lists pins and ordered `deploy` phases; CI executes phases.
- **Pin-only manifest + tooling-owned order (chosen):** manifest lists only the logical release id and pinned artifact tags; a **canonical deploy implementation** checked into the repository defines one **conservative** ordering between deployables that is always safe; CI (or equivalent) applies pins through that implementation.
- **Implicit coordination without a manifest:** promotion or branch workflows only; rejected for losing an auditable pin set for the train.

## Decision Outcome

Chosen option: **Pin-only manifest + tooling-owned deploy order**.

Justification: The manifest stays a lightweight **bill of materials** for the train—**which** immutable artifact tags belong to the coordinated release—while **how** deployables are sequenced relative to each other (including safe defaults when parallel optimizations are not required) lives in one place: the **canonical deploy implementation**, reviewed like other production automation. That reduces drift, avoids leaking step-level deployment logic into `.releases/`, and remains compatible with promotion-tag flows defined in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md).

### Consequences

- Good, because the manifest is small and stable and answers “what shipped together?” unambiguously.
- Good, because ordering is maintained once, alongside the code or infrastructure that enforces it.
- Good, because executors can be swapped or combined (for example task-runner orchestration calling into infrastructure-as-code) without changing manifest schema.
- Bad, because reviewers who only read `.releases/` no longer see artifact-to-artifact order; they must rely on the canonical deploy implementation and its review culture.
- Bad, because generic CI cannot infer order from the manifest; pipelines must invoke the repository’s documented deploy entrypoint (or equivalent) so behavior stays aligned with the implementation.

### Confirmation

- Release manifests participating in this model conform to the **Format** and **Rules** below.
- Coordinated staging and production deploys driven by promotion tags ([ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)) use **only** immutable artifact references from the manifest; no “latest” or implicit resolution for those deploys.
- Each repository adopting this model **documents** where the canonical deploy implementation and ordering live (for example contributor docs or a linked architecture note), so agents and humans know what to review for ordering and migration safety ([ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md)).
- Manifest validation (manual or automated) rejects unknown keys if strict validation is used, and enforces required fields and invariants in this ADR.

## Release manifest specification

A release manifest defines the **exact set of high-level deployable artifact versions** that belong to a coordinated logical release. It does **not** define a second deploy DAG: **artifact-to-artifact order is owned by the repository’s canonical deploy implementation** (see **Deploy order** below).

### Repository layout and file naming

- Release manifests MUST be stored under `.releases/` at the repository root.
- Each manifest file name MUST be `<release-id>.yml`, where `<release-id>` matches the `release` field inside the manifest and the suffix of the corresponding promotion tags (the logical release identifier after the `staging-` or `prod-` prefix; see [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)).

Example path for `release: 2026.04.06.1`:

`.releases/2026.04.06.1.yml`

### Format

The release manifest MUST be a YAML document with the following structure:

```yaml
release: string

artifacts:
  <artifact-name>: <artifact-tag>
  ...
```

No `deploy` key is defined by this ADR; if present in a file, tooling MUST either reject the file as invalid or ignore it consistently—repositories SHOULD prefer **strict validation** so manifests do not accumulate a shadow DAG.

### Example

File: `.releases/2026.04.06.1.yml`

```yaml
release: 2026.04.06.1

artifacts:
  server: server-v5.1.0
  web: web-v2.3.0
  ios: ios-v1.8.0
```

### Rules

- Each manifest MUST live at `.releases/<release-id>.yml` at the repository root, with `<release-id>` equal to the `release` field (see **Repository layout and file naming** above).
- The `release` field MUST match the **logical release identifier** used with promotion tags: the `YYYY.MM.DD.N` portion shared across environments, as defined in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md). Promotion tags add the `staging-` or `prod-` prefix to that identifier; the manifest `release` value does not include the environment prefix.
- The `artifacts` mapping MUST be present. Keys name **high-level deployables** (for example `server`, `web`, `ios`), not low-level steps such as individual database migration commands.
- All artifact values MUST reference **immutable artifact tags** ([ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)).
- CI or other automation performing coordinated deploys MUST deploy **exactly** the versions specified in the manifest for each listed deployable; no inference or “latest” resolution is allowed for those identities.
- The manifest MUST be committed to the repository and version-controlled.
- A release manifest commit remains the source of truth for **which artifact tags** constitute that coordinated release.

### Deploy order

**Ordering between deployables** for coordinated releases is defined solely by the repository’s **canonical deploy implementation** (for example resource dependency graphs, explicit pipeline stages, or ordered scripts), not by the manifest.

- That implementation SHOULD apply a **single conservative ordering** that remains safe across releases, rather than per-train optimized parallelism encoded in `.releases/`, unless a future ADR explicitly introduces optional manifest-level phases.
- **Sub-steps** required to roll out a given deployable (for example running production database migrations before new server code takes traffic) remain **inside** that deployable’s automation and policies ([ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md)), not as separate rows in `artifacts:` unless a deployable is intentionally versioned and released as its own artifact.

### Optional extensions (non-normative)

Future ADRs MAY reintroduce optional manifest-level phases for repositories that need cross-tool gating without adopting heavier orchestration platforms. Such an extension MUST remain backward compatible with pin-only manifests unless explicitly revised.

## Pros and Cons of the Options

### Phased manifest (superseded approach)

- Good, because order is visible in the same file as pins.
- Bad, because it duplicates and can drift from deployment tooling.
- Bad, because it invites manifest bloat toward deployment logic.

### Pin-only manifest + tooling-owned order

- Good, because one DAG owner; manifest stays a BOM for the train.
- Good, because aligns with common “desired versions” documents plus executor-owned apply order.
- Neutral, because requires discipline to review the deploy implementation, not only `.releases/`.
- Bad, because less obvious to readers who never open deploy code.

## More Information

This model preserves the **GitOps-style** idea that a small **desired composition** document pins released identities, while **apply order** matches how most teams already structure infrastructure and CI.

**Versioning vs composition:** Changesets and semver remain the system of record for **artifact** version bumps and user-facing release intent ([ADR 0026](0026-use-changesets-for-application-releases.md)). The manifest pins **which immutable artifact tags** belong to a coordinated train; it does not replace package versioning policy ([ADR 0028](0028-version-only-deployable-artifacts-by-default.md), [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) for library ecosystems).

## Related ADRs

- [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) — **superseded** by this ADR for manifest format and deploy-order ownership
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — artifact tags vs promotion tags; logical `release` identifier and promotion flow
- [ADR 0037](0037-release-train-identifiers-and-github-releases.md) — canonical `YYYY.MM.DD.N` train identifier and GitHub Releases alignment
- [ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md) — migrations as a distinct production step; ordering relative to traffic inside deploy tooling
- [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) — lockstep groups for related packages in library monorepos
- [ADR 0026](0026-use-changesets-for-application-releases.md) — application versioning and release intent
- [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) — which packages are versioned as deployable artifacts
