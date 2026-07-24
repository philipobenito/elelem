---
name: brainstorming-standard
description: "Turns an idea into an approved design through interactive dialogue with a user who already knows the codebase. Explores context, asks one question at a time, proposes alternatives, presents the design in sections, runs design-review, and hands off to create-tickets or subagent-driven-development."
---

# Brainstorming (Standard)

Interactive design dialogue for a user who already knows the codebase. The conversation is the design medium; nothing is written to disk during brainstorming.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. For the rule that this skill must be invoked before creative work, see `../../rules/common/skills-policy.md`. The design review step is delegated to the `design-review` skill.

## Preconditions

- You **MUST** be in plan mode before invoking this skill. If you are not, enter plan mode now using `EnterPlanMode`. Plan mode's read-only safety enforces the design-before-implementation rule from `../../rules/common/workflow.md`.
- This skill is invoked either directly by the orchestrator or by the `brainstorming` router after the user selects standard mode. If the user has not chosen a mode yet, invoke `brainstorming` instead so they can pick.

## Procedure

1. **Explore project context.** Read files, docs, and recent commits in the area the request touches. Stay focused: do not exhaustively map the codebase. If after the initial pass the request appears to span more than ~3 subsystems, stop and tell the user; help them decompose into subprojects before continuing.
2. **Ask clarifying questions.** One question per message. Prefer multiple choice via `AskUserQuestion` over open-ended prose. Focus on purpose, constraints, and success criteria. **MUST NOT** stack multiple questions in one turn.
3. **Propose 2-3 approaches.** Present trade-offs explicitly. Lead with the recommended option and explain why it is recommended.
4. **Present the design in sections.** Cover architecture, components, data flow, error handling, and testing. Scale each section to its complexity: a few sentences for straightforward sections, up to ~300 words for nuanced ones. Get user approval on each section before moving to the next.
5. **Consolidate the design summary.** Once every section has been approved individually, write a single structured summary covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. This block of text is the input to the next step.
6. **Invoke `design-review`** via `Skill` against the consolidated summary and follow the Return Contract set out in that skill. Its two outcomes ask different things of you: Approved may carry substantive reviewer edits the user has not seen, and outstanding issues means the review budget is spent, so the decision goes to the user rather than to another dispatch.
7. **Get explicit final approval.** Present the reviewed summary to the user and obtain explicit approval. Implicit signals ("looks fine", "sure") do not count; ask directly.
8. **Decide the next step.** Use `AskUserQuestion` to ask whether to create tickets or start implementation. The permitted downstream skills are `create-tickets` and the orchestration skills; when the user picks implementation, select the orchestrator per `../../rules/common/skills-policy.md`'s "Choosing an Orchestration Skill" table (`subagent-driven-development` by default; `team-driven-development` when the design qualifies for parallel execution, or `dispatching-parallel-agents` for a stateless one-shot fan-out). Invoke the chosen skill via `Skill`. **MUST NOT** invoke any other skill from here.

## Working in Existing Codebases

- Follow existing patterns. Where existing code has problems that affect the work, include targeted improvements in the design.
- **MUST NOT** propose unrelated refactoring. Per the YAGNI rule in `../../rules/common/coding-style.md`, "while we are here" cleanups are forbidden during a brainstorming pass.

## Worked Example

User: "I want to add structured logging across the API service."

1. **Explore.** Read `src/api/`, locate the existing logger setup, check if any structured logging library is already pulled in. Find: project uses `log/slog`-equivalent in three handlers, ad-hoc `print` calls everywhere else. Recent commit history shows a previous attempt at structured logging that was reverted.
2. **Clarifying question 1**: "Do you want every existing log call migrated, or only new code from this point forward?" The user picks "every existing call".
3. **Clarifying question 2**: "What is the highest-priority consumer of these logs: humans tailing files, a log aggregator, or both equally?" The user picks "aggregator (Loki)".
4. **Approaches**: A) standardise on `slog` and migrate everything in one pass; B) introduce a thin facade and migrate per-handler; C) leave existing code alone, only require structured logging in new code. Recommend A because the previous reverted attempt failed by mixing approaches.
5. **Sections**: architecture (single `slog` handler configured at startup, JSON output), components (logger factory, request middleware that injects request ID), data flow (every handler receives a context-scoped logger), error handling (errors are logged with stack at the boundary, never inside the call chain), testing (an in-memory handler for assertions). Each section is approved.
6. **Consolidate**: write a single ~400-word summary covering all of the above.
7. **Design review**: `design-review` runs and comes back Approved after two iterations, flagging one substantive change it made along the way. The testing section had not said what the tests assert about the JSON output, and it now specifies parsed JSON fields rather than raw string contents. Surface that change to the user before continuing, because they approved a testing section that no longer reads the same way.
8. **Final approval**: present reviewed summary, user says "approved".
9. **Next step**: `create-tickets` because the user wants the migration tracked across handlers.

## Completion Gate

You **MUST NOT** invoke `create-tickets` or any orchestration skill (`subagent-driven-development`, `team-driven-development`, `dispatching-parallel-agents`) until all of these are true:

- The design summary was consolidated into a single text block
- `design-review` returned Approved
- The user gave explicit final approval against the reviewed summary

If any one of these is false, the gate has not been crossed, and you **MUST NOT** hand off.

## Common Mistakes

| Mistake                                                                         | Why it is wrong                                                                                                                                                   |
|---------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Stacking multiple questions in one message                                      | Drowns the user. One question per message, prefer multiple choice.                                                                                                |
| Skipping the consolidation step and dispatching review against the conversation | `design-review` requires a single summary block. Conversation history is not a design.                                                                            |
| Treating "looks fine" as final approval                                         | Explicit approval is required. Ask directly.                                                                                                                      |
| Inventing requirements the user did not state                                   | YAGNI. The design covers what was asked for, not what you would also build.                                                                                       |
| Invoking an implementation skill before the gate is crossed                     | Violates the `../../rules/common/workflow.md` design-before-implementation rule.                                                                                  |
| Re-invoking `design-review` after it returns outstanding issues                 | By then it has spent three dispatches applying fixes and re-reviewing. A fresh invocation buys another three and hides the fact that a human now needs to decide. |
| Applying reviewer fixes and re-dispatching yourself                             | `design-review` runs that loop internally. Doing it from here duplicates the cycle and doubles the effective budget.                                              |
| Proposing unrelated refactors discovered during exploration                     | Log them as separate items for the user. Do not bundle them into the design.                                                                                      |
