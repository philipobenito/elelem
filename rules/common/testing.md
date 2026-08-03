# Testing

## Test Quality

Test names describe the expected behaviour in complete phrases (`user authentication fails when password is incorrect`). Each test exercises exactly one behaviour; if the name needs the word "and", split it. Tests **MUST** be deterministic: a flaky test is broken and gets fixed or removed.

You **MUST NOT** mock the code under test, pure functions, or internal collaborators you can drive with real data. Mocks are permitted only at true system boundaries: network, filesystem beyond a temp dir, clocks, randomness.

## Meaningful Assertions

A test exists to catch a genuine regression in the behaviour it names; if you cannot name the defect an assertion would catch, narrow or drop it. Assert the specific behaviour the name promises, never incidental structure: no collection-size assertions unless the behaviour is about the count, no full-object or snapshot equality unless it is about the object's complete shape. A test **MUST NOT** fail because unrelated code changed.

## Test-Driven Development

### The Iron Law

**No production code without a failing test first.**

You **MUST** write the test before the production code and watch it fail before writing the code that makes it pass; a test you never saw fail proves nothing about what it exercises. If you wrote production code before a test, you **MUST** delete that code and start again from a failing test. Delete means delete: not "keep as reference", not "adapt as I write the test".

### When TDD Applies

New features, bug fixes, and any change whose behaviour is externally visible. You **MAY** skip TDD only for throwaway prototypes, generated code, or configuration files, with explicit approval from your human partner.

### RED and GREEN Are Verified

Every RED step ends with the test run and failing for the expected reason: a test that errors, or passes on its first run, is not RED. Every GREEN step ends with the test passing, no other tests broken, and pristine output. During GREEN, write only the minimal code the test requires (the YAGNI rule in `coding-style.md`).

### Bug Fixes

You **MUST NOT** fix a bug without first writing a failing test that reproduces it.

The `work-tdd` skill is the executable cycle.
