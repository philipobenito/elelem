---
name: research
description: "Conducts user-directed conversational investigation and records evidence for a workflow design."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Research

Investigates the codebase, documentation, architecture records and necessary
external sources before planning. This is a preparation phase and requires
high-capability reasoning. Before conversational research, verify the active
primary-session model is appropriate. Metadata does not switch the active
model. If unsuitable, stop and ask the user to switch models; do not switch
silently. Record the confirmed model and reuse that confirmation while it
remains active, without prompting again. Before dispatching a researcher, read
`../_shared/subagent-dispatch.md` at execution time and verify model
availability and routing separately. If unavailable, report a blocker rather
than silently using a lower capability.

## Conversation

Research is collaborative by default. Start from the user's goal, use
`../_shared/project-context-discovery.md` as the bounded repository discovery
helper, and surface findings, uncertainty, options and consequential
questions. Ask the user which uncertainty or option to investigate next, then
refine the investigation with their input. Do not silently produce an
autonomous research report as a substitute for this dialogue.

Committee mode is available only when the user explicitly chooses the
less-conversational approach for Research, independently of any later Planning
choice. Return procedure and user-choice provenance under
`../_shared/phase-evidence.md`; invocation or code reading alone is insufficient.
In either mode, separate verified facts,
assumptions and user decisions. Cite repository paths and external sources;
distinguish evidence from interpretation. Investigate only what can affect
requirements, architecture, interfaces, risks or verification.

Use `{{ASK_USER_QUESTION_TOOL}}` for investigation choices and questions.
Respect plan-mode write restrictions. Keep drafts in conversation or an
authorised staging location until repository writing is allowed. Do not create
or edit shared workflow state; the coordinator owns it.

## Research record

When persistence is authorised, the coordinator records findings in
`.elelem/workflows/<ticket-or-slug>/research.md`. Preserve existing content
unless the coordinator explicitly updates the same workflow record. Include:

- Scope and questions investigated.
- Findings with paths, symbols, commands or source references.
- Verified facts, assumptions and unresolved uncertainty, labelled distinctly.
- Options and trade-offs discussed with the user, including selected direction.
- External references and the date checked when current facts matter.
- Remaining questions that planning must resolve.

Research informs planning but does not approve a design, implementation or
workflow transition. Return the record and unresolved points to the coordinator.
If evidence is unavailable or contradictory, state that limitation instead of
filling the gap with an assumption.

## Handoff

Return findings, evidence references, user direction, remaining questions and
blockers to the active coordinator. This ends the Research procedure; it does
not stop the overall workflow. The coordinator validates the result against the
current scope and state, records the next action in existing `workflow.md`, and
invokes the next required phase when its inputs are sufficient. Do not invoke a
second coordinator or treat an unanswered question or missing input as resolved.
