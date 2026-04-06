# Debugging

These rules apply to every debugging activity, regardless of whether the `debugging` skill has been invoked and regardless of how obvious the bug seems.

## The Hard Gate

You **MUST NOT** attempt any fix until both of the following are true:

1. You have reproduced the bug against the current state of the code, or you have explicitly noted that it cannot be reproduced and adjusted your confidence accordingly
2. You have identified the root cause with supporting evidence from actual code or actual program output

"I can see the problem" is not evidence. "The error message says X" is not evidence. Running code and observing the failure is evidence.

This gate applies to every bug. You **MUST NOT** waive it because the bug "looks simple", "is obviously a typo", or "will take longer to investigate than to fix".

## Evidence Over Intuition

Every claim you make about what is wrong **MUST** be supported by actual code you have read, actual output you have captured, or actual observations from a reproduction. Pattern-matching against an error message without reproduction is forbidden. "It looks like" and "I suspect" are not acceptable as the sole basis for a fix.

If you do not have evidence for a claim, your next action is to gather evidence, not to change code.

## Reproduction Is Non-Negotiable

Reproduction is verification infrastructure. Without a reproduction you cannot confirm that any fix actually addresses the bug.

If the bug cannot be reproduced, you **MUST**:

1. State explicitly that it is non-reproducible
2. Reduce the confidence with which you present any hypothesis
3. Refuse to claim a fix. A non-reproducible bug cannot have a verified fix.

Asking the user for reproduction steps is always acceptable. Guessing at reproduction steps and proceeding is not.

## Scope Discipline

During initial evidence gathering, you **MUST** limit your reading to:

- The error message and stack trace
- The file and function where the error occurs
- One level of callers and callees from the error site
- Recent git changes to affected files (`git log --oneline -10 <file>`)

You **MUST NOT**, during initial evidence gathering:

- Read every file in the directory
- Trace the entire call chain from the entry point
- Read configuration files unless the error points to configuration
- Search the whole codebase for patterns

Expand scope only after forming a hypothesis and only in the direction the hypothesis requires.

## The Refocus Rule

If you have read five files without forming a clear hypothesis, you **MUST** stop gathering evidence. Present what you know, what you have ruled out, and what remains uncertain. Ask the human partner which direction to pursue.

Unfocused investigation wastes time and context. The instinct to "just read one more file" is how investigation spirals begin; the rule exists to cut the spiral early.

## The Investigation Budget

You get three hypothesis cycles before you **MUST** stop and refocus:

- **Cycle 1**: test the most likely hypothesis
- **Cycle 2**: test the second hypothesis or widen the scope in the direction the first cycle's evidence suggests
- **Cycle 3**: test the third hypothesis or revisit with fresh framing

After three cycles without a confirmed root cause, you **MUST** present everything you have investigated, everything you have ruled out, and everything that remains uncertain, and ask the human partner to help refocus. You **MUST NOT** continue investigating in circles past the budget.

The budget exists because debugging without a budget becomes an ever-widening search that burns context without converging. Three focused cycles are enough to either find the root cause or establish that you need help.

## Root Cause, Not Symptom

You **MUST** distinguish the symptom from the root cause before fixing. "The function returns null" is a symptom. "The query filter excludes records where status is pending because the enum changed in commit abc123" is a root cause.

A fix that addresses the symptom without addressing the root cause is forbidden. If the symptom and the root cause are the same thing, state that explicitly with the evidence that supports it.

## Minimal Fix Principle

The fix **MUST** change only what is necessary to address the root cause. You **MUST NOT**:

- Refactor surrounding code
- Add features you noticed were missing
- Fix unrelated issues you spotted during the investigation
- "Improve" things that are not broken

If the fix touches more than two or three locations, stop and verify that you are fixing one root cause, not patching the same symptom in several places. One bug is one fix.

Any unrelated issues you notice during debugging **MUST** be logged separately (as tickets or notes), not fixed inside the debugging change.

## Bug Fixes Are Still Changes

Bug fixes do not waive the rules in `workflow.md`, `testing.md`, or `verification.md`:

- Per `workflow.md`, a bug fix **MUST** have an approved design, even if the design is a single sentence describing the reproduction approach and the module that will change.
- Per `testing.md`, a bug fix **MUST** begin with a failing regression test that reproduces the bug. The test goes red, the fix goes in, the test goes green. You **MUST NOT** fix a bug without first writing that test.
- Per `verification.md`, the fix is not complete until the verification gate has been run against it and the evidence has been cited.

## Rationalisation Prevention

Every thought below means **stop and return to the procedure**:

| You might think...                                               | Reality                                                                                        |
|------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| "The error message tells me exactly what's wrong"                | Error messages describe symptoms. Reproduce and find the root cause.                           |
| "This is obviously a simple typo or missing null check"          | If it is obvious, reproduction and root cause identification will be fast. Skip nothing.       |
| "Let me just try this quick fix and see if it works"             | That is shotgun debugging. It wastes time when it fails and masks root causes when it works.   |
| "I've been investigating for a while, let me just try something" | That is the investigation budget telling you to refocus, not to start guessing.                |
| "I need to read more code to understand the system"              | You need scoped evidence, not system understanding. Read what the bug touches, not everything. |
| "Let me check a few more files to be thorough"                   | Thoroughness without direction is waste. Form a hypothesis first, then read files to test it.  |
| "The fix is so small it doesn't need a regression test"          | Small fixes for subtle bugs are exactly what regression tests exist for. See `testing.md`.     |
| "I can see other issues while I'm here, let me fix those too"    | One bug, one fix. Log other issues separately.                                                 |
| "I don't need to reproduce this, the error is clear"             | Reproduction is verification infrastructure. Without it, you cannot confirm your fix works.    |

## Procedure

The executable procedure (the 7-phase investigation, mode selection, investigator subagent dispatch) lives in the `debugging` skill. This file is the rule set the skill enforces. The rules here apply whether or not the skill has been invoked.
