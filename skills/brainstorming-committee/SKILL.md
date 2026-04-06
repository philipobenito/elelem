---
name: brainstorming-committee
description: "Turns an idea into an approved design through autonomous deliberation by three subagents with different perspectives, who debate decisions and converge on consensus without user involvement until the final design is ready for review. Then runs design-review and hands off to create-tickets or subagent-driven-development."
---

# Brainstorming (Committee)

Hands-off design dialogue. The user provides the initial brief, then three subagents with deliberately different perspectives deliberate on each design decision and converge on consensus. The user only sees the final design.

For the rule that no implementation may begin until the user has approved a design, see `instructions/common/workflow.md`. For the rules on dispatching subagents (context isolation, type selection, model selection, git ban, worktree ban), see `instructions/common/subagents.md`. The design review step is delegated to the `design-review` skill.

## Load the Committee Member Prompts First

This skill depends on the prompt templates in `committee-member-prompt.md` (sibling file in this skill directory). Those templates are **not** always in context; they are loaded only when this skill is invoked. Before running the procedure below, you **MUST** read `committee-member-prompt.md` using the {{READ_FILE_TOOL}} tool if you have not already read it in this session. The committee dispatch in step 4 paste-fills those templates with codebase context and decision lists, so they need to be in your context first.

## Preconditions

- You **MUST** be in plan mode before invoking this skill. Use `{{ENTER_PLAN_TOOL}}` if you are not.
- This skill is invoked either directly or by the `brainstorming` router after the user selects committee mode.
- Use this skill only when there are at least two meaningful design decisions to make. For trivial requests (a single config change, a one-line fix), `brainstorming-standard` is the right tool.

## Procedure

1. **Confirm the brief.** This is the only point where you ask the user a question during deliberation. Restate what you understand they want to build, the scope as you see it, and any assumptions, then confirm via `{{ASK_USER_QUESTION_TOOL}}`. Once confirmed, the user is hands-off until step 7.
2. **Explore project context.** Read the area of the codebase relevant to the brief. Stay narrow: every file you read here gets passed to every committee member in every round, so unnecessary context dilutes focus and wastes capacity. Identify the project's primary language and framework now because the Pragmatist subagent type depends on it (see Pragmatist Type Mapping below). If the feature touches more than ~3 subsystems, or you cannot determine which code is relevant, surface what you have found and ask the user for guidance via `{{ASK_USER_QUESTION_TOOL}}`. This is the only other point where you may ask the user a question.
3. **Identify design decisions.** List the key decisions: architecture, approach, data flow, error handling, testing strategy, integration. Group-related decisions so each committee round addresses a coherent set, not individual micro-choices.
4. **Run committee deliberation rounds.** For each decision group, dispatch three committee members in parallel (single message, three tool calls) using `{{DISPATCH_AGENT_TOOL}}` and the templates in `committee-member-prompt.md`. Each member receives identical context: the brief, the relevant codebase context, the specific decisions, and any decisions already made. Each returns a recommendation, reasoning, and concerns.
5. **Synthesise consensus** after each round using the table below. Record the consensus before moving to the next round.
6. **Assemble the design summary.** Combine all consensus decisions into a single coherent summary covering goal, architecture, components, interfaces, data flow, error handling, testing strategy, and integration points. Scale each section to its complexity. Follow existing patterns; do not propose unrelated refactoring.
7. **Present the design to the user.** Include the full summary, a brief note on any decisions where the committee was split (with the reasoning for the chosen direction), and any risks the committee flagged. **MUST NOT** dump the deliberation transcripts. The user wants the result, not the process.
8. **Invoke `design-review`** via `{{INVOKE_SKILL_TOOL}}` against the consolidated summary. If the review surfaces issues that require new decisions (not just wording fixes), feed the affected decisions back into a targeted committee round, update the summary, and re-invoke `design-review`. If `design-review` escalates after three iterations, stop and ask the user how to proceed.
9. **Get explicit final approval.** Present the reviewed summary and ask directly. "Looks fine" is not approval.
10. **Decide the next step.** Use `{{ASK_USER_QUESTION_TOOL}}` to ask whether to create tickets or start implementation. The only permitted downstream skills are `create-tickets` and `subagent-driven-development`; invoke whichever the user picks via `{{INVOKE_SKILL_TOOL}}`.

## The Three Perspectives

Each committee member uses a specialised subagent type that reinforces its perspective. The full prompt templates live in `committee-member-prompt.md`.

| Role        | What it prioritises                                                                  | Subagent type           |
|-------------|--------------------------------------------------------------------------------------|-------------------------|
| Pragmatist  | Simplicity, maintenance cost, shipping quickly, reusing what already exists          | Stack-specific (below)  |
| Architect   | Patterns, separation of concerns, well-defined interfaces, testability               | `architect-reviewer`    |
| Advocate    | Correctness, edge cases, robustness under failure, hard-to-misuse interfaces         | `qa-expert`             |

For the general rule that specialised subagent types **MUST** be preferred over `general-purpose`, see `instructions/common/subagents.md`. The mapping above is the committee-specific instance of that rule.

### Pragmatist Type Mapping

Map the project's primary language or framework (identified during step 2) to the most specific available subagent type:

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
| Multi-language / other | `general-purpose`    |

## Synthesising Consensus

| Outcome             | Action                                                                            |
|---------------------|-----------------------------------------------------------------------------------|
| All three agree     | Take that approach.                                                               |
| Two of three agree  | Take the majority view; record the dissenting concern if it is substantive.       |
| All three disagree  | Run a tiebreaking round (see below).                                              |

Concerns flagged by two or more members **MUST** be addressed in the design, even if the specific recommendation differs.

## Tiebreaking

If a round produces irreconcilable disagreement (not just preference differences), dispatch a single tiebreaking round. All three positions are passed to a single `architect-reviewer` subagent that must converge to a final decision. The tiebreaking template is in `committee-member-prompt.md`. **MUST NOT** run more than one tiebreaking round per decision; if the tiebreaker still cannot converge, surface the unresolved decision to the user.

## Working in Existing Codebases

- Follow existing patterns. Where existing code has problems that affect the work, include targeted improvements in the design.
- **MUST NOT** propose unrelated refactoring. Committee members are explicitly instructed in their prompts to stay within scope; the synthesiser must reject any recommendation that exceeds it.

## Completion Gate

You **MUST NOT** invoke `create-tickets` or `subagent-driven-development` until all of these are true:

- Every identified decision group has a recorded consensus
- The design summary was assembled from those consensuses into a single text block
- `design-review` returned Approved
- The user gave explicit final approval against the reviewed summary

## Common Mistakes

| Mistake                                                                | Why it is wrong                                                                                                                |
|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Asking the user clarifying questions during deliberation               | The committee replaces user questioning. The only allowed user questions are step 1 and the optional step 2 escape hatch.      |
| Dispatching committee members sequentially                             | They **MUST** run concurrently. One message, three tool calls.                                                                 |
| Passing session history to committee members                           | Violates context isolation from `subagents.md`. Pass the brief, the codebase context, the decisions, and prior consensus only. |
| Using `general-purpose` when a specialised type is available           | Violates the type-selection rule in `subagents.md`.                                                                            |
| Showing the user the full deliberation transcripts                     | The user wants the design, not the process. Surface only the result, splits, and flagged risks.                                |
| Skipping `design-review` because the committee already reviewed itself | The committee deliberates, it does not review. `design-review` is a separate, holistic check.                                  |
| Running more than one tiebreaking round                                | If one tiebreaker cannot converge, the decision is genuinely unresolved and belongs to the user.                               |
| Letting the synthesiser quietly drop a concern flagged by two members  | Two members flagging a concern is signal. Address it in the design or the round did not really converge.                       |
