---
name: design-review
description: "Independently reviews a proposed design for completeness, consistency, scope and implementation-planning readiness."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Design Review

Runs a holistic review of a consolidated proposed design and bounded supporting evidence. It returns a review verdict to the coordinator, never design approval. The coordinator owns user approval and persistence.

The `workflow-coordinator` invokes this phase and records its verdict separately from explicit user approval. Follow `../_shared/subagent-dispatch.md` for independent high-capability reviewer selection and verified routing; skill metadata does not switch models. Do not silently downgrade.

## Preconditions

The caller must provide a consolidated proposed design as a single block covering goal, requirements, exclusions, architecture, components, interfaces, data flow, error handling and tests/verification. The coordinator may provide it from conversation or authorised staging; `plan.md` need not exist and approval must not precede review. The reviewer receives the proposal and only bounded supporting evidence, never session history. If the coordinator already recorded an explicit review skip, return `SKIPPED` without dispatching. If the user explicitly skips review here, return `SKIPPED`, never `Approved`, and let the coordinator record scope, reason and consequence.

## Procedure

1. **Validate inputs.** If there is no consolidated proposed design, return a blocker to the coordinator. Pass the full proposal and bounded research evidence, source references and assumptions relevant to its claims. Do not require an approved-plan file or use conversation history as evidence.
2. **Dispatch independently.** Use `{{DISPATCH_AGENT_TOOL}}` with the reviewer prompt in `design-reviewer-prompt.md`. Follow the shared dispatch procedure and verify high-capability routing. Do not use a low-cost default or invent a model identifier.
3. **Classify the verdict.** `Approved` means only that no blocking design issue was found; return that verdict and the reviewer's findings. `Issues Found` means the proposal needs correction. Recommendations are advisory.
4. **Resolve issues within the budget.** Minor wording clarifications or completing a missing non-substantive detail may be corrected against supplied evidence and independently re-reviewed. Any substantive change to goal, requirements, architecture, interfaces, errors or test commitments returns to Planning for user discussion. Do not treat that change as approved; the coordinator must obtain renewed explicit approval and run a fresh review.
5. **Respect the three-dispatch limit.** Maximum three reviewer dispatches per review cycle. If the third dispatch still finds issues, return the remaining issues and current proposal to the coordinator without approval.
6. **Return the verdict.** Report `Approved`, `Issues Found`, `SKIPPED` or `BLOCKED`, the review iteration count, findings and whether substantive changes are needed. Do not persist an approved plan, seek final approval or invoke later workflow phases.

## What the Reviewer Checks

| Category     | What to look for                                                               |
|--------------|--------------------------------------------------------------------------------|
| Completeness | Gaps, undefined behaviour, missing components, unanswered questions            |
| Consistency  | Contradictions between sections, conflicting requirements                      |
| Clarity      | Requirements ambiguous enough that someone could build the wrong thing         |
| Scope        | Cohesive and bounded to the stated goal; surface excessive breadth without imposing an arbitrary subsystem-count cutoff |
| YAGNI        | Unrequested features, over-engineering, unnecessary complexity                 |
| Readiness    | Requirements and key contracts are clear enough for later Wave Planning, without designing its task schedule here |

## Calibration

The reviewer **MUST** flag only issues that would cause real problems in planning or implementation. A missing component, contradiction, or ambiguity that could lead to materially different outcomes is an issue. Minor wording and stylistic preferences are not. Do not block solely because the request spans more than three subsystems or would later need multiple implementation tasks. Surface broad scope for Planning discussion only when it threatens coherence, requirements or safe implementation.

The full prompt, bounded evidence fields, calibration and output format live in `design-reviewer-prompt.md`.

The dispatched reviewer returns the verdict and findings to this review phase
for reconciliation. Return the reconciled verdict and any remaining issues to
the coordinator before explicit user approval or another phase. This ends the
review procedure, not the overall workflow. The coordinator records the result
and next action in existing `workflow.md` and continues without routine
prompting only when the applicable approval gate permits it.

## Verdict Gate

Return `Approved` only when the most recent reviewer dispatch for the current proposal returned `Approved`. A skipped review, prior verdict, or your own assessment is not approval. The coordinator separately records user approval.

## Common Mistakes

| Mistake                                                  | Why it is wrong                                                                                                                   |
|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| Passing session history to the reviewer                  | Pass only the proposal and bounded relevant evidence.                                 |
| Reviewing the design yourself                            | Dispatch an independent high-capability reviewer.                                    |
| Continuing past three iterations                         | Return unresolved issues to the coordinator.                                         |
| Treating advisory recommendations as blockers            | Only material issues block.                                                          |
| Treating a skipped review as approval                    | Return `SKIPPED`, not `Approved`.                                                    |
| Returning Approved after substantive changes             | Return to Planning and require renewed user approval and review.                     |
