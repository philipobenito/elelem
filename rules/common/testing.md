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

## Meaningful Assertions

A test **MUST** exist to catch a genuine regression in the behaviour it names, not to notice that something, anything, changed. Before writing an assertion, ask what real defect it would catch; if you cannot name one, the assertion is incidental and **MUST** be narrowed or dropped.

You **MUST** assert on the specific behaviour a test's name promises, not on incidental structure that only happens to hold true today. A test **MUST NOT** fail because unrelated code or data changed in a way that has nothing to do with the scenario it claims to cover. For example, a test that is not about counting **MUST NOT** assert the total size of a collection, since an unrelated addition elsewhere would break it for no genuine reason; assert the presence or absence of the specific items the scenario cares about instead, and reserve count or length assertions for tests whose stated behaviour is genuinely about the count. Similarly, a test that checks one field's behaviour **MUST NOT** assert deep equality against a full object or snapshot, since adding an unrelated field to that object would break it; assert the specific field or property the scenario is about instead, and reserve whole-object or snapshot comparisons for tests whose stated behaviour is genuinely about the object's complete shape.

## Test-Driven Development

### The Iron Law

**No production code without a failing test first.**

You **MUST** write the test before the production code. You **MUST** watch the test fail before writing the code that makes it pass. If you did not watch the test fail, you do not know that the test exercises what you think it exercises.

If you wrote production code before a test, you **MUST** delete that code and start again from a failing test. Delete means delete: not "keep as reference", not "adapt as I write the test".

### When TDD Applies

You **MUST** apply TDD to:

- New features
- Bug fixes
- Refactors that change observable behaviour
- Any change to code whose behaviour is externally visible

You **MAY** skip TDD only for throwaway prototypes that will be deleted, generated code, or configuration files. These exceptions require explicit approval from your human partner.

### Verification is Mandatory

Every RED step **MUST** end with you running the test and watching it fail for the expected reason. A test that errors (syntax error, import error, missing symbol) does not count as RED. A test that passes on its first run is testing behaviour that already exists; fix the test.

Every GREEN step **MUST** end with you running the test and watching it pass and confirming that no other tests broke. Output **MUST** be pristine: no warnings, no stray errors, no skipped tests you did not intend to skip.

### YAGNI During GREEN

In the GREEN step you **MUST** write only the minimal code required to pass the test. You **MUST NOT** add unrequested options, configurability, error paths for cases the test does not cover, or "while I am here" improvements. See `coding-style.md` for the general YAGNI rule.

### Bug Fixes

You **MUST NOT** fix a bug without first writing a failing test that reproduces it. The test proves the fix works and prevents the bug from returning.

### Procedural Rules

The procedural rules that bind once the `work-tdd` skill is running (the rationalisation table, the red-flags stop list) live in `../../skills/work-tdd/RULES.md` and load when the skill is invoked.
