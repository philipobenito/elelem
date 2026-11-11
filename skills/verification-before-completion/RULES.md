# Verification Before Completion - Procedural Rules

These rules apply once the `verification-before-completion` skill has been invoked. They are the procedural detail behind the iron law in `../../rules/common/verification.md`. The iron law itself, the scope of what counts as a completion claim, and the trigger conditions live in the always-on rule file and bind every message. The rules below help you recognise common failure modes and rationalisations once you are running the gate function.

## Common Failures

| Claim                  | Required evidence                                       | Not sufficient                         |
|------------------------|---------------------------------------------------------|----------------------------------------|
| Tests pass             | Actual command output, exit 0, 0 failures, validated against current inputs | Previous output without input validation, "should pass", linter ok |
| Linter clean           | Actual linter output, 0 errors, 0 warnings, validated against current inputs | Partial file check, extrapolation      |
| Build succeeds         | Actual build output, exit 0, validated against current inputs | Linter passing, logs "look fine"       |
| Bug fixed              | Failing test now passes; see `../../rules/common/testing.md` for red-green | Code changed, assumed fixed            |
| Regression test works  | Supported original RED and current GREEN relationship per `../../rules/common/testing.md` | Test passed once with no RED evidence |
| Subagent task complete | VCS diff inspected, independent evidence validated or checks executed | Subagent's own "success" report        |
| Requirements met       | Line-by-line checklist against the approved design      | Tests passing in general               |

Matching evidence may be revalidated and reused when its execution provenance,
scope, input identities and assumptions still match the claim. A new message or
resumed session alone does not invalidate it.

## Rationalisation Prevention

Every excuse below means **stop and apply the evidence gate**:

| Excuse                                    | Reality                                               |
|-------------------------------------------|-------------------------------------------------------|
| "It should work now"                      | Run the verification. "Should" is not evidence.       |
| "I'm confident"                           | Confidence is not evidence.                           |
| "Just this once"                          | No exceptions.                                        |
| "The linter passed"                       | The linter is not the compiler and not the tests.     |
| "The subagent said it succeeded"          | Verify independently. See `../../rules/common/subagents.md`.             |
| "I'm tired"                               | Exhaustion is not an exemption.                       |
| "A partial check is enough"               | Partial checks prove nothing about the whole.         |
| "I verified earlier in the session"       | Revalidate the exact inputs and provenance; rerun affected checks when they changed or are uncertain. |
| "Different wording so the rule is moot"   | Spirit over letter. The rule applies to implications. |
| "The change is too small to break things" | Small changes break things. Run the verification.     |

## Red Flags: Stop Immediately

If any of the following is true, you **MUST** stop, apply the evidence gate, and only then continue:

- You are about to write "should", "probably", "seems", "looks", or any hedged success wording
- You are about to express satisfaction ("Great", "Perfect", "Done") without having just read and evaluated actual output and input-validity evidence
- You are about to commit, push, or open a PR without validating the required evidence gate
- You are about to trust a subagent's self-report without inspecting the diff
- You are about to reuse earlier output without validating its input identities and provenance
- You are about to say "just this once" or "this case is different"
