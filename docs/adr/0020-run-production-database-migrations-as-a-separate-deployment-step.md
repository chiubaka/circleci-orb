---
status: accepted
date: 2026-03-31
decision-makers: Daniel Chiu
---

# ADR 0020: Run production database migrations as a separate deployment step

## Context and Problem Statement

Applications that use schema migrations need a reliable way to apply them in production. It is tempting to run migrations automatically during application startup or artifact creation because that appears to remove a deployment concern.

That convenience creates operational ambiguity. Builds, migration execution, and traffic-serving startup have different safety and coordination requirements, especially in multi-instance deployments and environments that require rollback discipline.

## Decision Drivers

* Keep schema changes coordinated and observable in production
* Preserve clear separation between artifact creation, release orchestration, and application serving
* Avoid race conditions and lock contention during rolling or parallel deployments
* Maintain least-privilege database access for long-running application processes
* Keep rollback and phased schema-change strategies operationally feasible

## Considered Options

* Run migrations automatically during application startup in production
* Run migrations during artifact or container image build
* Run migrations as a separate, coordinated deployment or release step in production

## Decision Outcome

Chosen option: "Run migrations as a separate, coordinated deployment or release step in production".

Justification: production migrations are operational changes to shared state and should run in one controlled place with explicit sequencing, visibility, and failure handling. Keeping them separate from both application startup and artifact creation preserves reproducibility, security boundaries, and deploy safety.

### Consequences

* Good, because migration execution has one intentional coordination point in the deployment workflow
* Good, because application startup stays focused on serving traffic rather than mutating shared schema state
* Good, because artifact builds remain reproducible and do not depend on live database access
* Good, because runtime application credentials can avoid schema-changing privileges
* Good, because local developer workflows can still choose a different convenience-oriented bootstrap path without weakening the production rule
* Bad, because deployment workflows must explicitly include and enforce a migration phase
* Bad, because teams must design deployment serialization intentionally rather than assuming it

### Confirmation

* Production deployment reviews should verify that migrations run in a dedicated deploy or release step, not in the normal application startup path
* Build and image-creation workflows should not require live production database connectivity to succeed
* Runtime application processes should not depend on migration execution to become healthy in production
* Local development workflows may intentionally run migrations during setup, but production-oriented scripts and documentation should preserve this separation

## Pros and Cons of the Options

### Run migrations automatically during application startup in production

* Good, because it can reduce the chance of forgetting a migration step
* Good, because it can simplify local development workflows when only one process is starting
* Neutral, because some migration tools can coordinate concurrent runners with advisory locks or equivalent mechanisms
* Bad, because multiple application instances may attempt migrations during the same rollout
* Bad, because startup time becomes less predictable and may block health checks or scaling
* Bad, because a failed migration is coupled directly to application availability
* Bad, because runtime processes need broader database permissions than they otherwise would
* Bad, because destructive or phased migrations become harder to sequence safely across application versions

### Run migrations during artifact or container image build

* Good, because it can appear to centralize responsibility in one automated workflow
* Neutral, because build systems already run in CI and may seem like a convenient place for additional automation
* Bad, because artifact creation should be reproducible and must not depend on live mutable production state
* Bad, because an image may be built multiple times, built long before deployment, or never deployed at all
* Bad, because promoting the same artifact across environments becomes unsafe when migration execution is tied to build time
* Bad, because build workers need database credentials and network access that do not belong at the artifact boundary

### Run migrations as a separate, coordinated deployment or release step in production

* Good, because deploy orchestration is the natural place to mutate shared production infrastructure state
* Good, because migration success or failure is visible as a distinct release event
* Good, because it supports serialized execution and explicit ordering before, during, or after traffic shifts as needed
* Good, because it aligns with least-privilege separation between deploy credentials and runtime credentials
* Neutral, because exact implementation can vary across platforms so long as execution stays coordinated and explicit
* Bad, because teams must maintain deployment automation rather than relying on application self-management

## More Information

This ADR is specifically about production expectations. Local development may deliberately optimize for one-command setup. In particular, a root development bootstrap such as `pnpm dev` may bring up local infrastructure and apply migrations before starting watch processes so developers do not have to run a separate migration command by hand.

That local convenience does not change the production rule: migrations in production still belong in an explicit, coordinated deploy or release step rather than application startup or artifact creation.
