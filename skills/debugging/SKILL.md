---
name: debugging
description: "Runs a disciplined, evidence-driven investigation to reproduce a bug and identify its root cause, then returns the evidence and bounded correction to workflow-coordinator for approved execution. Triggered by bugs, errors, failing tests, unexpected behaviour, or anything described as not working. Enforces the hard gate, scope discipline, investigation budget and minimal fix principle."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Debugging

The iron-law rules (the Hard Gate, Evidence Over Intuition, and the bug-fixes-still-need-tests-and-verification cross-references) live in `../../rules/common/debugging.md` and load on every session. The procedural rules that bind once this skill is running (scope discipline, the re-focus rule, the investigation budget, root cause vs symptom, the minimal fix principle, the rationalisation table) live in `RULES.md` alongside this file. The bug-fix TDD rule lives in `../../rules/common/testing.md`. The post-fix verification gate lives in `../../rules/common/verification.md`. This skill runs the seven investigation phases and returns evidence for coordinator-owned execution.

Before running the procedure below, you **MUST** read `RULES.md` (sibling file in this skill directory) and `../_shared/subagent-dispatch.md` (the debugging skill dispatches an investigator subagent) using the Read tool if you have not already read them in this session. The procedure below assumes those rules are in your context.

**Precondition**: the user has reported something not working, pasted an error, reported a failing test, or described behaviour differing from what was intended. If you are unsure whether the report is a bug or a feature request, clarify during Phase 1. This skill runs within a valid `workflow-coordinator` workflow. If invoked directly with no active workflow, invoke `workflow-coordinator` through `{{INVOKE_SKILL_TOOL}}`, pass through the report and any explicit debugging mode or skip, then stop. The coordinator establishes or resumes workflow state and invokes this investigation; on that re-entry, continue without invoking the coordinator again. Respect only explicitly scoped, coordinator-recorded skips. A skip does not create evidence or waive the hard gate.

## Mode Selection

At the start of the investigation, select the mode. If the user has not indicated a preference, pick based on context. If unclear, default to **Collaborative**.

| Mode              | When                                                                           | User involvement                                          |
|-------------------|--------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Collaborative** | User has domain knowledge, complex system, or wants to guide the investigation | High: user helps direct each phase                        |
| **Guided**        | User wants to understand the debugging process, learning context               | High: you explain the reasoning behind each step          |
| **Autonomous**    | User wants the fix; clear error; well-tested codebase                          | Low: you investigate independently and present findings   |

## The Seven Phases

Run the phases in order by default, and do not reorder them. Honour only an explicitly scoped skip recorded by the coordinator. A skipped phase supplies no missing evidence and cannot waive the hard gate or justify a fix, verified, or completion claim.

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

If reproduction fails, check whether the environment matches (dependencies, config, data), ask the user for reproduction steps, and apply the non-reproducibility rule in `../../rules/common/debugging.md` if the bug is truly non-reproducible.

In **Guided mode**, explain why reproduction matters: without it, you cannot verify that any fix works.

### Phase 3: Gather Scoped Evidence

Apply the scope discipline in `../../rules/common/debugging.md`. The initial-scope allowlist and the explicit prohibitions on wider reading are the rules; this phase is where they bite.

In **Autonomous mode**, dispatch two or three investigator subagents in parallel via `{{DISPATCH_AGENT_TOOL}}` using the template at `investigator-prompt.md` in this skill directory:

- One reads the error site and its immediate context
- One checks recent git history for affected files
- One traces the specific code path from the error

Per `../../rules/common/subagents.md`, give each investigator exactly the context it needs and nothing more.

In **Guided mode**, explain what evidence you are gathering and what you are deliberately not looking at yet.

If you hit the Refocus Rule in `../../rules/common/debugging.md` (five files read without a clear hypothesis), stop and return what you know to `workflow-coordinator` for user refocusing before doing anything else.

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

Apply the Investigation Budget from `../../rules/common/debugging.md`: three cycles maximum before you stop and return to `workflow-coordinator` for user refocusing.

### Phase 6: Identify Root Cause

State the root cause clearly, per the root-cause-not-symptom rule in `../../rules/common/debugging.md`:

- **What**: the specific code, configuration, or data causing the issue
- **Why**: the causal chain from the root cause to the observed symptom
- **Since when**: if determinable, when the bug was introduced (commit reference)

Return the evidence, root cause and intended minimal correction to `workflow-coordinator`:

- If a current explicitly approved design covers this reproduced correction, mark it as in-scope and return the evidence and proposed correction for execution under that approval. Do not seek approval again, create a competing design, or implement the correction here.
- If there is no valid approved design, or the evidence requires a scope or architecture change, return the findings to `workflow-coordinator` for Planning and explicit user approval. Do not proceed to implementation.

The investigation's evidence and correction proposal are not themselves approval. The coordinator owns phase transitions, reconciles investigator verdicts and decides whether the existing approval applies. If reproduction was skipped or could not be confirmed, report that accurately and do not claim a confirmed root cause or delegate a fix.

### Phase 7: Coordinator-Owned Execution

Phase 7 is coordinator-owned execution, not an implementation phase performed by this skill. For an in-scope correction, return a bounded task brief to `workflow-coordinator`. The coordinator uses `subagent-driven-development` to assign the regression test and minimal implementation to a worker under the approved task contract. TDD and worker checks run by default; reviews and final verification remain separate coordinator-owned gates. Honour any explicit scoped skips recorded by the coordinator, but never present a skipped reproduction, test, review or verification as evidence or claim the bug fixed or verified without the required fresh evidence. Do not edit code, manually patch worker output, schedule work, or start another autonomous fix flow here.

## Autonomous-Mode Subagent Dispatch

Autonomous mode is the only mode in which investigator subagents run. When dispatching:

- Use the template at `skills/debugging/investigator-prompt.md` as the base prompt
- Provide each investigator with: the bug description (expected vs actual), the specific hypothesis it is testing, and the scoped list of files or areas it may examine
- Per `../../rules/common/subagents.md` and `../_shared/subagent-dispatch.md`, pick the most specific subagent type and a verified model tier suited to the investigation scope. Integration reasoning may require a capable investigator; do not assume an unconditional low-cost default.
- Reconcile the returned verdicts yourself in the orchestrator context: CONFIRMED verdicts advance you to Phase 6, ELIMINATED verdicts move you to the next hypothesis, INCONCLUSIVE verdicts either need a better-scoped re-dispatch or a refocusing with the user

Investigators are evidence-only. A bounded worker owns approved implementation; `workflow-coordinator` owns transitions, dispatch, reviews and verification. The debugging skill and investigator do not patch code or take over execution.

## When the Bug Cannot Be Found

If you exhaust the Investigation Budget without a confirmed root cause, follow the rule in `../../rules/common/debugging.md`: return everything investigated, ruled out and uncertain to `workflow-coordinator` for user refocusing. Do not start guessing or apply a speculative fix.

## Workflow hand-off

Return a structured investigation result to `workflow-coordinator` with reproduction status and exact evidence, ranked hypotheses and test results, confirmed root cause or remaining uncertainty, and the minimal intended correction. State whether the correction is covered by the current approved plan revision or requires Planning and renewed approval. The coordinator reconciles investigator findings and owns all transitions and execution scheduling. Investigators gather evidence only; the assigned bounded worker implements approved changes, and the coordinator obtains required reviews and fresh verification. An explicit skip is recorded with its scope, reason and consequence, and is never reported as a verdict, evidence or successful outcome.

Investigators return their results to the debugging phase for reconciliation before
the debugging phase returns the reconciled evidence, questions, blockers and
proposed correction to the coordinator. The Phase 7 task brief also returns to the coordinator, not to a
second debugging or autonomous fix flow. A debugging handoff ends this
investigation procedure only; the coordinator records the result and next
action in existing `workflow.md` and continues when the approved design and
required evidence permit it. Missing reproduction evidence, user approval,
capability or safe execution remains a pause.
