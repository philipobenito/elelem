# Debugging

These rules apply to every debugging activity, regardless of whether the `debug-investigation` skill has been invoked and regardless of how obvious the bug seems.

## The Hard Gate

You **MUST NOT** attempt any fix until both of the following are true:

1. You have reproduced the bug against the current state of the code, or you have explicitly noted that it cannot be reproduced and adjusted your confidence accordingly
2. You have identified the root cause with supporting evidence from actual code or actual program output

"I can see the problem" is not evidence. "The error message says X" is not evidence. Running code and observing the failure is evidence.

This gate applies to every bug. You **MUST NOT** waive it because the bug "looks simple", "is obviously a typo", or "will take longer to investigate than to fix".

## Evidence Over Intuition

Every claim you make about what is wrong **MUST** be supported by actual code you have read, actual output you have captured, or actual observations from a reproduction. Pattern-matching against an error message without reproduction is forbidden. "It looks like" and "I suspect" are not acceptable as the sole basis for a fix.

If you do not have evidence for a claim, your next action is to gather evidence, not to change code.

## Bug Fixes Are Still Changes

Bug fixes do not waive the rules in `workflow.md`, `testing.md`, or `verification.md`:

- Per `workflow.md`, a bug fix **MUST** have an approved design, even if the design is a single sentence describing the reproduction approach and the module that will change.
- Per `testing.md`, a bug fix **MUST** begin with a failing regression test that reproduces the bug. The test goes red, the fix goes in, the test goes green. You **MUST NOT** fix a bug without first writing that test.
- Per `verification.md`, the fix is not complete until the verification gate has been run against it and the evidence has been cited.

## The Investigation Skill

The `debug-investigation` skill is the procedure that produces the evidence and the fix these rules require: mode selection, the seven-phase investigation, scope discipline, the refocus rule, the investigation budget, the minimal fix principle, and the subagent dispatch used in autonomous mode all live there and load when it is invoked.
