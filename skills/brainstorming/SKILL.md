---
name: brainstorming
description: "You MUST use this before any code edit: creating features, building components, adding functionality, refactoring, or modifying behaviour. Enters plan mode, then routes the design step to one of four modes (standard, guided, committee, or skip) on a single user choice and hands off to the chosen mode skill. For a bug, run `debugging` instead: it takes its own approval for the fix approach and returns here only if the fix turns out to be too large to apply minimally."
---

# Brainstorming (Router)

This skill is the procedural entry point for the design step required by `../../rules/common/workflow.md`. Its only job is to put the session into plan mode and then hand off to one of four mode skills:

- `brainstorming-standard`: interactive dialogue, user knows the codebase
- `brainstorming-guided`: interactive dialogue with codebase walkthrough, user is new to the area
- `brainstorming-committee`: hands-off deliberation by three subagents, user reviews the final design
- `brainstorming-skip`: lightweight design capture for cases where structured brainstorming would be overkill

For the rule that no implementation may begin until a design has been approved, see `../../rules/common/workflow.md`. For the rule that this skill must be invoked before any code edit, see `../../rules/common/skills-policy.md`.

## When to Run

Invoke this skill before any code edit, no matter how small. The four modes give you a gradient: full structured brainstorming for genuinely new design work, lightweight skip for changes where the design is already obvious to the user. The skip option exists so the router can be a hard requirement without becoming a usability tax. Deciding the work is "obvious" or "small" is the skip option's job, not yours.

## When Not to Run

**For a bug, `debugging` runs instead.** Reproduction and root cause come before design, because until you know what is actually broken there is nothing to design, and routing first produces a design for a bug nobody has reproduced. `debugging` Phase 6 then takes its own approval for the fix approach, and per `../../rules/common/workflow.md` that approval is the design: the bug does not come back here. Expect a return only when the root cause turns out to need work too large for the minimal fix principle, at which point it is new work and the mode question is worth asking again.

**Run once per design, not once per edit.** Once a mode skill has produced an approved design and handed off, every edit that follows is covered by that approval. Do not re-enter the router for each file an implementation touches, and never re-enter it from inside an orchestration loop: that re-enters plan mode and stalls the orchestrator mid-task. Come back only when the user brings genuinely new work, or when the approved design turns out to be wrong (see the stopping conditions in `../../rules/common/workflow.md`).

## Procedure

1. **Enter plan mode.** `EnterPlanMode` is a deferred tool in some sessions, meaning a direct call fails until its schema is loaded. If it is not already available, load it with `ToolSearch` (`select:EnterPlanMode`) first, then call it. Plan mode's read-only safety is what enforces the design-before-implementation rule from `../../rules/common/workflow.md` for the rest of the session, whichever mode is chosen, which is why it comes before the mode question rather than after.

   If plan mode genuinely cannot be entered in this environment, do not stop the design step. Tell the user plan mode is unavailable, ask the mode question anyway, and tell the chosen mode skill that its plan-mode precondition is unmet so it does not assume otherwise. The router is the only sanctioned route to an approved design, so halting here leaves no legal path to any code edit at all. A design captured without plan mode is weaker than one captured with it, and far better than no design.

2. **Ask the user which mode.** Use `AskUserQuestion` exactly as specified below, never plain text: freeform answers defeat the routing. The point of the question is that *you* never choose on the user's behalf, so if the user has already named a mode in their own message, they have chosen. Confirm it in one line and hand off. Absent that, ask. Never proceed on a mode you inferred from the shape of the work.

3. **Hand off via `Skill`.** Invoke the chosen mode skill and stop. Invoke exactly one, and nothing else.

## The Mode Question

```
AskUserQuestion:
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
| Other (free text)       | Map it, then confirm      |

`AskUserQuestion` always offers an "Other" box, and these option descriptions are written in the user's own voice, which invites them to nuance an answer rather than accept a label. When they do, read their text for the mode it implies and confirm the mapping in one line ("That sounds like standard mode, kept brief. Shall I go with that?"). If the text is an instruction for the mode skill rather than a mode choice, carry it into the hand-off as context. If it implies no mode at all, ask again. Do not silently pick.

## Stay Out of the Mode Skill's Job

The router routes. It does not explore the codebase, ask clarifying questions about the brief, present a design, invoke `design-review`, or invoke `create-tickets` or any orchestration skill. All of those belong to the mode skill and run after the hand-off. (`brainstorming-skip` deliberately does not run `design-review`: the user chose a lightweight path and is themselves the reviewer.)

If you find yourself doing any of it inside this skill, you have skipped the hand-off. Stop, invoke the chosen mode skill, and let it run.

## Worked Example

User: "we need to let people export their data as JSON as well as CSV"

1. Recognise this as new work rather than a bug, so the router runs rather than `debugging`.
2. Enter plan mode, loading `EnterPlanMode` via `ToolSearch` first because it is not in the base tool list this session.
3. Ask the mode question. The user picks "Other" and types "just the quick one, I know how the CSV exporter is wired".
4. Map that to skip mode, confirm in one line, invoke `brainstorming-skip`, and stop.

## Common Mistakes

| Mistake                                                       | Why it is wrong                                                                                                  |
|---------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| Choosing a mode for the user                                  | The user picks, the router asks. This covers picking skip because the work looked easy.                          |
| Skipping the router because the user said "just add X"        | "Just add X" does not waive the router. Invoke it; the user can pick skip in one keystroke.                      |
| Running the chosen mode's procedure inline                    | The router only routes. Hand off via `Skill`.                                                                    |
| Treating plan mode as optional because the session feels safe | Plan mode is the gate. Degrade only when the tool genuinely fails, never as a shortcut.                          |
| Stopping the workflow when plan mode is unavailable           | Plan mode is the preferred gate, not the only one. Degrade and warn rather than leaving the user with no design. |
| Routing a bug before `debugging` has reproduced it            | There is nothing to design until the root cause is known.                                                        |
