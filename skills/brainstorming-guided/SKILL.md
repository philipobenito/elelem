---
name: brainstorming-guided
description: "Turns an idea into an approved design through interactive dialogue with a user who is unfamiliar with the codebase. Walks the user through the relevant architecture, patterns, and conventions while designing, builds their mental model alongside the design, then runs design-review and hands off to create-tickets or subagent-driven-development. Invoked by the brainstorming router once the user has picked guided mode."
---

# Brainstorming (Guided)

Interactive design dialogue with built-in teaching for a user who does not know the codebase well. Same outcome as `brainstorming-standard`, but every phase surfaces what was found in the codebase and why it matters, so the user finishes the session with both a design and a working mental model of the area they will be touching.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. The design review step is delegated to the `design-review` skill.

## Preconditions

- This skill runs after the `brainstorming` router hands off, because the user picked guided mode. Invoke it directly only when the user has named guided mode themselves. Deciding on their behalf that they need the walkthrough is the choice `../../rules/common/workflow.md` reserves for them.
- You **MUST** be in plan mode. The router enters it before handing off. If you arrived here without it, call `EnterPlanMode`; both it and `ExitPlanMode` are deferred tools in some sessions, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first if a direct call fails. If the router has reported that plan mode could not be entered, or it genuinely cannot be entered here, tell the user and continue the design step anyway. A design captured without plan mode is weaker than one captured with it, and far better than no design at all.

## Communication Principles

These principles apply at every step of the procedure. They are what makes this skill different from `brainstorming-standard`:

- **Show your working.** When you read a file, name the file, say what you found, and say why it matters for this design. A claim the user cannot trace back to a file is a claim they have no way to check.
- **Name the patterns.** When the codebase follows a recognisable pattern (repository, MVC, event sourcing, plugin host), name it and point at where it lives.
- **Surface conventions.** Naming, testing approach, error handling, and module layout are conventions the user has no way to infer from the brief. State them.
- **Pitch to the user in front of you.** "New to the codebase" covers both a staff engineer who started on Monday and someone in their first year of the trade. The first needs each pattern named and located; the second needs the pattern itself explained. Read their brief for the signal, state in one line what you have assumed ("I will name patterns and point at files rather than explain the patterns themselves, say if you would like more"), and let them correct you. Explaining what someone already knows spends their attention just as surely as skipping what they do not.

## Procedure

1. **Guided codebase walkthrough.** Read the area of the codebase the brief touches and present it as one coherent walkthrough: how the project is organised (directory structure, key entry points), the patterns in use, the subsystems this work will touch and how they interact, and the conventions in those areas (naming, testing, error handling). Stay scoped to the brief. You are orienting the user, not documenting the repository, so aim for something they can hold in their head, roughly 300 to 400 words, rather than everything you read.

   Close the walkthrough with a single `AskUserQuestion` whose options are the specific areas you just covered, so their answer tells you where to spend more time. For example: "Go deeper on the middleware layer" / "Go deeper on the test conventions" / "All clear, carry on". A bare "does that make sense?" wastes the question, because whichever way they answer you learn nothing you can act on.

   If the brief looks like it spans more than about three subsystems, stop here and say so, then help the user decompose it into separate pieces of work before designing anything. A user new to the codebase has no way to feel that weight themselves, which is precisely why you have to name it for them.

   If there is little or nothing to walk through (a greenfield area, a near-empty repository), say so plainly and walk the nearest adjacent code and the project's conventions instead. Do not manufacture a tour of code that does not exist.

2. **Contextualised clarifying questions.** One question per message, anchored to what you found. "The codebase uses the repository pattern for data access, in `src/repo/`. Should this feature go through it or sit outside it?" gives the user something they can reason about; "How should we handle data access?" asks them to supply the context they came to you for. Prefer multiple choice via `AskUserQuestion`.

3. **Propose one approach, argue against it, then say where the argument lands.** Propose the approach you think is right, anchored to existing code: "this follows the pattern already in `src/services/`, which is the lowest-friction option because everything around it is shaped that way." Then make the strongest case against it you can, and unlike `brainstorming-standard`, do not leave that case hanging: say whether it bites here and point at the file that settles it.

   The difference is who can answer. A user who knows the codebase can rebut an objection from memory, so standard mode hands it to them. This user cannot, and an unanswered objection in front of someone with no basis to judge reads as "the design is bad" rather than as the test it is. Answering it yourself is also where much of the teaching happens: watching a plausible objection get checked against a specific file is how someone builds judgement about an unfamiliar area, and it shows them the move they will need next time you are not there.

   Where the objection turns on something only the user knows, their team's plans, a deadline, an appetite for risk, that one you do put to them, because no file in the repository settles it.

   Where two approaches are genuinely live and the deciding factor is preference rather than evidence, present both and say plainly that either works. Manufacturing a third to fill a menu teaches this user nothing except that some of your options are padding.

4. **Present the design in sections.** Cover architecture, components, data flow, error handling, and testing, referencing the existing code that informed each choice. Scale each section to its complexity: a few sentences where the answer is obvious, up to ~300 words where it is genuinely nuanced. Teaching context earns longer sections, not unbounded ones, and a user who has stopped reading has learned nothing. Get approval on each section before moving to the next.

5. **Consolidate the design summary.** Once every section has been approved, write a single structured summary covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. It has to stand alone: `design-review` receives this text and nothing else, so anything that only makes sense against the walkthrough is missing from the summary.

6. **Invoke `design-review`** via `Skill` against the consolidated summary and follow the Return Contract set out in that skill. Its outcomes ask different things of you: Approved may carry substantive reviewer edits, which this user needs walked through as carefully as the rest of the design, since they approved sections rather than the reviewer's changes to them. Outstanding issues means the review budget is spent, so the decision goes to the user rather than to another dispatch.

   Step 3 and this step are both adversarial, and neither substitutes for the other. Step 3 attacks the *approach* while the design is still forming and the user can supply constraints that exist nowhere in the code. `design-review` attacks the *artefact* afterwards, for completeness and consistency, and its reviewer cannot ask anyone anything.

7. **Get explicit final approval.** Present the reviewed summary and ask directly. "Looks fine" is not approval.

   If their response changes the summary substantively rather than approving it, that is text no reviewer has seen, so return to step 6 against the revised summary. What matters is whether the new invocation is prompted by new content or by an unwelcome verdict on unchanged content, not how many times the skill has run.

   Once they approve, call `ExitPlanMode` carrying the approved summary. Approval came from the question you just asked, so this call releases the session rather than seeking approval again, and it has to happen before the hand-off: every downstream skill starts by writing something, and plan mode does not lapse on its own.

8. **Decide the next step.** Use `AskUserQuestion` to ask whether to create tickets or start implementation. The permitted downstream skills are `create-tickets` and the orchestration skills; when the user picks implementation, select the orchestrator per `../../rules/common/skills-policy.md`'s "Choosing an Orchestration Skill" table (`subagent-driven-development` by default; `team-driven-development` when the design qualifies for parallel execution, or `dispatching-parallel-agents` for a stateless one-shot fan-out). Invoke the chosen skill via `Skill`. **MUST NOT** invoke any other skill from here.

## Working in Existing Codebases

Follow the patterns already there. Where existing code has problems that directly affect this work, fold targeted improvements into the design.

Everything else you noticed stays out. Reading unfamiliar code turns up plenty worth fixing, and this skill is more exposed to that failure than any other brainstorming mode: its opening phase is you reading code in front of someone who is relying on you to explain that code and cannot yet tell your recommendations apart from your asides. "We should tidy this up while we are here" lands as part of the design rather than as the separate opinion it is. Per the YAGNI rule in `../../rules/common/coding-style.md`, list those findings separately for the user and keep them out of the design.

## What Guided Mode Does Not Change

- The hard gate from `../../rules/common/workflow.md` still applies. No implementation before approval.
- One question per message, multiple choice preferred.
- YAGNI applies. Teaching the user about the codebase is not a licence to design extra features.
- The completion gate below is the same one every brainstorming mode crosses.

## Worked Example

User: "I need to add an audit log for admin actions. I've never worked on this codebase before."

1. **Walkthrough.** Read `src/admin/`, the routing layer, `src/middleware/`, and the persistence layer, and confirm no `src/audit/` exists. Present roughly this: the project is organised by feature rather than by layer, with each feature under `src/<feature>/` carrying its own routes, services, and tests; cross-cutting concerns live in `src/middleware/`, where `request_id.go` and `auth.go` are the two working examples to copy from; tests sit next to the code as `*_test.go` and are table-driven with no external framework; errors are returned rather than panicked, and wrapped with `fmt.Errorf` at each layer. Then one `AskUserQuestion`: "Go deeper on the middleware examples" / "Go deeper on the persistence layer" / "All clear, carry on". The user picks the middleware examples, so spend a few more lines on how `auth.go` is wired into the router before moving on.
2. **Contextualised question 1**: "Both existing middlewares write straight to `slog`. Do you want audit records flowing through that same pipeline, or into a separate store you can query?" The user answers "database table".
3. **Contextualised question 2**: "Nothing in the middleware layer touches the database today. Are you happy introducing that there, or would you rather middleware emit events that a separate audit service consumes?" The user answers "emit events".
4. **Propose and argue**: propose following the existing middleware pattern, emitting events on a Go channel that a new `audit` package consumes, because it is the only shape that matches something already in the tree. Against it: an unbuffered channel couples the admin request to the audit writer, so a slow database stalls the very actions being audited. Where that lands: it does not bite here, because `request_id.go` already shows the buffered-channel-plus-worker shape this would copy, and the error handling section will make an audit failure non-blocking. Note the one part no file can settle and put it to the user: whether losing an audit record on a hard crash is acceptable, or whether the write must be durable before the admin action returns.
5. **Sections**: architecture (middleware, event channel, audit service); components (`AuditEvent`, `AuditMiddleware`, `AuditService`); data flow (admin handler, middleware, channel, service, database); error handling (an audit failure must not block the admin action, so log and continue); testing (table-driven tests for the middleware, an integration test for the service against a test database). Each is approved in turn.
6. **Consolidate**, invoke `design-review`, which returns Approved on the first pass with no substantive changes to surface.
7. **Final approval** explicit, then `ExitPlanMode` carrying the approved summary.
8. **Next step**: `create-tickets`.

## Completion Gate

You **MUST NOT** invoke `create-tickets` or any orchestration skill (`subagent-driven-development`, `team-driven-development`, `dispatching-parallel-agents`) until all of these are true:

- The design summary was consolidated into a single text block
- `design-review` returned Approved against the text you are holding
- The user gave explicit final approval against the reviewed summary
- Plan mode has been released via `ExitPlanMode`, or was never entered because the router reported it unavailable

If any one of these is false, the gate has not been crossed, and you **MUST NOT** hand off.

## Common Mistakes

| Mistake                                                           | Why it is wrong                                                                                                                                                                                                              |
|-------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Skipping the walkthrough to "save time"                           | The walkthrough is the difference between this skill and `brainstorming-standard`. If it looks unnecessary, say so and let the user re-pick a mode; do not switch modes on their behalf.                                     |
| Walking through the entire codebase                               | Stay scoped to the brief. An exhaustive tour buries the parts that actually bear on the design.                                                                                                                              |
| Naming patterns without saying where they live                    | "It uses the repository pattern" is jargon until you point at the file that demonstrates it.                                                                                                                                 |
| Explaining everything at one fixed depth                          | State the level you assumed and invite correction. Over-explaining spends the user's attention as surely as under-explaining loses them.                                                                                     |
| Asking abstract questions instead of contextualised ones          | "How should we handle errors?" asks the user to supply context they do not have. "Errors are wrapped with `fmt.Errorf` at every layer here, should we follow that?" gives them something they can answer.                    |
| Presenting a walkthrough with no actionable question at the end   | The point of the closing question is to find out where to spend more time. A yes/no cannot tell you that.                                                                                                                    |
| Designing without flagging a brief that spans several subsystems  | The user cannot judge the size of the work from outside the codebase. Naming it is part of the teaching.                                                                                                                     |
| Re-invoking `design-review` after it returns outstanding issues   | It has already spent three dispatches applying fixes and re-reviewing. A fresh invocation buys another three and hides the fact that a human now needs to decide.                                                            |
| Bundling refactors spotted during the walkthrough into the design | They arrive sounding like design, because you are the one explaining the codebase. List them separately.                                                                                                                     |
| Treating the walkthrough as documentation                         | It lives in the conversation. It is not written to disk and is not a deliverable.                                                                                                                                            |
| Leaving the objection in step 3 hanging                           | Standard mode can hand an objection to the user because they can rebut it. This user cannot, so an unanswered objection reads as "the design is bad". Settle it against a file, or say plainly that only they can settle it. |
| Arguing against your own proposal with generic risks              | A hedge is not an objection. If it would not change the design were it true, it teaches this user nothing and spends the trust the walkthrough just built.                                                                   |
| Handing off to a downstream skill while still in plan mode        | Every downstream skill starts by writing something, and plan mode does not lapse on its own. The hand-off fails somewhere the design cannot explain.                                                                         |
