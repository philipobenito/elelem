---
name: brainstorming-standard
description: "Develops a proposed design through efficient interactive dialogue with a user who knows the codebase."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Brainstorming (Standard)

Interactive Planning dialogue for a user who already knows the codebase. The conversation is the design medium unless the coordinator authorises staging. This skill returns a self-contained proposed design; it does not approve it or advance the workflow.

The `workflow-coordinator` owns Research, Design Review, explicit final approval, persistence and Wave Planning. Use recorded research and user-approved external inputs rather than repeating broad discovery.

## Preconditions

- This skill runs only in the coordinator's active Planning phase. If no workflow is active, invoke `workflow-coordinator` and preserve standard mode as the requested Planning method. Do not start a second workflow or invoke the router recursively.
- If a coordinator is active but Planning is not the current phase, return control to it without continuing this skill.
- The coordinator verifies active-model capability and actual plan-mode restrictions. Do not silently switch models, repeatedly force a plan-mode toggle, or assume plan mode permits repository writes. Keep drafts in conversation or coordinator-authorised staging.
- Use the research record and relevant context supplied by the coordinator. Investigate only a specific gap that affects requirements or design; do not repeat broad Research.

## Procedure

1. **Orient from research.** Summarise relevant verified findings, assumptions, user decisions and open questions already recorded by Research. Ask one question per message when clarification is needed; use `{{ASK_USER_QUESTION_TOOL}}` for discrete choices and concise prose for discussion.
2. **Explore alternatives.** For each consequential open decision, discuss two or three feasible approaches and their trade-offs. Lead with a reasoned recommendation without presenting it as settled until the user decides. Keep dialogue efficient and within the brief.
3. **Refine sections progressively.** Present and refine the design in coherent sections, seeking the user's agreement on each before proceeding. Cover goal and requirements, exclusions, architecture, components, interfaces, data flow, errors and failure behaviour, and tests/verification. Capture unresolved assumptions explicitly. Do not invent requirements or force unrelated work into the design.
4. **Consolidate a proposed design.** Return one self-contained block covering goal, requirements, exclusions, architecture, components, interfaces, data flow, errors and tests/verification, with relevant assumptions or evidence references. This is a proposal for independent review, not final approval.
5. **Return to the coordinator.** Return the proposed design and unresolved points to `workflow-coordinator`. Do not invoke design review, ask for final approval, persist an approved plan, create tickets or begin implementation.

Returning the proposal ends this Planning procedure, not the overall workflow.
This procedure does not advance the workflow itself.
The coordinator validates and records the result and next action in existing
`workflow.md`, then invokes the next required phase without routine prompting.
Pause only when a user choice or approval, missing input, unsafe state or other
real blocker requires resolution.

## Working in Existing Codebases

- Follow existing patterns. Include targeted changes only when needed for the requested outcome.
- **MUST NOT** propose unrelated refactoring. Per the YAGNI rule in `../../rules/common/coding-style.md`, "while we are here" cleanups are forbidden during a brainstorming pass.

## Common Mistakes

| Mistake                                                                         | Why it is wrong                                                                        |
|---------------------------------------------------------------------------------|----------------------------------------------------------------------------------------|
| Stacking multiple questions in one message                                      | Drowns the user. One question per message, prefer multiple choice.                     |
| Skipping consolidation and returning only conversation history | The coordinator needs one self-contained proposed design. |
| Treating section agreement as final approval                                     | The coordinator separately reviews and obtains explicit final approval.                |
| Inventing requirements the user did not state                                   | YAGNI. The design covers what was asked for, not what you would also build.            |
| Invoking review, ticketing or implementation directly                            | The coordinator owns all workflow transitions. |
| Proposing unrelated refactors discovered during exploration                     | Log them as separate items for the user. Do not bundle them into the design.           |
