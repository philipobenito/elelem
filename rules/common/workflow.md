# Workflow

## Design Before Implementation

You **MUST NOT** write production code, scaffold a project, invoke an implementation skill, or take any implementation action until a design has been presented and explicitly approved by your human partner. This applies regardless of perceived simplicity. Every change needs a design. Trivial changes get trivial designs, but they are still presented and still approved.

The design lives in the conversation unless it has been captured in a ticket, an epic body, or a committed specification. You **MUST NOT** rely on a design state that exists only in your own context without the user having seen and approved it.

### The Brainstorming Router Is the Design Step

The procedural entry point for the design step is the `brainstorming` skill (the router). You **MUST** invoke it before any code edit, regardless of how obvious the change feels. The router enters plan mode and asks the user to pick one of four modes (standard, guided, committee, or skip). The skip option exists for cases where structured brainstorming would be overkill, it captures a brief design statement and proceeds, so the router being mandatory does not mean every change goes through a long dialogue.

You **MUST NOT** bypass the router by:

- Designing in your own context and considering it "presented" because you typed it in the conversation
- Entering plan mode manually instead of through the router
- Picking `brainstorming-skip` on the user's behalf, the user picks the mode, the router asks
- Deciding the work is "too small" or "obvious" to need the router, that judgement is the user's, not yours, and the skip option exists for exactly this case

### Plan Mode Mechanics

The router enters plan mode before handing off to a mode skill. A mode skill that finds itself without it calls `EnterPlanMode`; both it and `ExitPlanMode` are deferred tools in some sessions, meaning a direct call fails until the schema is loaded, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first.

Where plan mode genuinely cannot be entered, the design step still runs. A design captured without plan mode is weaker than one captured with it, and far better than no design at all, so halting would leave no legal route to any code edit. A mode whose final approval is an explicit question rather than the `ExitPlanMode` call itself needs no substitute for the call: tell the user plan mode is unavailable and run the design step anyway. A mode that needs more than that states its own degraded path, because the consequence differs: a mode that captures approval through `ExitPlanMode` itself needs a substitute for that call, and a mode that dispatches subagents loses the read-only backstop plan mode was providing.

`ExitPlanMode` releases the session and comes before the hand-off. Where the mode has already taken explicit approval through a question, that call is releasing the session rather than seeking approval a second time. Where plan mode was never entered, there is nothing to release and the call is skipped.

### Design Step Scope

A design covers one coherent piece of work. Where a brief spans more than three subsystems, the mode skill stops before designing anything and works with the user to split it, because a design spanning four subsystems produces tickets nobody can sequence.

Count one subsystem per top-level directory the brief requires you to change, plus any layer the codebase treats as its own concern. Where you cannot tell whether a brief clears that bar, ask the user rather than deciding for them.

### The Two Adversarial Passes

A design mode argues against its own proposal while the design is still forming, when the user can supply constraints that exist nowhere in the code. `design-review` argues against the finished artefact afterwards, for completeness and consistency, and its reviewer cannot ask anyone anything. Neither substitutes for the other, so a mode that has argued its own approach still runs the review.

Two approaches are genuinely live only where nothing in the codebase favours one over the other and you would defend either if the user chose it. Where a file or a convention does favour one, that is evidence rather than preference, and the mode presents its recommendation instead of a menu.

### What Counts as an Approved Design

- A design produced by the `brainstorming` router (any of its modes: standard, guided, committee, or skip) that the user has explicitly approved
- A root cause and fix approach produced by `debugging` Phase 6 that the user has explicitly approved (see "Bug Fixes" below)
- An epic or ticket containing a design that the user has written or previously approved
- A specification committed to the repository that the user has pointed to as the source of truth for the current change

### What Does Not Count

- A design you proposed but the user has not responded to
- A design the user said "it looks fine" to without reviewing specifics
- Your own interpretation of the user's request that you have not surfaced and confirmed through the router
- "Obvious" implementations where you skipped the router because the work felt small
- A plan you put in the conversation without entering plan mode through the router

### The Design Step Completion Gate

A design mode that runs `design-review` (`brainstorming-standard`, `brainstorming-guided`, `brainstorming-committee`) **MUST NOT** invoke `create-tickets`, `orchestrated-implementation`, or any other implementation skill until all of these are true:

- The design summary was consolidated into a single self-contained text block: `design-review` receives that text and nothing else, so anything that only makes sense against the design conversation is missing from it
- `design-review` returned Approved against the text you are holding
- The user gave explicit final approval against the reviewed summary
- Plan mode has been released via `ExitPlanMode`, or was never entered because it was reported or found unavailable

If any one of these is false, the gate has not been crossed, and you **MUST NOT** hand off. Plan mode does not lapse on its own and every downstream skill starts by writing something, so a hand-off made while still in plan mode fails somewhere the design cannot explain.

Once the gate is crossed, the mode skill asks the user via `AskUserQuestion` whether to create tickets or start implementation, then invokes the chosen skill via `Skill`. The permitted hand-offs are `create-tickets` and `orchestrated-implementation`, and a mode skill **MUST NOT** invoke anything else. An answer outside that set is new instruction rather than a hand-off, so the choice goes back to the user rather than being invented. The hand-off is stated here so the mode skills can point at it rather than each carrying their own copy of it.

Each mode adds its own conditions on top of these, in that mode's own `SKILL.md`. `brainstorming-skip` does not run `design-review` and has its own gate rather than a delta on this one.

### Bug Fixes

Bug fixes also require an approved design, even if the design is a single sentence. At minimum, present the failing-test reproduction approach and which function or module will change, and get explicit approval before writing the fix.

That approval comes from `debugging` Phase 6, not from the router. New work needs the router because the design has to be created and the user has to choose how; a bug's design is a consequence of evidence that Phase 6 has already gathered and presented, so the only mode that could apply is skip, and asking a four-option question with one viable answer is the usability tax the skip option exists to prevent. The two skills also terminate differently: skip mode's completion gate requires a hand-off to `create-tickets` or an orchestrator, while `debugging` Phase 7 applies the minimal fix inline via `test-driven-development`. Routing a bug through skip cannot satisfy both.

Return to the router only when the root cause turns out to need work large enough that the minimal fix principle in `debugging.md` no longer applies, and the fix needs decomposing rather than applying. The rules in `testing.md` still apply throughout: the failing test comes before the fix.

## Sequencing Work

When a task involves multiple changes, you **MUST** complete them in the order the design specifies. If the design does not specify an order, foundations and dependencies come first, features next, integration after dependencies, polish last. You **MUST NOT** reorder tasks to make progress look faster or to avoid a harder task.

## Stopping Conditions

You **MUST** stop and consult your human partner when:

- The design turns out to be wrong once implementation begins
- A subagent reports it is blocked in a way that changes the scope of the work
- Verification fails in a way that suggests the design, not just the implementation, is at fault
- You find yourself about to bypass any rule in these instructions

"I will just do this small thing first and tell them after" is not an acceptable response to any of the above. Stop, report, wait for instructions.
