# Code Style

## Self-Documenting Code

You **MUST** prioritise writing descriptive, self-explanatory code over adding comments or docblocks.

**Good practices:**

- Use meaningful, descriptive variable and function names
- Keep functions small and focused on a single responsibility
- Structure code to reveal intent through organisation and naming
- Use explicit over implicit logic

**Example (avoiding comments):**

```typescript
// Poor: Requires comment to explain
function calc(a: number, b: number): number {
  // Calculate total with 20% tax
  return a * b * 1.2;
}

// Good: Self-documenting
function calculateOrderTotalIncludingVAT(
  pricePerItem: number,
  quantity: number
): number {
  const VAT_RATE = 0.2;
  const subtotal = pricePerItem * quantity;
  return subtotal * (1 + VAT_RATE);
}
```

## Default rule: Write code without comments

You **MUST NOT** add comments unless ALL of these conditions are met:

1. The code implements a workaround for an external bug/limitation (e.g. browser quirk, library bug) **or** documents a non-obvious performance optimisation with a measurable benchmark
2. You have a specific ticket/issue/benchmark reference to cite
3. The workaround or optimisation cannot be extracted to a well-named function

**Specifically FORBIDDEN:**

- Comments explaining what code does (code should be self-documenting)
- Comments before function calls (`// Publish the article` before `publishArticle()`)
- Comments before variable assignments (`// Store the result` before `$result = ...`)
- Comments describing assertion intent in tests
- "Step X" comments in tests - use the test name instead
- Any comment that just repeats what the code says

**ABSOLUTE BAN in test files:**
Tests are documentation. Test names and assertions must be self-explanatory. Zero comments except ticket references for regression tests.

**When you think a comment is needed:**

1. FIRST: Can I rename variables/functions to make this clearer? (Do this)
2. SECOND: Can I extract to a well-named method? (Do this)
3. THIRD: Can I simplify the logic? (Do this)
4. LAST: Do I have a ticket reference for a workaround? (Only then add comment)

```php
<?php

// Example - When a comment IS appropriate:

// Workaround for Laravel bug #12345: Eager loading fails on self-referential relationships
// Remove this when upgrading to Laravel 12.x
$items = Model::all()->load('parent');

// Example - When to NEVER comment:

// BAD - comment is useless
// Publish the article
$this->articlesLibrary->publishArticle($article->ID, now());
// GOOD - no comment needed
$this->articlesLibrary->publishArticle($article->ID, now());
```

Your default behaviour: Write code. Ship code. No comments. If you catch yourself about to write a comment, stop and refactor instead.

This makes the hierarchy crystal clear:

1. Default = no comments
2. Refactor first (always)
3. Only comment for documented workarounds with ticket references
4. Tests get zero comments (except regression test references)

## Docblocks

You **MUST** avoid docblocks where type systems and function signatures provide sufficient information.

You **MAY ONLY** use docblocks when:

- The project uses a documentation generator that reads them (e.g. phpDocumentor, TypeDoc, JSDoc, Sphinx, Rustdoc, Javadoc) — check for a config file such as `phpdoc.xml`, `typedoc.json`, `jsdoc.json`, `docs/conf.py`, etc. before adding any
- Providing usage examples for complex public APIs that are part of a published package
- Documenting framework-specific annotations or decorators that the framework itself requires (e.g. Symfony attributes, NestJS decorators)
- Type information alone cannot convey the contract (e.g. documenting units, ranges, or invariants a type cannot express)

## Function and Method Length

You **MUST** keep functions concise and focused. A function is too long when any of these apply:

- It exceeds 20 lines of logic (excluding signature, braces, and blank lines)
- It mixes multiple levels of abstraction
- It cannot be named with a single clear verb phrase

Exceeding 20 lines is permitted only when the body is a flat, unavoidable structure (e.g. a single `switch` or match statement, configuration object literal, or straight-line setup for an integration test). Decompose in all other cases.

## Naming Conventions

You **MUST** follow language-specific conventions while prioritising clarity:

- Use full words over abbreviations unless the abbreviation is ubiquitous (e.g., `HTTP`, `URL`, `ID`)
- Avoid single-letter variables except in narrow scopes (loop counters, mathematical formulae)
- Boolean variables should read as predicates: `isActive`, `hasPermission`, `canExecute`

## YAGNI: Build Only What Was Asked For

You **MUST NOT** add features, refactor code, or make "improvements" beyond what the current task requires. This is the YAGNI principle (You Aren't Gonna Need It), and it applies to every change you make.

**Specifically forbidden:**

- Adding configurability, options, or flags the task did not ask for
- Adding error handling for cases the task does not cover
- Refactoring surrounding code that is not part of the task
- "While I am here" cleanups, even small ones
- Designing for hypothetical future requirements
- Creating helpers, utilities, or abstractions for one-time operations
- Adding backwards-compatibility shims when you can change the code
- Adding feature flags for changes that do not need them

**The right amount of complexity is what the task actually requires.** No speculative abstractions, but no half-finished implementations either. Three similar lines of code are better than a premature abstraction.

If you notice an unrelated issue while working on a task, log it separately (as a ticket, a note, or surface it to your human partner), but **MUST NOT** fix it inside the current change. One task, one change.

YAGNI is referenced from `testing.md` (where it applies during the GREEN step of TDD) and `code-review.md` (where it applies when a reviewer suggests "implementing properly" something that nothing currently uses).
