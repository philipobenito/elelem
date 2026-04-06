---
name: brainstorming
description: "You MUST use this before any code edit: creating features, fixing bugs, building components, adding functionality, refactoring, or modifying behaviour. Routes the design step to standard, guided, committee, or skip mode based on a single user choice, then hands off to the chosen mode skill."
---

# Brainstorming (Router)

This skill is the procedural entry point for the design step required by `../../rules/common/workflow.md`. Its only job is to put the session into plan mode and then hand off to one of four mode skills:

- `brainstorming-standard`: interactive dialogue, user knows the codebase
- `brainstorming-guided`: interactive dialogue with codebase walkthrough, user is new to the area
- `brainstorming-committee`: hands-off deliberation by three subagents, user reviews the final design
- `brainstorming-skip`: lightweight design capture for cases where structured brainstorming would be overkill

For the rule that no implementation may begin until a design has been approved, see `../../rules/common/workflow.md`. For the rule that this skill must be invoked before any code edit, see `../../rules/common/skills-policy.md`.

## When to Run

Invoke this skill before any code edit, no matter how small. The four modes give you a gradient: full structured brainstorming for genuinely new design work, lightweight skip for changes where the design is already obvious to the user. The skip option exists, so the router can be a hard requirement without becoming a usability tax. You **MUST NOT** rationalise your way out of invoking the router by deciding the work is "obvious" or "small", that is the skip option's job, not yours.

## Procedure

1. **Enter plan mode.** Use `{{ENTER_PLAN_TOOL}}`. Plan mode's read-only safety enforces the design-before-implementation rule from `../../rules/common/workflow.md` for the duration of the session, regardless of which mode is chosen.
2. **Ask the user which mode.** Use `{{ASK_USER_QUESTION_TOOL}}` exactly as specified below. **MUST NOT** ask as plain text, and **MUST NOT** assume a default mode without asking.
3. **Hand off via `{{INVOKE_SKILL_TOOL}}`.** Invoke the chosen mode skill and stop. Do not run any of the steps yourself; the mode skill owns the entire procedure from this point. **MUST NOT** invoke more than one mode skill, and **MUST NOT** invoke `create-tickets` or `subagent-driven-development` directly: those are downstream of the mode skill, not of the router.

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
      description: "Hands-off deliberation by 3 AI agents. I will only review the final design."
    - label: "Skip brainstorming"
      description: "I have a clear design already. Capture a brief statement and proceed to implementation."
  multiSelect: false
```

| User picks              | Hand off to               |
|-------------------------|---------------------------|
| Standard brainstorming  | `brainstorming-standard`  |
| Guided brainstorming    | `brainstorming-guided`    |
| Committee brainstorming | `brainstorming-committee` |
| Skip brainstorming      | `brainstorming-skip`      |

## What This Skill Does Not Do

- It does not explore the codebase. The mode skill does that.
- It does not ask clarifying questions about the brief. The mode skill does that.
- It does not present a design. The mode skill does that.
- It does not invoke `design-review`. The interactive mode skills do that; `brainstorming-skip` does not run `design-review` because the user has explicitly chosen a lightweight path.
- It does not invoke `create-tickets` or `subagent-driven-development`. The mode skill does that after the user has approved the design.

If you find yourself doing any of the above inside this skill, stop. You have skipped the hand-off. Invoke the chosen mode skill and let it run.

## Common Mistakes

| Mistake                                                    | Why it is wrong                                                                                    |
|------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Picking a mode for the user                                | The user picks. The router asks.                                                                   |
| Picking `brainstorming-skip` because the work "looks easy" | The user picks the mode. The router never picks skip on the user's behalf.                         |
| Skipping the router because the user said "just add X"     | "Just add X" does not waive the router. Invoke the router; the user can pick skip if they want to. |
| Running the chosen mode's procedure inline                 | The router only routes. Hand off via `{{INVOKE_SKILL_TOOL}}`.                                      |
| Skipping plan mode because the session "feels safe"        | Plan mode is the gate. Enter it before asking the question.                                        |
| Asking the mode question as plain text                     | Use `{{ASK_USER_QUESTION_TOOL}}`. Plain text invites freeform answers that defeat the routing.     |
