---
name: brainstorming-committee
description: "Develops a proposed design through explicitly selected committee deliberation by three perspectives."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Brainstorming (Committee)

Hands-off Planning method, selected explicitly by the user. Three perspectives deliberate on consequential design decisions and return a proposed design. The coordinator owns independent review, explicit final approval and later workflow phases.

The coordinator verifies active-model capability and owns lifecycle. Committee preparation and review require high-capability reasoning. Before dispatch, read `../_shared/subagent-dispatch.md` and follow its model-resolution and routing requirements. Metadata does not switch a model. Never silently use a lower-cost tier for preparation or review.

## Load Required Files First

This skill depends on two sibling/shared files that are **not** always in context:

- `committee-member-prompt.md` (sibling) - prompt templates paste-filled in step 4
- `../_shared/subagent-dispatch.md` - procedural rules for dispatching the committee members
- `../_shared/project-context-discovery.md` - only when the coordinator identifies a consequential research gap

Before dispatching, read `committee-member-prompt.md` and `../_shared/subagent-dispatch.md` using `{{READ_FILE_TOOL}}` if not already available. Do not repeat Research. Use the coordinator's recorded findings and approved external inputs. Read the context-discovery helper only for a bounded gap not covered by Research.

## Preconditions

- This skill runs only in the coordinator's active Planning phase. If invoked directly without an active workflow, invoke `workflow-coordinator`, preserve committee as the requested method and stop. Do not start another workflow or invoke the router recursively.
- If a coordinator is active but Planning is not the current phase, return control to it without continuing this skill.
- The user must explicitly select committee mode. Do not select it automatically based on task size or decision count. Respect actual harness plan-mode restrictions; keep drafts in conversation or coordinator-authorised staging and do not silently switch models.

## Procedure

1. **Orient to the confirmed brief.** Use the user-confirmed goal, coordinator-supplied research record, approved external inputs, assumptions and unresolved questions. If a material gap blocks committee work, return it to the coordinator; do not repeat broad discovery.
2. **Identify decisions.** Group consequential choices such as architecture, interfaces, data flow, errors and verification. Do not impose a subsystem-count limit or automatically split a cohesive request into unrelated tickets. If breadth creates genuine uncertainty, flag it to the coordinator for user discussion.
3. **Deliberate.** For each decision group, dispatch all three members concurrently in one message using `{{DISPATCH_AGENT_TOOL}}` and the templates in `committee-member-prompt.md`. Use specialised types and verify high-capability dispatch through the shared procedure. When a specialised type is unavailable, inspect the dispatch tool's currently exposed type options and select an available type whose description indicates broad general-purpose capability. Do not assume a type identifier. If no suitable available type exists, return a blocker to the coordinator and do not dispatch. Each member receives the same bounded brief, relevant stable evidence, decisions and prior consensus, never full session history. Members return proposals, reasoning, concerns and unresolved questions, not user approval.
4. **Synthesise consensus.** Apply the rules below, retaining material dissent and concerns. Use at most one tiebreaking round per decision. If it does not resolve the issue, return the unresolved choice to the coordinator for the user's decision.
5. **Assemble a proposed design.** Cover goal, requirements, exclusions, architecture, components, interfaces, data flow, errors/failure behaviour, tests/verification and evidence references. Summarise material splits and risks without exposing deliberation transcripts.
6. **Return to the coordinator.** Return the consolidated proposal, unresolved decisions and substantive uncertainty. Do not invoke design review, seek final user approval, persist an approved plan, create tickets or begin implementation.

Committee members and any tiebreaker return their results to the committee
skill's Planning procedure for reconciliation. Return the proposed design to
the coordinator after reconciliation. This ends the committee procedure, not the overall workflow; the
coordinator records the result and next action in existing `workflow.md` and
invokes the next required phase without routine prompting. User choices,
approval and unresolved blockers remain pauses.

## The Three Perspectives

Each committee member uses a perspective-specific subagent type. The full prompt templates live in `committee-member-prompt.md`.

| Role        | What it prioritises                                                                  | Subagent type           |
|-------------|--------------------------------------------------------------------------------------|-------------------------|
| Pragmatist  | Simplicity, maintenance cost, shipping quickly, reusing what already exists          | Stack-specific (below)  |
| Architect   | Patterns, separation of concerns, well-defined interfaces, testability               | `architect-reviewer`    |
| Advocate    | Correctness, edge cases, robustness under failure, hard-to-misuse interfaces         | `qa-expert`             |

Resolve and verify available subagent types and model routing through `../_shared/subagent-dispatch.md` before dispatch.

### Pragmatist Type Mapping

Map the project's primary language or framework, as supplied by the coordinator, to an available type:

| Project stack          | Subagent type        |
|------------------------|----------------------|
| TypeScript             | `typescript-pro`     |
| Python                 | `python-pro`         |
| Go                     | `golang-pro`         |
| Rust                   | `rust-engineer`      |
| React frontend         | `react-specialist`   |
| PHP / Laravel          | `laravel-specialist` |
| Java / Spring          | `java-architect`     |
| C# / .NET              | `csharp-developer`   |
| Ruby / Rails           | `rails-expert`       |
| Multi-language / other | An available generalist type, resolved at dispatch time |

## Synthesising Consensus

| Outcome             | Action                                                                            |
|---------------------|-----------------------------------------------------------------------------------|
| All three agree     | Recommend that approach, retaining any material concern.                         |
| Two of three agree  | Recommend the majority view and record substantive dissent.                      |
| All three disagree  | Run one tiebreaking round (see below).                                            |

Concerns flagged by two or more members **MUST** be addressed in the design, even if the specific recommendation differs.

## Tiebreaking

If a round produces irreconcilable disagreement (not just preference differences), dispatch at most one tiebreaking round. Pass all three positions to a single high-capability reviewer, resolved through the shared dispatch procedure. The tiebreaking template is in `committee-member-prompt.md`. If it does not converge, return the unresolved decision to the coordinator for the user's decision.

## Working in Existing Codebases

- Follow existing patterns. Include only changes needed for the requested outcome.
- **MUST NOT** propose unrelated refactoring. Committee members are explicitly instructed in their prompts to stay within scope; the synthesiser must reject any recommendation that exceeds it.

## Common Mistakes

| Mistake                                                                | Why it is wrong                                                                                                                |
|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Asking routine questions during deliberation                           | Return material gaps or user choices to the coordinator for targeted discussion. |
| Dispatching committee members sequentially                             | They **MUST** run concurrently. One message, three tool calls.                                                                 |
| Passing session history to committee members                           | Violates context isolation from `../../rules/common/subagents.md`. Pass the brief, the codebase context, the decisions, and prior consensus only. |
| Assuming a subagent type or model is available                          | Verify its availability and routing through the shared dispatch procedure.          |
| Showing the user the full deliberation transcripts                     | The user wants the design, not the process. Surface only the result, splits, and flagged risks.                                |
| Treating committee consensus as review or approval | The coordinator performs independent review and obtains explicit user approval. |
| Running more than one tiebreaking round                                | If one tiebreaker cannot converge, the decision is genuinely unresolved and belongs to the user.                               |
| Letting the synthesiser quietly drop a concern flagged by two members  | Two members flagging a concern is signal. Address it in the design or the round did not really converge.                       |
