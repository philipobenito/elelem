---
name: brainstorming-standard
description: "Turns an idea into an approved design through interactive dialogue with a user who already knows the codebase. Explores context, asks one question at a time, proposes an approach and argues against it, presents the design in sections, runs design-review, and hands off to create-tickets or an orchestration skill. Invoked by the `brainstorming` router once the user has picked standard mode, or directly when the user has named standard mode themselves. If the user has not picked a mode, invoke `brainstorming` instead so they can."
---

# Brainstorming (Standard)

Interactive design dialogue for a user who already knows the codebase. The conversation is the design medium; nothing is written to disk during brainstorming.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. For the rule that this skill must be invoked before creative work, see `../../rules/common/skills-policy.md`. The design review step is delegated to the `design-review` skill.

## Preconditions

- **Plan mode.** The router enters it before handing off. If you arrived without it, call `EnterPlanMode`; both it and `ExitPlanMode` are deferred tools in some sessions, meaning a direct call fails until the schema is loaded, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first. If the router has reported that plan mode could not be entered, or it genuinely cannot be entered here, tell the user and run the design step anyway. A design captured without plan mode is weaker than one captured with it, and far better than no design at all.
- **The router picks the mode, not you.** This skill runs as a hand-off after the user chose standard mode. Invoke it directly only when the user has named standard mode themselves. Deciding on their behalf which mode fits is the choice `../../rules/common/workflow.md` reserves for them, so if they have not picked, invoke `brainstorming` instead.

## Procedure

1. **Explore project context.** Read files, docs, and recent commits in the area the request touches. Stay focused: do not exhaustively map the codebase.

   If after the initial pass the request appears to span more than ~3 subsystems, stop and say so before designing anything. Either re-scope the brief with the user down to one coherent piece of work and carry on from step 2, or, when the work genuinely will not reduce, tell them it needs splitting into separate designs and stop there. Do not carry an oversized brief forward on the assumption that the sections will sort it out; a design that spans four subsystems produces tickets nobody can sequence.

   If there is little or nothing to read (a greenfield area, a near-empty repository), say so plainly and read the nearest adjacent code and the project's conventions instead, so the proposal in step 3 still has something to be anchored to.

2. **Ask clarifying questions.** One question per message, and prefer multiple choice via `AskUserQuestion`. Stacking questions makes the user triage a list instead of answering, and their answers arrive shallower for it; one at a time also lets each answer inform the next question, which a stacked list forecloses. Focus on purpose, constraints, and success criteria.

   Ask only what you need to form an approach you would defend. Step 3 is where the deeper context gathering happens, so questions you could answer better by proposing something and letting the user react belong there rather than here.

3. **Propose one approach, then argue against it.** State the approach you actually think is right and why, in terms of the code you just read. Then make the strongest case against it you can, and say what you would do instead if that case holds.

   The objection has to be one that would change the design if it were true: a constraint you cannot see from the code, a failure mode the approach handles badly, a cost the user may not want to pay. "This might be hard to maintain" is a hedge rather than an objection, and a user who reads two of those stops reading the section.

   The point is context, not theatre. A menu of alternatives asks the user to choose between options you may have invented; an objection asks them something only they can answer. When they rebut it they hand you the reason it does not apply here, and when they concede it they hand you a requirement. Either way you leave with the constraint the later sections need.

   Carry the objection as the question, via `AskUserQuestion` where it reduces to a choice. Run one round. If the objection lands and the approach changes, the new approach gets one round of its own, not a third. Where two approaches are genuinely live and the deciding factor is the user's preference rather than anything in the code, say so and let them pick: recommendation-plus-objection is the default shape, not a ban on ever presenting a choice.

4. **Present the design in sections.** Cover architecture, components, data flow, error handling, and testing. Scale each section to its complexity: a few sentences for straightforward sections, up to ~300 words for nuanced ones. Get user approval on each section before moving to the next.

   Where a section holds no real decision, say so in a line and fold it into its neighbour rather than seeking separate approval for a section that says nothing. Five approval gates on a change with two decisions in it teaches the user that approval is a formality, which is the opposite of what the gate is for.

5. **Consolidate the design summary.** Once every section has been approved, write a single structured summary covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. It has to stand alone: `design-review` receives this text and nothing else, so anything that only makes sense against the conversation is missing from the summary.

6. **Invoke `design-review`** via `Skill` against the consolidated summary and follow the Return Contract set out in that skill. Approved may carry substantive reviewer edits the user has not seen. A decision required return means the review found a question the design never answered, so put it to the user here rather than answering it yourself and carry their answer back through step 6 as new text. Outstanding issues means the review budget is spent, so the decision goes to the user rather than to another dispatch.

   Step 3 and this step are both adversarial, and neither substitutes for the other. Step 3 attacks the *approach* while the user is in the room and can supply constraints that exist nowhere in the code. `design-review` attacks the *artefact* afterwards, for completeness and consistency, and its reviewer cannot ask anyone anything.

7. **Get explicit final approval.** Present the reviewed summary to the user and obtain explicit approval. Implicit signals ("looks fine", "sure") do not count; ask directly.

   If their response changes the summary substantively rather than approving it, that is text no reviewer has seen, so return to step 6 against the revised summary. The Return Contract's distinction is what prompted the new invocation, new content or an unwelcome verdict on unchanged content, not how many times the skill has run.

   Once they approve, call `ExitPlanMode` carrying the approved summary. Approval came from the question you just asked, so this call is releasing the session rather than seeking approval again, and it has to happen before the hand-off: every downstream skill starts by writing something, and plan mode does not lapse on its own.

8. **Decide the next step.** Use `AskUserQuestion` to ask whether to create tickets or start implementation. The permitted downstream skills are `create-tickets` and the orchestration skills; when the user picks implementation, select the orchestrator per `../../rules/common/skills-policy.md`'s "Choosing an Orchestration Skill" table (`subagent-driven-development` by default; `team-driven-development` when the design qualifies for parallel execution, or `dispatching-parallel-agents` for a stateless one-shot fan-out). Invoke the chosen skill via `Skill`. **MUST NOT** invoke any other skill from here.

## Working in Existing Codebases

- Follow existing patterns. Where existing code has problems that affect the work, include targeted improvements in the design.
- **MUST NOT** propose unrelated refactoring. Per the YAGNI rule in `../../rules/common/coding-style.md`, "while we are here" cleanups are forbidden during a brainstorming pass. Log them separately for the user instead.

## Worked Example

User: "I want to add structured logging across the API service."

1. **Explore.** Read `src/api/`, locate the existing logger setup, check whether any structured logging library is already pulled in. Find: the project uses a `log/slog`-equivalent in three handlers and ad-hoc `print` calls everywhere else. Recent commit history shows a previous attempt at structured logging that was reverted.

2. **Clarifying questions.** First: "Do you want every existing log call migrated, or only new code from this point forward?" The user picks "every existing call". Second: "What is the highest-priority consumer of these logs: humans tailing files, a log aggregator, or both equally?" The user picks "aggregator (Loki)". Stop there; the rest is better learned by proposing something.

3. **Propose, then argue against it.** Propose standardising on `slog` and migrating every call in one pass, because the reverted attempt in the history failed by leaving two logging styles in the tree at once. Against it: a single pass touches every handler, so it collides with anything else in flight and there is no partial rollback. If a large branch is open against `src/api/`, the per-handler facade is the safer shape even though it reintroduces the mixed state that failed last time. Ask: is anything substantial in flight against `src/api/` right now? The user says no, so the one-pass migration holds, and their answer is what makes the migration section safe to write.

4. **Sections.** Architecture (a single `slog` handler configured at startup, JSON output), components (logger factory, request middleware that injects a request ID), data flow (every handler receives a context-scoped logger), error handling (errors logged with stack at the boundary, never inside the call chain), testing (an in-memory handler for assertions). Each is approved in turn.

5. **Consolidate** into a single ~400-word summary covering all of the above.

6. **Design review.** `design-review` returns Approved after two iterations, flagging one substantive change it made along the way: the testing section had not said what the tests assert about the JSON output, and it now specifies parsed JSON fields rather than raw string contents. Surface that change, because the user approved a testing section that no longer reads the same way.

7. **Final approval.** Present the reviewed summary, the user says "approved", then call `ExitPlanMode` with it.

8. **Next step.** `create-tickets`, because the user wants the migration tracked across handlers.

## Completion Gate

You **MUST NOT** invoke `create-tickets` or any orchestration skill (`subagent-driven-development`, `team-driven-development`, `dispatching-parallel-agents`) until all of these are true:

- The design summary was consolidated into a single text block
- `design-review` returned Approved against the text you are holding
- The user gave explicit final approval against the reviewed summary
- Plan mode has been released via `ExitPlanMode`, or was never entered because the router reported it unavailable

If any one of these is false, the gate has not been crossed, and you **MUST NOT** hand off.

## Common Mistakes

| Mistake                                                                         | Why it is wrong                                                                                                                                                                                                                                     |
|---------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Stacking multiple questions in one message                                      | Drowns the user, and forecloses letting each answer shape the next question. One at a time, prefer multiple choice.                                                                                                                                 |
| Arguing against your own proposal with generic risks                            | A hedge is not an objection. If it would not change the design were it true, it is not worth the turn, and it teaches the user the section is decoration.                                                                                           |
| Abandoning the approach as soon as you have argued against it                   | You made the case against it, not the user. Hold the recommendation until they confirm the objection bites; flip-flopping spends the credibility the recommendation rested on.                                                                      |
| Manufacturing alternatives to fill a menu                                       | A strawman the user can see through is worse than one honest proposal. Present a choice only where two approaches are genuinely live.                                                                                                               |
| Skipping the consolidation step and dispatching review against the conversation | `design-review` requires a single summary block. Conversation history is not a design.                                                                                                                                                              |
| Treating "looks fine" as final approval                                         | Explicit approval is required. Ask directly.                                                                                                                                                                                                        |
| Inventing requirements the user did not state                                   | YAGNI. The design covers what was asked for, not what you would also build.                                                                                                                                                                         |
| Handing off to a downstream skill while still in plan mode                      | Every downstream skill starts by writing something, and plan mode does not lapse on its own. The hand-off fails somewhere the design cannot explain.                                                                                                |
| Invoking an implementation skill before the gate is crossed                     | Violates the `../../rules/common/workflow.md` design-before-implementation rule.                                                                                                                                                                    |
| Re-invoking `design-review` after it returns outstanding issues                 | By then it has spent three dispatches applying fixes and re-reviewing. A fresh invocation buys another three and hides the fact that a human now needs to decide. Re-reviewing a summary the user has since revised is different: that is new text. |
| Applying reviewer fixes and re-dispatching yourself                             | `design-review` runs that loop internally. Doing it from here duplicates the cycle and doubles the effective budget.                                                                                                                                |
| Switching to a walkthrough because the user turns out not to know the area      | Say so and let them re-pick a mode. `brainstorming-guided` exists for this; changing mode on their behalf is the router's job, not yours.                                                                                                           |
| Proposing unrelated refactors discovered during exploration                     | Log them as separate items for the user. Do not bundle them into the design.                                                                                                                                                                        |
| Carrying a brief that spans several subsystems into the sections                | Re-scope it or split it at step 1. Sections cannot rescue a design whose scope was wrong before it started.                                                                                                                                         |
