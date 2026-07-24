---
name: debugging
description: "Runs a disciplined, evidence-driven investigation to reproduce a bug, identify its root cause, and deliver a minimal verified fix. You MUST use this before touching any code in response to a bug, an error, a crash, a failing or flaky test, a regression, or anything described as not working, including one-line fixes and changes that look like an obvious typo: the hard gate (no fix without a reproduction and an identified root cause) applies however simple the fix looks. Enforces scope discipline, the investigation budget, and the minimal fix principle, and takes its own approval for the fix approach so bugs do not go through the brainstorming router."
---

# Debugging

The iron-law rules (the Hard Gate, Evidence Over Intuition, and the bug-fixes-still-need-tests-and-verification cross-references) live in `../../rules/common/debugging.md` and load on every session. The procedural rules that bind once this skill is running (reproduction, scope discipline, the Refocus Rule, the investigation budget, root cause vs symptom, the minimal fix principle, the rationalisation table) live in `RULES.md` alongside this file, and every reference to them below points there. The bug-fix TDD rule lives in `../../rules/common/testing.md`. The post-fix verification gate lives in `../../rules/common/verification.md`. This skill is the seven-phase procedure that produces the evidence and the fix those rules require.

Before running the procedure below, read `RULES.md` using the Read tool if you have not already read it this session. The procedure assumes those rules are in your context. Read `../_shared/subagent-dispatch.md` only if you select Autonomous mode, which is the only mode that dispatches subagents; loading a dispatch protocol for an investigation you will run yourself costs context and buys nothing.

**Precondition**: the user has reported something not working, pasted an error, reported a failing test, or described behaviour differing from what was intended. If you are unsure whether the report is a bug or a feature request, clarify during Phase 1.

## Mode Selection

The three modes differ in who holds the wheel, not in how much rigour applies. Every phase runs in every mode.

| Mode              | When                                                                                       | How it runs                                                                                      |
|-------------------|--------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| **Collaborative** | The user knows this system and wants to steer; the failure spans components you cannot see | The user directs. You surface findings at each phase boundary and follow the direction they pick |
| **Guided**        | The user is unfamiliar with this system, or wants to learn how the investigation works     | You drive and narrate. You explain the reasoning behind each step as you take it                 |
| **Autonomous**    | The user has asked for the fix rather than the process; clear error; well-tested codebase  | You investigate independently with subagents and present findings once                           |

Pick between Collaborative and Guided from context: Collaborative when the user is already reasoning about the cause with you, Guided when they are asking what is happening or why. If it is unclear, default to Collaborative, because a user who did not want to steer can say so far more cheaply than a user who wanted to steer can undo an unsupervised investigation.

Autonomous mode is different in kind: it spends the most context with the least supervision. Select it only when the user has asked for it or has made clear they do not want to be involved. You **MUST NOT** select it on the user's behalf because the bug looks tractable.

## The Seven Phases

Run the phases in order. You **MUST NOT** skip a phase, and you **MUST NOT** reorder them. Two phases can terminate the skill early: Phase 2 when the bug is non-reproducible, and Phase 6 when the fix turns out to be too large. Both exits are described in place.

### Phase 1: Understand the Problem

Before touching code, establish:

- **Expected behaviour**: what should happen?
- **Actual behaviour**: what happens instead?
- **Trigger conditions**: when does it happen? Always, or only under specific conditions?
- **Recency**: when did it last work? What changed since then?

If the bug report is ambiguous, ask clarifying questions. Do not guess at what "broken" means.

In **Guided mode**, explain why each question matters for narrowing the search space.

### Phase 2: Reproduce

Run the failing scenario and observe the actual output:

- Run the failing test, command, or user action
- Capture the exact error output, stack trace, or incorrect behaviour
- Confirm the bug exists in the current state of the code

If reproduction fails, check whether the environment matches (dependencies, config, data) and ask the user for reproduction steps.

If the bug is still not reproducible, the Reproduction Is Non-Negotiable rule in `RULES.md` applies and the sequence stops here. Say explicitly that the bug is non-reproducible, present what the evidence supports at reduced confidence, and ask the user for the conditions you are missing. You **MUST NOT** continue to Phase 7: a non-reproducible bug cannot have a verified fix, so there would be nothing for the verification gate to check and no way to tell a fix from a coincidence.

In **Guided mode**, explain why reproduction matters: without it, you cannot verify that any fix works.

### Phase 3: Gather Scoped Evidence

Apply the scope discipline in `RULES.md`. The initial-scope allowlist and the explicit prohibitions on wider reading are the rules; this phase is where they bite.

In **Autonomous mode**, dispatch two or three evidence subagents in parallel via `Agent` using the template at `evidence-prompt.md` in this skill directory:

- One reads the error site and its immediate context
- One checks recent git history for affected files
- One traces the specific code path from the error

Use `evidence-prompt.md` rather than `investigator-prompt.md` here. No hypothesis exists yet, and the investigator template demands a verdict on one; an investigator dispatched at this phase can only invent a hypothesis or return INCONCLUSIVE by construction.

Per `../../rules/common/subagents.md`, give each subagent exactly the context it needs and nothing more.

In **Guided mode**, explain what evidence you are gathering and what you are deliberately not looking at yet.

Apply the Refocus Rule in `RULES.md`. When you gather the evidence yourself, the trigger is five files read without a clear hypothesis. When you delegate it in Autonomous mode, the trigger is the sweep: if a round of evidence subagents returns and you still cannot state a hypothesis, that is the same signal, and you **MUST NOT** dispatch a second round. Either way, stop and surface what you know to the user before doing anything else.

### Phase 4: Form Hypotheses

Based on the evidence, form two to four ranked hypotheses. Each hypothesis **MUST** include:

- **What**: the specific claim about the root cause
- **Evidence**: the specific observations that support it
- **Predicted observation**: what you would expect to see if the hypothesis is correct

In **Collaborative** and **Guided** modes, present the ranked list to the user. In **Collaborative** mode the user picks which to test first; in **Guided** mode you pick and explain the ranking. In **Autonomous** mode, rank internally and proceed to test the top two or three.

### Phase 5: Test Hypotheses

Test the most likely hypothesis first:

1. Identify a specific check that would confirm or eliminate it
2. Run the check: read code, add temporary logging, run a test with different input
3. Record the result as evidence for or against
4. If confirmed, proceed to Phase 6. If disproven, move to the next hypothesis.

In **Autonomous mode**, test the top two or three hypotheses in parallel using investigator subagents (see `investigator-prompt.md`), each with a clear scope and a single question to answer. Invoke the `dispatching-parallel-agents` skill if more than one investigator runs at once.

Apply the Investigation Budget from `RULES.md`: three cycles maximum before you stop and refocus with the user. A parallel round is one cycle however many hypotheses it tests, because the budget limits how many times you re-frame the problem before asking for help, not how many hypotheses you hold at once.

### Phase 6: Identify Root Cause

State the root cause clearly, per the Root Cause, Not Symptom rule in `RULES.md`:

- **What**: the specific code, configuration, or data causing the issue
- **Why**: the causal chain from the root cause to the observed symptom
- **Since when**: if determinable, when the bug was introduced (commit reference)

Then check the fix against the Minimal Fix Principle in `RULES.md` before proposing it. If the confirmed root cause needs work that principle cannot contain (several genuinely separate changes rather than one change, a redesign, or a new interface), the work is no longer a bug fix and this skill stops here. Per `../../rules/common/workflow.md`, hand back to the `brainstorming` router carrying the root cause, the reproduction approach, and the modules that will change, which is exactly the payload `brainstorming-skip` expects from an escalation. Do not shrink the fix to fit inside this skill, and do not apply a large fix here on the grounds that you already have the context.

Otherwise present the root cause and the proposed fix approach to the user for confirmation. Per `../../rules/common/workflow.md`, this is the approved design for the bug fix, and it is why a bug does not go back through the router. You **MUST** wait for explicit approval before moving to Phase 7.

### Phase 7: Fix

Once the user has approved the root cause and the fix approach:

1. **Invoke the `test-driven-development` skill** to write a failing regression test that reproduces the bug. Per `../../rules/common/testing.md`, the test **MUST** fail before the fix and pass after. Watch it fail for the right reason.
2. **Implement the minimal fix** per the Minimal Fix Principle in `RULES.md`. Do not refactor, do not add features, do not fix unrelated issues.
3. **Invoke the `requesting-code-review` skill** against the fix and its regression test. `../../rules/common/code-review.md` grants no exemption for a change that is small, simple, obvious, or locally tested, and a minimal bug fix is the change most likely to claim one. Process the result through `receiving-code-review`.
4. **Invoke the `verification-before-completion` skill** to run the full relevant test suite, confirm the regression test passes, confirm no other tests broke, and cite the evidence before claiming the fix complete.

## Autonomous-Mode Subagent Dispatch

Autonomous mode is the only mode in which subagents run. Phase 3 dispatches evidence gatherers via `evidence-prompt.md`; Phase 5 dispatches hypothesis testers via `investigator-prompt.md`. Both templates live in this skill directory.

Provide each subagent with: the bug description (expected vs actual), its single assignment (the evidence question at Phase 3, the hypothesis at Phase 5), and the scoped list of files or areas it may examine.

Resolve the subagent type at dispatch time, every time. `../_shared/subagent-dispatch.md` requires the most specific available type, and `../../rules/common/subagents.md` forbids writing an identifier you have not confirmed this environment exposes. Many types are plugin-supplied and namespaced (`voltagent-qa-sec:debugger`), so a bare name copied from any table may not resolve at all:

1. Enumerate the `subagent_type` values this environment exposes.
2. Search that enumeration for a debugging, diagnostic, or error-analysis type, or for a language specialist matching the code under investigation.
3. Take the most specific match, whatever its namespace.
4. Where nothing matches, use `general-purpose`, which is present in every environment.

Start at the Low-cost default tier, resolved per `../_shared/subagent-dispatch.md`, unless the investigation requires integration reasoning, in which case escalate to Standard escalation.

Reconcile the returned reports yourself in the orchestrator context. Evidence reports feed Phase 4. Investigator verdicts route as follows: CONFIRMED advances you to Phase 6, ELIMINATED moves you to the next hypothesis, INCONCLUSIVE needs either a better-scoped re-dispatch or a refocus with the user.

Subagents never fix anything. They only gather evidence. The orchestrator holds the fix authority.

## When the Bug Cannot Be Found

If you exhaust the Investigation Budget in `RULES.md` without a confirmed root cause, present everything you investigated, everything you ruled out, and everything that remains uncertain, and ask the user to help refocus. Do not start guessing. Do not apply a speculative fix.

This is distinct from a non-reproducible bug, which stops at Phase 2 before any hypothesis exists. Here you could reproduce the failure and still could not explain it, so the reproduction is worth handing over: it is the asset the next attempt starts from.

## Return Contract

This skill terminates in one of four states. Say which one explicitly, because three of them are not a fix and the difference decides what happens next.

**Fixed.** The root cause was confirmed and approved, the regression test went red then green, the review was processed, and the verification gate produced fresh evidence. Report the root cause, the test, and the cited evidence.

**Escalated.** Phase 6 confirmed a root cause whose fix exceeds the Minimal Fix Principle. Hand to the `brainstorming` router with the root cause, the reproduction, and the affected modules. Nothing has been changed.

**Non-reproducible.** Phase 2 could not reproduce the bug. No fix has been attempted and none may be. The user owes you reproduction conditions.

**Budget exhausted.** The reproduction stands but no hypothesis was confirmed within three cycles. Hand over the reproduction, the eliminated hypotheses, and the open questions.

**Commits.** This skill asks no commit-preference question; a bug report is usually urgent and a one-fix change does not warrant the ceremony that a multi-task orchestration does. Committing follows `../../rules/common/git.md`, which permits commits without asking, so commit the fix and its test together with a `fix:` Conventional Commits message once the Completion Gate passes. You **MUST NOT** push.

## Completion Gate

Before claiming a bug fixed, confirm every box:

- [ ] The bug was reproduced against the current code and the failure was observed
- [ ] The root cause was stated with its causal chain, not just the symptom
- [ ] The user explicitly approved the root cause and the fix approach
- [ ] A regression test was watched failing for the right reason before the fix
- [ ] The fix changes only what the root cause requires
- [ ] `requesting-code-review` ran and its findings were processed
- [ ] `verification-before-completion` ran fresh in the current message and the evidence was cited

An unchecked box means one of the four return states above is the honest one, not "Fixed".
