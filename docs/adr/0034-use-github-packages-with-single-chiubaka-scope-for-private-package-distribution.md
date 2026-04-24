---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
---

# ADR 0034: Use GitHub Packages with a single scope (`@chiubaka/*`) for private package distribution

## Revision and conflict with an earlier same-day decision (recorded here)

On **2026-04-07**, this ADR was first drafted to choose **npm private packages** (npmjs.com organization scopes) for the simplest native publishing and consumption story. That choice assumed **low ongoing cost** and **acceptable scope strategy** for multiple product or ecosystem namespaces.

Further analysis the same day showed a material constraint: **npm’s pricing model** makes **multiple organization-scoped namespaces** for private packages expensive in practice—each scope aligned with a product or ecosystem (for example distinct `@solarijs/*`, `@protectiva/*` namespaces) effectively pushes toward **multiple paid npm organizations** for private publishing, which does not scale affordably with a multi-ecosystem architecture.

Rather than add a new ADR number to supersede a decision made hours earlier, **this ADR is updated in place**. The **superseded outcome** was: _npm private packages_. The **current outcome** is: **GitHub Packages** with **one** npm registry scope under **`@chiubaka/*`**. The sections below reflect the **final** decision and rationale; the conflict above is the historical record of why the registry choice changed the same day.

## Context and Problem Statement

Chiubaka Technologies requires a private package registry solution to distribute internal packages across projects and selectively share packages with external clients and partners.

The solution must:

- be low-cost or effectively free at small scale
- avoid infrastructure and operational overhead
- support revocation of access
- integrate with existing tooling (GitHub, CircleCI)

Initial evaluation favored npm private packages due to simplicity. The pricing conflict above led to reevaluating **GitHub Packages** as the hosting layer while **collapsing published package identity** under **`@chiubaka/*`**, with ecosystem encoded in **package name** rather than **scope** (see [ADR 0036](0036-standardize-package-naming-under-chiubaka-scope-with-ecosystem-prefixes.md)).

### Billing and scope constraint (GitHub Pro)

**GitHub Packages** usage that counts against the included allowances for this setup is tied to the **maintainer GitHub account** on a **GitHub Pro** subscription. That subscription **includes** GitHub Packages storage and data transfer within published quotas, which—at current scale—makes private hosting **effectively free** compared with paying for multiple npm orgs or a separate registry vendor.

On GitHub’s npm registry, the **scope** for packages owned by a **user** account matches that **username**. Here, **all** private packages **must** be published under **`@chiubaka/*`** so they land under that **user scope** and consume the **Pro-included** Packages entitlement. Publishing under other owners (for example separate GitHub organizations) would **not** satisfy this “single subscription, single user scope” constraint without additional billing or account structure. That is an additional reason—alongside operational simplicity—for **one** collapsed scope rather than multiple GitHub org–aligned scopes.

## Relationship to existing org ADRs

- **Package manager:** [ADR 0029](0029-standardize-on-pnpm.md) standardizes **pnpm** for installs and workspaces; pnpm uses the **npm registry protocol**. This ADR chooses **which registry hosts** private packages (`https://npm.pkg.github.com` for the `@chiubaka` scope), not which local CLI installs them.
- **Publishing and versioning:** [ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0026](0026-use-changesets-for-application-releases.md), and related changesets ADRs remain in force; registry credentials apply at **publish** and **CI** boundaries.
- **Naming:** [ADR 0032](0032-monorepo-package-taxonomy-naming-and-domain-contracts.md) defines **taxonomy and roles** (`domain`, `contracts`, `plugin-*`, etc.). [ADR 0036](0036-standardize-package-naming-under-chiubaka-scope-with-ecosystem-prefixes.md) defines how **published** names map into **`@chiubaka/<ecosystem>-…`** under this single-scope registry model.

## Decision Drivers

- Low or negligible cost at current scale (including use of **GitHub Pro–included** GitHub Packages quotas under the **`@chiubaka`** user scope)
- Avoid per-namespace / per-org pricing that blocks multiple ecosystems
- No self-hosted infrastructure
- Ability to revoke access for external consumers
- Compatibility with GitHub-centric workflows
- Acceptable operational complexity
- Flexibility to evolve into a more advanced distribution model later

## Considered Options

- npm private packages (multi-org scopes)
- npm private packages (single collapsed scope)
- GitHub Packages (multi-org scopes)
- GitHub Packages (single collapsed scope under `@chiubaka/*`)
- Self-hosted Verdaccio
- Third-party registries (e.g. Cloudsmith, JFrog Artifactory)

## Decision Outcome

Chosen option: **GitHub Packages (single collapsed scope under `@chiubaka/*`)**.

**Justification:** GitHub Packages avoids npm’s per-organization pricing model for multiple private scopes. For this org, **GitHub Pro** already includes **GitHub Packages** usage within account quotas; publishing everything under **`@chiubaka/*`** (the **user** scope for that account) keeps private packages on that **included** entitlement. Collapsing all private packages under that single scope also avoids the operational complexity of managing multiple GitHub owners and fragmented permissions. Publishing and installation use the standard npm protocol with **explicit** `.npmrc` configuration for the scope and registry URL.

### Consequences

- Good, because private package hosting is effectively free under the **GitHub Pro–included** GitHub Packages allowances while usage stays on the **`@chiubaka`** user scope
- Good, because no infrastructure or registry hosting is required
- Good, because access can be revoked via GitHub users/teams and token invalidation
- Good, because a single scope significantly simplifies consumer configuration and CI setup
- Bad, because package permissions are identity-based (users/teams), not token-scoped
- Bad, because there is no native grouping of packages (permissions must be assigned per package)
- Bad, because per-package permission management scales poorly as number of packages × clients increases
- Bad, because GitHub Packages requires explicit `.npmrc` configuration for each scope
- Bad, because publishing and installation workflows are slightly more complex than “default registry only” npm
- Bad, because the system does not model “client entitlements” cleanly (no first-class concept)

### Confirmation

- All private packages are published under `@chiubaka/*`
- GitHub Packages is used as the npm registry (`https://npm.pkg.github.com`)
- Package permissions are configured with **granular access (no repository inheritance)** where that model applies
- Access is granted via GitHub teams and validated by successful install
- Access revocation is validated by removing users/teams and confirming install failure
- CI pipelines (CircleCI) successfully publish and install using PAT-based authentication

## Pros and Cons of the Options

### npm private packages (multi-org scopes)

- Good, because publishing and consumption are native to npm
- Good, because access control is relatively straightforward
- Bad, because each organization scope requires a paid npm org for private packages
- Bad, because costs scale with number of ecosystems/scopes
- Bad, because this model conflicts with multi-ecosystem architecture at acceptable cost

### npm private packages (single collapsed scope)

- Good, because it minimizes cost (single paid org)
- Good, because it preserves simple npm workflows
- Neutral, because it requires abandoning multi-scope branding
- Bad, because it still requires npm org subscription
- Bad, because it provides no advantage over GitHub Packages given existing GitHub usage

### GitHub Packages (multi-org scopes)

- Good, because it avoids per-scope npm pricing
- Good, because it allows clean ecosystem-aligned scopes
- Neutral, because it integrates with GitHub permissions
- Bad, because it introduces significant operational complexity (multiple orgs, tokens, configs)
- Bad, because quotas are fragmented across orgs
- Bad, because CI and consumer configuration becomes more complex
- Bad, for **this** setup, because packages must stay under the **`@chiubaka`** user scope to use **Pro-included** Packages usage; fanning packages across separate GitHub orgs does not match that constraint without a different billing posture

### GitHub Packages (single collapsed scope) — chosen

- Good, because it minimizes operational complexity
- Good, because it keeps permissions centralized
- Good, because it simplifies `.npmrc` and CI configuration
- Good, because it avoids npm multi-scope private pricing constraints
- Bad, because it sacrifices ecosystem-based namespace purity at the **scope** level
- Bad, because package grouping must be encoded in naming conventions (see [ADR 0036](0036-standardize-package-naming-under-chiubaka-scope-with-ecosystem-prefixes.md))

### Self-hosted Verdaccio

- Good, because it avoids vendor lock-in
- Good, because it is low cost
- Bad, because it introduces operational burden (hosting, uptime, security)
- Bad, because external access and permissions must be manually managed
- Bad, because it increases system complexity without strong justification

### Third-party registries (e.g. Cloudsmith, JFrog Artifactory)

- Good, because they provide strong access control and distribution models
- Good, because they support multi-ecosystem artifacts
- Bad, because they introduce significant cost relative to current needs
- Bad, because they solve problems not yet encountered
- Bad, because they introduce unnecessary vendor dependency at this stage

## More Information

GitHub Packages is treated as a **pragmatic, cost-efficient intermediate solution**, not a final long-term distribution platform.

Known limitations:

- No entitlement-based access model
- No package grouping abstraction
- Permissions scale linearly with packages and consumers

This decision should be revisited if:

- the number of external clients increases significantly
- per-package permission management becomes burdensome
- audit/compliance requirements emerge
- non-JavaScript ecosystems need to be supported

At that point, migration to a dedicated artifact platform (e.g. Cloudsmith) may be warranted.

The earlier “optimize for simplicity” motivation of the first same-day draft remains valid; the **registry host** changed once **cost and multi-ecosystem scope strategy** were fully weighed.
