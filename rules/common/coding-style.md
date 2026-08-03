# Code Style

## Comments

You **MUST NOT** add comments unless all three hold: the code works around an external bug or documents a measured optimisation; you have a ticket, issue, or benchmark reference to cite; and the workaround cannot be extracted into a well-named function. Code explains itself through naming and structure; when a comment feels needed, refactor first. Zero comments in test files except ticket references for regression tests. Docblocks only where a generator the project uses reads them, a published API needs examples, a framework requires them, or a type cannot express the contract (units, ranges, invariants).

## Functions and Naming

Keep functions under 20 lines of logic, at one level of abstraction, nameable with a single clear verb phrase. Exceeding 20 is permitted only for flat, unavoidable structures (a single switch, a configuration literal, straight-line integration-test setup). Use full words over abbreviations unless ubiquitous (`HTTP`, `ID`); booleans read as predicates (`isActive`, `hasPermission`).

## YAGNI

You **MUST NOT** build beyond what the current task requires: no unrequested options or flags, no error paths the task does not cover, no "while I am here" clean-ups, no speculative abstractions, compatibility shims, or helpers for one-time operations. Three similar lines beat a premature abstraction. Fold in only what the task cannot be completed correctly without; log or surface unrelated issues rather than fixing them in the current change. One task, one change.

## Consistency

You **MUST** match the codebase's established patterns even when you would prefer another approach, and you **MUST NOT** unilaterally refactor a pattern: raise it, wait for approval, then apply the change at every site you touch. Use the project's formatters and linters as configured.

## Dependencies

You **MUST NOT** add a runtime or development dependency without explicit user approval, stating why existing options are insufficient plus the package, version, licence, maintenance state, and approximate size. Prefer the standard library when a dependency would replace fewer than roughly 50 lines.

## Security

Validate and sanitise input wherever data enters from outside its trust zone: HTTP handlers, CLI and environment input, file and deserialisation reads, user-writable database rows, queues, third-party responses, IPC. Use parameterised queries. You **MUST NOT** commit credentials, keys, or personal data; use environment variables or a secret store, and warn the user when a change risks committing secrets.
