# Test-Driven Development - Procedural Rules

These rules apply once the `test-driven-development` skill has been invoked. They are the procedural detail behind the iron law in `../../rules/common/testing.md`. The iron law (no production code without a failing test first), the when-TDD-applies list, the verification requirement, and the YAGNI-during-GREEN rule live in the always-on rule file and bind whether or not this skill runs. The rules below help you recognise common failure modes and stop conditions once you are running the cycle.

## Common Rationalisations

You will be tempted to skip TDD. Every excuse below means **start over with a failing test**:

| Excuse                                  | Reality                                                                           |
|-----------------------------------------|-----------------------------------------------------------------------------------|
| "Too simple to test"                    | Simple code breaks. The test takes thirty seconds.                                |
| "I'll test after"                       | Tests passing immediately prove nothing.                                          |
| "I already manually tested it"          | Manual testing has no record and cannot be re-run.                                |
| "Deleting hours of work is wasteful"    | Sunk cost. Unverified code is technical debt.                                     |
| "Keep the code as reference"            | You will adapt it. That is testing after. Delete means delete.                    |
| "The test is hard to write"             | Hard to test means hard to use. Fix the design.                                   |
| "I must mock everything"                | Code is too coupled. Use dependency injection.                                    |
| "TDD will slow me down"                 | TDD is faster than debugging in production.                                       |
| "Existing code has no tests"            | You are improving it. Add the test.                                               |
| "Just this once" / "this case is different" | No.                                                                           |

## Red Flags: Stop and Start Over

If any of the following is true, stop immediately and restart the cycle from a failing test:

- You wrote code before a test
- A test passed immediately on its first run
- You cannot explain why a test failed
- You are keeping code "as reference" or to "adapt"
- You are about to say "just this once" or "this case is different"

There are no exceptions to these rules without explicit permission from your human partner.
