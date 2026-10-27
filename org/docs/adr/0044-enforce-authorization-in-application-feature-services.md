---
status: accepted
date: 2026-07-23
decision-makers: Daniel Chiu
---

# ADR 0044: Enforce authorization in application feature services

## Context and Problem Statement

Chiubaka Technologies applications may expose the same application logic through multiple hosts and delivery mechanisms, including HTTP controllers, GraphQL resolvers, background jobs, command-line tools, and other integrations. Per [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md), hosts translate transport-specific credential material into application-owned input, and the application facade authenticates that credential, resolves an application-specific actor, and delegates into feature-level application services.

Authorization must still be applied consistently regardless of the host, without duplicating authorization orchestration throughout each delivery layer or coupling persistence repositories to the current authorization model. ADR 0043 establishes that resource-aware authorization belongs in feature services; this ADR records where that enforcement sits relative to policy decision, policy information, and persistence responsibilities.

Where should authorization be enforced, and how should authentication identity, application authorization, service logic, policy evaluation, and persistence responsibilities be divided?

## Decision Drivers

- Authorization must be enforced consistently across every host and entry point.
- Application logic should remain reusable across HTTP, GraphQL, background jobs, and other execution environments, consistent with [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md).
- Controllers, resolvers, and other host adapters should remain thin and should not coordinate resource-level authorization ([ADR 0005](0005-composition-roots-and-wiring-boundaries.md), [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md)).
- Repositories should remain focused on retrieving and persisting data.
- Authorization must be difficult to omit accidentally.
- Application-facing APIs should remain domain-oriented and self-contained ([ADR 0014](0014-stable-facade-construction-and-centralized-composition.md)).
- Host applications should not need to reproduce application-specific identity resolution, policy selection, or authorization-service composition.
- Authorization rules should be testable independently of transport and persistence infrastructure.
- Repository APIs should reflect stable application use cases and projections rather than temporary roles or permission structures.
- The architecture should align with established authorization terminology without requiring every component to be implemented as a separate service or process.
- The placement of authorization enforcement should remain stable even if Primero later provides a more standardized policy model or canonical authorization implementation.
- Concrete authorization adapters should remain in vendor infrastructure slices rather than the public facade contract ([ADR 0019](0019-vendor-specific-infrastructure-slices.md)).

## Considered Options

- Enforce authorization in controllers, resolvers, and other host entry points
- Enforce authorization in repositories
- Enforce authorization in application feature services
- Distribute authorization checks across all architectural layers

## Decision Outcome

Chosen option: "Enforce authorization in application feature services".

**Justification:** Feature-level application services already own the named use case and the resource context needed for correct decisions. Making them the primary policy enforcement points keeps authorization consistent across hosts, preserves thin adapters and persistence-focused repositories, and leaves room to swap embedded, external, or future Primero-provided decision-point implementations without moving enforcement.

Application feature services are the primary policy enforcement points. They are responsible for identifying the authorization question associated with a domain operation, obtaining any required authorization-relevant resource state, requesting a decision from an application-supplied authorization decision point, and enforcing that decision before performing the protected operation.

Enforcement is fail-closed. Only an explicit allow decision permits the protected operation. PDP, PIP, or adapter errors, timeouts, missing decisions, and other indeterminate results must be treated as denial and must not execute the protected operation.

When a service loads an authorization view, obtains an allow decision, and later mutates or returns protected state, authorization facts may change between those steps. Feature services own that consistency risk for the use case they protect. Applications should choose an appropriate strategy—such as a shared transaction or lock, revalidation before commit, or accepting a bounded race for read-mostly paths—without this ADR mandating one mechanism for every operation.

Per ADR 0043, the application boundary authenticates credentials and resolves the actor or execution context that feature services receive. Hosts remain thin protocol adapters: they extract transport-specific credential material and invoke one named application operation. Repositories retrieve and persist data but do not determine whether the current principal is authorized.

This decision is independent of how Primero policies are ultimately represented or evaluated. Primero may initially support application-defined authorization implementations and later offer a standardized policy model or first-party decision-point implementation without changing the responsibility of application feature services to request and enforce authorization decisions.

### Standard Authorization Roles

The architecture uses the following established authorization roles:

| Role                              | Responsibility in Chiubaka Technologies applications                                                                                                                         |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Policy Enforcement Point (PEP)    | The application feature service that requests and enforces an authorization decision                                                                                         |
| Policy Decision Point (PDP)       | The application-supplied or Primero-provided implementation that evaluates authorization requests and returns decisions                                                      |
| Policy Administration Point (PAP) | The code repository, configuration system, external policy-management system, and associated workflow through which authorization policies are defined and maintained        |
| Policy Information Point (PIP)    | Any application or external component that supplies facts needed to evaluate authorization, such as memberships, relationships, feature entitlements, or resource attributes |

These terms describe architectural responsibilities. They do not require four separately deployed services or four correspondingly named TypeScript classes.

In a modular monolith with embedded TypeScript policies:

- Feature services are the PEPs.
- Application-provided TypeScript authorizers act as the PDP.
- The application repository and development workflow act as the PAP.
- Repositories or capability providers supplying authorization facts may act as PIPs.

When using an external authorization engine:

- Feature services remain the PEPs.
- The external engine and its adapter may form the PDP.
- The engine's policy store and management workflow may form the PAP.
- Application data providers and external relationship stores may act as PIPs.

If Primero later provides a standardized policy language or canonical authorization implementation:

- Feature services will remain the PEPs.
- The Primero implementation may serve as the PDP.
- Primero-provided policy-definition and management tooling may participate in the PAP.
- Application and infrastructure components may continue to act as PIPs.

### Consequences

- Good, because authorization is applied consistently regardless of whether an operation is invoked through HTTP, GraphQL, a job processor, or another host.
- Good, because authorization remains close to the business operation it protects.
- Good, because controllers, resolvers, and other host adapters remain thin.
- Good, because repositories remain reusable and focused on persistence rather than user, role, or policy semantics.
- Good, because service methods can protect domain actions that do not map cleanly to CRUD operations.
- Good, because application services can enforce authorization across multiple repository calls or an entire business transaction.
- Good, because authorization behavior can be unit tested at the service layer.
- Good, because persistence APIs can be designed around stable projections and use cases instead of current authorization roles.
- Good, because replacing an embedded PDP with an external or future Primero-provided PDP does not change where authorization is enforced.
- Good, because this architectural boundary remains valid if Primero's authorization implementation becomes more standardized later.
- Bad, because application feature services gain an additional responsibility and dependency.
- Bad, because services may need to load a narrow authorization view before retrieving a larger result projection.
- Bad, because careless internal service APIs could still expose unprotected operations unless architectural boundaries and tests are maintained.
- Bad, because an application may need explicit composition code for its PEP, PDP, and any required PIPs.
- Bad, because mutable-resource and compound operations may require additional consistency handling between the authorization decision and the protected write or read.
- Neutral, because the amount of application-owned authorization implementation may decrease if Primero later provides a canonical PDP, but service-level enforcement will remain necessary.

### Confirmation

Compliance with this decision should be verified through design and code review:

- Public controllers, resolvers, consumers, and jobs should not contain resource-level authorization rules.
- Publicly callable feature-service operations that access protected resources should enforce authorization internally.
- Feature services should request decisions through application- or feature-specific authorization abstractions.
- Protected operations should proceed only after an explicit allow; PDP, PIP, or adapter failures and indeterminate results should deny and must not execute the operation.
- Feature services should receive a resolved actor or execution context, not untrusted credentials ([ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md)).
- Design and review should consider consistency between authorization facts and protected mutations or compound operations, without requiring one prescribed locking or revalidation mechanism for every case.
- Repositories should not accept principals, roles, authentication identities, or authorization engines merely to decide whether an operation is permitted.
- Repository methods should be named around domain use cases, queries, and stable projections rather than authorization roles.
- Tests should demonstrate that protected service operations reject unauthorized callers regardless of the host through which they are invoked.
- Where practical, integration tests should invoke the same service operation through multiple hosts and confirm equivalent authorization behavior.
- Replacing one PDP implementation with another should not require moving enforcement into controllers or repositories.
- Adopting a future standardized Primero policy implementation should not require changing the location of the application's PEPs.

Static analysis or architectural tests may later be added to prohibit direct use of unprotected repositories from host-layer modules, consistent with the dependency-rule approach in [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and [ADR 0008](0008-barrel-files-public-api-boundaries.md).

## Pros and Cons of the Options

### Enforce Authorization in Controllers, Resolvers, and Other Host Entry Points

Each host checks authorization before invoking application logic.

- Good, because authorization is visible near the externally exposed endpoint.
- Good, because simple applications can implement this with familiar route guards or resolver checks.
- Bad, because every host must reproduce the same authorization coordination.
- Bad, because background jobs and non-network entry points may omit equivalent checks.
- Bad, because authorization becomes coupled to transport-layer concepts.
- Bad, because controllers and resolvers must understand application-specific resource and policy semantics.
- Bad, because internal service calls may bypass host-level enforcement.
- Bad, because host components become the effective PEPs even though they do not own the protected business operation.

### Enforce Authorization in Repositories

Repositories accept caller or authorization information and apply access controls while retrieving or mutating data.

- Good, because query restrictions can be applied close to the database.
- Good, because some unauthorized data access can be prevented at a low level.
- Bad, because repositories become coupled to identities, roles, policies, or authorization providers.
- Bad, because business operations involving several repositories cannot be authorized cleanly as one domain operation.
- Bad, because domain actions that do not correspond directly to persistence operations are difficult to express.
- Bad, because repository reuse becomes dependent on the current authorization model.
- Bad, because data retrieval and authorization enforcement become difficult to reason about separately.
- Bad, because repositories become both persistence components and PEPs.

### Enforce Authorization in Application Feature Services

Feature services obtain authorization-relevant data, request an authorization decision, enforce the result, and then use repositories to execute the operation.

- Good, because authorization is close to the domain operation being protected.
- Good, because all hosts receive the same enforcement.
- Good, because repositories remain persistence-focused.
- Good, because services can authorize compound transactions and domain-specific actions.
- Good, because application-specific authorization remains behind the application facade.
- Good, because services form clear and consistent PEPs.
- Good, because the decision remains valid across application-defined, external, or future Primero-provided PDP implementations.
- Neutral, because services require access to a feature-specific authorization capability.
- Neutral, because PEPs own consistency between authorization and mutation, while concrete transaction, lock, or revalidation choices remain application-specific.
- Bad, because service construction or method invocation must account for the current actor or execution context.
- Bad, because some operations may require separate authorization-view and result-projection queries.

### Distribute Authorization Checks Across All Architectural Layers

Controllers, services, and repositories each enforce portions of the authorization model.

- Good, because defense in depth can reduce the impact of an individual omitted check.
- Good, because each layer can enforce constraints suited to its capabilities.
- Bad, because responsibility becomes unclear.
- Bad, because policies are likely to be duplicated or become inconsistent.
- Bad, because it becomes difficult to determine which layer is authoritative.
- Bad, because authorization behavior becomes difficult to test and change.
- Bad, because transport, application, and persistence concepts become tightly coupled.
- Bad, because multiple unrelated components act as competing PEPs.

## More Information

### Relationship to Authentication

Authentication and actor resolution remain governed by [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md). The application facade authenticates application-owned credentials, resolves an application-specific actor, constructs an internal execution context, and delegates resource-aware authorization to feature services. Hosts must not validate sessions, fabricate trusted actors, or perform resource-level authorization.

Composition of authentication adapters, authorizers, feature services, and repositories belongs in the application's composition root or equivalent centralized wiring ([ADR 0005](0005-composition-roots-and-wiring-boundaries.md), [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md)). Individual controllers, resolvers, and jobs should not repeatedly perform credential-to-actor translation, Primero binding, policy-decision-point selection, or feature-service construction.

### Application Facade Shape

An application facade such as Midana should expose domain operations such as:

```ts
await midana.receipts.getDetails({
  credential,
  receiptId,
});
await midana.invoices.approve({
  credential,
  invoiceId,
});
```

It should not ordinarily expose principal-binding or actor-binding mechanics such as:

```ts
midana.forPrincipal(principal);
```

as part of its primary domain-facing API. That pattern was considered and rejected for host-facing use in ADR 0043.

Lower-level runtime or test APIs may accept a resolved actor or execution context when exercising feature services directly, but application-specific coordination should remain behind the host-facing facade boundary.

### Feature-Service and Authorizer Shape

Feature services may be lightweight, execution-scoped objects constructed for the current actor. Repositories, database connections, policy definitions, decision-point implementations, and other expensive infrastructure may remain application-scoped. This ADR does not require a particular dependency-injection lifecycle.

Feature services should normally consume feature-specific authorization abstractions:

```ts
export interface ReceiptAuthorizer {
  assertCanReadDetails(resource: ReceiptAuthorizationView): Promise<void>;

  assertCanUpdate(
    resource: ReceiptAuthorizationView,
    fields: readonly ReceiptUpdateField[],
  ): Promise<void>;

  authorizeSearch(
    query: SearchReceiptsQuery,
  ): Promise<QueryAuthorizationDecision<ReceiptReadScope>>;
}
```

The feature-specific authorizer may delegate to:

- Embedded application-defined TypeScript authorization logic
- An external authorization engine
- A future standardized Primero authorization implementation
- Another implementation compatible with Primero's authorization protocol

The feature service need not know which implementation is in use. Concrete adapters belong in vendor-specific infrastructure slices per [ADR 0019](0019-vendor-specific-infrastructure-slices.md).

### Deferred Decisions

A future decision to standardize more of Primero's policy language, policy administration model, or PDP implementation should be recorded separately. Such a decision may reduce application-specific authorization code, but it should preserve the placement of application feature services as the primary PEPs.

This ADR also does not prescribe a single transaction, locking, or revalidation strategy for authorization-to-mutation consistency. Applications choose mechanisms appropriate to each use case while keeping feature services as the PEPs that own that risk.

### Related ADRs

- [ADR 0005](0005-composition-roots-and-wiring-boundaries.md) — composition roots at the edges; thin hosts map transport to application calls.
- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — transport-agnostic backend packages, feature `application/` services, and thin server host apps.
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — barrels as public API boundaries for packages and features.
- [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md) — classes as ownership boundaries for orchestration and services.
- [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md) — stable facade construction for the host-facing application API.
- [ADR 0019](0019-vendor-specific-infrastructure-slices.md) — concrete auth/authz adapters belong in vendor infrastructure slices, not in the public facade contract.
- [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md) — authenticate at the application boundary; authorize within feature services.
