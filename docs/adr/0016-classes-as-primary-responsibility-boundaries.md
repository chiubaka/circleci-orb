---
status: accepted
date: 2026-03-27
decision-makers: Daniel Chiu
---

# Classes as Primary Responsibility Boundaries

## Context and Problem Statement

As the codebase grows, it becomes difficult to reason about ownership, flow of control, and cohesion when logic is spread across loosely related functions within modules. In particular, AI-generated code tends to produce module-level helper functions that are only implicitly related, leading to ambiguity about what constitutes a coherent unit of responsibility.

We need a consistent way to define architectural seams and ensure that each unit of behavior has a clear owner.

## Decision Drivers

* Maintain strong cohesion and clear ownership of logic
* Make flow of control explicit and easy to follow
* Reduce cognitive overhead when navigating code
* Avoid accidental expansion of public API surface
* Support incremental refinement of abstractions over time

## Considered Options

* Use module-level functions as the primary unit of structure
* Use classes as the primary unit of responsibility
* Hybrid approach with no strong convention

## Decision Outcome

Chosen option: "Use classes as the primary unit of responsibility".

Justification: Classes provide a clear and explicit boundary for grouping related behavior, defining ownership, and structuring flow. This improves readability and maintainability, especially in orchestration-heavy or domain-driven logic.

### Consequences

* Good, because responsibility boundaries are explicit and discoverable
* Good, because implementation details can be hidden via private methods
* Good, because public APIs are naturally constrained
* Good, because orchestration logic has a clear "home"
* Bad, because some classes may initially be thin or act as orchestration wrappers
* Bad, because there is a risk of overusing classes for simple logic

### Confirmation

* Code reviews should verify that each class represents a coherent responsibility
* Files named after classes (for example, `MasteryEvaluator.ts`) should primarily contain logic owned by that class
* Helper functions that are only relevant to a class should not be exported at module level
* Class-owned helper behavior should default to `private` or `private static` methods unless a separate reusable utility is intentionally extracted
* Tests should not force expansion of production public API surface (for example, exporting class-internal helpers only so tests can call them directly)

## Pros and Cons of the Options

### Use module-level functions as the primary unit of structure

* Good, because it encourages simple, composable, and often pure logic
* Good, because it avoids unnecessary object-oriented ceremony
* Good, because functions are easy to test in isolation
* Neutral, because modules can act as a structural boundary if treated carefully
* Bad, because ownership and responsibility boundaries are often implicit rather than explicit
* Bad, because related logic can become scattered across many loosely connected functions
* Bad, because public vs private intent is less obvious, leading to accidental API surface growth

### Use classes as the primary unit of responsibility

* Good, because responsibility and ownership are explicit and centralized
* Good, because encapsulation makes public vs private behavior clear
* Good, because orchestration logic has a natural home
* Good, because it aligns well with dependency injection patterns
* Neutral, because some classes may primarily act as orchestrators rather than rich domain objects
* Bad, because classes can be overused for simple or purely functional logic
* Bad, because there is a risk of introducing structure that is not strictly necessary

### Hybrid approach with no strong convention

* Good, because it allows maximum flexibility for developers
* Good, because each situation can be handled with the most appropriate construct
* Neutral, because experienced engineers may still produce well-structured code
* Bad, because inconsistency across the codebase increases cognitive load
* Bad, because responsibility boundaries become harder to identify
* Bad, because code review becomes more subjective and less predictable
