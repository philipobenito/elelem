---
name: brainstorming-committee
description: "Turns an idea into an approved design through autonomous deliberation by three named subagents with different perspectives. They state independent positions, cross-examine each other's reasoning, and converge on consensus without user involvement until the final design is ready for review. Use when the user wants to be hands-off, says 'committee mode', 'you decide', 'don't ask me questions', or 'come back when it's done'. Then runs design-review and hands off to create-tickets or subagent-driven-development."
---

# Brainstorming (Committee)

Hands-off design dialogue. The user provides the initial brief, then three subagents with deliberately different perspectives state independent positions, cross-examine each other, and converge on consensus. The user only sees the final design.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. The iron-law rules on subagent dispatch (context isolation, git ban, worktree ban, privilege ban, and the ban on writing an identifier you have not confirmed the environment exposes) live in `../../rules/common/subagents.md`. The procedural dispatch rules (type selection, model selection, escalation) live in `../_shared/subagent-dispatch.md`. The design review step is delegated to the `design-review` skill.

## Load Required Files First

This skill depends on two sibling/shared files that are **not** always in context:

- `committee-member-prompt.md` (sibling) - the prompt templates filled in during the deliberation rounds
- `../_shared/subagent-dispatch.md` - procedural rules for dispatching the committee members

Before running the procedure below, you **MUST** read both files using the Read tool if you have not already read them in this session.

## Preconditions

- You **MUST** be in plan mode before invoking this skill. Use `EnterPlanMode` if you are not; it is a deferred tool in some sessions, so load it with `ToolSearch` (`select:EnterPlanMode`) first if a direct call fails.
- If the `brainstorming` router has told you plan mode could not be entered, do not stop: the router's degraded path is sanctioned. Proceed, and treat the read-only instruction in "Keeping Members Read-Only" as load-bearing rather than belt-and-braces, because plan mode is no longer backing it up.
- This skill is invoked either directly or by the `brainstorming` router after the user selects committee mode.
- Use this skill only when there are at least two meaningful design decisions to make. For trivial requests (a single config change, a one-line fix), `brainstorming-standard` is the right tool.

## Procedure

1. **Confirm the brief.** Restate what you understand the user wants to build, the scope as you see it, and any assumptions, then confirm via `AskUserQuestion`. Once confirmed, the user is hands-off until step 8.
2. **Explore project context.** Read the area of the codebase relevant to the brief. Stay narrow: everything you read here is pasted into the opening prompt of every committee member, so unnecessary context dilutes focus and wastes capacity. Identify the project's primary language and framework now, because the Pragmatist's type depends on it. If the feature touches more than ~3 subsystems, or you cannot determine which code is relevant, surface what you have found and ask the user for guidance via `AskUserQuestion`. This is the only other point where you may question the user before the design is ready.
3. **Identify decision groups.** List the key decisions: architecture, approach, data flow, error handling, testing strategy, integration. Group related decisions so each group is a coherent set, not individual micro-choices. Decision groups run one after another, because each group's prompt carries the consensus from the groups before it.
4. **Round A - independent positions.** Dispatch the three members concurrently (one message, three `Agent` calls) using the templates in `committee-member-prompt.md`, following "Dispatching the Committee" below. Each receives identical context: the brief, the codebase context, the decisions in this group, and any consensus already recorded. Each returns a recommendation, reasoning, and concerns. Wait for all three to report before continuing.
5. **Round B - cross-examination.** Send each member the other two members' positions and ask what, if anything, they would revise and why, using the cross-examination template. This is the step that makes this a deliberation rather than a poll: a position that survives contact with the other two is worth more than one given in isolation, and a member that concedes has told you the disagreement was shallow. Skip this round only when Round A came back unanimous with no substantive concerns from any member.
6. **Synthesise consensus** using the table below, against the Round B positions where Round B ran. Record the consensus before starting the next decision group.
7. **Assemble the design summary.** Combine every consensus into a single coherent summary covering goal, architecture, components, interfaces, data flow, error handling, testing strategy, and integration points. Scale each section to its complexity. Follow existing patterns; do not propose unrelated refactoring.
8. **Present the design to the user.** Include the full summary, a brief note on any decision where the committee stayed split (with the reasoning for the chosen direction), and any risks the committee flagged. **MUST NOT** dump the deliberation transcripts. The user wants the result, not the process.
9. **Invoke `design-review`** via `Skill` against the consolidated summary. If the review surfaces issues that require new decisions (not just wording fixes), feed the affected decisions back into a targeted round, update the summary, and re-invoke `design-review`. If `design-review` escalates after three iterations, stop and ask the user how to proceed.
10. **Get explicit final approval.** Present the reviewed summary and ask directly. "Looks fine" is not approval.
11. **Decide the next step.** Use `AskUserQuestion` to ask whether to create tickets or start implementation. The permitted downstream skills are `create-tickets` and the orchestration skills; when the user picks implementation, select the orchestrator per `../../rules/common/skills-policy.md`'s "Choosing an Orchestration Skill" table: default to `subagent-driven-development`; use `team-driven-development` when the design qualifies for parallel execution (at least three independent components that can be built simultaneously with no shared state); use `dispatching-parallel-agents` for a stateless one-shot fan-out (all tasks are fully specified, idempotent, and require no inter-agent coordination). Invoke the chosen skill via `Skill`.

## The Three Perspectives

| Role       | What it prioritises                                                          |
|------------|------------------------------------------------------------------------------|
| Pragmatist | Simplicity, maintenance cost, shipping quickly, reusing what already exists  |
| Architect  | Patterns, separation of concerns, well-defined interfaces, testability       |
| Advocate   | Correctness, edge cases, robustness under failure, hard-to-misuse interfaces |

The full prompt templates live in `committee-member-prompt.md`.

## Dispatching the Committee

### Selecting Member Types

`../_shared/subagent-dispatch.md` requires the most specific available type, and `../../rules/common/subagents.md` forbids writing an identifier you have not confirmed the current environment exposes. Both apply here, and agent type names are the case where this bites hardest: many are supplied by plugins and are namespaced (`voltagent-qa-sec:architect-reviewer`, `voltagent-lang:typescript-pro`), so a bare name copied from any table may not resolve at all, and on a machine without that plugin no variant of it exists.

Resolve the three types at dispatch time, every time:

1. Enumerate the `subagent_type` values this environment actually exposes.
2. For each role, search that enumeration for the capability in the "What to search for" column below.
3. Take the most specific match, whatever its namespace.
4. Where nothing matches, take the built-in fallback, which is present in every environment.

| Role       | What to search for                                    | Built-in fallback |
|------------|-------------------------------------------------------|-------------------|
| Pragmatist | A developer type for the stack identified in step 2   | `general-purpose` |
| Architect  | An architecture, system design, or design review type | `Plan`            |
| Advocate   | A QA, testing, or quality review type                 | `general-purpose` |

`Plan` is the Architect's fallback rather than `general-purpose` because it is built for weighing architectural trade-offs and is read-only by construction.

The tables below are **worked examples of what a match looks like, not identifiers to paste**. They record what one environment happened to expose; yours may namespace them differently, name them differently, or not have them at all. Use them to recognise a match during step 2, then dispatch the identifier you actually enumerated.

| Role      | Example match        | As enumerated in one environment      |
|-----------|----------------------|---------------------------------------|
| Architect | `architect-reviewer` | `voltagent-qa-sec:architect-reviewer` |
| Advocate  | `qa-expert`          | `voltagent-qa-sec:qa-expert`          |

| Stack for the Pragmatist | Example match        | As enumerated in one environment    |
|--------------------------|----------------------|-------------------------------------|
| TypeScript               | `typescript-pro`     | `voltagent-lang:typescript-pro`     |
| Python                   | `python-pro`         | `voltagent-lang:python-pro`         |
| Go                       | `golang-pro`         | `voltagent-lang:golang-pro`         |
| Rust                     | `rust-engineer`      | `voltagent-lang:rust-engineer`      |
| React frontend           | `react-specialist`   | `voltagent-lang:react-specialist`   |
| PHP / Laravel            | `laravel-specialist` | `voltagent-lang:laravel-specialist` |
| Java / Spring            | `java-architect`     | `voltagent-lang:java-architect`     |
| C# / .NET                | `csharp-developer`   | `voltagent-lang:csharp-developer`   |
| Ruby / Rails             | `rails-expert`       | `voltagent-lang:rails-expert`       |
| Multi-language / other   | none                 | fall back to `general-purpose`      |

The third column is the point of these tables: the bare name in the second column did not resolve in that environment. If a more specific type than the example exists for your stack, prefer it.

When the Pragmatist falls back to `general-purpose`, tell it in the prompt to focus on the specific languages present in the codebase and to prioritise reuse of the existing patterns you identified in step 2, compensating for the missing stack expertise.

### Model Selection

Resolve the model per `../_shared/subagent-dispatch.md`, reading the `model` enum on the `Agent` tool schema to get values this harness will accept. Committee deliberation is design judgement over a codebase, which is the stated signal for the **High-capability** tier, so start there rather than at the low-cost default. This is not pre-escalation: the tier table names design judgement explicitly, and a cheap model that produces three shallow positions costs more than it saves, because the whole design is built on top of them.

### Keeping Members Read-Only

The committee reasons about code; it never changes it. Some of the types you will resolve to ship with `Write`, `Edit`, and `Bash`, and while subagents inherit the session's permission mode, an agent definition's own frontmatter can override it, and the router's degraded path may mean there is no plan mode to inherit.

So every member prompt **MUST** carry the read-only instruction in `committee-member-prompt.md`. Do not rely on plan mode alone to enforce it.

### Naming Members and Running Round B

Pass a stable `name` on each `Agent` call (`committee-pragmatist`, `committee-architect`, `committee-advocate`). A named agent is addressable with `SendMessage`, which resumes it from its transcript with its context intact. This is what makes Round B cheap: you send each member the other two positions in a short message rather than re-dispatching a fresh agent and re-pasting the brief and codebase context into it.

Reuse the same three names across every decision group in the run. Later groups then need only the new decisions in the message, since the members already hold the brief, the codebase context, and their own earlier reasoning.

Subagents run in the background by default, so a dispatch returns immediately and results arrive as notifications. Wait for all three before synthesising. You **MUST NOT** predict, infer, or write a member's response yourself; an unreturned position is not a position.

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

A tiebreak is for a decision that survived cross-examination still genuinely split, not for preference differences. Dispatch **one** tiebreaking agent, passing it all three positions and what Round B changed, using the tiebreaking template in `committee-member-prompt.md`. Prefer a type that did not sit on the committee, so the adjudicator is not weighing its own earlier position; where the environment offers nothing suitable, `general-purpose` with the full template is a better adjudicator than a re-used member type.

**MUST NOT** run more than one tiebreaking round per decision. If the tiebreaker cannot converge, the decision is genuinely unresolved and belongs to the user.

## Working in Existing Codebases

- Follow existing patterns. Where existing code has problems that affect the work, include targeted improvements in the design.
- **MUST NOT** propose unrelated refactoring. Committee members are instructed to stay within scope; the synthesiser must reject any recommendation that exceeds it.

## Worked Example

User: "Add webhook delivery for order events. I don't want to be involved, come back when you have a design."

1. **Confirm the brief**: outbound webhooks for order lifecycle events, customer-configurable endpoints, scope excludes the management UI. Confirmed via `AskUserQuestion`.
2. **Explore**: read `src/orders/`, `src/queue/`, `src/config/`. Find an existing Redis-backed job queue with an at-least-once contract, HMAC signing already used for inbound partner callbacks, and table-driven tests throughout. Primary stack is TypeScript.
3. **Decision groups**: (A) delivery mechanism and retry semantics; (B) endpoint configuration, signing, and failure handling. Two groups, run in that order.
4. **Round A, group A**: resolve types by enumeration - Pragmatist to the TypeScript developer type available here, Architect to the architecture review type, Advocate to the QA type; model resolved to the High-capability value in the `Agent` enum. Dispatch three named members concurrently. Pragmatist says reuse the existing job queue. Architect proposes a separate delivery service so webhook backpressure cannot starve order jobs. Advocate agrees with the Architect but only because of the retry-storm risk.
5. **Round B**: `SendMessage` each member the other two positions. The Pragmatist concedes the starvation point but counters that a separate service is unjustified before a second consumer exists, and proposes a dedicated queue on the existing infrastructure. The Architect accepts this as satisfying the isolation concern. The Advocate accepts it conditional on a dead-letter queue.
6. **Synthesise**: converged on a dedicated webhook queue on existing Redis infrastructure, with a dead-letter queue. The isolation concern was raised by two members, so it is addressed explicitly, not just noted.
7. **Group A recorded**, then groups repeat for group B, whose prompts carry group A's consensus and go to the same three named members.
8. **Assemble** the summary from both consensuses.
9. **Present** to the user, noting that the delivery-mechanism decision moved between rounds and why.
10. **`design-review`** returns one issue (the summary never says what happens when a customer endpoint 301-redirects). Wording plus a small behavioural decision, so it goes back to a targeted round, then re-review returns Approved.
11. **Final approval** explicit, then `create-tickets`.

## Completion Gate

You **MUST NOT** invoke `create-tickets` or any orchestration skill (`subagent-driven-development`, `team-driven-development`, `dispatching-parallel-agents`) until all of these are true:

- Every decision group has a recorded consensus
- The design summary was assembled from those consensuses into a single text block
- `design-review` returned Approved
- The user gave explicit final approval against the reviewed summary

## Common Mistakes

| Mistake                                                                | Why it is wrong                                                                                                                                     |
|------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| Asking the user design questions between steps 1 and 8                 | The committee replaces user questioning during deliberation. Steps 8 to 11 are user-facing by design; the deliberation itself is not.               |
| Dispatching committee members sequentially                             | They **MUST** run concurrently. One message, three tool calls.                                                                                      |
| Synthesising before all three members have reported                    | Subagents run in the background. An unreturned position is not a position, and predicting one is fabrication.                                       |
| Skipping Round B because Round A produced a majority                   | A majority is not a deliberation. Skip Round B only on unanimity with no substantive concerns.                                                      |
| Re-dispatching fresh members each round when `SendMessage` works       | Loses their reasoning and pays for the brief and codebase context again. Re-dispatch is the degraded path, not the default.                         |
| Pasting a subagent type name from a table without enumerating          | Type names are environment-specific and often plugin-namespaced. Violates the identifier rule in `../../rules/common/subagents.md`.                 |
| Dispatching members at the low-cost default tier                       | Design judgement is the stated High-capability signal. The whole design rests on these three positions.                                             |
| Omitting the read-only instruction because the session is in plan mode | Some member types carry `Write` and `Edit`, agent frontmatter can override inherited mode, and the router supports a path with no plan mode at all. |
| Counting votes instead of weighing evidence                            | Three agents on one base model produce correlated answers. A cited file beats a 2-1 split on general principle.                                     |
| Passing session history to committee members                           | Violates context isolation from `../../rules/common/subagents.md`. Pass the brief, the codebase context, the decisions, and prior consensus only.   |
| Showing the user the full deliberation transcripts                     | The user wants the design, not the process. Surface only the result, splits, and flagged risks.                                                     |
| Skipping `design-review` because the committee already deliberated     | The committee deliberates, it does not review. `design-review` is a separate, holistic check.                                                       |
| Running more than one tiebreaking round                                | If one tiebreaker cannot converge, the decision is genuinely unresolved and belongs to the user.                                                    |
| Letting the synthesiser quietly drop a concern flagged by two members  | Two members flagging a concern is signal. Address it in the design or the round did not really converge.                                            |
