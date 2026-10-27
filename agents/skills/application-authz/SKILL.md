---
name: application-authz
description: >-
  Agent runbook for authentication and authorization work aligned to org ADRs
  0043–0045. Use when changing authentication, authorization, credentials,
  sessions, secured facade methods, client capability/limit UI, or adapters
  such as Protectiva/Primero (illustrative).
---

# Application authentication and authorization

## Goal

Keep hosts thin, authenticate at the application boundary, authorize in feature `application/` services, and treat client authorization state as advisory UI projection only—never as a credential.

## Normative ADRs

Cite these paths; do not rephrase ADR text as agent mandates inside the ADR files:

- `org/docs/adr/0043-authenticate-at-application-boundary-authorize-in-feature-services.md`
- `org/docs/adr/0044-enforce-authorization-in-application-feature-services.md`
- `org/docs/adr/0045-expose-application-owned-authorization-state-to-clients.md`

## Checklist

- [ ] **Hosts stay thin** — Parse transport material (headers, cookies, protocol metadata) only; do **not** validate sessions or resolve trusted actors in the host.
- [ ] **One named facade operation per external use case** — Credentials are application-owned types on that operation; hosts do not orchestrate multiple application calls for one business use case.
- [ ] **Authenticate + resolve actor at the application boundary** — Feature services receive actor/execution context, not raw credentials.
- [ ] **Authorize in feature `application/` services** — Fail-closed; repositories are not the sole authz boundary.
- [ ] **Client authorization state (ADR 0045)** — Advisory UI projection only; never a credential. Every protected server operation re-authorizes.
- [ ] **Tests** — May inject actors/execution contexts into feature services without manufacturing tokens.
- [ ] **Untrusted inputs** — Pair with `runtime-boundary-validation-zod` at trust boundaries.

Protectiva, Primero, and similar names are **examples only**. Prefer portable wording; do not require specific package names unless the target repo already depends on them.

## Related

- `review` (security section)
- `feature-module-change-playbook`
- `external-api-integration`
- `runtime-boundary-validation-zod`
