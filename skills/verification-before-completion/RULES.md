# Verification Before Completion - Procedural Rules

These rules apply once the `verification-before-completion` skill has been invoked. They are the procedural detail behind the iron law in `../../rules/common/verification.md`. The iron law itself, the scope of what counts as a completion claim, and the trigger conditions live in the always-on rule file and bind every message. The rules below help you recognise common failure modes and rationalisations once you are running the gate function.

## Common Failures

| Claim                  | Required evidence                                       | Not sufficient                         |
|------------------------|---------------------------------------------------------|----------------------------------------|
| Tests pass             | Test command output in this message, exit 0, 0 failures | Previous run, "should pass", linter ok |
| Linter clean           | Linter output in this message, 0 errors, 0 warnings     | Partial file check, extrapolation      |
| Build succeeds         | Build command output in this message, exit 0            | Linter passing, logs "look fine"       |
| Bug fixed              | Failing test now passes; see `../../rules/common/testing.md` for red-green | Code changed, assumed fixed            |
| Regression test works  | Red-green cycle executed per `../../rules/common/testing.md`               | Test passed once after the fix         |
| Subagent task complete | VCS diff inspected, verification commands re-run        | Subagent's own "success" report        |
| Requirements met       | Line-by-line checklist against the approved design      | Tests passing in general               |

## Rationalisation Prevention

Every excuse below means **stop and run the verification**:

| Excuse                                    | Reality                                               |
|-------------------------------------------|-------------------------------------------------------|
| "It should work now"                      | Run the verification. "Should" is not evidence.       |
| "I'm confident"                           | Confidence is not evidence.                           |
| "Just this once"                          | No exceptions.                                        |
| "The linter passed"                       | The linter is not the compiler and not the tests.     |
| "The subagent said it succeeded"          | Verify independently. See `../../rules/common/subagents.md`.             |
| "I'm tired"                               | Exhaustion is not an exemption.                       |
| "A partial check is enough"               | Partial checks prove nothing about the whole.         |
| "I verified earlier in the session"       | Not fresh. Run it again after the last change.        |
| "Different wording so the rule is moot"   | Spirit over letter. The rule applies to implications. |
| "The change is too small to break things" | Small changes break things. Run the verification.     |

## Red Flags: Stop Immediately

If any of the following is true, you **MUST** stop, run verification, and only then continue:

- You are about to write "should", "probably", "seems", "looks", or any hedged success wording
- You are about to express satisfaction ("Great", "Perfect", "Done") without having just read verification output
- You are about to commit, push, or open a PR without fresh verification in this message
- You are about to trust a subagent's self-report without inspecting the diff
- You are about to rely on verification output from earlier in the session
- You are about to say "just this once" or "this case is different"
