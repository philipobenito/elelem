# Testing

## Test Naming

You **MUST** write descriptive test names that explain the scenario:

- Use complete sentences or clear phrases
- Describe the expected behaviour, not implementation
- Make failures self-explanatory

Example:

```typescript
// Good
test('calculateOrderTotalIncludingVAT adds 20% VAT to subtotal')
test('user authentication fails when password is incorrect')

// Poor
test('test1')
test('calcTotal')
```

## Test Structure

You **SHOULD** follow an Arrange-Act-Assert pattern:

- Set up test data (Arrange)
- Execute the code under test (Act)
- Verify outcomes (Assert)

## What Makes a Good Test

You **MUST** write tests that:

- Test exactly one behaviour. If the test name contains the word "and", split it into two tests.
- Exercise real code. Mocks are permitted only at true system boundaries (network, filesystem beyond `tmp_path`, clocks, randomness).
- Demonstrate how the code should be used, not how it is implemented.
- Are deterministic. A test that sometimes passes and sometimes fails is broken and **MUST** be fixed or removed.

You **MUST NOT** mock:

- The code under test
- Pure functions or data classes
- Internal collaborators that you own and can drive with real data

## Test-Driven Development

### The Core Principle

You **MUST** write the test before the production code. You **MUST** watch the test fail before writing the code that makes it pass. If you did not watch the test fail, you do not know that the test exercises what you think it exercises.

### When TDD Applies

You **MUST** apply TDD to:

- New features
- Bug fixes
- Refactors that change observable behaviour
- Any change to code whose behaviour is externally visible

You **MAY** skip TDD only for:

- Throwaway prototypes that will be deleted
- Generated code
- Configuration files

These exceptions require explicit approval from your human partner. "This case is different" is not an exception. "Just this once" is not an exception.

### The Iron Law

**No production code without a failing test first.**

If you wrote production code before a test, you **MUST** delete that code and start again from a failing test. You **MUST NOT**:

- Keep the code as "reference" while writing the test
- "Adapt" the code as you write the test
- Look at the code while writing the test

Delete means delete. Implement fresh from the test.

### Verification is Mandatory

Every RED step **MUST** end with you running the test and watching it fail for the expected reason.

- A test that errors (syntax error, import error, missing symbol) does not count as RED. Fix the error and re-run until the test fails for the right reason.
- A test that passes on its first run is testing behaviour that already exists. Fix the test.

Every GREEN step **MUST** end with you running the test and watching it pass and confirming that no other tests broke. Output **MUST** be pristine: no warnings, no stray errors, no skipped tests you did not intend to skip.

### YAGNI During GREEN

In the GREEN step you **MUST** write only the minimal code required to pass the test. You **MUST NOT** add unrequested options, configurability, error paths for cases the test does not cover, or "while I am here" improvements. See `coding-style.md` for the general YAGNI rule.

### Bug Fixes

You **MUST NOT** fix a bug without first writing a failing test that reproduces it. The test proves the fix works and prevents the bug from returning.

### Why Test-First, Not Test-After

Tests written after the code pass immediately. Passing immediately proves nothing. The test may exercise the wrong behaviour, test implementation instead of contract, miss cases you forgot, or mirror a bug you already shipped. Test-first forces you to see the test fail, which is the only proof that the test actually tests something.

Test-first answers "what should this do". Test-after answers "what does this do". These are different questions and they produce different tests.

### Common Rationalisations

You will be tempted to skip TDD. Every excuse in this table means **start over with a failing test**:

| Excuse                                  | Reality                                                                           |
|-----------------------------------------|-----------------------------------------------------------------------------------|
| "Too simple to test"                    | Simple code breaks. The test takes thirty seconds.                                |
| "I'll test after"                       | Tests passing immediately prove nothing.                                          |
| "Tests after achieve the same goals"    | Tests after answer "what does this do". Tests first answer "what should this do". |
| "I already manually tested it"          | Manual testing has no record and cannot be re-run.                                |
| "Deleting hours of work is wasteful"    | Sunk cost. Unverified code is technical debt.                                     |
| "Keep the code as reference"            | You will adapt it. That is testing after. Delete means delete.                    |
| "I need to explore first"               | Fine. Throw away the exploration, then start with TDD.                            |
| "The test is hard to write"             | Hard to test means hard to use. Fix the design.                                   |
| "I must mock everything"                | Code is too coupled. Use dependency injection.                                    |
| "TDD will slow me down"                 | TDD is faster than debugging in production.                                       |
| "Existing code has no tests"            | You are improving it. Add the test.                                               |
| "TDD is dogmatic, I am being pragmatic" | TDD is pragmatic. Shortcuts mean debugging in production.                         |
| "Just this once"                        | No.                                                                               |
| "This case is different because..."     | No.                                                                               |

### Red Flags: Stop and Start Over

If any of the following is true, stop immediately and restart the cycle from a failing test:

- You wrote code before a test
- You wrote a test after the implementation
- A test passed immediately on its first run
- You cannot explain why a test failed
- You are keeping code "as reference" or to "adapt"
- You are about to say "just this once" or "this case is different"

There are no exceptions to these rules without explicit permission from your human partner.
