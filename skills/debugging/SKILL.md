---
name: debugging
description: "Runs a disciplined, evidence-driven investigation to reproduce a bug, identify its root cause, and deliver a minimal verified fix. Triggered by bugs, errors, failing tests, unexpected behaviour, or anything described as not working. For the standing rules on the hard gate, scope discipline, investigation budget, and minimal fix principle, see instructions/common/debugging.md."
---

# Debugging

The governing rules live in `instructions/common/debugging.md`. The bug-fix TDD rule lives in `instructions/common/testing.md`. The post-fix verification gate lives in `instructions/common/verification.md`. This skill is the 7-phase procedure that produces the evidence and the fix those rules require.

**Precondition**: the user has reported something not working, pasted an error, reported a failing test, or described behaviour differing from what was intended. If you are unsure whether the report is a bug or a feature request, clarify during Phase 1.

## Mode Selection

At the start of the investigation, select the mode. If the user has not indicated a preference, pick based on context. If unclear, default to **Collaborative**.

| Mode              | When                                                                           | User involvement                                          |
|-------------------|--------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Collaborative** | User has domain knowledge, complex system, or wants to guide the investigation | High: user helps direct each phase                        |
| **Guided**        | User wants to understand the debugging process, learning context               | High: you explain the reasoning behind each step          |
| **Autonomous**    | User wants the fix; clear error; well-tested codebase                          | Low: you investigate independently and present findings   |

## The Seven Phases

Run the phases in order. You **MUST NOT** skip a phase, and you **MUST NOT** reorder them.

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

If reproduction fails, check whether the environment matches (dependencies, config, data), ask the user for reproduction steps, and apply the non-reproducibility rule in `debugging.md` if the bug is truly non-reproducible.

In **Guided mode**, explain why reproduction matters: without it, you cannot verify that any fix works.

### Phase 3: Gather Scoped Evidence

Apply the scope discipline in `debugging.md`. The initial-scope allowlist and the explicit prohibitions on wider reading are the rules; this phase is where they bite.

In **Autonomous mode**, dispatch two or three investigator subagents in parallel via `{{DISPATCH_AGENT_TOOL}}` using the template at `investigator-prompt.md` in this skill directory:

- One reads the error site and its immediate context
- One checks recent git history for affected files
- One traces the specific code path from the error

Per `instructions/common/subagents.md`, give each investigator exactly the context it needs and nothing more.

In **Guided mode**, explain what evidence you are gathering and what you are deliberately not looking at yet.

If you hit the Refocus Rule in `debugging.md` (five files read without a clear hypothesis), stop and surface what you know to the user before doing anything else.

### Phase 4: Form Hypotheses

Based on the evidence, form two to four ranked hypotheses. Each hypothesis **MUST** include:

- **What**: the specific claim about the root cause
- **Evidence**: the specific observations that support it
- **Predicted observation**: what you would expect to see if the hypothesis is correct

In **Collaborative** and **Guided** modes, present the ranked list to the user. In **Autonomous** mode, rank internally and proceed to test the top two or three.

In **Guided mode**, explain the reasoning behind the ranking. What makes one hypothesis more likely than another?

### Phase 5: Test Hypotheses

Test the most likely hypothesis first:

1. Identify a specific check that would confirm or eliminate it
2. Run the check: read code, add temporary logging, run a test with different input
3. Record the result as evidence for or against
4. If confirmed, proceed to Phase 6. If disproven, move to the next hypothesis.

In **Autonomous mode**, test the top two or three hypotheses in parallel using investigator subagents (see `investigator-prompt.md`), each with a clear scope and a single question to answer. Invoke the `dispatching-parallel-agents` skill if more than one investigator runs at once.

Apply the Investigation Budget from `debugging.md`: three cycles maximum before you stop and refocus with the user.

### Phase 6: Identify Root Cause

State the root cause clearly, per the root-cause-not-symptom rule in `debugging.md`:

- **What**: the specific code, configuration, or data causing the issue
- **Why**: the causal chain from the root cause to the observed symptom
- **Since when**: if determinable, when the bug was introduced (commit reference)

Present the root cause and your proposed fix approach to the user for confirmation. Per `workflow.md`, this is the approved design for the bug fix. You **MUST** wait for explicit approval before moving to Phase 7.

### Phase 7: Fix

Once the user has approved the root cause and the fix approach:

1. **Invoke the `test-driven-development` skill** to write a failing regression test that reproduces the bug. Per `testing.md`, the test **MUST** fail before the fix and pass after. Watch it fail for the right reason.
2. **Implement the minimal fix** per the minimal fix principle in `debugging.md`. Do not refactor, do not add features, do not fix unrelated issues.
3. **Invoke the `verification-before-completion` skill** to run the full relevant test suite, confirm the regression test passes, confirm no other tests broke, and cite the evidence before claiming the fix complete.

## Autonomous-Mode Subagent Dispatch

Autonomous mode is the only mode in which investigator subagents run. When dispatching:

- Use the template at `skills/debugging/investigator-prompt.md` as the base prompt
- Provide each investigator with: the bug description (expected vs actual), the specific hypothesis it is testing, and the scoped list of files or areas it may examine
- Per `subagents.md`, pick the most specific subagent type available (for example `debugger`, `python-pro`, `typescript-pro`) and default to `haiku` unless the investigation requires integration reasoning
- Reconcile the returned verdicts yourself in the orchestrator context: CONFIRMED verdicts advance you to Phase 6, ELIMINATED verdicts move you to the next hypothesis, INCONCLUSIVE verdicts either need a better-scoped re-dispatch or a refocusing with the user

Investigators never fix anything. They only gather evidence. The orchestrator holds the fix authority.

## When the Bug Cannot Be Found

If you exhaust the Investigation Budget without a confirmed root cause, follow the rule in `debugging.md`: present everything you investigated, everything you ruled out, and everything that remains uncertain, and ask the user to help refocus. Do not start guessing. Do not apply a speculative fix.
