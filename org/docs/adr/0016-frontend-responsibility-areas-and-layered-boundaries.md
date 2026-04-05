---
status: accepted
date: 2026-03-29
decision-makers: Daniel Chiu
---

# ADR 0016: Frontend responsibility areas and layered boundaries

## Context and Problem Statement

As frontend codebases grow in size and complexity, organizing code purely by technical type (for example `components/`, `hooks/`, and `utils/`) or by thin feature slices leads to unclear ownership, scattered logic, and poor maintainability.

Coding agents also perform better when architectural boundaries are explicit and predictable. We need a frontend architecture that:

- Encourages clear ownership and separation of concerns
- Keeps business logic independent from presentation frameworks
- Supports cross-domain composition without ambiguity
- Remains practical for real-world UI development, including interaction state
- Scales to multiple presentation environments such as web and React Native
- Avoids “junk drawer” directories like undifferentiated `utils` and `shared`

**Question:** How should we structure frontend code to balance domain clarity, composability, and practical usability?

## Relationship to existing org ADRs

This ADR is the **frontend complement** to [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md): top-level **responsibility areas** (feature modules) use the same **per-slice** `domain/` / `application/` / `infrastructure/` vocabulary, extended with a first-class **`presentation/`** layer for UI-facing code and a constrained **`app/`** (or equivalent) subtree for **routing, top-level layout, and cross-area screen assembly**—the same **thin composition at the edge** idea as the server host in ADR 0007 and [ADR 0005](0005-composition-roots-and-wiring-boundaries.md).

- **Public surfaces** and **barrel discipline** follow [ADR 0008](0008-barrel-files-public-api-boundaries.md): consumers depend on another area **only** through intentional exports (feature root and layer barrels), not deep file paths.
- **Cross-layer visibility** inside an area matches ADR 0007: sibling layers import **through** `domain/`, `application/`, `infrastructure/`, and **`presentation/`** layer barrels (**required** whenever that layer directory exists; see [ADR 0008](0008-barrel-files-public-api-boundaries.md) **first-class slice** rule)—not by skipping barrels to reach private files.
- **Import specifiers** in TypeScript monorepos follow [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md): `~/…` for production code under a package’s `src/`, and scoped **`@scope/pkg`** imports for **cross-package** public APIs. This ADR’s code sketches use `~/` **illustratively** inside one client package; they are not a second, conflicting alias rule.
- **Tests** that need stable paths into `test/` use `#/` per [ADR 0011](0011-test-import-alias-hash-root.md) (not shown in every sketch below).
- **Orchestration** in `application/` (for example `*Service` classes) aligns with [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md) and the class vs function heuristics in [ADR 0013](0013-use-of-classes-vs-module-level-functions-and-interfaces.md).
- **File granularity** (for example one focused function per module where it helps discovery) aligns with [ADR 0009](0009-prefer-small-focused-files.md).
- **New work** should **match idioms** of neighboring code per [ADR 0006](0006-consistency-and-extension-for-new-features.md) unless a deliberate exception is documented.
- **Package-level** centralized composition patterns may additionally follow [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md) at the client package edge where that shape applies.

**Portability:** Trees use `src/` as a shorthand; in a monorepo the same layout may live under `packages/<app>/src/` (or similar). Exact package names and ESLint boundary plugins are **repository-specific**; this ADR records **invariants**, not one repo’s config.

## Decision Drivers

- Clear ownership and maintainability at scale
- Strong separation of business logic from presentation
- Predictable structure for coding agents
- Support for cross-domain composition without ambiguity
- Avoidance of “junk drawer” directories
- Flexibility across presentation environments
- Avoidance of over-architecture or unnecessary ceremony
- Consistency with DDD-oriented and hexagonal-in-spirit conventions in [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md)

## Considered Options

- Feature-based structure (flat feature folders)
- Centralized pages/screens in `app` only
- Responsibility-area-based structure with layered internals (DDD-inspired, aligned with ADR 0007)
- Hybrid models combining features, entities, and app layers without a single placement rule
- Cross-domain features under `app/features`

## Decision Outcome

**Chosen option:** responsibility-area-based structure with layered internals (`domain/`, `application/`, `infrastructure/`, `presentation/`) and a constrained **`app/`** composition layer for routing, top-level layout, providers at the client edge, and genuinely cross-domain screen composition.

**Justification:** This approach provides strong ownership boundaries, isolates business logic from presentation, and supports both domain-driven design and practical UI development. It avoids ambiguity introduced by feature-only or centralized-page structures while remaining flexible for cross-domain composition. It gives coding agents repeatable placement rules and stays aligned with **barrel-gated** imports in [ADR 0008](0008-barrel-files-public-api-boundaries.md) and slice layering in [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md).

### Consequences

- Good, because responsibility areas provide clear ownership and reduce ambiguity
- Good, because business logic can stay isolated from presentation frameworks
- Good, because agents have predictable placement rules
- Good, because cross-domain composition is explicitly modeled (thin glue in `app/`, durable flows as top-level areas)
- Bad, because placement decisions require judgment rather than being purely mechanical
- Bad, because some duplication of structure (for example screens living under an area and route tables under `app/`) requires clear rules
- Bad, because strict boundaries require discipline through linting, code review, and export curation per [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and [ADR 0008](0008-barrel-files-public-api-boundaries.md)

### Confirmation

Compliance can be validated via:

- **Code review** enforcing: no durable business rules owned only by `app/`; `presentation/` does not become the home for domain invariants; cross-area imports use **public barrels** only
- **Lint rules** (where adopted): disallow imports outside module public surfaces; restrict cross-layer dependencies; block deep cross-module paths—aligned with ADR 0007/0008
- **Periodic architectural review:** ensure `app/` is not becoming a second feature layer; ensure `core/` is not becoming a dumping ground; ensure responsibility areas stay coherent

## Pros and Cons of the Options

### Feature-based structure (flat feature folders)

Organizes code by UI features or pages.

- Good, because simple and intuitive initially
- Good, because it aligns with small app development
- Bad, because feature boundaries are often unclear or unstable
- Bad, because business logic gets scattered across features
- Bad, because stable domain ownership is weaker over time

### Centralized `app/pages` or `app/screens` only

All screens live under `app`.

- Good, because entry points are easy to discover
- Good, because routing can be centralized
- Bad, because `app` tends to become the true feature layer
- Bad, because responsibility areas degrade into support libraries
- Bad, because cross-domain coordination logic accumulates in `app`

### Responsibility-area-based structure with layered internals (chosen)

Top-level modules represent domain or responsibility areas, each internally layered per ADR 0007, plus `presentation/`.

- Good, because ownership boundaries are strong and match backend instincts
- Good, because business logic can stay isolated from UI and framework details
- Good, because module public surfaces stay explicit via barrels
- Neutral, because it requires consistent application of placement rules
- Bad, because initial structure may feel heavier than a flat frontend layout
- Bad, because cross-domain composition must be handled explicitly

### Hybrid models combining features, entities, and app layers

Uses several top-level organizational axes at once (for example `features/`, `entities/`, and `app/`).

- Good, because some relationships can be modeled explicitly
- Bad, because placement rules become harder to teach and enforce
- Bad, because multiple top-level taxonomies compete with one another

### `app/features` cross-domain modules

Introduces a second feature layer under `app` for cross-domain concerns.

- Good, because it names cross-cutting UI
- Bad, because it introduces a competing taxonomy and ambiguous ownership
- Bad, because `app/` risks becoming a parallel module system

## Decision Details

### Top-level structure (illustrative)

```text
src/
  app/
    navigation/
    presentation/
      screens/
      components/
      providers/
    index.ts

  core/
    presentation/
      components/
      layouts/
    lib/
    types/
    testing/
    index.ts

  <responsibility-area>/     # e.g. auth, users, invoices — repeat per area
    domain/
    application/
    infrastructure/
    presentation/
    index.ts
```

Each responsibility area includes **layer barrels** (`domain/index.ts`, `application/index.ts`, `infrastructure/index.ts`, `presentation/index.ts`) and a **feature root** `index.ts`, per [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) and [ADR 0008](0008-barrel-files-public-api-boundaries.md). **Within** a layer, files may import private siblings via **relative** paths; barrels govern **cross-layer** and **cross-feature** visibility.

**Composition hosts (`app/` or equivalent)** follow the same **slice-barrel** idea with a **custom slice set**: they often omit `domain/`, `application/`, and `infrastructure/`, but first-class subdirectories that encapsulate a cohesive concern—typically **`presentation/`** (root UI assembly, providers, shell screens), **`navigation/`**, **`lib/`**, and similarly scoped buckets—each define **`index.ts`** as that slice’s public surface. The host’s **root** `app/index.ts` (or `index.tsx`) aggregates what may leave `app/` toward the rest of the client; **cross-slice** imports **inside** `app/` use slice barrels (for example the root re-exports from `./presentation`, not from deep paths under `./presentation/...` unless the importer stays **within** the same slice). This is the same **first-class slice directory** rule as in ADR 0008, not a one-off exception for a particular folder name.

When `infrastructure/` grows multiple adapter families, use **`infrastructure/<category>/`** subtrees with **category barrels**, as in ADR 0007 (for example `http/`, `localStorage/`).

### Layer responsibilities

- **`domain/`** — business rules, entities, invariants, selectors, predicates, policies, and other framework-free domain logic
- **`application/`** — class-based services and orchestration for user or system intent (ports/concrete wiring per ADR 0007)
- **`infrastructure/`** — concrete clients, persistence mechanisms, DTO mappers, and other external adapters
- **`presentation/`** — screens, components, hooks, layouts, providers, context wiring, and interaction state
- **`app/`** — route registration, top-level layout composition, top-level navigation, global providers, and genuinely cross-domain screen composition
- **`core/`** — foundational cross-cutting code not owned by any responsibility area; same **high bar** as `core` in ADR 0007—not a default dump

### `presentation/` internal shape (illustrative)

```text
presentation/
  context/
  screens/
  components/
  hooks/
  layouts/
  index.ts                 # layer barrel: what may leave presentation cross-layer or cross-feature
```

### Naming decisions

- Use **`screens`** instead of **`pages`** where “page” is too tied to one web router
- Use **`presentation`** instead of a vague **`ui`** when the layer includes interaction concerns
- Use **`core/lib`** (or similarly **named** buckets) instead of a generic **`utils`** root
- Prefer explicit directory names like `selectors/`, `predicates/`, and `policies/` where they improve clarity
- Prefer **one function per file** where it improves discoverability, consistent with [ADR 0009](0009-prefer-small-focused-files.md)
- Standardize on **module-level context hooks** named `use<Module>` (for example `useUsers`, `useInvoices`, `useAuth`) as the primary presentation-facing API for an area’s application surface

## Placement Rules

### Rule 1: Ownership follows primary reason to change

Code should live where behavioral changes are most likely to originate.

- Put a screen in a responsibility area when its data, actions, and most future changes are primarily driven by that area
- Put a screen in `app/` when it mainly coordinates multiple areas without one clearly dominating
- Create a new top-level module when a cross-domain flow becomes durable enough to have its own concepts, workflows, and rules

### Rule 2: `app/` is for composition, not ownership

`app/` **owns:** route registration; navigation integration; top-level layouts; global providers; **thin** cross-domain screen composition.

`app/` **does not own:** responsibility-area domain logic; reusable workflows that belong in one area; domain-specific components clearly owned by one module; a generic second feature layer.

### Rule 3: Cross-domain workflows

- Thin coordination lives in `app/`
- Deep or durable coordination becomes a new top-level responsibility area

Examples:

- Account overview that composes existing module summaries → `app/presentation/screens/`
- Organization onboarding with durable concepts and state transitions → `onboarding/` (full layer stack)

### Rule 4: Public surfaces are explicit and curated

- Every top-level module defines an explicit public barrel in `index.ts`
- **Layer** slices (`domain/`, `application/`, `infrastructure/`, `presentation/`) and other **first-class slice** directories under a module (including under `app/`) define barrels per ADR 0007/0008
- Cross-module imports go through the **feature root barrel** (for example `~/users`) or another **documented** public surface—not through deep paths into internals
- If importing through a public surface creates a circular dependency, treat that as a **design smell** to resolve rather than routinely bypassing barrels

### Rule 5: Cross-module presentation composition only through public exports

**Allowed** (illustrative `~/` usage inside one client package per [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md)):

```ts
import { UserAvatar, UserSummaryCard } from '~/users';
```

**Not allowed:**

```ts
import { InternalUserRow } from '~/users/presentation/components/InternalUserRow';
```

**Cross-package** consumption uses **`@scope/pkg`** public APIs, not `~/` paths into another package’s filesystem.

### Rule 6: Utilities should be named by role, not hidden behind generic `utils`

- Cross-cutting technical utilities belong in `core/lib` (only when they meet the `core` bar)
- Domain-meaningful pure helpers belong in the relevant module and should be named by role
- Avoid generic `utils` directories by default; keep single-use helpers local until real reuse exists

Examples:

```text
users/domain/
  selectors/
    getDisplayName.ts
  predicates/
    isInvitableUser.ts

invoices/domain/
  policies/
    canArchiveInvoice.ts
  selectors/
    getInvoiceDisplayStatus.ts
```

Prefer that over:

```text
users/domain/utils/userUtils.ts
invoices/domain/utils/invoiceUtils.ts
```

### Rule 7: Presentation should consume module APIs through provider/context boundaries

- Responsibility areas expose application behavior to React through provider/context wiring where that pattern fits
- Prefer a high-level hook such as `useUsers`, `useInvoices`, or `useAuth` as the primary presentation language
- Narrower hooks may wrap the high-level hook when useful

## Complete example

The following example is **illustrative**. Import paths use **`~/`** as in [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md). **Cross-layer** imports use **layer barrels**; **within** `presentation/`, **relative** imports between private siblings match [ADR 0008](0008-barrel-files-public-api-boundaries.md).

### Example directory tree

```text
src/
  app/
    navigation/
      routeDefinitions.ts
      routes.tsx
    presentation/
      context/
        AppProviders.tsx
      screens/
        AccountOverviewScreen.tsx
      components/
        TopNavigation.tsx
        AccountMenu.tsx
      providers/
        AppQueryClientProvider.tsx
        AppThemeProvider.tsx
      index.ts
    index.ts

  core/
    presentation/
      components/
        Button.tsx
        Modal.tsx
        PageHeader.tsx
      layouts/
        TwoColumnLayout.tsx
      index.ts
    lib/
      dates/
        formatDate.ts
      collections/
        groupBy.ts
      strings/
        titleCase.ts
    types/
      Result.ts
      AsyncState.ts
    testing/
      renderWithProviders.tsx
    index.ts

  auth/
    domain/
      entities/
        Session.ts
        AuthenticatedUser.ts
      predicates/
        isAuthenticated.ts
      index.ts
    application/
      AuthService.ts
      AuthClient.ts
      index.ts
    infrastructure/
      RestApiAuthClient.ts
      sessionDtoMappers.ts
      index.ts
    presentation/
      context/
        AuthContext.tsx
        AuthProvider.tsx
      components/
        SignOutButton.tsx
      hooks/
        useAuth.ts
        useCurrentSession.ts
        useSignOut.ts
      screens/
        SignInScreen.tsx
      index.ts
    index.ts

  users/
    domain/
      entities/
        User.ts
        UserProfile.ts
      selectors/
        getDisplayName.ts
      predicates/
        isInvitableUser.ts
      index.ts
    application/
      UsersService.ts
      UsersClient.ts
      index.ts
    infrastructure/
      RestApiUsersClient.ts
      userDtoMappers.ts
      index.ts
    presentation/
      context/
        UsersContext.tsx
        UsersProvider.tsx
      components/
        UserAvatar.tsx
        UserBadge.tsx
        UserSummaryCard.tsx
      hooks/
        useUsers.ts
        useUserProfile.ts
        useUpdateUserProfile.ts
      screens/
        UserProfileScreen.tsx
      layouts/
        UserProfileLayout.tsx
      index.ts
    index.ts

  invoices/
    domain/
      entities/
        Invoice.ts
        InvoiceStatus.ts
      policies/
        canArchiveInvoice.ts
      selectors/
        getInvoiceDisplayStatus.ts
      index.ts
    application/
      InvoicesService.ts
      InvoicesClient.ts
      index.ts
    infrastructure/
      RestApiInvoicesClient.ts
      invoiceDtoMappers.ts
      index.ts
    presentation/
      context/
        InvoicesContext.tsx
        InvoicesProvider.tsx
      components/
        InvoiceSummaryCard.tsx
        InvoiceStatusBadge.tsx
        InvoiceLineItemsTable.tsx
        InvoiceOwnerSummary.tsx
      hooks/
        useInvoices.ts
        useInvoiceDetail.ts
        useArchiveInvoice.ts
      screens/
        InvoiceDetailScreen.tsx
        InvoiceListScreen.tsx
      layouts/
        InvoiceDetailLayout.tsx
      index.ts
    index.ts

  onboarding/
    domain/
      entities/
        OnboardingStep.ts
      policies/
        canAdvanceToNextStep.ts
      index.ts
    application/
      OnboardingService.ts
      OnboardingDraftClient.ts
      index.ts
    infrastructure/
      BrowserOnboardingDraftClient.ts
      index.ts
    presentation/
      context/
        OnboardingContext.tsx
        OnboardingProvider.tsx
      hooks/
        useOnboarding.ts
      screens/
        OrganizationOnboardingScreen.tsx
      index.ts
    index.ts
```

### Example A: Responsibility-area-owned screen

`InvoiceDetailScreen.tsx` belongs in `invoices/presentation/screens/`.

Supporting files (relative **within** `presentation/`; **cross-layer** via barrels):

```text
invoices/application/InvoicesService.ts
invoices/application/InvoicesClient.ts
invoices/presentation/context/InvoicesProvider.tsx
invoices/presentation/hooks/useInvoices.ts
invoices/presentation/hooks/useInvoiceDetail.ts
invoices/presentation/components/InvoiceStatusBadge.tsx
```

```ts
// invoices/application/InvoicesClient.ts
import type { Invoice } from '~/invoices/domain';

export interface InvoicesClient {
  getInvoiceDetail(invoiceId: string): Promise<Invoice | null>;
  archiveInvoice(invoiceId: string): Promise<void>;
}
```

```ts
// invoices/application/InvoicesService.ts
import { canArchiveInvoice } from '~/invoices/domain';
import type { InvoicesClient } from './InvoicesClient';

export class InvoicesService {
  public constructor(private readonly invoicesClient: InvoicesClient) {}

  public async getInvoiceDetail(invoiceId: string) {
    return this.invoicesClient.getInvoiceDetail(invoiceId);
  }

  public async archiveInvoice(input: { invoiceId: string }): Promise<void> {
    const invoice = await this.invoicesClient.getInvoiceDetail(input.invoiceId);

    if (!invoice) {
      throw new Error('Invoice not found.');
    }

    if (!canArchiveInvoice(invoice)) {
      throw new Error('Invoice cannot be archived.');
    }

    await this.invoicesClient.archiveInvoice(invoice.id);
  }
}
```

**Note:** Same-layer imports may use **relative** paths between private siblings (see [ADR 0008](0008-barrel-files-public-api-boundaries.md)); the `domain` import uses the **`~/invoices/domain`** barrel because it crosses into `domain/`.

```tsx
// invoices/presentation/context/InvoicesProvider.tsx
import { createContext, useMemo, type ReactNode } from 'react';
import { InvoicesService } from '~/invoices/application';
import { RestApiInvoicesClient } from '~/invoices/infrastructure';

export const InvoicesContext = createContext<InvoicesService | null>(null);

export interface InvoicesProviderProps {
  children: ReactNode;
}

export function InvoicesProvider({ children }: InvoicesProviderProps) {
  const invoicesService = useMemo(() => {
    const invoicesClient = new RestApiInvoicesClient();
    return new InvoicesService(invoicesClient);
  }, []);

  return (
    <InvoicesContext.Provider value={invoicesService}>
      {children}
    </InvoicesContext.Provider>
  );
}
```

```ts
// invoices/presentation/hooks/useInvoices.ts
import { useContext } from 'react';
import { InvoicesContext } from '../context/InvoicesContext';

export function useInvoices() {
  const invoicesService = useContext(InvoicesContext);

  if (!invoicesService) {
    throw new Error('useInvoices must be used within an InvoicesProvider.');
  }

  return invoicesService;
}
```

```tsx
// invoices/presentation/screens/InvoiceDetailScreen.tsx
import { InvoiceLineItemsTable } from '../components/InvoiceLineItemsTable';
import { InvoiceStatusBadge } from '../components/InvoiceStatusBadge';
import { useInvoiceDetail } from '../hooks/useInvoiceDetail';

export function InvoiceDetailScreen() {
  const invoiceDetailQuery = useInvoiceDetail();

  if (invoiceDetailQuery.isLoading) {
    return <div>Loading…</div>;
  }

  if (!invoiceDetailQuery.data) {
    return <div>Invoice not found.</div>;
  }

  return (
    <div>
      <h1>{invoiceDetailQuery.data.invoiceNumber}</h1>
      <InvoiceStatusBadge status={invoiceDetailQuery.data.status} />
      <InvoiceLineItemsTable lineItems={invoiceDetailQuery.data.lineItems} />
    </div>
  );
}
```

### Example B: App-owned cross-domain screen

`AccountOverviewScreen.tsx` belongs in `app/presentation/screens/`. It composes **public** exports from other areas through **feature barrels**.

```tsx
// app/presentation/screens/AccountOverviewScreen.tsx
import { PageHeader } from '~/core';
import { SignOutButton } from '~/auth';
import { InvoiceSummaryCard } from '~/invoices';
import { UserSummaryCard } from '~/users';

export function AccountOverviewScreen() {
  return (
    <div>
      <PageHeader title="Account Overview" />
      <UserSummaryCard />
      <InvoiceSummaryCard />
      <SignOutButton />
    </div>
  );
}
```

### Example C: Route registration stays in `app`

Even when a screen is owned by a responsibility area, route registration stays centralized under `app/navigation`.

```tsx
// app/navigation/routes.tsx
import { AccountOverviewScreen } from '~/app';
import { OrganizationOnboardingScreen } from '~/onboarding';
import { InvoiceDetailScreen, InvoiceListScreen } from '~/invoices';
import { UserProfileScreen } from '~/users';

export const routes = [
  {
    path: '/account',
    element: <AccountOverviewScreen />,
  },
  {
    path: '/invoices',
    element: <InvoiceListScreen />,
  },
  {
    path: '/invoices/:invoiceId',
    element: <InvoiceDetailScreen />,
  },
  {
    path: '/profile',
    element: <UserProfileScreen />,
  },
  {
    path: '/onboarding',
    element: <OrganizationOnboardingScreen />,
  },
];
```

### Example D: Public surfaces via barrels

**Presentation layer barrel** (cross-feature consumption of selected presentation symbols):

```ts
// users/presentation/index.ts
export { UsersContext } from './context/UsersContext';
export { UsersProvider } from './context/UsersProvider';
export { UserAvatar } from './components/UserAvatar';
export { UserBadge } from './components/UserBadge';
export { UserSummaryCard } from './components/UserSummaryCard';
export { useUsers } from './hooks/useUsers';
export { useUserProfile } from './hooks/useUserProfile';
export { useUpdateUserProfile } from './hooks/useUpdateUserProfile';
export { UserProfileScreen } from './screens/UserProfileScreen';
```

**Feature root** re-exports **from layer barrels** (aggregate only what may leave the module):

```ts
// users/index.ts
export type { User, UserProfile } from './domain';
export { getDisplayName, isInvitableUser } from './domain';
export { UsersService, UsersClient } from './application';
export { RestApiUsersClient } from './infrastructure';
export {
  UsersContext,
  UsersProvider,
  UserAvatar,
  UserBadge,
  UserSummaryCard,
  useUsers,
  useUserProfile,
  useUpdateUserProfile,
  UserProfileScreen,
} from './presentation';
```

Keep this surface **small**; avoid turning the feature root into a full catalog (see [ADR 0008](0008-barrel-files-public-api-boundaries.md)).

### Example E: Cross-module presentation composition that is allowed

```tsx
// invoices/presentation/components/InvoiceOwnerSummary.tsx
import { UserAvatar } from '~/users';

export interface InvoiceOwnerSummaryProps {
  ownerName: string;
  ownerAvatarUrl: string | null;
}

export function InvoiceOwnerSummary({
  ownerName,
  ownerAvatarUrl,
}: InvoiceOwnerSummaryProps) {
  return (
    <div>
      <UserAvatar displayName={ownerName} avatarUrl={ownerAvatarUrl} />
      <span>{ownerName}</span>
    </div>
  );
}
```

This is acceptable because the import goes through the **`users`** feature public surface, not internal paths.

### Example F: Cross-domain workflow promoted to a first-class module

`OrganizationOnboardingScreen` belongs in `onboarding/` when the workflow is deep enough to own concepts and state transitions—not under `app/features/…`.

```ts
// onboarding/application/OnboardingService.ts
export class OnboardingService {
  public async completeOrganizationSetup(): Promise<void> {
    // Coordinates organization creation, initial admin invitation,
    // initial user setup, and onboarding completion.
  }
}
```

### Example G: Shared presentation primitives in `core`

App-wide primitives with **no** natural responsibility area belong in `core/presentation/`.

```text
core/presentation/components/Button.tsx
core/presentation/components/Modal.tsx
core/presentation/components/PageHeader.tsx
```

They should remain domain-agnostic; a domain-specific component such as `InvoiceStatusBadge` does not belong in `core` even if reused heavily inside `invoices/`.

## Practical guidance for agents and reviewers

When placing new code, ask in order:

1. Is this fundamentally owned by a single responsibility area? → place it in that module
2. Is this primarily thin composition across several modules? → place it in `app/`
3. Is this cross-domain concern deep enough to have its own concepts and lifecycle? → new top-level module
4. Is this reusable presentation from another module? → import only through that module’s **public** barrel (or documented public surface)
5. Is this generic technical functionality with no domain ownership? → consider `core/lib` or `core/presentation` only if the **`core` bar** is met

Principles:

- Implementation ownership follows **primary reason to change**
- Route visibility **alone** does not determine implementation ownership
- `app/` is a composition layer, not a second feature layer
- `core/` is foundational, not a dumping ground
- Public module exports are part of the architecture, not just import ergonomics

## More Information

### Related ADRs

- [ADR 0007](0007-vertical-feature-modules-hexagonal-slices-and-packages.md) — vertical modules, per-slice layers, `core` discipline, packages and thin host
- [ADR 0008](0008-barrel-files-public-api-boundaries.md) — barrels as public API boundaries
- [ADR 0005](0005-composition-roots-and-wiring-boundaries.md) — composition at system edges
- [ADR 0006](0006-consistency-and-extension-for-new-features.md) — extend by matching existing idioms
- [ADR 0009](0009-prefer-small-focused-files.md) — small, focused files
- [ADR 0010](0010-import-specifier-conventions-for-monorepo-packages.md) — `~/` vs `@scope/pkg`
- [ADR 0011](0011-test-import-alias-hash-root.md) — `#/` for tests
- [ADR 0012](0012-classes-as-primary-responsibility-boundaries.md) — classes as primary responsibility boundaries
- [ADR 0013](0013-use-of-classes-vs-module-level-functions-and-interfaces.md) — classes vs functions vs interfaces
- [ADR 0014](0014-stable-facade-construction-and-centralized-composition.md) — stable facade composition at package scale
- [ADR 0018](0018-index-barrels-re-export-only.md) — re-export-only `index` barrels where enforced
- [ADR 0001](0001-hexagonal-architecture-with-ddd-naming.md) — historical layout context; superseded for **where** layers live by ADR 0007

Illustrative backend layout and alias usage also appear under `org/docs/adr/examples/` (for example [feature-module-layout-example.md](examples/feature-module-layout-example.md), [import-aliases-example.md](examples/import-aliases-example.md)).

### When to revisit

- `app/` accumulates business logic or durable workflows that belong in an area
- `core/` becomes a generic sink
- Cross-module dependencies bypass barrels or form cycles
- Modules sprawl without internal structure, or agents systematically misplace code
