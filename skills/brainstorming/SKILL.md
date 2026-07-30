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

## When Not to Run

**For a bug, `debugging` runs instead.** Reproduction and root cause come before design, because until you know what is actually broken there is nothing to design, and routing first produces a design for a bug nobody has reproduced. `debugging` Phase 6 then takes its own approval for the fix approach, and per `../../rules/common/workflow.md` that approval is the design: the bug does not come back here. Expect a return only when the root cause turns out to need work too large for the minimal fix principle, at which point it is new work and the mode question is worth asking again.

**Run once per design, not once per edit.** Once a mode skill has produced an approved design and handed off, every edit that follows is covered by that approval. Do not re-enter the router for each file an implementation touches, and never re-enter it from inside an orchestration loop: that re-enters plan mode and stalls the orchestrator mid-task. If you have been invoked on either of those routes, do not enter plan mode: say in one line that the design step has already happened and hand control straight back to the caller. Come back when the user brings genuinely new work, when the approved design turns out to be wrong (see the stopping conditions in `../../rules/common/workflow.md`), or when a mode skill sends the user back because the mode was the wrong fit (`brainstorming-skip` does this when the user turns out to be uncertain). On that last route, go straight to the mode question if the session is still in plan mode from the first run, otherwise start at step 1, and either way say in one line which mode has been ruled out.

## Procedure

1. **Enter plan mode.** `EnterPlanMode` is a deferred tool in some sessions, meaning a direct call fails until its schema is loaded. If it is not already available, load it with `ToolSearch` (`select:EnterPlanMode`) first, then call it. Plan mode's read-only safety is what enforces the design-before-implementation rule from `../../rules/common/workflow.md` for the rest of the session, whichever mode is chosen, which is why it comes before the mode question rather than after.

   If plan mode genuinely cannot be entered in this environment, do not stop the design step. Tell the user plan mode is unavailable, ask the mode question anyway, and tell the chosen mode skill that its plan-mode precondition is unmet so it does not assume otherwise. The router is the only sanctioned route to an approved design, so halting here leaves no legal path to any code edit at all.

2. **Ask the user which mode.** Use `AskUserQuestion` exactly as specified below, never plain text: freeform answers defeat the routing. The point of the question is that *you* never choose on the user's behalf, so if the user has already named a mode in their own message, they have chosen. Naming a mode in that message means referring to one of the four explicitly, by option label or by skill name; anything else, including phrasing that only signals how involved the user wants to be, is unnamed. Free text typed into the question's own "Other" box is read differently, for the mode it implies. Confirm a named mode in one line and hand off. Absent that, ask. Never proceed on a mode you inferred from the shape of the work.

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

`AskUserQuestion` always offers an "Other" box, and these option descriptions are written in the user's own voice, which invites them to nuance an answer rather than accept a label. When they do, read their text for the mode it implies and confirm the mapping in one line ("That sounds like standard mode, kept brief. Shall I go with that?"). If the text is an instruction for the mode skill rather than a mode choice, it names no mode: ask the mode question again, and carry the instruction into the hand-off as context once a mode has been chosen. If it implies no mode at all, ask again. Ask at most twice. If a second free-text answer still names no mode, say in plain text that the router cannot choose on the user's behalf, restate the four labels, and ask them to name one before anything else happens. Do not silently pick.

## Stay Out of the Mode Skill's Job

The router routes. It does not explore the codebase, ask clarifying questions about the brief, present a design, invoke `design-review`, or invoke `create-tickets` or any orchestration skill. All of those belong to the mode skill and run after the hand-off.

If you find yourself doing any of it inside this skill, you have skipped the hand-off. Stop, ask the mode question if you have not yet, then invoke the chosen mode skill and let it run.

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
| Running the chosen mode's procedure inline                    | The router only routes. Hand off via `Skill`.                                                                    |
| Treating plan mode as optional because the session feels safe | Plan mode is the gate. Degrade only when the tool genuinely fails, never as a shortcut.                          |
| Stopping the workflow when plan mode is unavailable           | Plan mode is the preferred gate, not the only one. Degrade and warn rather than leaving the user with no design. |
