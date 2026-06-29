---
status: accepted
date: 2026-06-16
decision-makers: Daniel Chiu
---

# Standardize on Playwright for Web End-to-End Testing

## Context and Problem Statement

Hyperdrive and related projects need a standard approach for end-to-end testing of web applications. Historically, Cypress was a strong candidate for JavaScript-heavy frontend projects because it offered a much better developer experience than Selenium-era browser automation. However, the web E2E testing ecosystem has shifted, and Playwright now offers a more general-purpose, CI-friendly, cross-browser, and composable testing platform.

The decision we need to make is: **what E2E testing framework should we standardize on for future web-based projects?**

## Decision Drivers

- We want a reliable default for greenfield web E2E testing across Hyperdrive projects.
- The framework should work naturally with TypeScript-heavy monorepos.
- Tests should compose well into shared helpers, fixtures, authentication utilities, and test-data factories.
- The framework should support modern browser behavior, including multiple browser contexts, multiple users, tabs, popups, redirects, and downloads.
- The framework should have strong CI ergonomics, including parallel execution, traces, screenshots, videos, retries, and useful failure artifacts.
- The framework should provide first-class cross-browser testing, including Chromium, Firefox, and WebKit.
- The framework should minimize long-term tool fragmentation across projects.
- The framework should remain viable even when the backend language is not TypeScript.

## Considered Options

- Playwright
- Cypress
- Selenium / WebDriver
- WebdriverIO
- Puppeteer
- Project-local or language-specific E2E testing choices

## Decision Outcome

Chosen option: "Playwright".

Justification: Playwright provides the best default balance of reliability, developer experience, cross-browser support, CI ergonomics, and architectural flexibility for modern web E2E testing. Its ordinary async programming model, browser context isolation, and first-class test runner make it a better long-term fit for Hyperdrive-style reusable test infrastructure than Cypress, Selenium, Puppeteer, or per-project bespoke choices.

For TypeScript-based Hyperdrive projects, the standard implementation should be **Playwright Test using TypeScript**. For projects primarily written in another language, Playwright remains the preferred tool, either through the official language binding or through a TypeScript-based E2E test package, depending on repository structure and team ownership.

### Consequences

- Good, because Hyperdrive projects will converge on one standard web E2E testing framework.
- Good, because shared E2E utilities can be extracted into reusable packages.
- Good, because Playwright supports realistic browser scenarios such as multiple users, independent sessions, popups, redirects, downloads, and cross-browser checks.
- Good, because Playwright's trace viewer, screenshots, videos, HTML reports, retries, and parallelism provide strong CI debugging ergonomics.
- Good, because Playwright uses ordinary async TypeScript, making helpers and fixtures easier to compose than Cypress command-chain abstractions.
- Good, because Playwright can be used across TypeScript, Python, Java, and .NET ecosystems when needed.
- Bad, because teams with existing Cypress expertise may need to learn Playwright's APIs and conventions.
- Bad, because Cypress may still provide a more polished interactive local debugging experience for some frontend-only workflows.
- Bad, because Cypress component testing may be more attractive in some frontend stacks; this ADR only standardizes web E2E testing, not necessarily component testing.
- Bad, because standardizing on Playwright may require migrating or rewriting any existing Cypress E2E tests over time.

### Confirmation

Compliance with this ADR should be confirmed through code review and project scaffolding:

- New web E2E test suites should use Playwright unless a follow-up ADR explicitly grants an exception.
- New Hyperdrive web app templates should include Playwright configuration by default.
- Shared E2E helpers should be implemented in Playwright-compatible packages.
- Cypress, Selenium, WebdriverIO, or Puppeteer should not be introduced for web E2E testing in new projects without documenting a project-specific exception.
- Existing non-Playwright E2E suites may remain temporarily, but should be considered candidates for migration when materially changed.

## Pros and Cons of the Options

### Playwright

Playwright is a modern browser automation and E2E testing framework with official support for Chromium, Firefox, and WebKit. It includes a test runner, fixtures, assertions, parallelism, traces, screenshots, videos, HTML reports, browser contexts, and strong TypeScript support.

- Good, because it is the strongest greenfield default for modern TypeScript web E2E testing.
- Good, because it supports ordinary `async` / `await` TypeScript instead of a custom command queue.
- Good, because it composes naturally with shared helpers, page objects, test fixtures, seeded test data, and API clients.
- Good, because browser contexts make multi-user and multi-session testing straightforward.
- Good, because it handles browser-level features such as tabs, popups, downloads, redirects, and cross-origin flows well.
- Good, because Chromium, Firefox, and WebKit are first-class testing targets.
- Good, because CI debugging artifacts are strong, especially Playwright traces.
- Good, because it has official bindings for multiple languages.
- Neutral, because Playwright's component testing story exists but is not necessarily the main reason to choose it.
- Bad, because teams familiar with Cypress may initially find Playwright less distinctive or less polished in local interactive mode.
- Bad, because adopting Playwright may require establishing new project conventions around fixtures, selectors, authentication setup, and test data.

### Cypress

Cypress is a mature JavaScript/TypeScript testing framework that historically provided a much better frontend testing experience than Selenium. It remains a strong tool, especially for frontend-centric teams and teams already invested in the Cypress ecosystem.

- Good, because it has excellent local interactive debugging ergonomics.
- Good, because its command log and time-travel style debugging can be very productive.
- Good, because `cy.intercept()` and `cy.session()` are ergonomic for many common frontend testing needs.
- Good, because it has a strong component testing story in several frontend ecosystems.
- Good, because many JavaScript frontend engineers already know it.
- Neutral, because Cypress remains a reasonable choice for existing Cypress-heavy projects.
- Bad, because Cypress uses a custom command queue rather than ordinary `async` / `await`, which can make shared helper abstractions less natural.
- Bad, because Cypress is less natural for multi-user, multi-session, popup, tab, and browser-context-heavy scenarios.
- Bad, because WebKit support has historically been less central than in Playwright.
- Bad, because advanced CI parallelization and orchestration often push teams toward Cypress Cloud or additional tooling.
- Bad, because choosing Cypress for new Hyperdrive projects would likely increase long-term friction relative to Playwright.

### Selenium / WebDriver

Selenium is the long-standing browser automation ecosystem and remains common in enterprise QA environments, especially where WebDriver infrastructure already exists.

- Good, because it is mature, widely known, and language-agnostic.
- Good, because it integrates with many existing enterprise browser grids and QA workflows.
- Good, because WebDriver remains an important browser automation standard.
- Neutral, because Selenium may still be appropriate in organizations with substantial existing Selenium infrastructure.
- Bad, because it generally has more setup and ceremony than Playwright for modern web app testing.
- Bad, because the developer experience is usually weaker for TypeScript product engineering teams.
- Bad, because it is not the best default for greenfield Hyperdrive-style projects.
- Bad, because standardizing on Selenium would likely slow down E2E test authoring and debugging compared with Playwright.

### WebdriverIO

WebdriverIO is a JavaScript/TypeScript automation framework built around WebDriver-compatible workflows and can be attractive when web and mobile automation need to share tooling.

- Good, because it offers a modern JS/TS developer experience on top of WebDriver-compatible infrastructure.
- Good, because it can be useful when Appium or native mobile testing is part of the same automation strategy.
- Good, because it may fit teams that need compatibility with existing browser/device farms.
- Neutral, because it may be a better fit for projects where web and native mobile E2E testing need one unified toolchain.
- Bad, because for pure web E2E testing, Playwright is simpler and more directly aligned with Hyperdrive's needs.
- Bad, because adopting WebdriverIO would introduce WebDriver complexity that is unnecessary for most Hyperdrive web projects.

### Puppeteer

Puppeteer is a browser automation library commonly used for Chrome/Chromium automation, screenshots, scraping, PDF generation, and specialized browser workflows.

- Good, because it is excellent for browser automation tasks such as screenshots, scraping, PDF generation, and one-off browser control.
- Good, because it is relatively lightweight when a full E2E test framework is not needed.
- Neutral, because Puppeteer can be useful inside supporting tools or scripts.
- Bad, because it is not as complete an E2E testing platform as Playwright Test.
- Bad, because it is not the best choice for cross-browser product confidence.
- Bad, because choosing Puppeteer for E2E would require assembling more test-runner, fixture, assertion, reporting, and CI behavior manually.

### Project-local or Language-specific E2E Testing Choices

Each project could choose its own E2E framework based on its primary language, team preference, or local constraints.

- Good, because individual projects could optimize for their own team preferences.
- Good, because Python-heavy, Java-heavy, or .NET-heavy projects could use test tooling that feels native to those ecosystems.
- Neutral, because Playwright itself supports multiple languages, so language-specific needs do not necessarily require a different browser automation framework.
- Bad, because per-project choice would fragment Hyperdrive's test infrastructure.
- Bad, because shared helpers, fixtures, authentication flows, and test data utilities would be harder to reuse.
- Bad, because engineers moving across projects would need to learn multiple E2E conventions.
- Bad, because the organization would lose the benefits of a single standard for CI behavior, debugging artifacts, and review expectations.

## More Information

This ADR standardizes **web E2E testing**, not all forms of testing.

Recommended default testing stack for TypeScript Hyperdrive projects:

- Unit tests: Vitest
- Component and UI behavior tests: Testing Library with Vitest, and optionally Storybook interaction tests
- Web E2E tests: Playwright Test
- Visual regression tests: Playwright screenshots, Chromatic, Percy, or Applitools where needed

E2E tests should be used selectively. They should cover critical user journeys and integration boundaries, not every business logic branch. In general, prefer unit, integration, and component tests for detailed logic coverage, and use Playwright E2E tests to confirm that the full application works when the frontend, backend, database, authentication, routing, and browser behavior are wired together.

Initial Playwright conventions should include:

- Prefer user-facing locators such as role, label, text, and accessible name.
- Use test IDs only where user-facing locators are insufficient or unstable.
- Keep tests isolated and avoid dependence on execution order.
- Prefer seeded test data or explicit setup helpers over fragile UI-only setup.
- Reuse authenticated storage state where appropriate.
- Use separate browser contexts for multi-user tests.
- Capture traces, screenshots, and videos on CI failures.
- Avoid adding broad E2E coverage where lower-level tests would provide faster and more precise feedback.

This ADR should be revisited if:

- Cypress, Selenium, WebdriverIO, or another tool materially changes the trade-off landscape.
- Playwright's maintenance, ecosystem health, or CI reliability significantly declines.
- Hyperdrive adopts a non-web platform where Playwright is not applicable.
- A specific project has unusual browser, device, compliance, or QA infrastructure constraints that warrant a documented exception.
