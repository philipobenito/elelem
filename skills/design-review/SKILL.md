---
name: design-review
description: "Reviews a consolidated design summary for completeness, consistency, clarity, scope, and YAGNI issues by dispatching a reviewer subagent against the summary text and iterating until the design is approved or escalated."
---

# Design Review

Runs a holistic review, passes over a consolidated design summary, catches issues that incremental approval missed, and either returns an approved design or escalates after the iteration budget is exhausted.

For the rule that no implementation may begin until a design has been approved, see `instructions/common/workflow.md`. For the rules on dispatching the reviewer subagent (context isolation, type selection, model selection), see `instructions/common/subagents.md`.

## Preconditions

This skill **MUST NOT** be invoked until the caller has produced a consolidated design summary as a single block of text covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. Reviewing a design that lives only in conversation history is forbidden because the reviewer must receive the design text directly and **MUST NOT** inherit session context.

## Procedure

1. **Confirm the summary is consolidated.** If the caller has not produced a single design summary block, stop and tell the caller to consolidate before invoking this skill.
2. **Dispatch the reviewer.** Use `{{DISPATCH_AGENT_TOOL}}` to dispatch a reviewer subagent following `design-reviewer-prompt.md`. Paste the full design summary into the prompt. Do not pass session history. Default model: `haiku`. Escalate to `sonnet` only if the design is architecturally complex enough that the reviewer needs deeper reasoning, per the model selection rules in `subagents.md`.
3. **Read the reviewer's status.**
   - **Approved**: return the design summary unchanged to the caller. Done.
   - **Issues Found**: extract each issue, decide whether the fix is a wording change, a missing section, or a substantive design change.
4. **Apply fixes to the summary.** Edit the design summary text to address each issue. Substantive design changes (not just wording) **MUST** be flagged when the summary is returned to the caller, because the caller may need to surface the change to the user before continuing.
5. **Re-dispatch.** Run the reviewer again against the updated summary.
6. **Iteration budget.** Maximum three reviewer dispatches. If the third dispatch still returns issues, **STOP** and surface the remaining issues plus the current summary to the caller. The caller decides whether to escalate to the human partner.
7. **Return the approved summary.** When a dispatch returns Approved, return the (possibly updated) design summary text to the caller along with a one-line note recording how many iterations the review took and whether any substantive changes were made.

## What the Reviewer Checks

| Category     | What to look for                                                               |
|--------------|--------------------------------------------------------------------------------|
| Completeness | Gaps, undefined behaviour, missing components, unanswered questions            |
| Consistency  | Contradictions between sections, conflicting requirements                      |
| Clarity      | Requirements ambiguous enough that someone could build the wrong thing         |
| Scope        | Focused enough for a single plan, not covering multiple independent subsystems |
| YAGNI        | Unrequested features, over-engineering, unnecessary complexity                 |

## Calibration

The reviewer **MUST** only flag issues that would cause real problems during implementation planning. A missing component, a contradiction, or a requirement so ambiguous it could be interpreted two different ways are issues. Minor wording improvements, stylistic preferences, and "sections less detailed than others" are not.

The full prompt with calibration language and output format lives in `design-reviewer-prompt.md`.

## Worked Example

The caller (a brainstorming skill) consolidates a design summary for a new ingest pipeline and invokes this skill.

- **Iteration 1**: reviewer flags two issues. Issue A: "Error handling section does not say what happens when the upstream feed returns malformed records." Issue B: "Components section lists `IngestWorker` but interfaces section never describes how `IngestWorker` is invoked." Both are real gaps. Caller adds an "Upstream malformed input" subsection to error handling and an interface description for `IngestWorker`. Substantive design change flagged: introducing the malformed-input handling adds a dead-letter queue that was not in the original conversation, so this is surfaced for caller review.
- **Iteration 2**: reviewer returns Approved with one advisory recommendation about consistent terminology. Approved design summary returned to the caller along with the substantive-change note from iteration 1.

## Completion Gate

You **MUST NOT** return Approved to the caller unless the most recent reviewer dispatch in this invocation returned Approved. A previous Approved from earlier in the session, or your own belief that the issues are minor, does not count.

## Common Mistakes

| Mistake                                                  | Why it is wrong                                                                                                                   |
|----------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| Passing session history to the reviewer                  | Violates context isolation. The reviewer must read only the design summary, otherwise it grades the conversation, not the design. |
| Skipping the dispatch and reviewing the summary yourself | The orchestrator's perspective is not a fresh review. The whole point is the second pair of eyes.                                 |
| Continuing past three iterations                         | The budget exists to prevent endless polish loops. Past three, the caller and the human need to decide whether to redesign.       |
| Treating advisory recommendations as blockers            | Recommendations are advisory. Only Issues block.                                                                                  |
| Returning Approved without re-dispatching after fixes    | The Approved status must come from a reviewer run against the updated summary, not the original.                                  |
