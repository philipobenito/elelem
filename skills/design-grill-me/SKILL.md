---
name: design-grill-me
description: "Turns an idea into an approved design through interactive dialogue: explores the affected code, asks one question at a time, proposes one approach and argues against it, presents the design in sections, has the consolidated summary design-reviewed, and takes explicit approval before any hand-off. The default design step for building features, adding functionality, or refactoring, whatever the user's familiarity with the codebase; scales from quickly capturing a design the user already holds to walking a newcomer through the area while designing. Not for bugs (debug-investigation takes its own fix approval), not for tickets already carrying an approved design, not for trivial changes below the design threshold, and not when the user asks for hands-off deliberation, which is design-committee's job."
---

# Design Grill Me

Interactive design dialogue. The conversation is the design medium; nothing is written to disk while designing. The centre of the skill is the grill: propose the approach you actually believe in, then make the strongest case against it, and let whoever can answer that case, the user or the code, settle it. A design that has survived one real objection is worth more than one that was merely agreed to.

## When Not to Run

- **A change below the design threshold.** The always-on workflow rules define the threshold; below it the design is a short statement presented in conversation and explicitly approved, with no skill invoked. If such a change has reached this skill anyway, say so in one line and take the inline path instead.
- **A bug.** Reproduction and root cause come before design, and the fix approach takes its own approval inside the debug-investigation procedure. Expect a return here only when a confirmed root cause needs work too large for a minimal fix, at which point it arrives as new work carrying the root cause, the reproduction approach, and the affected modules.
- **A design that already exists and is approved**, on a ticket, in an epic body, or in a committed specification. That work goes to implementation, not to a second design.
- **A user who wants to be hands-off.** "You decide, come back when it's done" is deliberation without them, and that is a different skill.

Run once per design. Once the user has approved a design, every edit implementing it is covered by that approval; do not re-enter this skill for each file the implementation touches. Come back when the user brings genuinely new work or the approved design turns out to be wrong.

## Preconditions

- **Plan mode.** Enter it before designing; `EnterPlanMode` and `ExitPlanMode` are deferred tools in some sessions, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first. Where plan mode genuinely cannot be entered, say so and run the dialogue anyway: approval here is an explicit question rather than a tool call, so nothing needs substituting, but the read-only backstop is gone and you edit nothing while designing.
- **A brief from the user.** This skill turns their idea into a design; it does not invent the idea.

## Read the Depth From the Brief

Depth is a dial, not a menu. Read the brief for two signals, how settled the design already is and how well the user knows the area, state your read in one line, and let them correct you. "I will keep this brief and anchor everything in file paths, say if you would like the tour" costs one sentence and prevents a whole conversation pitched wrong.

| The brief shows                                        | Posture                                                                                                    |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| A design the user has already settled                  | Capture: restate it, read the affected code once to anchor it in files, ask at most one follow-up          |
| A goal, and a user who knows the codebase              | Grill at full speed: no narration, objections the user can rebut from memory                               |
| A goal, and a user new to the area                     | Grill plus walkthrough: show your working, name the patterns you find, and say where each one lives        |

At walkthrough depth, every claim traces to a file the user can check, conventions they cannot infer are stated outright, and the explanation is pitched to the person in front of you: a staff engineer who started Monday needs each pattern named and located, someone in their first year needs the pattern itself explained. At capture depth, steps 2 to 4 below compress to almost nothing; the grill still runs, because a settled design the user is sure of is exactly the design most worth one hard look.

## Procedure

1. **Explore the affected code.** Read the files, docs, and recent commits the brief touches. Stay scoped: you are anchoring a design, not mapping the repository. Where the brief spans more than three subsystems, stop before designing anything and split it with the user into pieces that can each carry one coherent design. If there is little to read (a greenfield area, a near-empty repository), say so and read the nearest adjacent code and the project's conventions instead, so the proposal in step 3 still has something to be anchored to.

   Reading unfamiliar code turns up plenty worth fixing. Those findings go in a separate list for the user, never into the design; at walkthrough depth especially, an aside lands as a recommendation.

2. **Ask clarifying questions.** One question per message, multiple choice via `AskUserQuestion` where the answer reduces to a choice. Ask only what you need to form an approach you would defend; anything you could learn better by proposing something and letting the user react belongs to step 3. At walkthrough depth, anchor each question to what you found: "the codebase routes data access through `src/repo/`, should this go through it or sit outside it" gives the user something to reason about.

3. **The grill: propose one approach, then argue against it.** State the approach you think is right and why, in terms of the code you just read. Then make the strongest case against it you can. The objection must be one that would change the design if true: a constraint the code cannot show, a failure mode handled badly, a cost the user may not want to pay. A hedge ("might be hard to maintain") is not an objection, and a user who reads two of them stops reading.

   Who answers depends on who can. Where only the user can settle it, their team's plans, a deadline, an appetite for risk, put it to them, via `AskUserQuestion` where it reduces to a choice. Where the code can settle it, check and say where the argument lands, naming the file that decides it; for a user new to the area this is where most of the teaching happens, because watching a plausible objection get checked against a real file is how judgement about a codebase gets built. Run one round; if the objection bites and the approach changes, the new approach gets one round of its own, not a third. Where two approaches are genuinely live, nothing in the codebase favours either and you would defend both, present the pair and say plainly the deciding factor is preference.

4. **Present the design in sections.** Architecture, components, data flow, error handling, testing. Scale each section to its complexity, a few sentences where nothing is contested, up to ~300 words where it genuinely is, and take approval on each before moving on. A section holding no real decision, one whose deletion would change nothing that gets built, is folded into its neighbour rather than given its own approval gate: five gates on a two-decision change teach the user that approval is a formality. At capture depth the sections collapse into a single block: what to build, acceptance criteria traceable to the statement, and what is out of scope.

5. **Consolidate the summary.** One structured, self-contained block covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. Anything that only makes sense against the conversation is missing from it.

6. **Run a design review of the consolidated summary** and follow the return contract it states. Two arms need care here: an approval may carry substantive reviewer edits the user has not seen, so surface them before treating the design as settled, and an open decision the review uncovers goes to the user, never answered on their behalf, with their answer earning the revised summary a fresh review.

7. **Take explicit final approval.** Present the reviewed summary and ask directly; "looks fine" is not approval. A response that changes the summary's meaning is text no reviewer has seen, so return to step 6 with it. Once they approve, release plan mode via `ExitPlanMode` carrying the approved summary; approval came from the question just asked, so the call releases the session rather than asking again.

8. **Ask what happens next**, via `AskUserQuestion` with two options: "Create tickets first" and "Start implementation". Then do what they chose. An answer outside that pair is new instruction, so it goes back to the user rather than being mapped onto one of them.

## Working in Existing Codebases

Follow the patterns already there. The design covers what was asked for, not what you would also build; requirements you invented and improvements you noticed both fail that test, and the latter go in the separate list from step 1.

## Worked Example

User: "I want to add structured logging across the API service. I know this code well."

1. **Depth**: full-speed grill, stated in a line. **Explore**: `src/api/` uses a `slog`-equivalent in three handlers and ad-hoc `print` calls everywhere else; commit history shows a previous structured-logging attempt that was reverted.
2. **Clarify**: "Migrate every existing call, or only new code from here on?" Every call. "Primary consumer: humans tailing files, an aggregator, or both?" Aggregator. Stop there.
3. **Grill**: propose one-pass migration to `slog`, because the reverted attempt failed precisely by leaving two logging styles coexisting. Against it: a single pass touches every handler, so it collides with anything in flight and has no partial rollback; if a large branch is open against `src/api/`, a per-handler facade is safer even though it reintroduces the mixed state that failed before. Only the user knows what is in flight, so ask. Nothing is, and their answer is what makes the migration section safe to write.
4. **Sections**: architecture (one `slog` handler configured at startup, JSON output), components (logger factory, request middleware injecting a request ID), data flow (context-scoped logger per handler), error handling (log with stack at the boundary, never inside the call chain), testing (in-memory handler for assertions). Approved in turn.
5. **Consolidate** into a single ~400-word summary.
6. **Design review** returns approved with one substantive edit: the testing section now asserts parsed JSON fields rather than raw strings. Surface it, because the user approved a section that no longer reads the same way.
7. **Final approval** explicit, then `ExitPlanMode` carrying the summary.
8. **Next step**: create tickets first, because the user wants the migration tracked across handlers.

At capture depth the same skeleton compresses: a user who says "I want the CSV export to stream instead of buffering the whole result set" gets the affected code read once, one objection (streaming changes error semantics mid-response; is a truncated file acceptable, or does the export need a trailer the client checks?), a single design block, the review, and the approval question, in a handful of messages.

## Completion Gate

Do not create tickets or start implementation until all of these hold:

- The design was consolidated into a single self-contained summary
- The design review approved the summary text you are holding
- The user gave explicit final approval against the reviewed summary
- Plan mode was released via `ExitPlanMode`, or was never entered because it was unavailable
- The user chose the next step themselves

## Common Mistakes

| Mistake                                                        | Why it is wrong                                                                                                                                  |
|----------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| Abandoning the approach as soon as you have argued against it  | You made the case against it, not the user. Hold the recommendation until whoever can answer confirms the objection bites.                       |
| Arguing against your own proposal with generic risks           | A hedge is not an objection. If it would not change the design were it true, it is filler, and it spends the credibility the proposal rested on. |
| Inventing requirements the user did not state                  | The design covers what was asked for. Improvements you noticed while reading go in a separate list.                                              |
| Pitching the depth without stating it                          | The one-line depth statement is what lets the user correct a wrong read before it costs a whole conversation.                                    |
| Re-running the design review after its budget is spent         | An exhausted review means a human needs to decide, and a fresh invocation hides that. Only genuinely revised text earns a fresh review.          |
| Carrying an oversized brief into the sections                  | Split it at step 1. Sections cannot rescue a design whose scope was wrong before it started.                                                     |
| Handing off while still in plan mode                           | Every downstream step starts by writing something. Release the session first, carrying the approved summary.                                     |
