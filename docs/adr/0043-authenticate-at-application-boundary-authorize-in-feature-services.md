---
status: accepted
date: 2026-07-17
decision-makers: Daniel Chiu
---

# ADR 0043: Authenticate at the application boundary and authorize within feature services

## Context and Problem Statement

Chiubaka Technologies applications expose their internal capabilities through a high-level application API—typically a stable facade class named after the application (for example `Midana`), constructed per [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md). Environment-specific hosts such as Hono servers translate HTTP or other transport protocols into calls to this API, consistent with the thin **server host app** / transport-agnostic backend split in [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and composition-root boundaries in [ADR 0005](0005-composition-roots-and-wiring-boundaries.md).

Authentication and authorization introduce additional boundary concerns. A host receives transport-specific session information, but the application must determine which actor is making the call and whether that actor may perform the requested operation. The architecture must establish where credential validation, actor resolution, authorization, and business orchestration belong without coupling application logic to a particular host, framework, authentication library, or authorization library.

## Decision Drivers

- Keep application and domain logic independent of Hono, HTTP, GraphQL, queues, CLI hosts, and other deployment environments.
- Preserve the application-level facade as the primary trust boundary.
- Ensure each host invokes one complete, named application operation rather than orchestrating multiple application steps.
- Avoid exposing Hyperdrive-specific types as part of an application's public API.
- Prevent authentication credentials and session-library concepts from leaking into feature services, domain services, or repositories.
- Make authorization difficult to bypass when application services are invoked outside a particular host.
- Place resource-aware authorization close enough to the relevant data and business operation to make correct decisions.
- Support applications that use Protectiva and Primero together, either library independently, or alternative implementations.
- Keep secured application operations self-contained from the host's perspective.
- Retain explicit and testable actor propagation within application internals.

## Considered Options

- Authenticate entirely in the environment host and pass a resolved actor into the application
- Expose a two-step application API that returns a context which the host passes to later calls
- Expose a request-scoped or actor-bound application object
- Use ambient request state such as asynchronous local storage
- Pass authentication credentials into each named application operation and resolve the actor internally

## Decision Outcome

Chosen option: "Pass authentication credentials into each named application operation and resolve the actor internally".

**Justification:** This keeps the transport-agnostic application facade as the trust boundary, keeps hosts as thin protocol adapters (ADR 0005 / ADR 0007), and places resource-aware authorization inside feature `application/` services where use-case and data context already live—without inviting host-level orchestration or leaking Protectiva, Primero, or host-framework types into the public API.

A secured application operation will accept an application-owned credential type alongside its operation-specific input. The application boundary will authenticate the credential, resolve it into an application-specific actor, create an internal execution context, and invoke the appropriate feature-level application service.

The environment host will invoke exactly one named application operation for each externally initiated use case. Multi-step business orchestration will be implemented inside that named application operation rather than in the host.

Authorization will be enforced within feature-level application services. These services have enough use-case and resource context to make correct authorization decisions and can ensure that authorization is not bypassed by callers that do not enter through a particular host.

### Consequences

- Good, because hosts remain thin protocol adapters rather than participants in application security or business orchestration.
- Good, because a route, resolver, queue consumer, or CLI command makes one self-contained call into the application.
- Good, because authentication credentials do not propagate beyond the top-level application boundary.
- Good, because internal services operate on an explicit, resolved actor rather than untrusted credential material.
- Good, because authorization decisions can use loaded resources, ownership information, tenant information, transaction state, and other feature-specific context.
- Good, because application services remain secure when called from hosts other than the original HTTP server.
- Good, because the application controls the types and semantics of its public API rather than exposing Protectiva or Primero types directly.
- Good, because authentication and authorization implementations can be replaced through adapters without changing the host-facing application API.
- Good, because internal tests may supply actors or execution contexts directly to feature services without manufacturing authentication tokens.
- Bad, because secured application methods must explicitly accept credential information even when their primary purpose is unrelated to authentication.
- Bad, because authentication may be repeated across separate named application calls made during the same transport request.
- Bad, because the top-level application class becomes an application boundary and coordinator rather than a mechanically thin forwarding facade.
- Neutral, because internal application services still receive an execution context even though that context is not exposed to the host.

### Confirmation

Compliance will be confirmed through code review and architectural tests where practical.

The following conditions should hold:

- Environment hosts may parse headers, cookies, transport metadata, and protocol-specific authentication material, but must not validate sessions or construct trusted application actors.
- Each externally initiated use case must map to one named application operation.
- Hosts must not coordinate multiple application operations to implement one business use case.
- Public application methods must expose application-owned input and output types.
- Protectiva, Primero, Hono, and other infrastructure-specific types must not appear in the application's public API unless the application has intentionally adopted such a type as its own contract.
- Authentication credentials must not be accepted by feature services, domain services, entities, or repositories.
- Feature application services must receive a resolved internal execution context or actor.
- Resource-aware authorization must occur before protected state is returned or mutated.
- Pure domain services and entities must enforce domain invariants but must not depend directly on authentication credentials or authorization frameworks.
- Repositories must not be treated as the sole authorization boundary.

Dependency-rule tests, lint restrictions, or package-boundary checks should prevent feature and domain packages from importing host-framework modules or concrete authentication adapters, consistent with [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and [ADR 0008](0008-barrel-files-public-api-boundaries.md).

## Pros and Cons of the Options

### Authenticate Entirely in the Environment Host

The host validates the session, resolves the current user, and passes an actor or user identifier into the application.

- Good, because application methods do not accept credential material.
- Good, because authentication may be performed once per transport request.
- Bad, because every host becomes part of the trusted computing base.
- Bad, because hosts must understand the authentication implementation and its types.
- Bad, because a host may fabricate or incorrectly construct an actor.
- Bad, because switching from Protectiva to another authentication implementation requires host changes.
- Bad, because security behavior may differ between HTTP, queue, CLI, and other hosts.

### Expose a Two-Step Context API

The host first authenticates credentials and receives an application context, then passes that context into a second application call.

Example:

```ts
const context = await midana.authenticate(credential);
return midana.listReceipts(context, params);
```

- Good, because authentication and operation execution are explicitly separated.
- Good, because context propagation is visible and testable.
- Good, because one context may be reused across multiple operations.
- Bad, because ordinary host code must perform two calls for one use case.
- Bad, because the host has little legitimate work to perform between the calls.
- Bad, because the API encourages hosts to reuse the context and orchestrate multiple application operations.
- Bad, because it exposes an internal execution concept as part of the host-facing application contract.

### Expose a Request-Scoped or Actor-Bound Application Object

The root application authenticates the caller and returns an object whose methods capture the resolved actor.

Example:

```ts
const invocation = await midana.forCredential(credential);
return invocation.receipts.list(params);
```

- Good, because credential validation occurs once.
- Good, because subsequent method calls do not require explicit context arguments.
- Good, because the captured context is not ambient global state.
- Bad, because the API implies a multi-operation lifecycle that hosts are not intended to use.
- Bad, because terms such as `Request` incorrectly introduce host-specific vocabulary into the application model.
- Bad, because it encourages host-level orchestration across several application methods.
- Bad, because the additional object lifecycle provides little value when each host invocation should call one complete use case.

### Use Ambient Request State

The host or application stores the current actor in asynchronous local storage or another ambient context mechanism.

- Good, because application method signatures remain visually simple.
- Good, because actor information can be accessed deeply without explicit parameters.
- Bad, because security-critical dependencies become hidden.
- Bad, because tests and background execution require special runtime setup.
- Bad, because actor state may be unavailable or incorrect outside supported asynchronous execution paths.
- Bad, because concurrency and context-propagation failures can become security vulnerabilities.
- Bad, because domain and infrastructure code may begin accessing the current actor opportunistically.

### Pass Credentials Into Each Named Application Operation

Each secured application operation accepts an application-owned credential type and performs authentication as part of the operation.

Example:

```ts
return midana.listReceipts({
  credential,
  params,
});
```

- Good, because each host performs one self-contained application call.
- Good, because the application remains the trust boundary.
- Good, because hosts only translate transport-specific material into application-owned input.
- Good, because authentication is performed once for the complete named use case.
- Good, because the application may internally propagate an explicit actor context across all steps of the use case.
- Good, because the API does not invite host-level business orchestration.
- Bad, because credential input appears on many secured application methods.
- Bad, because separate application calls may independently validate the same credential.
- Neutral, because the top-level application API explicitly acknowledges that authentication is part of invoking secured use cases.

## More Information

### Application Boundary Responsibilities

The application boundary (the host-facing facade) is responsible for:

- Accepting application-owned credential and operation input types.
- Authenticating credentials through an injected authentication abstraction.
- Resolving authenticated principals into application-specific actors.
- Constructing an internal execution context.
- Coordinating the complete named use case.
- Delegating resource-aware authorization and operation execution to feature-level application services.
- Returning application-owned result and error types.

The application boundary must not understand HTTP headers, cookies, Hono contexts, GraphQL resolver metadata, or other transport-specific constructs.

### Environment Host Responsibilities

An environment host is responsible for:

- Parsing the incoming protocol.
- Extracting transport-specific credential material.
- Translating that material into the application's credential type.
- Parsing and validating transport-level inputs.
- Calling one named application operation.
- Translating application results and errors into protocol responses.
- Applying transport-level concerns such as request-size limits, rate limiting, serialization, and response headers.

The host must not implement multi-step business workflows by chaining application calls. When such a need appears, the application should expose a new named operation that owns the orchestration.

### Internal Security Vocabulary

Applications should distinguish among the following concepts:

- **Credential:** untrusted evidence supplied by an external caller.
- **Principal:** a subject whose credential has been authenticated.
- **Actor:** the application's interpretation of that principal, such as a registered user, anonymous user, or service.
- **Execution context:** internal invocation information propagated across the implementation of one application operation.

The exact names may vary by application, but these concepts should not be collapsed into a single ambiguous `User` or `Identity` type.

### Self-Service and Administrative Operations

Self-service operations should derive the acting user's identifier from the resolved actor rather than accept a caller-supplied user identifier.

Prefer:

```ts
midana.listReceipts({
  credential,
  params,
});
```

over:

```ts
midana.listReceiptsForUser({
  credential,
  userId,
  params,
});
```

Operations in which one actor intentionally acts upon another user must express that distinction explicitly and authorize it accordingly.

### Deferred Decisions

This ADR does not define Primero's final policy, action, resource, relationship, or query-scope abstractions. Those decisions require a separate ADR.

The detailed placement of authorization enforcement relative to policy decision points, policy information points, and repositories is recorded in [ADR 0044](0044-enforce-authorization-in-application-feature-services.md).

This ADR also does not require every public application method to perform authentication. Public, anonymous, optionally authenticated, and service-only operations may expose distinct input contracts appropriate to their security requirements.

### Related ADRs

- [ADR 0005](0005-composition-roots-and-wiring-boundaries.md) — composition roots at the edges; thin hosts map transport to application calls.
- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — transport-agnostic backend packages, feature `application/` services, and thin server host apps.
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — barrels as public API boundaries for packages and features.
- [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md) — classes as ownership boundaries for orchestration and services.
- [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md) — stable facade construction for the host-facing application API.
- [ADR 0019](0019-vendor-specific-infrastructure-slices.md) — concrete auth/authz adapters belong in vendor infrastructure slices, not in the public facade contract.
- [ADR 0044](0044-enforce-authorization-in-application-feature-services.md) — feature services as PEPs; PDP/PAP/PIP responsibilities and repository boundaries.
