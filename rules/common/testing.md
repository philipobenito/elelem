# Testing

## Test Quality

Test names describe the expected behaviour in complete phrases (`user authentication fails when password is incorrect`). Each test exercises exactly one behaviour; if the name needs the word "and", split it. Tests **MUST** be deterministic: a flaky test is broken and gets fixed or removed.

You **MUST NOT** mock the code under test, pure functions, or internal collaborators you can drive with real data. Mocks are permitted only at true system boundaries: network, filesystem beyond a temp dir, clocks, randomness.

## Meaningful Assertions

A test exists to catch a genuine regression in the behaviour it names; if you cannot name the defect an assertion would catch, narrow or drop it. Assert the specific behaviour the name promises, never incidental structure: no collection-size assertions unless the behaviour is about the count, no full-object or snapshot equality unless it is about the object's complete shape. A test **MUST NOT** fail because unrelated code changed.

## Test-Driven Development

### The Iron Law

**No production code without a failing test first.**

You **MUST** write the test before the production code and watch it fail before writing the code that makes it pass; a test you never saw fail proves nothing about what it exercises. If production code exists before its test, that code is unverified: write the test, stash or disable the change so the test runs against code without it, watch it fail for the right reason, then restore the change and watch it pass. Write that test from the behaviour the change should have, not from the shape of the code you already wrote; a test fitted to the code fails without it and still proves nothing. Code whose test has never been observed failing **MUST NOT** be presented as complete; the observed failure is the evidence a reviewer checks.

### When TDD Applies

New features, bug fixes, and any change whose behaviour is externally visible. You **MAY** skip TDD in exactly two cases, and this rule grants no others. The first is throwaway prototypes, generated code, or configuration files, which additionally requires explicit approval from your human partner. The second is files the project provides no test framework for, where the project's own instructions define a proving command rather than a test suite; that qualifier is the whole permission, and a project that merely has no tests yet does not meet it. A waiver from your human partner is not a third case but an override of this rule, and `./workflow.md` governs it, including the requirement to confirm the scoped opt-out before acting on it.

### RED and GREEN Are Verified

Every RED step ends with the test run and failing for the expected reason: a test that errors, or passes on its first run, is not RED. Every GREEN step ends with the test passing, no other tests broken, and pristine output. During GREEN, write only the minimal code the test requires (the YAGNI rule in `coding-style.md`).

### Bug Fixes

You **MUST NOT** fix a bug without first writing a failing test that reproduces it.

The `work-tdd` skill is the executable cycle.
