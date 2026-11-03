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

Assertions protect approved requirements, public contracts, or existing
supported behaviour. Apply this ordered generic audit after checking applicable
instructions:

1. Classify each test or parameterised case as scaffolding,
   implementation-detail, duplicate, timing-dependent, or none of these. A
   wrong-layer category exists only when applicable project rules define it.
2. For a category candidate, the category guard permits removal only when a
   retained survivor detects the named defect or the auditor states that no
   defect can be caught, unless applicable project rules relax the guard. A
   blocked category guard does not prevent a later removal decision.
3. Remove when the auditor cannot name a production defect that the test or
   case can detect. This is not a claim that no defect exists. Also remove a
   duplicate when one retained survivor detects a defect shared with the
   source, even if other defects detected by the source are not preserved.
4. If neither removal condition applies, MERGE when a small assertion from the
   source can be added to a KEEP survivor and protects a named production
   defect. Otherwise KEEP.

Return exactly one KEEP, REMOVE, or MERGE decision for each case, with its
category, rationale, and supporting evidence. Apply precedence in this order:
higher-priority instructions, this canonical rule, applicable project rules,
then generic categories. Applicable project rules may override generic
categories to the extent this canonical rule allows, but they cannot override
higher-priority instructions or this canonical rule. Never delete a test file
or its last test. MERGE and removal survivors must be stable, retained, and
non-cyclic. Treat parameterised cases independently when their inputs or
outcomes differ, and include older tests in every task-touched test file.

Use the shared test-pruning procedure for the audit, evidence, application,
recovery, and invalidation lifecycle. This section is the sole canonical value
rule. Auditor prompts receive this section verbatim; they must not substitute
or paraphrase it.

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

The procedural rules that bind once the `test-driven-development` skill is running (the rationalisation table, the red-flags stop list) live in `../../skills/test-driven-development/RULES.md` and load when the skill is invoked.
