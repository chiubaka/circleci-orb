---
name: playwright-e2e
description: >-
  Thin playbook for web end-to-end testing under ADR 0040. Use when adding or
  changing web E2E suites, Playwright tests, critical user journeys, browser
  tests, or cross-browser CI.
---

# Playwright web E2E

## Goal

Ship critical web user journeys with Playwright as the org default, without replacing unit/integration TDD or introducing competing E2E frameworks for new suites.

## Cite

- `org/docs/adr/0040-standardize-on-playwright-for-web-end-to-end-testing.md`

## Defaults

- Prefer **Playwright Test + TypeScript** for org web apps.
- Do **not** introduce Cypress, Selenium, WebdriverIO, or Puppeteer for **new** web E2E suites without an ADR exception.
- Prefer real user journeys over exhaustive UI coverage. Pair unit/integration work with `test-driven-development`.

## Practices

- Use **browser contexts** for multi-user / multi-session scenarios.
- Use **fixtures** for auth and seed data.
- Capture **traces / screenshots** on failure for CI debugging.
- Prefer **user-facing locators** (role, label, text, accessible name) for stability over brittle CSS chains. Use **test IDs only** when those locators are insufficient or unstable (high-level; no mandatory page-object framework).
- Move shared helpers into reusable packages when patterns stabilize (see ADR confirmation bullets).

## When not to use

- Unit- or component-only changes with no web journey impact.
- Non-web surfaces (CLI, workers without a browser UI, pure library packages).

## Related

- `test-driven-development`
- `review`
