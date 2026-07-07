---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
---

# Separation of artifact tags and environment promotion tags

## Context and Problem Statement

The system requires both artifact versioning (for example, `server-v1.2.3`) and coordinated deployment across environments (staging, production). Using a single type of tag to represent both artifact versions and deployments leads to ambiguity and unintended deployments.

The problem is: how do we clearly separate artifact identity from deployment intent while maintaining a tag-based workflow?

This decision works together with [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md), which defines the release manifest (pin set) and delegates deploy ordering to the repository’s canonical deploy implementation. Artifact tags identify built artifacts; promotion tags trigger environment deploys that must read pinned versions from the manifest. Historical phased-manifest requirements appear in superseded [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md).

## Decision Drivers

- Clear separation of concerns between build artifacts and deployments
- Prevention of accidental or partial deployments
- Support for explicit environment promotion (staging → production)
- Compatibility with CI-triggered workflows
- Maintainability and clarity of release history
- Deterministic deployment behavior

## Considered Options

- Single tag type for both artifacts and deployments
- Artifact tags triggering deployments directly
- Release tags without environment distinction
- Separate artifact tags and environment-specific promotion tags (chosen)

## Decision Outcome

Chosen option: **Separate artifact tags and environment-specific promotion tags**.

Justification: This approach cleanly separates artifact creation from deployment intent, enabling deterministic and controlled releases while maintaining flexibility in CI workflows.

### Consequences

- Good, because artifact creation is decoupled from deployment
- Good, because deployments are explicitly triggered and controlled
- Good, because staging and production promotions are clearly represented
- Good, because prevents accidental deployment of incomplete systems
- Bad, because introduces additional tag types and conventions
- Bad, because requires discipline in tag naming and usage
- Bad, because slightly increases operational complexity

### Confirmation

- Artifact tags must never trigger production deployments
- CI pipelines for staging/production coordinated deploys must trigger only from promotion tags (for repos following this model)
- Promotion tags must reference a commit containing a valid release manifest ([ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md))
- Code review ensures tag naming conventions are followed

## Tagging conventions

### Artifact tags

Artifact tags identify immutable versions of deployable artifacts (aligned with versioned deployable units; see [ADR 0028](0028-version-only-deployable-artifacts-by-default.md)):

- `server-vX.Y.Z`
- `web-vX.Y.Z`
- `ios-vX.Y.Z`

Exact names are chosen per repository; the invariant is that **artifact tags denote immutable build outputs**, not an environment promotion.

### Promotion tags

Promotion tags trigger deployments to specific environments. The tag body after the environment prefix is a **promotion id** ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)):

- **Staging (three-environment):** `staging-<cycle-id>-rc<n>` (for example `staging-2026.07.01.1-rc2`)
- **Production:** `prod-<cycle-id>` (for example `prod-2026.07.01.1`; no RC suffix)
- **Two-environment (single cut):** `prod-<cycle-id>` or `staging-<cycle-id>-rc1` when staging is used

### Release cycle identifier (`YYYY.MM.DD.N`)

The substring `YYYY.MM.DD.N` (for example `2026.07.01.1`) is the **release cycle id** (historically “logical release id”). It names a coordinated release **cycle** from first RC cut through production promotion.

- The **calendar portion** is the **cycle open date** (UTC date of the first `rc1` cut), not the production ship date ([ADR 0038](0038-release-train-identifiers-and-github-releases.md), [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).
- **`N`** counts **release cycles opened on that UTC calendar day**, not RC iterations within a cycle.
- Manifest layout and RC directories are defined in [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md); pin-only manifest fields remain in [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md).

### Increment (`N`) rules (cycle id)

- `N` MUST start at **1** for each new UTC calendar date (cycle open date).
- `N` increments by 1 for each **new release cycle** opened on that date (after a prior cycle `…N` has started on the same day).
- The first cycle on a given date MUST use `.1`, not `.0`.
- **RC iterations** within a cycle use `-rc<n>` on staging tags (`rc1`, `rc2`, …), not a bumped cycle `N`.

Example (three-environment, one cycle with two RCs):

- `staging-2026.07.01.1-rc1` → deploy `.releases/2026.07.01.1/rc1/manifest.yml`
- `staging-2026.07.01.1-rc2` → deploy `.releases/2026.07.01.1/rc2/manifest.yml` (soak patch; same cycle id)
- `prod-2026.07.01.1` → deploy final validated RC on the tagged commit

Example (two-environment, single cut):

- `prod-2026.07.01.1` → deploy highest `rc*/manifest.yml` on the tagged commit (`.releases/2026.07.01.1/rc2/manifest.yml` when rc2 is the final cut)

### Promotion flow

1. Allocate a **release cycle** and create `.releases/<cycle-id>/` with `rc1/` manifest on the first version cut ([ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md)).
2. Create a **staging** promotion tag with `-rc<n>` when staging is a coordinated target (topologies A, B) → triggers staging deployment.
3. Validate in staging; if soak fixes require a new version cut, add `rc<n+1>/` under the **same** cycle id and re-promote staging with the new `-rc` suffix.
4. Create a **prod** promotion tag with the **cycle id only** (no `-rc` suffix) on the final validated commit → triggers production deployment.
5. **Production hotfix:** allocate a **new** cycle from the current `prod-*` commit; do not add RC directories to a cycle that already has `promotedAt` ([ADR 0042 — Hotfix releases](0042-release-cycles-rc-identifiers-and-manifest-directories.md#hotfix-releases)).

**Automation:** Repos MAY configure CI to push a promotion tag on release merge when an environment prefix is set (for example `staging` or `prod` on gated publish). The tag MUST reference the merge commit that contains the manifest. **Staging deploy workflows MUST NOT** push `prod-*` tags; production promotion after staging validation remains **manual** unless the repo explicitly opts into `prod` on merge.

**Dev / default branch:** Continuous deploys from the default branch are **out of band** from promotion trains and MUST NOT use `prod-*` promotion tags or artifact tags as production triggers. Topology **C** uses this for dev while prod remains gated.

### Invariants

- Promotion tags MUST NOT modify artifact versions (they select a manifest commit; artifact versions live in the manifest).
- Production MUST deploy the exact manifest validated in staging when following this promotion flow.
- CI MUST NOT infer versions outside the manifest for coordinated deploys.

## Pros and cons of the options

### Single tag type for both artifacts and deployments

- Good, because simple and minimal
- Good, because easy to understand initially
- Neutral, because works for single-artifact systems
- Bad, because conflates artifact identity with deployment intent
- Bad, because leads to accidental or partial deployments
- Bad, because does not support coordinated multi-artifact releases

### Artifact tags triggering deployments directly

- Good, because aligns with common CI/CD patterns
- Good, because minimal configuration required
- Neutral, because works for independent services
- Bad, because cannot coordinate multiple artifacts
- Bad, because ordering and dependencies cannot be enforced
- Bad, because deployments become nondeterministic

### Release tags without environment distinction

- Good, because simpler than environment-specific tags
- Good, because still separates artifact and deployment concerns
- Neutral, because can work with additional metadata
- Bad, because lacks clarity between staging and production
- Bad, because promotion flow becomes implicit and error-prone
- Bad, because harder to audit environment history

### Separate artifact tags and environment-specific promotion tags

- Good, because clearly separates concerns
- Good, because enables explicit promotion workflows
- Good, because supports deterministic deployments
- Neutral, because requires additional conventions
- Bad, because introduces more moving pieces
- Bad, because requires CI discipline and enforcement

## More Information

Promotion tags represent explicit deployment intent, not artifact creation. That keeps deployments deliberate, auditable, and reproducible.

This model is compatible with future evolution toward GitOps or Kubernetes-based deployment systems.

Application versioning and changelog intent remain driven by Changesets where applicable ([ADR 0026](0026-use-changesets-for-application-releases.md)); artifact tags in CI should correspond to immutable outputs of those release processes, not replace them.

## Related ADRs

- [ADR 0038](0038-release-train-identifiers-and-github-releases.md) — canonical release train identifier and GitHub Releases alignment
- [ADR 0041](0041-release-train-review-artifacts-for-deployable-applications.md) — staging/prod review changelog artifacts and train notes file
- [ADR 0042](0042-release-cycles-rc-identifiers-and-manifest-directories.md) — release cycles, RC suffix on staging tags, manifest directory layout
- [ADR 0026](0026-use-changesets-for-application-releases.md) — application versioning and user-facing release intent
- [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) — which artifacts are versioned
- [ADR 0039](0039-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) — release manifest format (pin sets) and coordination rules; superseded [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) for historical phased manifests
