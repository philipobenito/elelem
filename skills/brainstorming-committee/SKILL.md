---
name: brainstorming-committee
description: "Turns an idea into an approved design through autonomous deliberation by three named subagents with different perspectives. They state independent positions, cross-examine each other's reasoning, and converge on consensus without user involvement until the final design is ready for review. Use when the user wants to be hands-off, says 'committee mode', 'you decide', 'don't ask me design questions', or 'come back when it's done'. Invoked by the `brainstorming` router once the user has picked committee mode, or directly when the user has named committee mode themselves. Then runs design-review and hands off to create-tickets or orchestrated-implementation."
---

# Brainstorming (Committee)

Hands-off design dialogue. The user provides the initial brief, then three subagents with deliberately different perspectives state independent positions, cross-examine each other, and converge on consensus. The user only sees the final design.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. The iron-law rules on subagent dispatch (context isolation, git ban, worktree ban, privilege ban, and the ban on writing an identifier you have not confirmed the environment exposes) live in `../../rules/common/subagents.md`. The procedural dispatch rules (model selection, escalation) live in `../_shared/subagent-dispatch.md`. The design review step is delegated to the `design-review` skill.

## Load Required Files First

This skill depends on two shared files that are **not** always in context:

- `../_shared/committee-member-prompt.md` - the prompt templates filled in during the deliberation rounds
- `../_shared/subagent-dispatch.md` - procedural rules for dispatching the committee members

Before running the procedure below, you **MUST** read both files using the Read tool if you have not already read them in this session.

## Preconditions

- You **MUST** be in plan mode before invoking this skill. Enter it per the Plan Mode Mechanics in `../../rules/common/workflow.md`.
- Where plan mode could not be entered, proceed rather than stopping, and treat the read-only instruction in "Keeping Members Read-Only" as load-bearing rather than belt-and-braces, because plan mode is no longer backing it up. That is this mode's degraded path, and the loss bites harder here than in the other modes because this one dispatches subagents.
- This skill is invoked either directly or by the `brainstorming` router after the user selects committee mode.
- Use this skill only when there are at least two meaningful design decisions to make. For trivial requests (a single config change, a one-line fix), `brainstorming-standard` is the right tool.

## Procedure

1. **Confirm the brief.** Restate what you understand the user wants to build, the scope as you see it, and any assumptions, then confirm via `AskUserQuestion`. Once confirmed, the user is hands-off until step 8.
2. **Explore project context.** Read the area of the codebase relevant to the brief. Stay narrow: everything you read here is pasted into the opening prompt of every committee member, so unnecessary context dilutes focus and wastes capacity. If the brief requires reading more than three top-level source directories, or you cannot determine which code is relevant, surface what you have found and ask the user for guidance via `AskUserQuestion`. This is the only other point where you may question the user before the design is ready.
3. **Identify decision groups.** List the key decisions: architecture, approach, data flow, error handling, testing strategy, integration. Group related decisions so each group is a coherent set, not individual micro-choices. Decision groups run one after another, because each group's prompt carries the consensus from the groups before it.
4. **Round A - independent positions.** Dispatch the three members concurrently (one message, three `Agent` calls) using the templates in `../_shared/committee-member-prompt.md`, following "Dispatching the Committee" below. Each receives identical context: the brief, the codebase context, the decisions in this group, and any consensus already recorded. Each returns a recommendation, reasoning, and concerns. Wait for all three to report before continuing.
5. **Round B - cross-examination.** Send each member the other two members' positions and ask what, if anything, they would revise and why, using the cross-examination template. This is the step that makes this a deliberation rather than a poll: a position that survives contact with the other two is worth more than one given in isolation, and a member that concedes has told you the disagreement was shallow. Skip this round only when all three recommendations agree and no member raised a concern it would want addressed before committing.
6. **Synthesise consensus** using the table below, against the Round B positions where Round B ran. Record the consensus before starting the next decision group.
7. **Assemble the design summary.** Combine every consensus into a single coherent summary covering goal, architecture, components, interfaces, data flow, error handling, testing strategy, and integration points. Scale each section to its complexity. Follow existing patterns; do not propose unrelated refactoring.
8. **Present the design to the user.** Include the full summary, a brief note on any decision where the committee stayed split (with the reasoning for the chosen direction), and any risks the committee flagged. **MUST NOT** dump the deliberation transcripts. The user wants the result, not the process.
9. **Invoke `design-review`** via `Skill` against the consolidated summary and follow the Return Contract set out in that skill, with one addition specific to this mode: where a return would otherwise let one reviewer effectively overrule a committee-deliberated decision, run one targeted committee round first.

   Use this decision table. A reviewer edit **affects** a committee-deliberated decision when it changes a constraint, a trade-off, or an interface boundary the committee explicitly decided, rather than adding detail consistent with what it decided. Where you cannot tell which it is, run the round: an unnecessary round costs one dispatch, and a missed one lets a reviewer overrule a decision three members deliberated.

| `design-review` return type                                                             | Action                                                                                                                                                                                                                                                           | Re-invoke `design-review`?                   |
|-----------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------|
| Approved, no substantive reviewer edit affecting a committee-deliberated decision       | Keep summary as-is and continue to step 10.                                                                                                                                                                                                                      | No                                           |
| Approved, **with** substantive reviewer edit affecting a committee-deliberated decision | Run a targeted committee round on that decision, update the summary with the result.                                                                                                                                                                             | Yes, against the updated summary             |
| Decision required                                                                       | Run a targeted committee round to answer the missing decision, update the summary. If the round cannot settle it, escalate to the user as a stopping condition per `../../rules/common/workflow.md`.                                                             | Yes if the round settles it; No if escalated |
| Issues outstanding                                                                      | Escalate to the user (review budget is spent).                                                                                                                                                                                                                   | No                                           |
| Not consolidated                                                                        | Nothing was reviewed and no budget was spent. Consolidate the summary into a single self-contained block per step 7. A second Not consolidated means step 7 cannot fix it, so escalate to the user as a stopping condition per `../../rules/common/workflow.md`. | Yes once; No if escalated                    |
10. **Get explicit final approval.** Present the reviewed summary and ask directly. "Looks fine" is not approval.

    If the user's response revises the summary rather than approving it, take the revision: the user overrules the committee, and a targeted round is for reconciling a reviewer with the committee, not a user with it. Update the summary and return to step 9, because the revision is text no reviewer has seen.

    Once the user approves, call `ExitPlanMode` carrying the approved summary. Approval came from the question you just asked, so this call releases the session rather than seeking approval again, and it has to happen before the hand-off, for the reason `../../rules/common/workflow.md` gives.
11. **Decide the next step.** Hand off per the design-step completion gate in `../../rules/common/workflow.md`, which states the question to ask, the permitted set, and what to do with an answer outside it.

## The Three Perspectives

| Role       | What it prioritises                                                          |
|------------|------------------------------------------------------------------------------|
| Pragmatist | Simplicity, maintenance cost, shipping quickly, reusing what already exists  |
| Architect  | Patterns, separation of concerns, well-defined interfaces, testability       |
| Advocate   | Correctness, edge cases, robustness under failure, hard-to-misuse interfaces |

The full prompt templates live in `../_shared/committee-member-prompt.md`.

## Dispatching the Committee

### Model Selection

Read the `model` enum on the `Agent` tool schema to get values this harness will accept, and resolve the tier per `../_shared/subagent-dispatch.md`. Committee deliberation is a stated exception to that file's start-low-and-escalate sequence: begin at the **High-capability** tier rather than the low-cost default. This is an announced deviation, not pre-escalation. The tier table names design judgement explicitly, and a cheap model that produces three shallow positions costs more than it saves, because the whole design is built on top of them.

### Keeping Members Read-Only

The committee reasons about code; it never changes it. `Plan` cannot write files, but it does carry `Bash`, and the router's degraded path may mean there is no plan mode backing it up.

So every member prompt **MUST** carry the read-only instruction in `../_shared/committee-member-prompt.md`. Do not rely on the agent type alone to enforce it.

### Naming Members and Running Round B

Pass a stable `name` on each `Agent` call (`committee-pragmatist`, `committee-architect`, `committee-advocate`). A named agent is addressable with `SendMessage`, which resumes it from its transcript with its context intact. This is what makes Round B cheap: you send each member the other two positions in a short message rather than re-dispatching a fresh agent and re-pasting the brief and codebase context into it.

Reuse the same three names across every decision group in the run. Later groups then need only the new decisions in the message, since the members already hold the brief, the codebase context, and their own earlier reasoning.

Subagents run in the background by default, so a dispatch returns immediately and results arrive as notifications. Wait for all three before synthesising. You **MUST NOT** predict, infer, or write a member's response yourself; an unreturned position is not a position.

If a member does not return (timeout, tool error, or no response) in Round A or Round B, re-dispatch that same member once with the same prompt. If that retry also fails, surface the failure to the user and halt. Proceeding with fewer than three returned positions breaks the deliberation contract.

If `SendMessage` is unavailable in this environment, or a send to a named member fails, announce the degradation in one line and run Round B by re-dispatching the three members with the other two positions pasted into the prompt. The deliberation still happens; it just costs more context.

## Synthesising Consensus

Synthesise against the Round B positions, weighing the reasoning rather than counting the votes. Three agents drawing on the same base model produce correlated answers, so a 2-1 split is weak evidence on its own: a lone dissenter who cites a specific file or failure mode outranks two members agreeing on general principle.

| Outcome                              | Action                                                                                     |
|--------------------------------------|--------------------------------------------------------------------------------------------|
| Converged after cross-examination    | Take that approach; note what changed between rounds if a member moved.                    |
| Split, one position better evidenced | Take the better-evidenced position and record the dissent.                                 |
| Split, positions equally well argued | Run the tiebreaking round.                                                                 |
| Positions are not comparable         | The decision group was underspecified. Re-scope it and re-run Round A for that group only. |

Concerns flagged by two or more members **MUST** be addressed in the design, even where the recommendations differ.

## Tiebreaking

A tiebreak is for a decision that survived cross-examination still genuinely split, not for preference differences. Dispatch **one** tiebreaking agent, passing it all three positions and what Round B changed, using the tiebreaking template in `../_shared/committee-member-prompt.md`. It is a fresh dispatch, so it holds no position of its own to defend.

**MUST NOT** run more than one tiebreaking round per decision. If the tiebreaker cannot converge, the decision is genuinely unresolved and belongs to the user. Record both positions as an unresolved decision and continue to the next decision group; it surfaces at step 8 as a decision the committee stayed split on.

## Working in Existing Codebases

- Follow existing patterns.
- The boundary test in the YAGNI section of `../../rules/common/coding-style.md` decides what belongs in the design. Committee members are instructed to stay within scope; the synthesiser must reject any recommendation that exceeds it.

## Worked Example

User: "Add webhook delivery for order events. I don't want to be involved, come back when you have a design."

1. **Confirm the brief**: outbound webhooks for order lifecycle events, customer-configurable endpoints, scope excludes the management UI. Confirmed via `AskUserQuestion`.
2. **Explore**: read `src/orders/`, `src/queue/`, `src/config/`. Find an existing Redis-backed job queue with an at-least-once contract, HMAC signing already used for inbound partner callbacks, and table-driven tests throughout. Primary stack is TypeScript.
3. **Decision groups**: (A) delivery mechanism and retry semantics; (B) endpoint configuration, signing, and failure handling. Two groups, run in that order.
4. **Round A, group A**: model resolved to the High-capability value in the `Agent` enum. Dispatch three named members concurrently. Pragmatist says reuse the existing job queue. Architect proposes a separate delivery service so webhook backpressure cannot starve order jobs. Advocate agrees with the Architect but only because of the retry-storm risk.
5. **Round B**: `SendMessage` each member the other two positions. The Pragmatist concedes the starvation point but counters that a separate service is unjustified before a second consumer exists, and proposes a dedicated queue on the existing infrastructure. The Architect accepts this as satisfying the isolation concern. The Advocate accepts it conditional on a dead-letter queue.
6. **Synthesise**: converged on a dedicated webhook queue on existing Redis infrastructure, with a dead-letter queue. The isolation concern was raised by two members, so it is addressed explicitly, not just noted.
7. **Group A recorded**, then groups repeat for group B, whose prompts carry group A's consensus and go to the same three named members.
8. **Assemble** the summary from both consensuses.
9. **Present** to the user, noting that the delivery-mechanism decision moved between rounds and why.
10. **`design-review`** returns Decision required: the summary never says what happens when a customer endpoint 301-redirects, and following redirects, treating them as delivery failures, and rejecting them outright are all consistent with the design. The reviewer named the question and did not answer it, which is what sends it to a targeted round rather than back as a change to an approved design. The round follows redirects with a cap of three. The summary is now new text, so `design-review` runs again against it and returns Approved.
11. **Final approval** explicit, then `ExitPlanMode` carrying the approved summary, then `create-tickets`.

## Completion Gate

The design-step completion gate in `../../rules/common/workflow.md` applies in full, and additionally:

- Every decision group has a recorded consensus
- The summary was assembled from those consensuses rather than written independently of them

## Common Mistakes

| Mistake                                                                | Why it is wrong                                                                                                                                                                                                                           |
|------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Asking the user design questions between steps 1 and 8                 | The committee replaces user questioning during deliberation. Steps 8 to 11 are user-facing by design; the deliberation itself is not.                                                                                                     |
| Synthesising before all three members have reported                    | Subagents run in the background. An unreturned position is not a position, and predicting one is fabrication.                                                                                                                             |
| Skipping Round B because Round A produced a majority                   | A majority is not a deliberation. Two members agreeing tells you nothing about whether the third had the better argument.                                                                                                                 |
| Re-dispatching fresh members each round when `SendMessage` works       | Loses their reasoning and pays for the brief and codebase context again. Re-dispatch is the degraded path, not the default.                                                                                                               |
| Omitting the read-only instruction because the session is in plan mode | Some member types carry `Write` and `Edit`, agent frontmatter can override inherited mode, and the router supports a path with no plan mode at all.                                                                                       |
| Passing session history to committee members                           | Violates context isolation from `../../rules/common/subagents.md`. Pass the brief, the codebase context, the decisions, and prior consensus only.                                                                                         |
| Showing the user the full deliberation transcripts                     | The user wants the design, not the process. Surface only the result, splits, and flagged risks.                                                                                                                                           |
| Skipping `design-review` because the committee already deliberated     | The committee deliberates, it does not review. `design-review` is a separate, holistic check.                                                                                                                                             |
| Re-invoking `design-review` after it returns Issues outstanding        | By then it has spent three dispatches applying fixes and re-reviewing. A fresh invocation buys another three and hides the fact that a human now needs to decide. A targeted round after an Approved is different: that reviews new text. |
| Letting the synthesiser quietly drop a concern flagged by two members  | Two members flagging a concern is signal. Address it in the design or the round did not really converge.                                                                                                                                  |
