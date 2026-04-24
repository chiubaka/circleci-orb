---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Use ecosystem-level lockstep versioning for library-oriented monorepos

## Context and Problem Statement

Library-oriented monorepos host numerous packages that naturally cluster into ecosystems, where multiple packages evolve in tandem and are typically consumed together. These ecosystems span domains such as auth, payments, core, and integrations. Hyperdrive is one illustrative example of such a monorepo, where Solari and Protectiva each represent ecosystem-level groupings with tightly coupled packages.

We need a versioning model that answers:

> Should packages be versioned together, completely independently, or within grouped ecosystems?

## Decision Drivers

- Preserve compatibility guarantees within closely related packages
- Avoid version churn for unrelated ecosystems
- Scale gracefully as package count grows
- Keep the versioning mental model understandable for consumers
- Prevent brittle or overly complex policies that are hard to maintain

## Considered Options

- Full monorepo lockstep versioning
- Fully independent versioning
- Ecosystem-level lockstep versioning (release groups)

## Decision Outcome

Chosen option: "Ecosystem-level lockstep versioning (release groups)".

Justification: Global lockstep is too rigid for large monorepos with multiple ecosystems, and fully independent versioning makes coordination and compatibility harder to reason about. Grouping tightly coupled packages into release-bound ecosystems balances cohesion, clarity, and scalability.

In practice, this means that each ecosystem has its own release cadence and version number—for example, Solari packages may move together, Protectiva packages may move together, but Solari and Protectiva can evolve independently. Hyperdrive serves as an example of how this policy is applied, but the decision is meant for any library-oriented monorepo that contains multiple release ecosystems.

## Pros and Cons of the Options

### Full monorepo lockstep versioning

All packages share a single version.

- Good, because it provides a very simple mental model.
- Good, because it guarantees compatibility across every package.
- Bad, because unrelated packages are forced to release together.
- Bad, because changelogs become noisy and less meaningful.
- Bad, because frequent releases can become operationally heavy.

👉 Rejected because library monorepos normally include loosely coupled ecosystems that do not benefit from global lockstep.

---

### Fully independent versioning

Each package versions on its own schedule.

- Good, because it maximizes flexibility.
- Good, because unrelated packages do not depend on each other’s releases.
- Bad, because breaking changes ripple unpredictably across ecosystems.
- Bad, because consumers must track many version boundaries.
- Bad, because dependency coordination becomes increasingly complex.

👉 Rejected because the ecosystems we care about (e.g., Solari, Protectiva) release together and need stability guarantees within each group.

---

### Ecosystem-level lockstep versioning

Packages are grouped into release cohorts that move together.

- Good, because it preserves cohesion within ecosystems.
- Good, because unrelated ecosystems remain independent.
- Good, because it scales as the monorepo grows.
- Bad, because getting the grouping right requires upfront discipline.
- Bad, because reshuffling ecosystems over time requires migration work.

👉 Chosen because it balances simplicity with the flexibility needed across multiple ecosystems.

## Consequences

- Ecosystem boundaries become an explicit architectural concern.
- Versioning policy reinforces domain-driven package organization.
- Refactors may need to revisit ecosystem groupings and migration plans.
- Consumers gain clearer compatibility guarantees per ecosystem.

## Related ADRs

- [ADR 0024](0024-use-changesets-for-library-monorepos.md) – captures release intent explicitly within these grouped ecosystems.
- [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) – explains how release tooling stays unified across libraries and applications.
