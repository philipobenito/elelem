---
name: brainstorming-skip
description: "Captures an existing design as a lightweight Planning proposal; other workflow phases remain active."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Brainstorming (Lightweight Planning)

This is the lightweight Planning method selected explicitly by the user. It captures an existing design as a proposed design without a full alternatives dialogue. It does not skip Research, independent Design Review, explicit final approval or Wave Planning.

The `workflow-coordinator` owns lifecycle, explicit phase skips, final approval, persistence and downstream work. Selecting this method is not authorisation to skip any phase.

## Preconditions

- This skill runs only in the coordinator's active Planning phase. If directly invoked without an active workflow, invoke `workflow-coordinator`, preserve lightweight Planning as the requested method and stop. Do not start another workflow or invoke the router recursively.
- If a coordinator is active but Planning is not the current phase, return control to it without continuing this skill.
- The user must explicitly select this method. Respect actual harness plan-mode restrictions; keep drafts in conversation or coordinator-authorised staging. Do not silently switch models or force plan-mode toggles.
- Research and approved external inputs come from the coordinator. If the existing design lacks required detail, ask one focused question or return the gap to the coordinator; do not guess.

## Procedure

1. **Reuse existing design input.** Check the current conversation and coordinator-supplied approved inputs for the design already described. Do not ask the user to repeat it.
2. **Ask only when needed.** If no design exists, ask for a concise statement. Ask one focused follow-up only when a required design point is genuinely ambiguous or missing; if more exploration is needed, return to the coordinator for another Planning method.
3. **Shape the proposal.** Capture goal, requirements, exclusions, architecture, components, interfaces, data flow, errors/failure behaviour and tests/verification. Use explicit assumptions and research references. Do not invent acceptance criteria or claim the design is approved.
4. **Return to the coordinator.** Return one self-contained proposed-design block and unresolved points. The coordinator runs any required independent review, seeks explicit final approval, persists the approved plan, and proceeds with Wave Planning.

Returning the proposed-design block ends this Planning procedure only. The
procedure does not stop the overall workflow. The coordinator validates and records the proposal and next action in existing
`workflow.md`, then invokes the next required phase without routine prompting.
Lightweight Planning is not a phase skip; user choices, approval and missing
inputs remain governed by the usual gates.

## What Skip Mode Does Not Do

- It does not repeat Research or run independent Design Review; those remain coordinator-owned phases.
- It does not treat the user's original statement or section confirmation as final approval.
- It does not skip any workflow phase. Any explicit phase skip must be requested and recorded by the coordinator separately.
- It does not invoke review, ticketing or implementation skills.

## Common Mistakes

| Mistake                                                          | Why it is wrong                                                                                                                                |
|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Treating this as a phase skip                                   | It is a Planning method only; all other phases remain on by default.                  |
| Stacking multiple clarifying questions                           | Skip is the lightweight path. If you need a dialogue, the user should be in standard or guided mode instead.                                   |
| Treating the proposal as approved                               | The coordinator separately runs review and obtains explicit final approval.            |
| Invoking review, ticketing or implementation directly             | The coordinator owns every workflow transition.                                       |
| Inventing requirements not in the user's statement               | YAGNI per `../../rules/common/coding-style.md`. The design covers what the user asked for, not what you would also build.                     |
| Selecting this method automatically                             | The user must explicitly choose it through the router or coordinator.                 |
| Asking "what would you like to build" when a design was already discussed in the conversation | Re-check context first. Making the user repeat an already-stated design defeats the point of skip mode and ignores the spirit of prior discussion. |
| Asking a follow-up question to confirm something already unambiguous in context | Only ask when something is genuinely ambiguous or missing, not as a reflexive double-check. |
