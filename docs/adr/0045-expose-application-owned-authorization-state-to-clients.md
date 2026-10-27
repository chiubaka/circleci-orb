---
status: proposed
date: 2026-07-23
decision-makers: Daniel Chiu
---

# ADR 0045: Expose application-owned authorization state to clients

## Context and Problem Statement

Web and mobile clients of Chiubaka Technologies applications need enough authorization information to present appropriate navigation, controls, upgrade prompts, and usage-limit messaging. Without an explicit client-facing authorization model, clients may infer permissions from authentication claims, duplicate authorization policy, construct arbitrary authorization queries, or discover unavailable operations only after the server rejects them.

Applications therefore need a consistent way to communicate the current actor's broad authorization state to clients. This information must remain an application-owned public contract and must not become an authorization credential or a replacement for server-side enforcement ([ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md), [ADR 0044](0044-enforce-authorization-in-application-feature-services.md)).

How should applications expose authorization information to clients without weakening server-side enforcement or leaking authorization-framework internals into public APIs?

## Decision Drivers

- Keep authoritative authorization enforcement on the server.
- Allow clients to render appropriate user interfaces without duplicating actor-specific authorization policy.
- Make the point-in-time and potentially stale nature of client authorization information explicit.
- Preserve application ownership of public API contracts ([ADR 0014](0014-stable-facade-construction-and-centralized-composition.md)).
- Avoid exposing authorization framework actions, resources, policies, or implementation types to clients ([ADR 0019](0019-vendor-specific-infrastructure-slices.md)).
- Support strongly typed, application-specific capability and limit shapes.
- Support capabilities that apply across different scopes or have different applicability models.
- Support a simple initialization-time authorization flow for client applications.
- Avoid fragmenting authorization state across many narrowly scoped facade operations ([ADR 0005](0005-composition-roots-and-wiring-boundaries.md)).
- Distinguish actor-specific authorization from ordinary domain and lifecycle rules.
- Avoid coupling authentication tokens and sessions to mutable roles, purchases, subscriptions, or application state.
- Permit reusable authorization-state machinery without imposing one universal capability vocabulary.

## Considered Options

- Do not expose authorization information to clients
- Embed permissions, capabilities, or entitlements in authentication tokens or sessions
- Expose a generic client authorization-check API
- Expose many narrowly scoped or resource-specific authorization-state operations
- Expose one application-owned, broadly useful authorization state through the application facade

## Decision Outcome

Chosen option: "Expose one application-owned, broadly useful authorization state through the application facade".

**Justification:** A broad authorization state gives clients the information needed for normal UI and UX decisions without making the client an authorization enforcement point. The application retains control over the public shape ([ADR 0014](0014-stable-facade-construction-and-centralized-composition.md)), while authorization libraries may provide generic evaluation and projection machinery behind the facade. Server-side feature services remain the authoritative policy enforcement points ([ADR 0044](0044-enforce-authorization-in-application-feature-services.md)).

An **authorization state** is defined as:

> A point-in-time, advisory projection of authorization decisions, limits, and related application information for the current actor.

Authorization state is not a credential, durable permission grant, or guarantee that a later operation will succeed. Every protected server operation must independently authorize the operation when it is executed.

### Application-Owned Shape

Applications define explicit capability, limit, and metadata types appropriate to their domain.

A shared authorization library may standardize only a minimal outer envelope:

```ts
export interface AuthorizationState<
  Capabilities,
  Limits = undefined,
  Metadata = undefined,
> {
  capabilities: Capabilities;
  limits: Limits;
  metadata: Metadata;

  evaluatedAt: string;

  /**
   * An opaque application- or implementation-defined
   * revision that may assist with refresh and caching.
   */
  revision?: string;
}
```

An illustrative Falcon contract might resemble:

```ts
export interface FalconAuthorizationState {
  capabilities: {
    reports: {
      read: AuthorizationScope<FalconReportReadScope>;

      update: AuthorizationScope<FalconReportUpdateScope>;

      canCreate: boolean;
    };

    projects: {
      canCreate: boolean;

      manageableProjectIds: readonly FalconProjectId[];
    };

    billing: {
      canManageSubscription: boolean;
    };
  };

  limits: {
    monthlyReports: {
      maximum: number | null;
      used: number;
      remaining: number | null;
    };

    projects: Readonly<
      Record<
        FalconProjectId,
        {
          collaborators: {
            maximum: number | null;
            used: number;
            remaining: number | null;
          };
        }
      >
    >;
  };

  metadata: {
    actorId: FalconActorId;
    activeProjectId?: FalconProjectId;
  };

  evaluatedAt: string;
  revision?: string;
}
```

Applications are not required to represent capabilities as lists of strings or limits as generic records.

An application may use:

- Explicit nested boolean properties.
- Enums or discriminated unions.
- `AuthorizationScope<Scope>` values.
- Structured capability results.
- Flat capability records.
- Bounded collections of scope identifiers.
- Plugin-defined string keys.
- Any other shape appropriate to its public API.

The common architectural requirement is the semantic role of authorization state, not one mandatory internal representation.

### Optional Scoped Authorization Values

Primero may provide the following reusable utility:

```ts
export type AuthorizationScope<Scope> =
  | {
      type: "none";
    }
  | {
      type: "all";
    }
  | {
      type: "scoped";
      scope: Scope;
    };
```

The `Scope` type is fully application-defined.

For example:

```ts
export type FalconReportUpdateScope =
  | {
      type: "owned";
    }
  | {
      type: "assigned";
    }
  | {
      type: "projects";
      projectIds: readonly FalconProjectId[];
    };
```

A resulting capability could be:

```ts
{
  type: "scoped",
  scope: {
    type: "owned",
  },
}
```

This primitive is useful when a capability naturally has three broad outcomes:

- No access.
- Unrestricted access.
- Access restricted according to an application-defined scope.

It is not required for every capability.

For example:

```ts
billing: {
  canManageSubscription: boolean;
}
```

may be clearer than forcing billing access into `AuthorizationScope`.

Similarly, limits, rollout variants, approval requirements, or other authorization-related values may require unrelated application-defined structures.

`AuthorizationScope<Scope>` is therefore an optional capability-building primitive rather than the mandatory structure of all authorization state.

### Authorization State May Cross Scopes

One top-level scope does not govern every capability or limit in an authorization state.

A single authorization state may communicate that the actor:

- Can read reports throughout a project.
- Can update only reports they own.
- Can manage selected projects.
- Cannot manage account billing.
- Has an account-wide storage limit.
- Has separate collaborator limits for individual projects.

Each capability or limit may carry its own applicability semantics when necessary.

For example:

```ts
export interface FalconCapabilities {
  reports: {
    read: AuthorizationScope<FalconReportReadScope>;

    update: AuthorizationScope<FalconReportUpdateScope>;
  };

  billing: {
    canManageSubscription: boolean;
  };
}
```

Primero and organization-level architecture do not require all capability keys to share one scoping model.

### Application-Level Authorization Input

The application may need high-level input to construct authorization state.

For example:

```ts
export interface GetFalconAuthorizationStateInput {
  credential: FalconCredential;
  activeProjectId?: FalconProjectId;
}
```

The facade may expose:

```ts
const authorizationState = await falcon.getAuthorizationState({
  credential,
  activeProjectId,
});
```

The application is responsible for deriving any additional information required to construct the state, including:

- The authenticated principal.
- The application actor.
- The current account.
- The active project.
- Relevant billing subjects.
- Memberships.
- Roles.
- Other application facts.

The host must not be required to orchestrate a complex sequence of facade calls merely to construct authorization state ([ADR 0005](0005-composition-roots-and-wiring-boundaries.md), [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md)).

For example, the host should not need to do this:

```ts
const actor = await falcon.getActor(...);

const account = await falcon.getAccount(...);

const project = await falcon.getProject(...);

const accountAuthorization =
  await falcon.getAccountAuthorizationState(...);

const projectAuthorization =
  await falcon.getProjectAuthorizationState(...);
```

The application facade should provide one self-contained operation for the normal client use case.

### Client Lifecycle

The default client pattern is:

1. Fetch authorization state during application initialization.
2. Store it in client application state.
3. Use it for broad UI and UX decisions.
4. Refresh it when something likely to affect authorization occurs.
5. Independently authorize every protected server operation when executed.

Potential refresh triggers include:

- Authentication changes.
- Purchase completion.
- Subscription changes.
- Membership changes.
- Role changes.
- Switching an active account, project, or similar application context.
- Receiving a server event indicating authorization state changed.
- Receiving an unexpected authorization denial.
- Returning to the application after a sufficiently long period.

Overlapping initialization and refresh requests are a real client concern: a slower earlier response must not overwrite fresher authorization state. Clients should ensure stale responses are ignored. The concrete mechanism—cancelling in-flight requests, sequencing requests, comparing `revision` or `evaluatedAt`, or another approach—is an implementation detail for each client stack. Organization architecture does not prescribe a specific concurrency protocol here. Hyperdrive libraries may later standardize shared refresh machinery if that proves valuable; doing so is not currently planned.

Authorization state may include more information than the currently visible screen strictly requires. This is acceptable when the state remains reasonably bounded and provides a simpler client architecture.

Applications should not prematurely divide authorization state into many narrowly scoped requests merely to avoid evaluating a small number of unused capabilities.

### Authorization Versus Domain Rules

Client display logic may depend on both:

1. What the current actor is authorized to do.
2. What the domain currently allows for the resource.

These are related but distinct questions.

For example:

```text
The actor may update reports they own.
```

is actor-specific authorization.

By contrast:

```text
Approved reports cannot be edited.
```

is primarily a domain or lifecycle rule.

The client may combine coarse authorization state with resource attributes. The helper below is deliberately narrow: it only demonstrates the `all` and `owned` paths. A production client must handle every variant of its application-defined scope union (for example `assigned` and `projects`).

```ts
export function canDisplayReportEditor(input: {
  report: FalconReport;
  actorId: FalconActorId;
  authorization: FalconAuthorizationState;
}): boolean {
  const { report, actorId, authorization } = input;

  const updateScope = authorization.capabilities.reports.update;

  // Illustrative: owned-only. Handle other FalconReportUpdateScope
  // variants explicitly in real clients.
  const actorMayUpdate =
    updateScope.type === "all" ||
    (updateScope.type === "scoped" &&
      updateScope.scope.type === "owned" &&
      report.ownerId === actorId);

  const reportIsEditable = report.status === "draft";

  return actorMayUpdate && reportIsEditable;
}
```

This client logic is advisory and exists to present an understandable UI.

The backend feature service remains authoritative and independently enforces:

- Actor-specific authorization through the authorization system.
- Domain invariants through the domain model or feature service.

For example:

```ts
await authorization.assertAllowed({
  principal,
  action: "report.update",
  resource: report,
});

report.assertEditable();

await reportRepository.save(report);
```

The fact that the frontend may reproduce simple domain checks does not make those checks authorization credentials or authoritative policy decisions.

### No Standard Resource-Specific Authorization State

Organization architecture does not require applications to expose separately calculated authorization state for every resource instance.

Resource-specific authorization projections are not the default because they can:

- Fragment client authorization into many requests.
- Make resource DTOs actor-relative.
- Reduce cacheability.
- Cause authorization evaluation to be repeated for large resource collections.
- Move simple domain display logic into unnecessary server endpoints.
- Add substantial API complexity for limited benefit.

Applications should ordinarily communicate coarse actor-specific authorization through the broad authorization state and allow clients to combine that state with ordinary resource attributes.

An application may introduce a resource-specific authorization projection when:

- The result depends on server-only information.
- Reproducing the display rule in clients would expose sensitive data.
- The actor-specific policy is too complex or unstable to reproduce safely.
- The relevant resource set is small and bounded.
- The application has another concrete reason that outweighs the added complexity.

Primero does not need to standardize this pattern in its initial client authorization-state model.

### No Generic Client Authorization Queries

Applications must not expose the underlying authorization framework directly through client methods such as:

```ts
falcon.checkAuthorization({
  action: "report.delete",
  resource: {
    type: "report",
    id: reportId,
  },
});
```

Clients should consume application-owned concepts:

```ts
authorizationState.capabilities.reports.update;
```

This prevents clients from:

- Depending on internal policy action names.
- Constructing arbitrary authorization questions.
- Becoming coupled to authorization resource modeling.
- Learning policy structure or resource information that should remain internal.
- Treating an allow result as a durable authorization grant.

### No Authoritative Capabilities in Authentication Tokens

Authentication tokens and sessions may carry stable authentication information needed to identify a principal. They must not normally carry authoritative application capabilities, mutable roles, purchase-derived entitlements, or usage limits.

Claims such as the following should not be treated as authoritative:

```ts
{
  canExportReports: true,
  hasProfessionalPlan: true,
}
```

These values may become stale because of:

- Subscription changes.
- Refunds or purchase revocation.
- Role changes.
- Membership removal.
- Account suspension.
- Resource-state changes.
- Usage-limit changes.
- Administrative overrides.

Clients refresh authorization state through the application facade rather than requiring authentication-token renewal whenever authorization facts change.

### Consequences

- Good, because clients receive strongly typed information tailored to the application domain.
- Good, because applications can use `none | all | scoped<Scope>` where it fits without forcing that model onto every capability.
- Good, because one authorization state may describe capabilities and limits across different scopes.
- Good, because clients do not need to duplicate broad actor-specific authorization policy.
- Good, because simple resource lifecycle display rules remain ordinary client and domain logic.
- Good, because protected operations remain secure even when client authorization state is stale.
- Good, because application APIs do not expose Protectiva, Primero, Solari, or another framework's public types.
- Good, because one initialization-time call supports a simple client architecture.
- Bad, because applications must define and maintain explicit authorization-state contracts.
- Bad, because clients may briefly display stale controls until state is refreshed.
- Bad, because client display helpers may partially repeat domain rules enforced on the server.
- Bad, because broad authorization state may evaluate or return some information that the current screen does not use.
- Neutral, because applications may choose different capability and limit representations while preserving the same architectural semantics.

### Confirmation

Compliance can be confirmed through API and architecture review.

Reviewers should verify that:

- Public client contracts use application-owned authorization-state types.
- Protected server operations independently authorize the requested operation.
- Domain invariants are independently enforced by the domain model or feature service.
- Authentication claims are not treated as authoritative mutable authorization state.
- Clients do not construct raw authorization framework checks.
- Capability and limit names belong to the application domain.
- One broad authorization-state operation supports the normal client initialization path.
- Resource-specific authorization endpoints are introduced only for a demonstrated need.
- `AuthorizationScope<Scope>` is used as an optional primitive rather than a mandatory shape for all capabilities.
- Authorization state includes point-in-time metadata such as `evaluatedAt`.

Integration tests should confirm that:

- A stale client capability does not allow an operation after server-side authorization has changed.
- A resource that violates a domain invariant remains invalid even when the actor has the broad capability.
- Different actors may receive different authorization states for the same application data.
- Refreshing authorization state after a purchase or membership change reflects the new actor-specific capabilities.

## Pros and Cons of the Options

### Do Not Expose Authorization Information to Clients

Clients render controls without advance authorization information and learn that an operation is unavailable only after attempting it.

- Good, because no authorization-state API must be designed.
- Good, because there is no risk that the client mistakes a capability projection for server authority.
- Bad, because clients cannot reliably hide, disable, or explain unavailable functionality.
- Bad, because failed operations become part of normal navigation and discovery.
- Bad, because upgrade and limit messaging becomes difficult.
- Bad, because clients may begin duplicating broad authorization heuristics.

### Embed Permissions, Capabilities, or Entitlements in Authentication Tokens or Sessions

Authentication credentials include authorization-related claims that clients inspect directly.

- Good, because the client receives claims during authentication.
- Good, because no separate authorization-state request is needed.
- Bad, because mutable authorization state becomes stale for the lifetime of the token or session.
- Bad, because authentication becomes coupled to application authorization and commerce.
- Bad, because changes may require token invalidation or reissuance.
- Bad, because multi-scope authorization can substantially increase token size and complexity.
- Bad, because resource state and usage limits often cannot be represented accurately in stable claims.

### Expose a Generic Client Authorization-Check API

The client constructs arbitrary action and resource checks against the authorization system.

- Good, because the API can answer a wide range of authorization questions.
- Good, because the application does not need to define a dedicated capability contract.
- Bad, because the frontend becomes coupled to the authorization framework's protocol.
- Bad, because policy actions and resource modeling become public API.
- Bad, because clients may probe arbitrary authorization questions.
- Bad, because application authorization refactors become client-breaking changes.
- Bad, because clients may treat an allow response as an authorization credential.

### Expose Many Narrowly Scoped or Resource-Specific Authorization-State Operations

Clients request separate state for accounts, projects, resources, or screens.

- Good, because each response can be small and narrowly relevant.
- Good, because resource-specific policy can be calculated entirely on the server.
- Bad, because client initialization and navigation require additional orchestration.
- Bad, because authorization becomes fragmented across many requests.
- Bad, because simple domain display rules may be over-centralized.
- Bad, because the design optimizes data loading before a concrete performance need exists.

### Expose One Application-Owned, Broadly Useful Authorization State Through the Application Facade

The application returns a typed, point-in-time authorization state suitable for normal client initialization.

- Good, because the public API uses application terminology.
- Good, because client contracts remain strongly typed and discoverable.
- Good, because common framework machinery can exist behind the facade.
- Good, because capabilities may cross scopes and use different representations.
- Good, because simple resource-state logic can remain client-side.
- Bad, because applications must define projection logic.
- Bad, because authorization-state refresh behavior must be designed.
- Bad, because the result may include some currently unused information.

## More Information

This ADR defines an organization-wide application architecture rule and does not require the use of Primero, Protectiva, or Solari.

When those Hyperdrive libraries are used:

- Protectiva authenticates the credential and resolves a principal.
- Primero evaluates authorization decisions and coordinates authorization-state construction.
- Solari provides purchase- and subscription-derived entitlements.
- The application owns the public authorization-state contract and facade operation.

The `AuthorizationScope<Scope>` abstraction was previously introduced to represent unrestricted, restricted, or absent access without requiring Primero to define the application's scope language. This ADR retains that model as an optional primitive for individual capability values rather than requiring one scope to govern an entire authorization state.

This ADR complements [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md) and [ADR 0044](0044-enforce-authorization-in-application-feature-services.md): those decisions place authentication and authoritative authorization inside the application; this decision describes how advisory authorization information is projected to clients for UI and UX purposes.

### Related ADRs

- [ADR 0005](0005-composition-roots-and-wiring-boundaries.md) — composition roots at the edges; thin hosts map transport to one self-contained application call.
- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — transport-agnostic backend packages, feature `application/` services, and thin hosts.
- [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md) — stable facade construction for the host-facing application API.
- [ADR 0016](0016-frontend-responsibility-areas-and-layered-boundaries.md) — frontend responsibility areas; clients consume application-facing APIs rather than inventing authorization policy.
- [ADR 0019](0019-vendor-specific-infrastructure-slices.md) — concrete auth/authz adapters belong in vendor infrastructure slices, not in the public facade contract.
- [ADR 0043](0043-authenticate-at-application-boundary-authorize-in-feature-services.md) — authenticate at the application boundary; authorize within feature services.
- [ADR 0044](0044-enforce-authorization-in-application-feature-services.md) — feature services as PEPs; server-side authorization remains authoritative even when client state is stale.
