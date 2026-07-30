---
name: brainstorming-guided
description: "Turns an idea into an approved design through interactive dialogue with a user who is unfamiliar with the codebase. Walks the user through the relevant architecture, patterns, and conventions while designing, builds their mental model alongside the design, then runs design-review and hands off to create-tickets or orchestrated-implementation. Invoked by the brainstorming router once the user has picked guided mode, or directly when the user has named guided mode themselves or asked to be walked through the codebase while designing."
---

# Brainstorming (Guided)

Interactive design dialogue with built-in teaching for a user who does not know the codebase well. Same outcome as `brainstorming-standard`, but every phase surfaces what was found in the codebase and why it matters, so the user finishes the session with both a design and a working mental model of the area they will be touching.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. The design review step is delegated to the `design-review` skill.

## Preconditions

- This skill runs after the `brainstorming` router hands off, because the user picked guided mode. Invoke it directly only when the user has named guided mode themselves, or asked for the walkthrough this mode is built around. Inferring that they need it, because they mentioned being new to the codebase or because the area looks unfamiliar to you, is the choice `../../rules/common/workflow.md` reserves for them.
- You **MUST** be in plan mode. Enter it per the Plan Mode Mechanics in `../../rules/common/workflow.md`. This mode's approval is step 7's explicit question, so the no-substitute case stated there is the one that applies.

## Communication Principles

These principles apply at every step of the procedure:

- **Show your working.** When you read a file, name the file, say what you found, and say why it matters for this design. A claim the user cannot trace back to a file is a claim they have no way to check.
- **Name the patterns.** When the codebase follows a recognisable pattern (repository, MVC, event sourcing, plugin host), name it and point at where it lives.
- **Surface conventions.** Naming, testing approach, error handling, and module layout are conventions the user has no way to infer from the brief. State them.
- **Pitch to the user in front of you.** "New to the codebase" covers both a staff engineer who started on Monday and someone in their first year of the trade. The first needs each pattern named and located; the second needs the pattern itself explained. Read their brief for the signal, state in one line what you have assumed ("I will name patterns and point at files rather than explain the patterns themselves, say if you would like more"), and let them correct you. Explaining what someone already knows spends their attention just as surely as skipping what they do not.

## Procedure

1. **Guided codebase walkthrough.** Read the area of the codebase the brief touches and present it as one coherent walkthrough: how the project is organised (directory structure, key entry points), the patterns in use, the subsystems this work will touch and how they interact, and the conventions in those areas (naming, testing, error handling). Stay scoped to the brief. You are orienting the user, not documenting the repository, so aim for something they can hold in their head, roughly 300 to 400 words, rather than everything you read.

   Close the walkthrough with a single `AskUserQuestion` whose options are the specific areas you just covered, so their answer tells you where to spend more time. For example: "Go deeper on the middleware layer" / "Go deeper on the test conventions" / "All clear, carry on". A bare "does that make sense?" wastes the question, because whichever way they answer you learn nothing you can act on.

   Apply the Design Step Scope rule in `../../rules/common/workflow.md`. A user new to the codebase has no way to feel that weight themselves, which is precisely why you have to name it for them. Once the split has produced separate pieces, ask via `AskUserQuestion` which one to design first and treat it as the brief for a fresh run of this skill, or hand back to `brainstorming` if the user would rather reconsider the mode.

   If there is little or nothing to walk through (a greenfield area, a near-empty repository), say so plainly and walk the nearest adjacent code and the project's conventions instead. Do not manufacture a tour of code that does not exist.

2. **Contextualised clarifying questions.** One question per message, anchored to what you found. "The codebase uses the repository pattern for data access, in `src/repo/`. Should this feature go through it or sit outside it?" gives the user something they can reason about; "How should we handle data access?" asks them to supply the context they came to you for. Prefer multiple choice via `AskUserQuestion`.

3. **Propose one approach, argue against it, then say where the argument lands.** Propose the approach you think is right, anchored to existing code: "this follows the pattern already in `src/services/`, which is the lowest-friction option because everything around it is shaped that way." Then make the strongest case against it you can, and unlike `brainstorming-standard`, do not leave that case hanging: say whether it bites here and point at the file that settles it. Where it does bite, revise the proposal or drop it, and name the file that forced the change.

   The difference is who can answer. A user who knows the codebase can rebut an objection from memory, so standard mode hands it to them. This user cannot, and an unanswered objection in front of someone with no basis to judge reads as "the design is bad" rather than as the test it is. Answering it yourself is also where much of the teaching happens: watching a plausible objection get checked against a specific file is how someone builds judgement about an unfamiliar area, and it shows them the move they will need next time you are not there.

   Where the objection turns on something only the user knows, their team's plans, a deadline, an appetite for risk, that one you do put to them, because no file in the repository settles it.

   Where two approaches are genuinely live, in the sense the Two Adversarial Passes rule in `../../rules/common/workflow.md` defines, and the deciding factor is preference rather than evidence, present both and say plainly that either works. Manufacturing a third to fill a menu teaches this user nothing except that some of your options are padding.

4. **Present the design in sections.** Cover architecture, components, data flow, error handling, and testing, referencing the existing code that informed each choice. Scale each section to its complexity: a few sentences where the answer is obvious, up to ~300 words where it is genuinely nuanced. Teaching context earns longer sections, not unbounded ones, and a user who has stopped reading has learned nothing. Get approval on each section before moving to the next, at the same bar as step 7: an explicit yes to that section, not the absence of an objection.

5. **Consolidate the design summary.** Once every section has been approved, write a single structured summary covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. It has to be self-contained, per the design-step completion gate: nothing in it may lean on the walkthrough.

6. **Invoke `design-review`** via `Skill` against the consolidated summary and handle every arm of the Return Contract set out in that skill. Invoking it is what puts that contract in context, so follow it there rather than working from a copy here. Three arms ask something of this mode beyond what the contract states. Approved may carry substantive reviewer edits, which this user needs walked through as carefully as the rest of the design, since they approved sections rather than the reviewer's changes to them. A Decision required return needs the same treatment as any other question in a walkthrough: explain what turns on it and what each option costs before asking, then carry their answer back through step 6 as new text. Issues outstanding sends the decision to the user, and the contract stops there, so this mode names what the decision is: whether to carry the remaining issues into step 7 as they stand, or to revise the design through steps 4 and 5 and earn a fresh review of the revised text.

7. **Get explicit final approval.** Present the reviewed summary and ask directly. "Looks fine" is not approval.

   If their response changes the summary substantively rather than approving it, that is text no reviewer has seen, so return to step 6 against the revised summary. The Return Contract explains why returning is a first review of new content rather than budget evasion.

   Once they approve, release plan mode per the Plan Mode Mechanics in `../../rules/common/workflow.md`, carrying the approved summary.

8. **Decide the next step.** Hand off per the design-step completion gate in `../../rules/common/workflow.md`, which states the question to ask, the permitted set, and what to do with an answer outside it.

## Working in Existing Codebases

Follow the patterns already there. The boundary test in the YAGNI section of `../../rules/common/coding-style.md` decides what belongs in the design.

Everything else you noticed stays out. Reading unfamiliar code turns up plenty worth fixing, and this skill is more exposed to that failure than any other brainstorming mode: its opening phase is you reading code in front of someone who is relying on you to explain that code and cannot yet tell your recommendations apart from your asides. "We should tidy this up while we are here" lands as part of the design rather than as the separate opinion it is. List those findings separately for the user and keep them out of the design.

## What Guided Mode Does Not Change

- The hard gate cited at the top of this file still applies. Nothing in guided mode relaxes it.
- Step 2's one-question-per-message rule still applies.
- YAGNI applies. Teaching the user about the codebase is not a licence to design extra features.

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

The design-step completion gate in `../../rules/common/workflow.md` applies in full. This mode adds no conditions of its own.

## Common Mistakes

| Mistake                                                         | Why it is wrong                                                                                                                                                                                                   |
|-----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Skipping the walkthrough to "save time"                         | The walkthrough is the difference between this skill and `brainstorming-standard`. If it looks unnecessary, say so and hand back to `brainstorming` so the user can re-pick; do not switch modes on their behalf. |
| Re-invoking `design-review` after it returns Issues outstanding | It has already spent three dispatches applying fixes and re-reviewing. A fresh invocation buys another three and hides the fact that a human now needs to decide.                                                 |
| Treating the walkthrough as documentation                       | It lives in the conversation. It is not written to disk and is not a deliverable.                                                                                                                                 |
| Arguing against your own proposal with generic risks            | A hedge is not an objection. If it would not change the design were it true, it teaches this user nothing and spends the trust the walkthrough just built.                                                        |
