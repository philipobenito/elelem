# Debugging

These rules bind every debugging activity, however obvious the bug seems, skill or no skill.

## The Hard Gate

You **MUST NOT** attempt any fix until both of these are true:

1. You have reproduced the bug against the current state of the code, or explicitly noted that it cannot be reproduced and adjusted your confidence accordingly
2. You have identified the root cause with supporting evidence from actual code or actual program output

"I can see the problem" and "the error message says X" are not evidence; running code and observing the failure is. You **MUST NOT** waive the gate because the bug "looks simple", "is obviously a typo", or "will take longer to investigate than to fix".

## Evidence Over Intuition

Every claim about what is wrong **MUST** be supported by code you have read, output you have captured, or a reproduction you have observed. Without evidence, your next action is gathering it, not changing code.

Bug fixes waive nothing: an approved design (`workflow.md`), a failing regression test first (`testing.md`), and fresh verification (`verification.md`) still apply. The `debug-investigation` skill is the procedure that produces this evidence.
