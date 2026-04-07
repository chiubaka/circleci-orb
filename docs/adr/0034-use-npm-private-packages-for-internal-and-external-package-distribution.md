---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
consulted: -
informed: -
---

# ADR 0034: Use npm private packages for internal and external package distribution

## Context and Problem Statement

Chiubaka Technologies requires a private package registry solution to support distribution of internal packages across multiple projects, as well as controlled sharing with external partners or client organizations. The solution must be cost-effective, easy to operate, and provide sufficient access control to grant and revoke access to packages as needed.

The key question is: **what package registry solution best balances simplicity, cost, and access control without introducing unnecessary infrastructure or vendor lock-in?**

## Relationship to existing org ADRs

- **Package manager:** [ADR 0029](0029-standardize-on-pnpm.md) standardizes **pnpm** for installs and workspaces; pnpm uses the **npm registry protocol** by default. This ADR chooses **where** private packages are hosted (npmjs.com private scopes), not which local CLI installs them.
- **Publishing and versioning:** Library and application release workflows in [ADR 0024](0024-use-changesets-for-library-monorepos.md), [ADR 0026](0026-use-changesets-for-application-releases.md), and related changesets ADRs remain in force; private registry credentials apply at **publish** and **CI** boundaries.
- **Naming and scopes:** [ADR 0032](0032-monorepo-package-taxonomy-naming-and-domain-contracts.md) defines taxonomy and illustrative `@<scope>/…` names; private packages on npm are published under an **organization scope** consistent with that convention (for example `@chiubaka/*`).

## Decision Drivers

- Low cost (preferably negligible ongoing cost)
- Minimal operational overhead (no infrastructure to maintain)
- No lock-in to a specific cloud provider
- Sufficient access control for granting and revoking access
- Native compatibility with the Node.js / TypeScript ecosystem
- Simple and predictable publishing and consumption workflows
- Acceptable onboarding friction for external consumers

## Considered Options

- npm private packages
- GitHub Packages (npm registry)
- Self-hosted Verdaccio
- Third-party hosted registries (e.g. Cloudsmith, JFrog Artifactory)

## Decision Outcome

Chosen option: **npm private packages**.

Justification: npm provides the simplest and most native experience for publishing and consuming private packages in the Node.js ecosystem, with minimal cost and no operational overhead. Its team-based access control model is sufficient for current needs, including the ability to grant and revoke access at the package level. More advanced distribution or access control requirements can be revisited in the future if needed.

### Consequences

- Good, because publishing and consuming packages follows the standard npm workflow with minimal additional configuration
- Good, because there is no infrastructure to operate or maintain
- Good, because the solution is inexpensive and scales with usage
- Good, because access can be revoked cleanly via teams or token invalidation
- Bad, because access control is team-based and may not map perfectly to external client use cases
- Bad, because external consumers must have npm accounts and manage npm authentication
- Bad, because npm is limited to JavaScript/TypeScript ecosystems and does not generalize to other artifact types

### Confirmation

- Private packages are published under an organization scope (for example `@chiubaka/*`)
- Access is managed via npm teams and validated by granting or revoking access to specific packages
- External consumers can install packages using scoped `.npmrc` configuration
- Revocation is validated by removing team membership or invalidating tokens and confirming access is denied
- CI/CD pipelines publish and consume private packages without manual intervention

## Pros and Cons of the Options

### npm private packages

- Good, because it is the native registry for Node.js and requires no ecosystem adaptation
- Good, because publishing and installation workflows are simple and well understood
- Good, because it has minimal cost and no infrastructure overhead
- Good, because it supports package-level access control via teams
- Neutral, because external access requires npm accounts and token management
- Bad, because access control is not designed specifically for external client distribution scenarios
- Bad, because it is limited to npm-compatible ecosystems

### GitHub Packages (npm registry)

- Good, because it integrates tightly with GitHub repositories and GitHub Actions
- Good, because it supports granular package-level permissions
- Good, because many external collaborators already have GitHub accounts
- Neutral, because publishing requires additional registry configuration compared to npm
- Bad, because it introduces coupling between package distribution and GitHub as a platform
- Bad, because consumer setup is slightly more complex due to custom registry configuration

### Self-hosted Verdaccio

- Good, because it provides full control and no vendor dependency
- Good, because it can be very low cost to operate
- Neutral, because it supports flexible authentication and authorization models
- Bad, because it introduces operational overhead (hosting, uptime, backups, security)
- Bad, because access control and external distribution workflows must be implemented and maintained manually
- Bad, because it increases system complexity for relatively little benefit at current scale

### Third-party hosted registries (e.g. Cloudsmith, JFrog Artifactory)

- Good, because they provide robust access control, audit logs, and external distribution capabilities
- Good, because they support multiple artifact types beyond npm
- Neutral, because they offer a more complete long-term solution for complex distribution needs
- Bad, because they introduce significant cost relative to current needs
- Bad, because they add vendor dependency without immediate necessity
- Bad, because they solve problems that are not yet present at the current stage of the ecosystem

## More Information

This decision is intentionally optimized for the current stage of the ecosystem, where simplicity and cost are prioritized over advanced distribution capabilities.

If future requirements include:

- fine-grained external client access control
- audit logging and compliance
- multi-ecosystem artifact support

then this decision should be revisited, with Cloudsmith or similar platforms as likely candidates.

This ADR aligns with a general principle of deferring complexity and cost until justified by concrete requirements.
