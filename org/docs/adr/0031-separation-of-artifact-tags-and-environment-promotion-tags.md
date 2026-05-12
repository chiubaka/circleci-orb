---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
---

# Separation of artifact tags and environment promotion tags

## Context and Problem Statement

The system requires both artifact versioning (for example, `server-v1.2.3`) and coordinated deployment across environments (staging, production). Using a single type of tag to represent both artifact versions and deployments leads to ambiguity and unintended deployments.

The problem is: how do we clearly separate artifact identity from deployment intent while maintaining a tag-based workflow?

This decision works together with [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md), which defines the release manifest and phased deploy model. Artifact tags identify built artifacts; promotion tags trigger environment deploys that must read pinned versions from the manifest.

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
- Promotion tags must reference a commit containing a valid release manifest ([ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md))
- Code review ensures tag naming conventions are followed

## Tagging conventions

### Artifact tags

Artifact tags identify immutable versions of deployable artifacts (aligned with versioned deployable units; see [ADR 0028](0028-version-only-deployable-artifacts-by-default.md)):

- `server-vX.Y.Z`
- `web-vX.Y.Z`
- `ios-vX.Y.Z`

Exact names are chosen per repository; the invariant is that **artifact tags denote immutable build outputs**, not an environment promotion.

### Promotion tags

Promotion tags trigger deployments to specific environments:

- `staging-YYYY.MM.DD.N`
- `prod-YYYY.MM.DD.N`

### Logical release identifier

The substring `YYYY.MM.DD.N` (for example, `2026.04.06.1`) is the **logical release id**. It MUST match the `release` field in the release manifest and the manifest filename `.releases/<release-id>.yml` ([ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md)). Promotion tags prepend `staging-` or `prod-` to that same identifier so staging and production promotions remain auditable and distinct while referring to one coordinated release definition.

### Increment (`N`) rules

- `N` MUST start at **1** for each new calendar date.
- `N` increments by 1 for each subsequent promotion on the same date.
- The first promotion of a given date MUST use `.1`, not `.0`.

Example:

- `staging-2026.04.06.1`
- `staging-2026.04.06.2`
- `prod-2026.04.06.1`

Corresponding manifest:

- Path: `.releases/2026.04.06.1.yml`
- Contents include `release: 2026.04.06.1` (same logical id as in the tags above, without the environment prefix)

### Promotion flow

1. Create or update the release manifest at `.releases/<release-id>.yml` (with `release` set to the logical release id).
2. Create a **staging** promotion tag → triggers staging deployment.
3. Validate the release in staging.
4. Create a **prod** promotion tag referencing the **same commit** → triggers production deployment.

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

- [ADR 0037](0037-release-train-identifiers-and-github-releases.md) — canonical release train identifier and GitHub Releases alignment
- [ADR 0026](0026-use-changesets-for-application-releases.md) — application versioning and user-facing release intent
- [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) — which artifacts are versioned
- [ADR 0030](0030-coordinated-release-model-release-manifests-and-promotion-tags.md) — release manifest format, deploy phases, and coordination rules
