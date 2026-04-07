---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Versioning policy for ecosystem plugins vs core packages

## Context and Problem Statement

Library-oriented monorepos typically split into:

- **Core ecosystem packages**, which define public APIs, contracts, shared domain models, and the compatibility surface that other packages depend on.
- **Plugin or adapter packages**, which integrate the ecosystem with specific infrastructure, frameworks, or third-party services.

Examples range from a payments ecosystem that exposes port definitions to adapters for Stripe or PayPal, to integrations that target different frameworks such as Next.js or Astro.

We already apply the ecosystem grouping policy described in [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md), and we capture release intent explicitly via [ADR 0024](0024-use-changesets-for-library-monorepos.md). Within that broader context, we still need to answer:

> Should optional plugins move in lockstep with their ecosystem, or can they version independently?

This affects release cadence, compatibility messaging, developer expectations, and long-term maintainability for any library-oriented monorepo, not just a single project.

## Decision Drivers

* Keep the compatibility guarantees consumers expect for core ecosystems
* Avoid unnecessary version churn driven by optional integrations
* Let adapters evolve independently when their dependencies or feature priorities diverge
* Keep the versioning model understandable even as the number of plugins grows
* Prevent third-party dependency volatility from forcing unrelated ecosystem releases
* Scale a monorepo without adding rigid coupling between optional integrations and the core surface

## Considered Options

* Version all packages (core + plugins) in ecosystem lockstep
* Version every package fully independently
* Hybrid model: core packages follow lockstep cohorts; plugins default to independent versioning

## Decision Outcome

Chosen option: **Hybrid model (core lockstep, plugins independent by default)**.

Justification: The core packages define the ecosystem’s compatibility surface and benefit from synchronized version bumps, while most plugins are optional adapters whose lifecycle and third-party dependencies make independent releases more natural. This keeps the strongly coupled components aligned (per ADR 0023) while giving the adapters room to move at their own pace.

## Policy

### Core rule

A package remains in lockstep with an ecosystem **only if it is part of the ecosystem’s core compatibility surface**.

A package uses **independent versioning** when it is an optional adapter or plugin that can be swapped or upgraded without requiring a coordinated ecosystem release.

### Default classification

#### Lockstep (core ecosystem packages)

Packages that:

* define ports, contracts, shared domain models, or primitives that other packages consume
* are part of the primary public API surface
* are expected to be consumed together
* contribute directly to the canonical ecosystem experience

Examples:

* API contract packages
* shared domain models
* port/interface definitions

#### Independent (plugin / adapter packages)

Packages that:

* implement ports using specific infrastructure or third-party libraries
* are optional and swappable without breaking the ecosystem
* may require releases due to external ecosystem changes (e.g. Stripe, Postgres, Next.js)
* have lifecycles that diverge from the core ecosystem’s cadence

Examples:

* `@example/plugin-postgres`
* `@example/plugin-stripe`
* `@example/plugin-nextjs`
* `@example/plugin-s3`

### Exception rule

A plugin may be included in lockstep versioning if it becomes part of the canonical supported platform surface, such as when:

* most users expect the plugin by default
* documentation and examples assume its presence
* it is effectively treated as part of the core platform experience

### Practical Tests

1. **Consumer expectation** – Would users expect this package version to match the ecosystem version?
   * Yes → Lockstep
   * No → Independent
2. **External dependency pressure** – Does the package need releases because of third-party changes?
   * Yes → Independent
   * No → Lockstep
3. **Release independence** – Would an independent release feel natural and expected?
   * Yes → Independent
   * No → Lockstep
4. **Role in the ecosystem** – Is the package part of the core platform surface or a swappable implementation?
   * Core surface → Lockstep
   * Swappable implementation → Independent
5. **Compatibility guarantees** – Does lockstepping imply a stronger guarantee than intended?
   * Yes → Independent
   * No → Lockstep

## Pros and Cons of the Options

### Lockstep all plugins

* Good: Simplifies the versioning model.
* Good: Guarantees compatibility alignment across all packages.
* Bad: Forces every plugin to bump whenever the ecosystem releases.
* Bad: Third-party churn now impacts core ecosystem releases.
* Bad: Implies stronger guarantees than the adapters typically provide.

👉 Rejected because plugins tend to have independent lifecycles and should not drag unrelated ecosystems along.

### Independent all packages (core + plugins)

* Good: Maximizes flexibility and decouples adapters completely.
* Good: Freely avoids unnecessary coupling between ecosystems.
* Bad: Fragments the consumer compatibility story.
* Bad: Increases coordination overhead across ecosystems.
* Bad: Weakens guarantees that core packages aim to provide.

👉 Rejected because the core ecosystem surface needs strong cohesion (per ADR 0023).

### Hybrid model (chosen)

* Good: Preserves compatibility guarantees for the core ecosystem.
* Good: Lets plugins evolve at their own cadence when appropriate.
* Good: Scales with the growing number of integrations.
* Good: Matches real-world usage; plugins are optional.
* Bad: Requires classification decisions for each package.
* Bad: Introduces conceptual complexity compared to global lockstep.

👉 Chosen because it balances correctness for core packages with flexibility for optional integrations.

## Consequences

* Core ecosystems keep strong, predictable version alignment.
* Plugins evolve independently without forcing new ecosystem releases.
* Plugin compatibility must be documented explicitly (peer dependencies, docs, etc.).
* Introducing new packages requires deliberate classification against the tests above.
* Release tooling (e.g. ADR 0024’s Changesets) must capture independent plugin releases alongside grouped ecosystems.

## Confirmation

* New packages are classified using the defined tests.
* Changesets configuration reflects ecosystem grouping and independent releases.
* Plugin packages default to independent versioning unless explicitly grouped.
* Documentation clearly communicates compatibility expectations for each package.

## More Information

* **Core packages define the ecosystem’s compatibility surface.**
* **Plugins extend the ecosystem with optional integrations.**
* **Application release policy** – See [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) for how deployable-only versioning keeps application workflows separate from library plugin classification.

Maintaining this distinction keeps versioning semantics aligned with the architecture.

## Related ADRs

- See [ADR 0023](0023-lockstep-versioning-for-related-package-groups.md) for ecosystem-level lockstep versioning.
- See [ADR 0024](0024-use-changesets-for-library-monorepos.md) for the release tooling that codifies intents across core and plugin packages.
- See [ADR 0027](0027-use-single-changesets-workflow-in-hybrid-monorepos.md) for the unified workflow that keeps library and application releases aligned.
- See [ADR 0028](0028-version-only-deployable-artifacts-by-default.md) for the application monorepo versioning default that identifies which artifacts participate in Changesets.
