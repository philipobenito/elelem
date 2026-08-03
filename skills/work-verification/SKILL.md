---
name: work-verification
description: Runs the gate function that produces fresh verification evidence before a completion claim. Identifies the proving command, runs it fresh in the current message, reads the output, and only states the claim with cited evidence.
---

# Verification Before Completion

Runs the gate function that stands between a change and any claim about it: name the proving command, run it fresh, read the output, and state the claim only with the evidence cited.

## The Gate Function

Run these five steps, in order, every time. Skipping any step means the gate has not been passed, and you **MUST NOT** state the claim.

1. **Identify the command.** Name the exact command whose output would prove the claim (test runner, build, linter, type checker, diff inspection, requirement checklist). If you cannot name one, the claim is not verifiable, and you **MUST NOT** make it.
2. **Run it fresh.** Execute the full command in the current message, after your most recent change to the code it verifies. No partial runs. No reuse of earlier output.
3. **Read the output.** Read exit code, pass/fail counts, error lines. Do not scan. Do not assume. If the output is long, read the summary line and the failure lines in full.
4. **Compare to the claim.** Does the output actually prove the claim you are about to make? If the claim is "tests pass", the output must show zero failures and the expected test count. If the claim is "bug fixed", the reproducing test must now pass. If the claim is "subagent task complete", the VCS diff must show the expected changes and the verification commands must pass against that diff.
5. **State the claim with the evidence.** Quote or reference the command and its relevant output alongside the claim. A claim without cited evidence is a claim that has not passed the gate.

If step 4 fails, you **MUST** state the actual status with the evidence, not the claim you hoped to make.

## Worked Examples

### Tests

1. Identify: `uv run pytest tests/test_widget.py -x`
2. Run: execute it now, in this message
3. Read: `12 passed in 0.43s`, exit 0
4. Compare: the claim is "the widget tests pass"; output confirms 12/12 pass
5. State: "Widget tests pass: 12/12, `uv run pytest tests/test_widget.py -x` exit 0"

Incorrect: "Widget tests should pass now" with no command run.

### Build

1. Identify: `pnpm build`
2. Run: execute it now
3. Read: exit 0, no TypeScript errors, bundle emitted
4. Compare: the claim is "the build succeeds"; output confirms
5. State: "Build succeeds: `pnpm build` exit 0, no TS errors"

Incorrect: "Linter passed, build should be fine." The linter is not the build.

### Regression Test for a Bug Fix

1. Identify: the reproducing test command, and the fix revert step
2. Run the test against the fix: must pass
3. Revert the fix, run the test: must fail with the original symptom
4. Restore the fix, run the test: must pass again
5. State: "Regression test confirmed: fails without fix (original symptom reproduced), passes with fix"

A regression test that has only been observed to pass once has not been verified. You **MUST** complete the revert-and-restore cycle before claiming the regression is covered.

### Subagent Handback

1. Identify: the VCS diff command and the verification commands named in the task spec
2. Run `git status` and `git diff` to inspect what the subagent actually changed
3. Re-run the task's verification commands yourself against the current working tree
4. Compare: do the changes match the task spec, and do the verifications pass?
5. State: "Subagent task complete: diff matches spec (N files, expected changes), `<verify command>` exit 0"

You **MUST NOT** propagate a subagent's "success" report without running steps 2 and 3 yourself.

### Requirements Checklist

1. Identify: the approved design, epic body, or ticket containing the acceptance criteria
2. Run: read the criteria line by line, compare each to the current state of the code or behaviour
3. Read: note which criteria are met, which are partial, which are missing
4. Compare: the claim "requirements met" requires every criterion to be met
5. State: either a full checklist with each criterion marked met with its evidence, or a gap report naming what is missing

"Tests pass, so the requirements are met" is not enough. Tests verify the tests; the checklist verifies the requirements.

## Common Failures

| Claim                  | Required evidence                                             | Not sufficient                         |
|------------------------|---------------------------------------------------------------|----------------------------------------|
| Tests pass             | Test command output in this message, exit 0, 0 failures       | Previous run, "should pass", linter ok |
| Linter clean           | Linter output in this message, 0 errors, 0 warnings           | Partial file check, extrapolation      |
| Build succeeds         | Build command output in this message, exit 0                  | Linter passing, logs "look fine"       |
| Bug fixed              | The reproducing test fails without the fix and passes with it | Code changed, assumed fixed            |
| Regression test works  | The full revert-and-restore cycle executed                    | Test passed once after the fix         |
| Subagent task complete | VCS diff inspected, verification commands re-run              | Subagent's own "success" report        |
| Requirements met       | Line-by-line checklist against the approved design            | Tests passing in general               |

## Completion Gate

You have passed the gate for a given claim only if, in the current message:

- You named the verification command
- You ran it fresh against your latest change
- You read the output
- The output proves the exact claim
- You stated the claim with the evidence cited

Any other state is a gate failure. On a gate failure, you **MUST NOT** make the claim. Fix the underlying issue, re-run the gate, or report the actual status honestly.

## Rationalisation Prevention

Every excuse below means **stop and run the verification**:

| Excuse                                    | Reality                                               |
|-------------------------------------------|-------------------------------------------------------|
| "It should work now"                      | Run the verification. "Should" is not evidence.       |
| "I'm confident"                           | Confidence is not evidence.                           |
| "Just this once"                          | No exceptions.                                        |
| "The linter passed"                       | The linter is not the compiler and not the tests.     |
| "The subagent said it succeeded"          | Verify independently. Trust nothing.                  |
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
