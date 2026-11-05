---
name: brainstorming
description: "Routes Planning to standard, guided, committee, or skip mode inside the workflow-coordinator lifecycle."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Brainstorming (Router)

This skill selects a Planning method within the lifecycle owned by `../workflow-coordinator/SKILL.md`. It does not own phase transitions, approval, persistence, review or execution.

- `brainstorming-standard`: interactive dialogue for a user familiar with the codebase
- `brainstorming-guided`: interactive dialogue with explanations for a user new to the area
- `brainstorming-committee`: explicitly selected, hands-off deliberation by three perspectives
- `brainstorming-skip`: lightweight Planning method that captures an existing design

All workflow phases remain on by default. Choosing a Planning method, including skip, does not skip Research, Design Review, explicit final approval or Wave Planning. The coordinator owns these phases and all state transitions.

Use `../_shared/phase-evidence.md`: return explicit method-selection,
selected-mode invocation and proposal provenance to the coordinator. Router
loading alone is not Planning evidence and cannot repair missing Research.

## When to Run

The coordinator invokes this router when the workflow reaches Planning and no Planning method has been selected. Do not choose a method based on task size or complexity. The user chooses explicitly.

## Procedure

1. **Check workflow state.** If there is no active coordinator, invoke `workflow-coordinator` and stop. The coordinator starts or resumes the workflow, completes or reuses Research, then invokes this router when Planning is ready. If a coordinator is active but Planning is not current, return control to it without selecting a method.
2. **Avoid recursion.** When the coordinator invokes this router during active Planning, continue with the mode question. A direct router invocation must not invoke a mode prematurely.
3. **Ask for a method.** Use `{{ASK_USER_QUESTION_TOOL}}` exactly as specified below. Do not ask as plain text or assume a default.
4. **Record and hand off.** Preserve the selected method in coordinator state, then invoke exactly one selected mode skill using `{{INVOKE_SKILL_TOOL}}`. Stop after hand-off. Mode skills return proposed designs; they do not transition phases.

Stop after hand-off ends the current phase procedure only, not the overall workflow.
The selected mode returns its proposal and unresolved choices to the coordinator;
the coordinator records the result and next action in existing `workflow.md`
and continues through required phases without routine prompts. A required user
choice or approval remains a pause.

## The Mode Question

```
{{ASK_USER_QUESTION_TOOL}}:
  question: "How would you like to approach the design step?"
  header: "Mode"
  options:
    - label: "Standard brainstorming"
      description: "Interactive dialogue. I know the codebase. Reach a design efficiently."
    - label: "Guided brainstorming"
      description: "Interactive dialogue with codebase walkthrough. New to the area, teach me as we go."
    - label: "Committee brainstorming"
      description: "Explicitly choose hands-off deliberation by three perspectives."
    - label: "Skip brainstorming"
      description: "Capture an existing design as a proposal. Other workflow phases still run."
  multiSelect: false
```

| User picks              | Hand off to               |
|-------------------------|---------------------------|
| Standard brainstorming  | `brainstorming-standard`  |
| Guided brainstorming    | `brainstorming-guided`    |
| Committee brainstorming | `brainstorming-committee` |
| Skip brainstorming      | `brainstorming-skip`      |

## What This Skill Does Not Do

- It does not run Research or repeat recorded research; the coordinator supplies findings and approved external inputs to Planning.
- It does not present or approve a design. The selected method develops a proposal; the coordinator owns independent review and explicit final approval.
- It does not skip a workflow phase. A user must explicitly authorise any phase skip through the coordinator, with scope, reason and consequence recorded.
- It does not invoke `design-review`, ticketing or implementation skills. The coordinator owns those transitions.

If there is no active coordinator, invoke it rather than starting a standalone brainstorming flow. A direct mode invocation follows the same rule and preserves the requested method.

## Common Mistakes

| Mistake                                                    | Why it is wrong                                                                                    |
|------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Picking a mode for the user                                | The user picks. The router asks.                                                      |
| Picking skip because the task looks small                  | Complexity never skips a phase or chooses a method automatically.                     |
| Treating skip as skipping the workflow                     | Skip is a Planning method only. Other phases remain on.                               |
| Starting a standalone brainstorming flow                   | The coordinator owns lifecycle and resumes without recursive routing.                 |
| Running a mode procedure inline                            | Hand off via `{{INVOKE_SKILL_TOOL}}`.                                                 |
| Assuming plan-mode behaviour                               | Respect actual harness restrictions; use conversation or authorised staging for drafts. |
