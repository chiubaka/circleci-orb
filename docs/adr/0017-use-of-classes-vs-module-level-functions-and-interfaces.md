---
status: accepted
date: 2026-03-27
decision-makers: Daniel Chiu
---

# Use of Classes vs Module-Level Functions and Interfaces

## Context and Problem Statement

TypeScript supports both object-oriented and functional/module-oriented patterns. Without clear guidelines, code can become inconsistent, mixing classes, module-level functions, and interfaces in ways that obscure structure and intent.

We need guidance on when to use classes, module-level functions, and interfaces to maintain clarity without introducing unnecessary abstraction.

## Decision Drivers

* Maintain structural clarity and consistency
* Avoid over-abstraction and premature generalization
* Preserve simplicity for pure logic
* Keep APIs minimal and intentional
* Enable evolution of abstractions under real design pressure

## Considered Options

* Prefer classes everywhere
* Prefer module-level functions everywhere
* Use a hybrid approach with clear heuristics

## Decision Outcome

Chosen option: "Use a hybrid approach with clear heuristics".

Justification: Both classes and module-level functions are valuable tools. The key is to use each where it provides the most clarity, while avoiding unnecessary abstraction or ceremony.

### Guidelines

#### Classes

Use classes when:

* Defining a clear area of responsibility or architectural boundary
* Orchestrating multi-step workflows
* Managing dependencies (for example, via constructor injection)
* Providing a stable public API

Within classes:

* Prefer `private` or `private static` methods for implementation details
* Avoid exporting helper functions solely for testing
* Test primarily through public methods
* In class-named orchestration files (for example, `*Evaluator.ts`, `*Service.ts`), treat the class as the default architectural boundary

Precedence note:

* When this ADR's hybrid guidance and ADR 0016 could both apply, prefer ADR 0016 for class-owned orchestration modules. In those files, module-level exports should be limited to true shared utilities, not class-local helpers.

#### Module-Level Functions

Use module-level functions when:

* Implementing pure transformations or small composable logic
* Defining utilities that are genuinely reusable across multiple domains
* The logic does not benefit from object identity or lifecycle

Module-level functions should:

* Remain internal unless they are true shared utilities
* Be promoted to shared utility modules only when reuse emerges

#### Interfaces

Use interfaces when:

* There is a real need for substitutability (multiple implementations)
* Defining a boundary between domains or infrastructure (for example, ports/adapters)
* The abstraction itself is important for protecting a boundary

Avoid interfaces when:

* There is only a single implementation with no real pressure for variation
* They are introduced solely for hypothetical future flexibility

### Consequences

* Good, because code remains flexible without becoming over-engineered
* Good, because abstraction is introduced when justified by real pressure
* Good, because structure is preserved without forcing everything into classes
* Bad, because some decisions remain subjective and require judgment
* Bad, because inconsistency may arise if guidelines are not followed carefully

### Confirmation

* Code reviews should challenge:
  * whether a class represents a real responsibility
  * whether an interface is justified by actual variation or boundary protection
  * whether module-level functions are appropriately scoped
* Helper functions exported only for tests should be refactored
* Refactoring toward interfaces or shared utilities should be driven by demonstrated reuse or variation

## Pros and Cons of the Options

### Prefer classes everywhere

* Good, because structure and ownership are always explicit
* Good, because consistency across the codebase is high
* Good, because encapsulation is enforced by default
* Neutral, because dependency injection patterns are easy to apply uniformly
* Bad, because it introduces unnecessary ceremony for simple logic
* Bad, because many classes become thin wrappers or namespaces
* Bad, because it can obscure simple data transformations behind object structure

### Prefer module-level functions everywhere

* Good, because code remains simple and direct
* Good, because pure functions are easy to reason about and test
* Good, because there is minimal ceremony or boilerplate
* Neutral, because modules can serve as structural boundaries if used carefully
* Bad, because ownership and responsibility boundaries are less explicit
* Bad, because large modules can devolve into loosely organized collections of functions
* Bad, because encapsulation and API boundaries are harder to enforce

### Use a hybrid approach with clear heuristics

* Good, because each construct is used where it provides the most value
* Good, because it balances structure with simplicity
* Good, because abstraction evolves based on real needs
* Neutral, because it requires engineering judgment rather than strict rules
* Bad, because inconsistency can arise if heuristics are not well understood
* Bad, because decisions may be debated more frequently in code review
