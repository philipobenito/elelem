# Workflow

## Design Before Implementation

You **MUST NOT** write production code, scaffold a project, invoke an implementation skill, or take any implementation action until a design has been presented and explicitly approved by your human partner. This applies at every size of change. Trivial changes get trivial designs, but they are still presented and still approved.

The design lives in the conversation unless it has been captured in a ticket, an epic body, or a committed specification. You **MUST NOT** rely on a design state that exists only in your own context without the user having seen and approved it.

### The Design Threshold

The design step has two paths, and the change's own evidence picks between them.

A change takes the **inline path** only when all three of these hold, judged on code you have read rather than on the feel of the request:

1. **Fully determined.** The request plus the code you have read fixes every remaining choice: no decision is left that two competent implementers could resolve differently.
2. **No new surface.** No new public interface of any kind: no new endpoint, export, event, contract, configuration key, or component.
3. **Glanceable.** The whole design fits in a statement the user can read at a glance: what changes, where, and the acceptance criteria.

Where any of the three fails, or you cannot tell whether it does, the change is above the threshold and a design skill runs. Uncertainty is not a tie broken in favour of the lighter path: if classifying the change takes real investigation, that difficulty is itself the verdict, and the verdict is above.

### The Inline Path

Below the threshold, present a short design statement in the conversation, what will change, in which files, and the acceptance criteria, and get explicit approval before any edit. No skill is invoked and plan mode is not entered; the statement and the approval are the whole ceremony. The rule this path preserves is the same one the design skills serve: the user sees and approves a design before code changes, however small the design is.

Traced for a one-line change: read the affected code, post the statement, receive the user's explicit yes, implement. Because the statement names the files it touches, downstream sizing has evidence to work from rather than defaulting to the heaviest classification.

### The Design Skills

Above the threshold, the design step is `design-grill-me`: an interactive dialogue that scales its own depth, from quickly capturing a design the user already holds to walking a newcomer through the area while designing. `design-committee` runs instead only when the user has asked to be hands-off; deliberation without them is theirs to ask for, and you **MUST NOT** choose it on their behalf.

You **MUST NOT** bypass the design step by:

- Designing in your own context and considering it "presented" because you typed it in the conversation
- Taking the inline path on a change that fails, or might fail, any of the three threshold criteria
- Treating the user's silence, or an unreviewed "looks fine", as the explicit approval either path requires

### Plan Mode Mechanics

The design skills enter plan mode before designing; the inline path does not. `EnterPlanMode` and `ExitPlanMode` are deferred tools in some sessions, meaning a direct call fails until the schema is loaded, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first.

Where plan mode genuinely cannot be entered, the design step still runs: a design captured without plan mode is weaker than one captured with it, and far better than no design at all, so halting would leave no legal route to any code edit. Each design skill states its own degraded path, because the consequence differs: a skill whose approval is an explicit question needs no substitute for the missing call, while a skill that dispatches agents loses the read-only backstop plan mode was providing and says so.

`ExitPlanMode` releases the session and comes before any hand-off. Approval was already taken through an explicit question, so the call releases the session rather than seeking approval a second time. Where plan mode was never entered, there is nothing to release and the call is skipped.

### Design Step Scope

A design covers one coherent piece of work. Where a brief spans more than three subsystems, the design skill stops before designing anything and works with the user to split it, because a design spanning four subsystems produces tickets nobody can sequence.

Count one subsystem per top-level directory the brief requires you to change, plus any layer the codebase treats as its own concern. Where you cannot tell whether a brief clears that bar, ask the user rather than deciding for them.

### The Two Adversarial Passes

A design skill argues against its own proposal while the design is still forming, when the user can supply constraints that exist nowhere in the code; in `design-grill-me` that is the grill itself, and in `design-committee` it is the cross-examination round. `design-review` argues against the finished artefact afterwards, for completeness and consistency, and its reviewer cannot ask anyone anything. Neither substitutes for the other, so a design that has been argued against still gets the review.

Two approaches are genuinely live only where nothing in the codebase favours one over the other and you would defend either if the user chose it. Where a file or a convention does favour one, that is evidence rather than preference, and the recommendation is presented instead of a menu.

### What Counts as an Approved Design

- A design produced by `design-grill-me` or `design-committee` that the user has explicitly approved
- An inline-path design statement, for a change below the threshold, that the user has explicitly approved
- A root cause and fix approach produced by the debugging skill's fix-approval phase that the user has explicitly approved (see "Bug Fixes" below)
- An epic or ticket containing a design that the user has written or previously approved
- A specification committed to the repository that the user has pointed to as the source of truth for the current change

### What Does Not Count

- A design you proposed but the user has not responded to
- A design the user said "it looks fine" to without reviewing specifics
- Your own interpretation of the user's request that you have not surfaced and confirmed
- An inline-path statement for a change that fails any threshold criterion
- "Obvious" implementations where you skipped the design step because the work felt small

### The Design Step Completion Gate

A design skill **MUST NOT** create tickets, start implementation, or invoke any implementation skill until all of these are true:

- The design summary was consolidated into a single self-contained text block: `design-review` receives that text and nothing else, so anything that only makes sense against the design conversation is missing from it
- `design-review` returned Approved against the text you are holding
- The user gave explicit final approval against the reviewed summary
- Plan mode has been released via `ExitPlanMode`, or was never entered because it was reported or found unavailable

If any one of these is false, the gate has not been crossed, and you **MUST NOT** hand off. Plan mode does not lapse on its own and every downstream skill starts by writing something, so a hand-off made while still in plan mode fails somewhere the design cannot explain.

Once the gate is crossed, the design skill asks the user whether to create tickets first or start implementation, and does what they chose. An answer outside that pair is new instruction rather than a hand-off, so the choice goes back to the user rather than being invented.

### Bug Fixes

Bug fixes also require an approved design, even if the design is a single sentence. At minimum, present the failing-test reproduction approach and which function or module will change, and get explicit approval before writing the fix.

That approval comes from the debugging skill's own fix-approval phase, not from a design skill: a bug's design is a consequence of evidence the investigation has already gathered and presented, so re-designing it would ask the user to approve the same thing twice. Route the work to `design-grill-me` only when the root cause turns out to need work large enough that the minimal fix principle in `debugging.md` no longer applies, and the fix needs decomposing rather than applying; it arrives there carrying the root cause, the reproduction approach, and the affected modules. The rules in `testing.md` still apply throughout: the failing test comes before the fix.

## Sequencing Work

When a task involves multiple changes, you **MUST** complete them in the order the design specifies. If the design does not specify an order, foundations and dependencies come first, features next, integration after dependencies, polish last. You **MUST NOT** reorder tasks to make progress look faster or to avoid a harder task.

## Stopping Conditions

You **MUST** stop and consult your human partner when:

- The design turns out to be wrong once implementation begins
- A subagent reports it is blocked in a way that changes the scope of the work
- Verification fails in a way that suggests the design, not just the implementation, is at fault
- You find yourself about to bypass any rule in these instructions

"I will just do this small thing first and tell them after" is not an acceptable response to any of the above. Stop, report, wait for instructions.
