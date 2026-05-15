---
status: accepted
date: 2026-04-07
decision-makers: Daniel Chiu
consulted: -
informed: -
---

# Chiubaka CircleCI orb: design defaults, jobs vs commands, and escape hatches

## Context and Problem Statement

This repository publishes **`chiubaka/circleci-orb`**, which encodes reusable CircleCI **commands**, **jobs**, and **bash scripts** for Chiubaka Technologies client repositories. Those clients are expected to follow org conventions such as:

- **pnpm + Turbo monorepos** — [ADR 0022](../../org/docs/adr/0022-standardize-monorepos-to-pnpm-turbo.md)
- **GitHub Packages** for private `@chiubaka/*` packages — [ADR 0034](../../org/docs/adr/0034-use-github-packages-with-single-chiubaka-scope-for-private-package-distribution.md)
- **Changesets** and related versioning ADRs — e.g. [ADR 0024](../../org/docs/adr/0024-use-changesets-for-library-monorepos.md), [0026](../../org/docs/adr/0026-use-changesets-for-application-releases.md), [0027](../../org/docs/adr/0027-use-single-changesets-workflow-in-hybrid-monorepos.md), [0028](../../org/docs/adr/0028-version-only-deployable-artifacts-by-default.md)
- **Release manifests and promotion tags** — [ADR 0038](../../org/docs/adr/0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) (supersedes [ADR 0030](../../org/docs/adr/0030-coordinated-release-model-release-manifests-and-promotion-tags.md)), [ADR 0031](../../org/docs/adr/0031-separation-of-artifact-tags-and-environment-promotion-tags.md)

We need durable **repository-level** decisions for:

1. How the orb balances **out-of-the-box defaults** for “standard” org monorepos with **escape hatches** for custom pipelines.
2. Whether shared automation lives in **this repo** vs a **separate npm package**, and how we avoid **unnecessary CI duplication** (duplicate builds / minutes) while keeping jobs **self-contained** when needed.
3. How we structure **CircleCI configuration surface** (YAML shape) so it stays **concise, clear, and explicit**.

## Decision Drivers

- **Developer experience:** Standard monorepos should “just work” with minimal wiring; advanced teams must not be blocked.
- **Avoid pointless duplication:** Do not require copy-pasting identical `package.json` or shell scripts into every client if the orb can own a **single tested implementation**.
- **Coupling:** Prefer invoking **repo-defined `package.json` scripts** for builds and publishes; avoid hardcoding **Turbo** or other tools inside the orb beyond what org ADRs already assume.
- **Testability:** Bash in this repo is covered by **Bats** and shellcheck; keep using that strength.
- **Alignment with org ADRs:** The orb encodes **workflow shape** (when auth runs, how manifests are validated); **policy** (Changesets groups, which packages release) remains in client repos and org ADRs as today.
- **Operability:** **Fail fast** with **actionable error messages** when prerequisites or schemas are wrong.

## Considered Options

- **Thin orb only** — orb provides auth + a single `run` hook; all publish logic lives in every client repo.
- **Fat orb only** — orb embeds monorepo-specific publish logic with few overrides.
- **Layered defaults (chosen)** — orb ships **tested default bash** and **both** a **command** and a **self-sufficient job**, with **explicit parameters** for disabling steps, swapping scripts, attaching workspaces, and replacing the entire job.

## Decision Outcome

Chosen option: **Layered defaults with explicit parameters, shared scripts in this repository, and first-class jobs plus commands.**

**Justification:** A thin-only orb duplicates scripts across N repos and drifts over time. A fat-only orb fights legitimate per-repo differences. A **default command** plus a **default job** that composes setup, auth, optional install/build, and publish—each step skippable or overridable—matches “magic defaults” without removing control. Keeping scripts **in this repo** (for now) uses existing Bats/shellcheck; extracting a separate package is deferred until the cost of duplication or release coupling becomes real.

### Consequences

- Good, because client `config.yml` can stay small for the common case.
- Good, because escape hatches avoid forking the orb for one-off needs.
- Good, because bash changes are tested in one place.
- Bad, because the orb maintainers own more surface area (parameters, scripts) and must semver carefully.
- Bad, because some clients will still need custom jobs; documentation must show **when** to compose commands manually.
- Neutral: `changesets-gated-publish` with default `create-github-release` adds a **GitHub Release** and a **train git tag** `release/<UTC-date>.N` (title `YYYY.MM.DD.N` only) alongside any existing **semver artifact tags** (for example this repo’s `vX.Y.Z` for `orb-tools/publish`). Workflow filters can keep matching only `^v[0-9]+\.[0-9]+\.[0-9]+$` so train tags do not double-trigger orb production publish; repos that must not create GitHub Releases set `create-github-release: false`.

### Confirmation

- Orb examples and docs list **default** usage and **override** patterns.
- Bats tests cover new shell helpers; manifest validation tests include **invalid** fixtures expecting **non-zero exit** and clear messages.
- Repo-level implementation plan stays aligned with this ADR: see [`docs/plans/orb-release-and-registry-workflows.md`](../plans/orb-release-and-registry-workflows.md).

---

## Detailed policies (normative for this repository)

### 1. Jobs vs commands

- **`command`s** are composable steps (e.g. `setup-npm-registry-auth`, `publish` logic entrypoint).
- **`job`s** are **end-to-end** workflows for the common case: checkout/setup, optional install, optional build, auth, publish (or coordinated deploy), with **parameters** to disable or replace parts.
- **Default publish (illustrative names):** ship a **`publish` command** and a **`publish` job** that uses that command internally so clients may:
  - use the **job** unchanged,
  - **replace the entire job** with a custom job that still calls orb **commands**, or
  - **reuse the job** but **override** which command/script runs for the publish step (escape hatch).

### 2. Self-contained jobs vs avoiding duplicate builds

- **Default:** The publish job should be able to run **standalone** (install + build + publish) so simple pipelines do not require workspace plumbing.
- **Optional:** Parameters (or workflow patterns) should support **skipping** install/build when upstream jobs **persist artifacts** via CircleCI **workspaces** (or caches), to save **CI minutes**—without making self-contained mode impossible.

### 3. YAML configuration style (“Direction 2”)

- Prefer **explicit orb parameters** (booleans, enums, script names) so configuration is **self-documenting** in client repos, rather than relying only on undocumented implicit defaults.
- Sensible defaults remain, but **important behaviors** (e.g. registry backend, whether to run build, custom publish script) should be **named** in YAML where practical.

### 4. Builds, Turbo, and `package.json`

- **Invoke builds through `package.json` scripts** (e.g. `pnpm run build`, `pnpm run build:libs`) as the primary extension point.
- Do **not** embed Turbo-specific CLI flags in the orb unless unavoidable; coupling to Turbo belongs in **repo scripts**, consistent with [ADR 0022](../../org/docs/adr/0022-standardize-monorepos-to-pnpm-turbo.md).

### 5. Registry authentication

- Provide **`setup-npm-registry-auth`** (or equivalent) supporting:
  - **`npmjs`** — public or npmjs-hosted publishing (`registry.npmjs.org`).
  - **`github-packages`** — GitHub Packages (`npm.pkg.github.com`) for `@chiubaka/*` per org [ADR 0034](../../org/docs/adr/0034-use-github-packages-with-single-chiubaka-scope-for-private-package-distribution.md).
- Standardize on **`GITHUB_TOKEN`** in documentation and examples for GitHub Packages auth in CircleCI (subject to least-privilege tokens in contexts).

### 6. Encoding org release patterns

- The orb should implement **workflow scaffolding** aligned with org ADRs (e.g. Changesets-driven publish flows; manifest validation and repo-defined deploy hooks for [ADR 0038](../../org/docs/adr/0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md) / [ADR 0031](../../org/docs/adr/0031-separation-of-artifact-tags-and-environment-promotion-tags.md)).
- **Escape hatches** (custom script names, custom jobs, skipping steps) remain **first-class** so repos are not locked into one release topology.

### 7. Validation and errors

- **Release manifest** validation must **fail the job** on any **schema or invariant violation** (per [ADR 0038](../../org/docs/adr/0038-release-manifest-pin-sets-and-tooling-owned-deploy-order.md)), printing a **short, actionable** message (what failed, which file, how to fix).

### 8. Versioning of this orb (pre-1.0)

- Until **v1.0**, treat **minor version bumps** as the normal vehicle for **meaningful** or **potentially breaking** YAML/script behavior changes; **patch** bumps for small fixes. Revisit strict semver semantics at **v1.0**.

---

## Pros and Cons of the Options

### Thin orb only

- Good: minimal maintenance in this repo.
- Bad: duplicated scripts and drift across client repositories.

### Fat orb only

- Good: one implementation.
- Bad: poor fit for repos that diverge; high coupling.

### Layered defaults (chosen)

- Good: defaults for standard monorepos; explicit overrides; scripts tested here.
- Bad: more parameters and documentation to maintain.

---

## More Information

- Implementation backlog and staged delivery: [`docs/plans/orb-release-and-registry-workflows.md`](../plans/orb-release-and-registry-workflows.md).
- Org ADRs remain the **source of policy** for versioning and releases; this ADR governs **how this orb** exposes those patterns in CircleCI.
