---
status: superseded
date: 2026-04-07
decision-makers: Daniel Chiu
---

> **Superseded by [ADR 0038 — Release manifest pin sets and tooling-owned deploy order](0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md)** (accepted 2026-05-14). Normative manifest requirements and deploy-order ownership are defined there; the remainder of this document is **historical context** only.

# Coordinated release model using release manifests and promotion tags

## Context and Problem Statement

The system consists of multiple interdependent deployable artifacts (for example, server, web, mobile clients) that may require coordinated deployment. Tag-based deployment where each artifact tag independently triggers deployment is insufficient when deployment order, compatibility, and environment promotion must be controlled.

The problem is: how do we coordinate deployment of multiple artifacts in a deterministic, auditable, and scalable way without introducing heavy infrastructure (for example, Kubernetes) prematurely?

This decision complements artifact versioning and release intent captured elsewhere ([ADR 0026](0026-use-changesets-for-application-releases.md), [ADR 0028](0028-version-only-deployable-artifacts-by-default.md)) by defining how **orchestrated** multi-artifact deployments are expressed and executed. It assumes promotion tags and artifact-tag separation as specified in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md).

## Decision Drivers

- Need for coordinated deployment of interdependent components
- Deterministic and reproducible releases across environments
- Avoidance of premature infrastructure complexity (for example, Kubernetes)
- Clear separation between artifact versioning and release orchestration
- Compatibility with tag-based workflows and CI pipelines
- Support for staging → production promotion workflows

## Considered Options

- Independent artifact tag-based deployments
- Branch-based environment deployment (dev/staging/prod branches)
- Release orchestration via external tooling (for example, Spinnaker, Argo CD)
- Custom release manifest with CI orchestration (chosen)

## Decision Outcome

Chosen option: **Custom release manifest with CI orchestration**.

Justification: This approach provides explicit, deterministic coordination of multiple artifacts while remaining lightweight and flexible. It avoids premature adoption of complex infrastructure while preserving a clear upgrade path to more advanced systems (for example, Kubernetes or GitOps).

### Consequences

- Good, because deployments are deterministic and reproducible
- Good, because interdependent artifacts can be deployed in a controlled order
- Good, because staging and production can use the same release definition (see [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) for promotion mechanics)
- Good, because the system remains simple and understandable
- Bad, because it requires custom CI orchestration logic
- Bad, because it introduces a new concept (release manifest) that must be maintained
- Bad, because enforcement relies on process discipline rather than platform guarantees

### Confirmation

- All staging and production deployments that participate in this model must originate from a release manifest under `.releases/` using the naming convention above
- CI pipelines must read artifact versions exclusively from the manifest for those deployments
- No deployment may rely on “latest” tags or implicit version resolution for coordinated releases
- CI must respect declared deployment ordering and phases
- Code review ensures manifest updates correctly reflect intended releases

## Release manifest specification

A release manifest defines the exact set of artifact versions that must be deployed together and the order in which they must be deployed.

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

deploy:
  - artifacts:
      - <artifact-name>
      - ...
  - artifacts:
      - <artifact-name>
      - ...
```

### Example

File: `.releases/2026.04.06.1.yml`

```yaml
release: 2026.04.06.1

artifacts:
  server: server-v5.1.0
  web: web-v2.3.0
  ios: ios-v1.8.0

deploy:
  - artifacts:
      - server
  - artifacts:
      - web
      - ios
```

### Rules

- Each manifest MUST live at `.releases/<release-id>.yml` at the repository root, with `<release-id>` equal to the `release` field (see **Repository layout and file naming** above).
- The `release` field MUST match the **logical release identifier** used with promotion tags: the `YYYY.MM.DD.N` portion shared across environments, as defined in [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md). Promotion tags add the `staging-` or `prod-` prefix to that identifier; the manifest `release` value does not include the environment prefix.
- All artifact values MUST reference immutable artifact tags ([ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md)).
- The `deploy` field MUST be present and define an ordered list of deployment phases.
- Each phase MUST contain one or more artifact names under `artifacts`.
- Phases MUST execute sequentially in the order defined.
- Artifacts within a single phase MAY be deployed in parallel.
- Every artifact in `artifacts` MUST appear in exactly one deployment phase.
- No artifact may appear in more than one phase.
- CI MUST deploy exactly the versions specified; no inference or “latest” resolution is allowed.
- The manifest MUST be committed to the repository and version-controlled.
- A release manifest commit represents the source of truth for a coordinated release.

### Relationship to database migrations

Production database migrations must run as a separate, coordinated deployment or release step ([ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md)). The manifest’s `deploy` ordering SHOULD place migration execution in an explicit phase (or an explicit sub-step within a phase) before dependent application artifacts roll out, so schema changes stay serialized and observable relative to traffic-serving deploys.

### Optional extensions (non-normative)

Future extensions MAY include:

- Health check requirements between phases
- Explicit wait conditions
- Rollback policies
- Environment-specific overrides

These are intentionally excluded from the initial design to maintain simplicity.

## Pros and cons of the options

### Independent artifact tag-based deployments

- Good, because simple to implement
- Good, because aligns with basic CI/CD patterns
- Neutral, because works well for independent services
- Bad, because cannot coordinate interdependent deployments
- Bad, because ordering and compatibility cannot be enforced
- Bad, because leads to nondeterministic system states

### Branch-based environment deployment

- Good, because familiar model (dev/staging/prod branches)
- Good, because supports freezing release candidates
- Neutral, because integrates with existing Git workflows
- Bad, because branches represent code state, not artifact versions
- Bad, because artifact builds and deployments become conflated
- Bad, because difficult to guarantee reproducibility across environments

### External orchestration tooling (Spinnaker, Argo CD)

- Good, because provides robust orchestration and promotion capabilities
- Good, because supports advanced deployment strategies (canary, rollback)
- Neutral, because aligns with industry-standard practices
- Bad, because introduces significant operational complexity
- Bad, because requires infrastructure investment (often Kubernetes)
- Bad, because overkill for current system scale

### Custom release manifest with CI orchestration

- Good, because explicitly defines coordinated artifact versions and deployment phases
- Good, because simple to implement with existing CI
- Good, because aligns with future GitOps/Kubernetes models
- Neutral, because requires some custom scripting
- Bad, because not enforced by platform constraints
- Bad, because requires discipline to avoid bypassing the system

## More Information

This model intentionally mirrors the core concept used by Kubernetes and GitOps systems, where a “desired state” defines the full system. The release manifest acts as a lightweight version of this concept.

This approach is expected to evolve naturally into more advanced orchestration systems if needed in the future.

**Versioning vs orchestration:** Changesets and semver remain the system of record for **artifact** version bumps and user-facing release intent ([ADR 0026](0026-use-changesets-for-application-releases.md)). The manifest pins **which immutable artifact tags** ship together for a coordinated rollout; it does not replace package versioning policy ([ADR 0028](0028-version-only-deployable-artifacts-by-default.md), [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) for library ecosystems).

## Related ADRs

- [ADR 0038](0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) — **current** coordinated release manifest policy (supersedes this ADR)
- [ADR 0037](0037-release-train-identifiers-and-github-releases.md) — canonical `YYYY.MM.DD.N` train identifier and GitHub Releases alignment
- [ADR 0020](0020-run-production-database-migrations-as-a-separate-deployment-step.md) — migrations as a distinct production step; ordering relative to traffic is owned by deploy tooling ([ADR 0038](0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md))
- [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) — lockstep groups for related packages in library monorepos
- [ADR 0026](0026-use-changesets-for-application-releases.md) — application versioning and release intent
- [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) — which packages are versioned as deployable artifacts
- [ADR 0031](0031-separation-of-artifact-tags-and-environment-promotion-tags.md) — artifact tags vs promotion tags; `release` identifier and promotion flow
