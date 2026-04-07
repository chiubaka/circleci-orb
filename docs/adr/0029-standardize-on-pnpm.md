---
status: accepted
date: 2026-04-05
decision-makers: Daniel Chiu
---

# Standardize on pnpm as the Package Manager for All Monorepos

## Context and Problem Statement

Chiubaka Technologies currently uses a mix of package managers across repositories, including `yarn` (historically chosen for monorepo support and React Native compatibility) and `npm` (used in other environments such as Snowday). This inconsistency introduces cognitive overhead, tooling fragmentation, and potential differences in dependency resolution behavior across projects.

The JavaScript ecosystem has evolved significantly in recent years, with improvements to `npm`, the emergence of `pnpm`, and shifts in community adoption away from `yarn` as the default choice. The organization needs to standardize on a single package manager that supports modern monorepo workflows, enforces strong dependency correctness, and minimizes long-term maintenance risk.

The core question is: **Which package manager should be adopted as the default for all new and existing Chiubaka Technologies monorepos?**

## Decision Drivers

* Consistency across all repositories and teams
* Strong guarantees around dependency correctness and isolation
* First-class support for large monorepos and multi-package ecosystems
* Performance (install speed, disk efficiency, CI efficiency)
* Low cognitive overhead and maintainability over time
* Compatibility with modern tooling (e.g., Turborepo, Vite, Next.js)
* Avoidance of ecosystem lock-in or brittle tooling assumptions

## Considered Options

* pnpm
* npm
* yarn (Classic and Berry)

## Decision Outcome
Chosen option: "pnpm".

Justification: `pnpm` provides the best balance of correctness, performance, and developer ergonomics for modern JavaScript monorepos. Its strict dependency model aligns with architectural goals around strong boundaries, and its workspace and performance characteristics make it well-suited for large-scale, multi-package systems.

### Consequences

* Good, because dependency boundaries are enforced strictly, reducing hidden coupling and improving long-term maintainability
* Good, because install performance and disk efficiency are significantly improved, especially in large monorepos and CI environments
* Good, because workspace tooling is simple, predictable, and well-aligned with modern build systems
* Bad, because stricter dependency resolution may surface issues in existing codebases (e.g., missing or incorrectly declared dependencies)
* Bad, because some ecosystem tools and documentation still assume `npm`, requiring occasional adaptation
* Neutral, because developers familiar with `npm` or `yarn` will need minor onboarding to `pnpm`

### Confirmation

This decision is considered successfully implemented when:

* All new repositories use `pnpm` as the default package manager
* Existing repositories are migrated to `pnpm` where practical
* Lockfiles (`pnpm-lock.yaml`) are consistently used and committed
* CI pipelines use `pnpm install` and related commands
* Code review enforces that no new repositories adopt `npm` or `yarn` without explicit justification

Periodic validation can be performed via:

* Repository audits for package manager usage
* CI configuration checks
* Tooling consistency reviews across projects

## Pros and Cons of the Options

### pnpm

A modern package manager that uses a content-addressable store and strict dependency resolution.

* Good, because it enforces explicit dependency declarations and prevents phantom dependencies
* Good, because it improves long-term maintainability by ensuring packages are self-contained and portable
* Good, because it provides excellent performance via shared storage and efficient installs
* Good, because it offers strong, simple workspace support for monorepos
* Neutral, because it retains a `node_modules` structure (unlike Yarn PnP), which trades some theoretical purity for compatibility
* Bad, because strictness can introduce short-term friction when migrating existing projects
* Bad, because some third-party tools may require minor adjustments due to assumptions about hoisting

### npm

The default package manager distributed with Node.js.

* Good, because it is universally available and requires no additional tooling
* Good, because it has improved significantly in recent years (workspaces, lockfile stability, performance)
* Good, because ecosystem compatibility is effectively guaranteed
* Neutral, because its feature set is sufficient for many simple projects
* Bad, because workspace ergonomics are less mature compared to `pnpm`
* Bad, because it allows implicit dependency access via hoisting, which can lead to hidden coupling
* Bad, because it lacks the same level of performance and disk efficiency as `pnpm` in large monorepos

### yarn (Classic and Berry)

Historically popular package manager with two major versions.

***Yarn Classic (v1):***

* Good, because it introduced early improvements over npm (workspaces, performance)
* Neutral, because it remains functional for legacy projects
* Bad, because it is effectively in maintenance mode and no longer evolving meaningfully
* Bad, because it lacks the correctness guarantees and performance of newer tools like `pnpm`

***Yarn Berry (v2+):***

* Good, because it introduces advanced features like Plug'n'Play (PnP) and zero-install workflows
* Good, because it enforces stricter dependency resolution than npm
* Neutral, because it offers a highly configurable and extensible architecture
* Bad, because it introduces significant complexity and cognitive overhead
* Bad, because PnP can cause compatibility issues with tools that assume a `node_modules` structure
* Bad, because debugging and onboarding are more difficult compared to simpler alternatives

## More Information

* This ADR extends and reinforces [ADR 0022](docs/adr/0022-standardize-monorepos-to-pnpm-turbo.md), which already mandates pnpm workspaces alongside Turborepo for monorepo orchestration. By aligning the package manager itself, we reduce fragmentation and simplify tooling guidance across the organization.
* This decision should be revisited if a significant shift occurs in the JavaScript package manager landscape, tooling compatibility issues with `pnpm` become widespread, or new requirements (e.g., specific platform constraints) necessitate reevaluating trade-offs.
* Migration strategy (to be documented separately):
  * Incrementally migrate existing repositories
  * Fix dependency declaration issues surfaced by `pnpm`
  * Standardize CI and local development workflows
