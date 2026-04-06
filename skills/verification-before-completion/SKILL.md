---
name: verification-before-completion
description: Runs the gate function that produces fresh verification evidence before a completion claim. Identifies the proving command, runs it fresh in the current message, reads the output, and only states the claim with cited evidence.
---

# Verification Before Completion

The iron-law rules (the iron law itself, what counts as a completion claim, when the rule fires) live in `../../rules/common/verification.md`. The procedural rules that bind once this skill is running (the common-failures table, the rationalisation prevention table, the red-flags stop list) live in `RULES.md` alongside this file. This skill is the procedure that produces the evidence those rules require.

Before running the gate function below, you **MUST** read `RULES.md` (sibling file in this skill directory) using the Read tool if you have not already read it in this session.

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

See `../../rules/common/testing.md` for the full red-green rules. The verification-layer procedure is:

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

You **MUST NOT** propagate a subagent's "success" report without running steps 2 and 3 yourself. See `../../rules/common/subagents.md`.

### Requirements Checklist

1. Identify: the approved design, epic body, or ticket containing the acceptance criteria
2. Run: read the criteria line by line, compare each to the current state of the code or behaviour
3. Read: note which criteria are met, which are partial, which are missing
4. Compare: the claim "requirements met" requires every criterion to be met
5. State: either a full checklist with each criterion marked met with its evidence, or a gap report naming what is missing

"Tests pass, so the requirements are met" is not enough. Tests verify the tests; the checklist verifies the requirements.

## Completion Gate

You have passed the gate for a given claim only if, in the current message:

- You named the verification command
- You ran it fresh against your latest change
- You read the output
- The output proves the exact claim
- You stated the claim with the evidence cited

Any other state is a gate failure. On a gate failure, you **MUST NOT** make the claim. Fix the underlying issue, re-run the gate, or report the actual status honestly.
