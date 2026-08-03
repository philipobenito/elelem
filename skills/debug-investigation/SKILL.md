---
name: debug-investigation
description: "Runs a disciplined, evidence-driven investigation to reproduce a bug, identify its root cause, and deliver a minimal verified fix. You MUST use this before touching any code in response to a bug, an error, a crash, a failing or flaky test, a regression, or anything described as not working, including one-line fixes and changes that look like an obvious typo: the hard gate (no fix without a reproduction and an identified root cause) applies however simple the fix looks. Enforces scope discipline, the investigation budget, and the minimal fix principle, and takes its own approval for the fix approach so bugs do not go through the design step."
---

# Debugging

Reproduces a reported bug, gathers scoped evidence, tests ranked hypotheses within a fixed budget, confirms the root cause, and delivers a minimal fix through test, review and verification.

**Precondition**: the user has reported something not working, pasted an error, reported a failing test, or described behaviour differing from what was intended. If you are unsure whether the report is a bug or a feature request, clarify during Phase 1.

## How It Runs

You drive the investigation and keep the user in it: surface findings at each phase boundary, explain the reasoning behind a step where the user is unfamiliar with the system or asks what is happening, and follow their direction whenever they steer. How much the user steers is their choice turn by turn, not a mode selected up front. Two decisions are always theirs regardless: the direction to pursue when the Refocus Rule or the Investigation Budget triggers, and the approval of the root cause and fix approach in Phase 6.

## The Seven Phases

Run the phases in order. You **MUST NOT** skip a phase, and you **MUST NOT** reorder them. Two phases can terminate the skill early: Phase 2 when the bug is non-reproducible, and Phase 6 when the fix turns out to be too large. Both exits are described in place.

### Phase 1: Understand the Problem

Before touching code, establish:

- **Expected behaviour**: what should happen?
- **Actual behaviour**: what happens instead?
- **Trigger conditions**: when does it happen? Always, or only under specific conditions?
- **Recency**: when did it last work? What changed since then?

If the bug report is ambiguous, ask clarifying questions. Do not guess at what "broken" means.

### Phase 2: Reproduce

Run the failing scenario and observe the actual output:

- Run the failing test, command, or user action
- Capture the exact error output, stack trace, or incorrect behaviour
- Confirm the bug exists in the current state of the code

Reproduction is verification infrastructure: without it, you cannot confirm that any fix actually addresses the bug. Asking the user for reproduction steps is always acceptable. Guessing at reproduction steps and proceeding is not.

If reproduction fails, check whether the environment matches (dependencies, config, data) and ask the user for reproduction steps.

If the bug is still not reproducible, the sequence stops here. Say explicitly that the bug is non-reproducible, present what the evidence supports at reduced confidence, and ask the user for the conditions you are missing. You **MUST NOT** continue to Phase 7: a non-reproducible bug cannot have a verified fix, so there would be nothing for the verification gate to check and no way to tell a fix from a coincidence.

### Phase 3: Gather Scoped Evidence

During initial evidence gathering, limit your reading to:

- The error message and stack trace
- The file and function where the error occurs
- One level of callers and callees from the error site
- Recent git changes to affected files (`git log --oneline -10 <file>`)

You **MUST NOT**, during initial evidence gathering, read every file in the directory, trace the entire call chain from the entry point, read configuration files unless the error points to configuration, or search the whole codebase for patterns. Expand scope only after forming a hypothesis and only in the direction the hypothesis requires.

**The Refocus Rule.** If you have read five files without forming a clear hypothesis, stop gathering evidence. A hypothesis is clear when you can state its What, its Evidence and its Predicted observation distinctly, as Phase 4 requires; clarity is whether those three can be stated, not how confident you are in them. Stop and present what you know, what you have ruled out, and what remains uncertain, and ask the user which direction to pursue. Unfocused investigation wastes time and context; the instinct to "just read one more file" is how investigation spirals begin, and the rule exists to cut the spiral early.

### Phase 4: Form Hypotheses

Based on the evidence, form two to four ranked hypotheses. Rank by the specificity and recency of the evidence supporting each, breaking ties by ease of testing. Each hypothesis **MUST** include:

- **What**: the specific claim about the root cause
- **Evidence**: the specific observations that support it
- **Predicted observation**: what you would expect to see if the hypothesis is correct

Present the ranked list to the user with the evidence behind the ranking, then test in that order; the user can reorder or redirect at any point.

### Phase 5: Test Hypotheses

Test the most likely hypothesis first:

1. Identify a specific check that would confirm or eliminate it
2. Run the check: read code, add temporary logging, run a test with different input
3. Record the result as evidence for or against
4. If confirmed, proceed to Phase 6. If disproven, move to the next hypothesis.

**The Investigation Budget.** You get three hypothesis cycles before you stop and refocus with the user:

- **Cycle 1**: test the most likely hypothesis
- **Cycle 2**: test the second hypothesis, or widen the scope in the direction the first cycle's evidence suggests
- **Cycle 3**: test the third hypothesis, or revisit with fresh framing

A cycle is a round of testing followed by a reassessment: the budget limits how many times you re-frame the problem before asking for help, not how many hypotheses you hold at once. After three cycles without a confirmed root cause, you **MUST** stop per "When the Bug Cannot Be Found" below, and you **MUST NOT** continue investigating in circles past the budget. Debugging without a budget becomes an ever-widening search that burns context without converging; three focused cycles are enough to either find the root cause or establish that you need help.

### Phase 6: Identify Root Cause

Distinguish the symptom from the root cause before fixing. "The function returns null" is a symptom. "The query filter excludes records where status is pending because the enum changed in commit abc123" is a root cause. A fix that addresses the symptom without addressing the root cause is forbidden; if the symptom and the root cause are the same thing, state that explicitly with the evidence that supports it. State the root cause clearly:

- **What**: the specific code, configuration, or data causing the issue
- **Why**: the causal chain from the root cause to the observed symptom
- **Since when**: if determinable, when the bug was introduced (commit reference)

Then check the fix against the **Minimal Fix Principle** before proposing it. The fix changes only what is necessary to address the root cause: no refactoring surrounding code, no adding features you noticed were missing, no fixing unrelated issues you spotted, no "improving" things that are not broken. Unrelated issues you noticed during the investigation are logged separately, as tickets or notes, never fixed inside the debugging change. If the fix touches more than three locations, stop and verify that you are fixing one root cause, not patching the same symptom in several places: one bug is one fix.

If it genuinely is one root cause but the fix it needs cannot be contained (several genuinely separate changes rather than one change, a redesign, or a new interface), the work has stopped being a bug fix and this skill stops here. Hand to `design-grill-me` carrying the root cause, the reproduction approach, and the modules that will change. Do not shrink the fix to fit inside this skill, and do not apply a large fix here on the grounds that you already have the context: shrinking leaves the root cause in place, and applying it anyway ships a redesign under a bug-fix approval the user never gave.

Otherwise present the root cause and the proposed fix approach to the user for confirmation. This is the approved design for the bug fix, and it is why a bug does not go through the design step again. You **MUST** wait for explicit approval before moving to Phase 7.

### Phase 7: Fix

Once the user has approved the root cause and the fix approach:

1. **Write the failing regression test first**, through the red-green cycle: the test reproduces the bug, it **MUST** fail before the fix and pass after, and you watch it fail for the right reason.
2. **Implement the minimal fix** per the Minimal Fix Principle above. Do not refactor, do not add features, do not fix unrelated issues.
3. **Request a code review** of the fix and its regression test. No exemption exists for a change that is small, simple, obvious, or locally tested, and a minimal bug fix is the change most likely to claim one. The fix is still uncommitted at this point, because this skill commits only after the Completion Gate; the review diffs against the base rather than across a commit range for exactly this reason, so the uncommitted work is what gets reviewed. The review skill owns the fix-and-re-review loop and processes findings itself, so do not run that loop here. An **Issues outstanding** return means the fix did not pass review, and none of the four return states below is Fixed until it does.
4. **Verify before claiming completion**: run the full relevant test suite fresh, confirm the regression test passes, confirm no other tests broke, and cite the evidence before claiming the fix complete.

## When the Bug Cannot Be Found

If you exhaust the Investigation Budget without a confirmed root cause, present everything you investigated, everything you ruled out, and everything that remains uncertain, and ask the user to help refocus. Do not start guessing. Do not apply a speculative fix.

This is distinct from a non-reproducible bug, which stops at Phase 2 before any hypothesis exists. Here you could reproduce the failure and still could not explain it, so the reproduction is worth handing over: it is the asset the next attempt starts from.

## Return Contract

This skill terminates in one of four states. Say which one explicitly, because three of them are not a fix and the difference decides what happens next.

**Fixed.** The root cause was confirmed and approved, the regression test went red then green, the review was processed, and the verification gate produced fresh evidence. Report the root cause, the test, and the cited evidence.

**Escalated.** Phase 6 confirmed a root cause whose fix exceeds the Minimal Fix Principle. Hand to `design-grill-me` with the root cause, the reproduction, and the affected modules. Nothing has been changed.

**Non-reproducible.** Phase 2 could not reproduce the bug. No fix has been attempted and none may be. The user owes you reproduction conditions.

**Budget exhausted.** The reproduction stands but no hypothesis was confirmed within three cycles. Hand over the reproduction, the eliminated hypotheses, and the open questions.

**Commits.** This skill asks no commit-preference question; a bug report is usually urgent and a one-fix change does not warrant the ceremony that a multi-task orchestration does. Commit the fix and its regression test together with a `fix:` Conventional Commits message once the Completion Gate passes.

## Completion Gate

Before claiming a bug fixed, confirm every box:

- [ ] The bug was reproduced against the current code and the failure was observed
- [ ] The root cause was stated with its causal chain, not just the symptom
- [ ] The user explicitly approved the root cause and the fix approach
- [ ] A regression test was watched failing for the right reason before the fix
- [ ] The fix changes only what the root cause requires
- [ ] A code review ran and its findings were processed
- [ ] Verification ran fresh in the current message and the evidence was cited

An unchecked box means one of the four return states above is the honest one, not "Fixed".

## Rationalisation Prevention

Every thought below means **stop and return to the procedure**:

| You might think...                                                | Reality                                                                                                                                                |
|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| "The error message tells me exactly what's wrong"                 | Error messages describe symptoms. Reproduce and find the root cause.                                                                                   |
| "This is obviously a simple typo or missing null check"           | If it is obvious, reproduction and root cause identification will be fast. Skip nothing.                                                               |
| "Let me just try this quick fix and see if it works"              | That is shotgun debugging. It wastes time when it fails and masks root causes when it works.                                                           |
| "I've been investigating for a while, let me just try something"  | That is the investigation budget telling you to refocus, not to start guessing.                                                                        |
| "I need to read more code to understand the system"               | You need scoped evidence, not system understanding. Read what the bug touches, not everything.                                                         |
| "Let me check a few more files to be thorough"                    | Thoroughness without direction is waste. Form a hypothesis first, then read files to test it.                                                          |
| "The fix is so small it doesn't need a regression test"           | Small fixes for subtle bugs are exactly what regression tests exist for.                                                                               |
| "I can see other issues while I'm here, let me fix those too"     | One bug, one fix. Log other issues separately.                                                                                                         |
| "I don't need to reproduce this, the error is clear"              | Reproduction is verification infrastructure. Without it, you cannot confirm your fix works.                                                            |
| "I can't reproduce it, but the fix is obvious anyway"             | A non-reproducible bug cannot have a verified fix. Phase 2 is where that investigation stops, not a hurdle to route around.                            |
| "The fix is bigger than expected, but I already have the context" | A fix that outgrows the minimal fix principle is new work. Escalate to `design-grill-me` rather than spending saved context on an unapproved redesign. |
| "It's a one-line fix, a code review would be ceremony"            | No exemption exists for small, simple, or obvious. Subtle bugs get small fixes; that is where review pays.                                             |
