---
name: brainstorming-guided
description: "Develops a proposed design with an explanatory codebase walkthrough for a user new to the area."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Brainstorming (Guided)

Interactive Planning dialogue with built-in teaching for a user who does not know the codebase well. Use the coordinator's recorded Research instead of repeating broad discovery. Return a self-contained proposed design; review, final approval, persistence and later phases belong to the coordinator.

The `workflow-coordinator` owns lifecycle and verifies the active model and actual plan-mode restrictions. Do not silently switch models or assume repository writes are allowed in plan mode.

## Preconditions

- This skill runs only in the coordinator's active Planning phase. If directly invoked without an active workflow, invoke `workflow-coordinator`, preserve guided mode as the requested method and stop. Do not start another workflow or invoke the router recursively.
- If a coordinator is active but Planning is not the current phase, return control to it without continuing this skill.
- Keep drafts in conversation or coordinator-authorised staging. Use research.md and relevant approved inputs supplied by the coordinator; investigate only a consequential gap. Respect actual harness plan-mode controls without repeatedly forcing toggles.

## Communication Principles

These principles apply at every step of the procedure. They are what makes this skill different from `brainstorming-standard`:

- **Show your working.** When you read a file, name the file and explain what you found and why it matters for the design.
- **Name the patterns.** When the codebase follows a recognisable pattern (repository, MVC, event sourcing, plugin host), name it explicitly and explain it in one or two sentences.
- **Surface conventions.** Naming, testing approach, error handling, and module layout are conventions the user may not know. State them.
- **Invite questions.** After each explanation, ask if anything needs deeper exploration before moving on.

## Procedure

1. **Walk through relevant research.** Explain verified findings from Research, their sources, relevant patterns and why each matters to the design. Distinguish facts, assumptions and user decisions. Do not repeat broad codebase discovery already done in Research.
2. **Invite exploration.** After each short explanatory section, ask whether the user wants more detail before proceeding. Ask one contextualised design question per message when needed. Explain unfamiliar terminology and anchor questions to evidence.
3. **Compare approaches.** For consequential open decisions, present two or three feasible approaches grounded in research, their trade-offs and a recommendation. Let the user decide.
4. **Refine sections progressively.** Explain and refine goal and requirements, exclusions, architecture, components, interfaces, data flow, errors/failure behaviour, and tests/verification. Seek agreement on each section before proceeding. Teaching is not permission to add features.
5. **Consolidate and return.** Provide a self-contained proposed design covering these sections, assumptions and evidence references. Return it to `workflow-coordinator` for independent review. It is not final approval.
6. **Stop at the Planning boundary.** Do not invoke design review, ask for final approval, persist an approved plan, create tickets or begin implementation.

Stop at the Planning boundary ends this guided procedure, not the overall
workflow. This procedure does not advance the workflow itself. The coordinator validates and records the proposal and next action in
existing `workflow.md`, then invokes the next required phase without routine
prompting. A user choice or approval and any genuine missing input remain
required pauses.

## What Guided Mode Does Not Change

- One question per message, multiple choices are preferred.
- YAGNI applies. Teaching the user about the codebase is not a licence to design extra features.
- The coordinator owns independent review, explicit final approval and all subsequent phases.

## Common Mistakes

| Mistake                                                  | Why it is wrong                                                                                                                                   |
|----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Skipping the walkthrough to "save time"                  | The walkthrough is the difference between this skill and `brainstorming-standard`. Without it, use the standard skill instead.                    |
| Walking through the entire codebase                      | Stay scoped. Walk the area the brief touches and the patterns directly relevant to the design.                                                    |
| Naming patterns without explaining them                  | The user does not know the codebase. "It uses the repository pattern" without an explanation is just jargon.                                      |
| Asking abstract questions instead of contextualised ones | "How should we handle errors?" is abstract. "Errors are wrapped with `fmt.Errorf` at every layer here, should we follow that?" is contextualised. |
| Treating the walkthrough as documentation                | The walkthrough lives in the conversation. It is not written to disk and is not a deliverable.                                                    |
