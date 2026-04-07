---
status: accepted
date: 2026-04-04
decision-makers: Daniel Chiu
---

# Standardize Monorepos on pnpm + Turborepo (Turbo) Instead of Nx

## Context and Problem Statement

Chiubaka Technologies and Hyperdrive require a standardized approach to managing monorepos across projects. Historically, Nx was adopted due to its strong feature set, including affected package execution, integrated tooling, and scaffolding/generation capabilities.

Over time, Nx introduced significant maintenance overhead, particularly around plugin ecosystems, version coupling, and upgrades. Custom Nx plugins and generators became difficult to maintain, and application-level upgrades were frequently entangled with Nx ecosystem upgrades.

At the same time, the emergence of agentic coding has reduced the need for rigid, ecosystem-wide scaffolding and generation systems. Tools like Turborepo (Turbo) offer a significantly simpler, more focused approach centered on task orchestration and caching.

The key question is:

What monorepo paradigm best supports long-term maintainability, flexibility, and low operational overhead for Chiubaka and Hyperdrive?

## Decision Drivers

* Minimize long-term maintenance burden and upgrade complexity
* Avoid tight coupling between monorepo tooling and application dependencies
* Preserve flexibility to choose and evolve tools independently
* Support efficient CI and local workflows (including affected execution)
* Maintain debuggability and transparency of task execution
* Reduce reliance on complex internal platform tooling (e.g., generators)
* Align with agentic coding workflows that reduce need for rigid scaffolding
* Favor composability over monolithic platform solutions
* Avoid repeating prior negative experiences with ecosystem lock-in

## Considered Options

* Nx (full adoption as monorepo platform)
* Nx (restricted usage as lightweight task runner)
* pnpm workspaces + Turborepo (Turbo)
* pnpm workspaces alone (no orchestrator)
* Rush
* moon
* Bazel / build-system-first approaches

## Decision Outcome

Chosen option: "pnpm workspaces + Turborepo (Turbo)".

Justification: This approach provides the best balance of simplicity, flexibility, and long-term maintainability. It minimizes coupling and platform overhead while still delivering essential monorepo capabilities such as task orchestration, caching, and affected execution. It aligns strongly with organizational priorities and lessons learned from prior Nx usage.

### Consequences

* Good, because monorepo tooling remains lightweight and easier to upgrade
* Good, because application dependencies are decoupled from monorepo infrastructure
* Good, because tools (linting, testing, build, release) can evolve independently
* Good, because Turbo provides sufficient affected execution and caching for CI efficiency
* Good, because agentic workflows reduce the need for rigid scaffolding systems
* Good, because debugging and reasoning about task execution is simpler
* Good, because avoids reintroducing a complex internal platform to maintain

* Bad, because loss of built-in Nx features such as generators, migrations, and integrated release tooling
* Bad, because requires assembling a modular toolchain (generation, release, standards) separately
* Bad, because less “out-of-the-box” structure compared to Nx
* Bad, because some advanced features (e.g., deeply integrated affected analysis) may be less mature than Nx

### Confirmation

This decision is validated through:

* Successful use of Turbo in Snowday with positive developer experience
* Demonstrated ability to run affected tasks in CI and locally using Turbo
* Absence of monorepo-tool-related blockers during dependency upgrades
* Ability to introduce or modify tooling without modifying the monorepo orchestrator
* Developer feedback indicating improved clarity and reduced friction

Compliance checks:

* New monorepos must use pnpm workspaces
* Turbo must be used for task orchestration and caching
* No reliance on Nx or equivalent platform-level tooling unless explicitly justified
* Tooling (lint, test, build) must remain defined in package scripts and independent configs

## Pros and Cons of the Options

### Nx (full adoption as monorepo platform)

* Good, because provides comprehensive monorepo platform (task orchestration, generators, release tooling)
* Good, because mature affected execution and project graph capabilities
* Good, because strong ecosystem and plugin support

* Neutral, because requires adopting Nx-specific concepts and conventions

* Bad, because tightly couples monorepo tooling with application dependencies
* Bad, because upgrades frequently require coordinated ecosystem migrations
* Bad, because custom plugins and generators are costly to maintain
* Bad, because introduces significant platform complexity and cognitive overhead
* Bad, because prior experience demonstrated high maintenance burden

### Nx (restricted usage as lightweight task runner)

* Good, because retains access to Nx affected execution and graph capabilities
* Good, because avoids some deeper platform features

* Neutral, because technically feasible to use Nx in a limited capacity

* Bad, because still inherits Nx versioning, migration, and conceptual overhead
* Bad, because creates ambiguity in how Nx should or should not be used
* Bad, because does not fully eliminate platform coupling risk
* Bad, because partially solving the problem still leaves long-term complexity

### pnpm workspaces + Turborepo (Turbo)

* Good, because clearly separates concerns: pnpm handles workspace, Turbo handles orchestration
* Good, because minimal coupling to application tooling and dependencies
* Good, because simple mental model (tasks + dependency graph + caching)
* Good, because sufficient affected execution support
* Good, because aligns with composable tooling philosophy
* Good, because easier upgrades with smaller blast radius
* Good, because works well with agentic coding workflows

* Neutral, because requires assembling additional tooling (generation, release) separately

* Bad, because lacks built-in generators and platform features
* Bad, because requires discipline to maintain consistency across repos
* Bad, because fewer guardrails compared to Nx

### pnpm workspaces alone (no orchestrator)

* Good, because extremely simple and minimal
* Good, because zero additional tooling layer

* Neutral, because pnpm supports filtering and recursive execution

* Bad, because lacks caching and advanced task orchestration
* Bad, because weaker CI performance at scale
* Bad, because missing features that Turbo provides with minimal overhead

### Rush

* Good, because strong governance and incremental build system
* Good, because mature tooling for large-scale monorepos

* Neutral, because well-suited for enterprise-scale JS repos

* Bad, because heavier operational complexity
* Bad, because less aligned with desire for simplicity and flexibility
* Bad, because introduces its own ecosystem and conventions

### moon

* Good, because offers structured task running with affected execution
* Good, because sits between Turbo and Nx in capability

* Neutral, because evolving tool with growing ecosystem

* Bad, because trends toward owning more repository structure and behavior
* Bad, because risks reintroducing platform-like complexity
* Bad, because unclear long-term advantage over Turbo for this use case

### Bazel / build-system-first approaches

* Good, because extremely powerful, reproducible, and scalable
* Good, because language-agnostic and highly deterministic

* Neutral, because best suited for very large or polyglot systems

* Bad, because extremely high complexity and steep learning curve
* Bad, because far exceeds needs of current organization
* Bad, because introduces significant operational overhead

## More Information

### Key Insight: Platform vs Composability

This decision is fundamentally about choosing between:

* A platform-style monorepo tool (Nx)
* A composable toolchain (pnpm + Turbo + independent tools)

Chiubaka is explicitly choosing composability to minimize long-term risk and maintenance burden.

### Impact of Agentic Coding

Previously, Nx’s generators and scaffolding were a major advantage. With modern agentic workflows:

* Generators are less critical
* Standardization can be achieved via prompts, skills, and templates
* Maintaining generator infrastructure is no longer worth the cost

This significantly reduces Nx’s relative value.

### Lessons Learned from Nx

* Tight integration increases upgrade complexity
* Plugin ecosystems create hidden coupling
* Custom extensions are expensive to maintain
* Platform ownership requires sustained investment

These lessons directly informed this decision.

### Adoption Guidelines

All new Chiubaka / Hyperdrive monorepos should:

* Use `pnpm` for workspace management
* Use `turbo` for task orchestration and caching
* Define tasks via package scripts (source of truth)
* Keep tooling (lint, test, build) independent of the monorepo orchestrator
* Avoid introducing platform-style monorepo tools

### Exception Policy

Nx (or similar tools) may be used only if:

* The repository explicitly requires platform-level features
* The team is willing to own the associated maintenance burden
* The decision is documented in a separate ADR

### When to Revisit This Decision

Re-evaluate if:

* Turbo fails to meet scaling or CI requirements
* A new tool provides clear advantages without platform coupling
* Organizational needs shift toward heavy internal platform investment
* Agentic workflows change significantly in capability or cost
