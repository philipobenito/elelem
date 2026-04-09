# Subagent Dispatch - Procedural Rules

These rules apply to every subagent dispatch made from inside a skill. They are the procedural detail behind the iron laws in `../../rules/common/subagents.md`. The iron laws (context isolation, the git ban, the worktree ban, the privilege ban) live in the always-on rule file and bind whether or not a skill is running. The rules below govern *how* a dispatch is constructed and managed once a skill has decided to dispatch.

Skills that dispatch subagents (`subagent-driven-development`, `dispatching-parallel-agents`, `fast-path-implementation`, `brainstorming-committee`, `debugging`) **MUST** read this file before performing a dispatch.

## Subagent Type Selection

Before every dispatch, you **MUST** check the available subagent types and select the most specific one that fits the task. Generic agents produce generic work; specialised agents understand their domain, follow its conventions, and catch domain-specific issues a general-purpose agent will miss.

The selection process:

1. Identify the language, framework, or domain the task involves
2. Scan available subagent types for a match (e.g. `typescript-pro` for TypeScript, `react-specialist` for React components, `python-pro` for Python, `code-reviewer` for reviews)
3. If a specialised type matches, use it via the `subagent_type` parameter
4. Fall back to `general-purpose` only when no specialised type fits

This applies to implementers and reviewers equally. A TypeScript task gets a TypeScript implementer and a code-review specialist, not two general-purpose agents.

When decomposing work into tasks, you **MUST** annotate each task with its recommended subagent type during decomposition, not at dispatch time. This makes the choice explicit and reviewable.

## Model Selection

You **MUST** use the cheapest model capable of the task. This is cost and speed discipline, not a suggestion.

Choose exactly one concrete model per dispatch. Use the first available model from the relevant ordered list below. Escalate only when you have specific evidence the task requires more capability.

Use these ordered model lists:

| Use case            | Ordered models                                                  |
|---------------------|-----------------------------------------------------------------|
| Low-cost default    | `haiku`, `gpt-5.1-codex-mini`, `gemini-2.5-flash-lite`          |
| Standard escalation | `sonnet`, `gpt-5.2`, `gemini-2.5-flash`                         |
| High-capability     | inherited session model, `opus`, `gpt-5.4`, `gemini-2.5-pro`    |

Google names in these lists are valid only when the current environment actually exposes them. If they are unavailable, skip them and keep the same order.

| Role                                | Default                                                          | Escalate to                                                                 | Escalation trigger                                                            |
|-------------------------------------|------------------------------------------------------------------|-----------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| Implementer (clear spec, 1-3 files) | `haiku`, then `gpt-5.1-codex-mini`, then `gemini-2.5-flash-lite` | `sonnet`, then `gpt-5.2`, then `gemini-2.5-flash`                           | Task failed on the low-cost choice, or needs multi-file integration reasoning |
| Implementer (integration, judgment) | `sonnet`, then `gpt-5.2`, then `gemini-2.5-flash`                | inherited session model, then `opus`, then `gpt-5.4`, then `gemini-2.5-pro` | Multi-file coordination, pattern matching, debugging                          |
| Reviewer (standard)                 | `haiku`, then `gpt-5.1-codex-mini`, then `gemini-2.5-flash-lite` | `sonnet`, then `gpt-5.2`, then `gemini-2.5-flash`                           | Architecturally complex code requiring deep reasoning                         |
| Fix subagent                        | `haiku`, then `gpt-5.1-codex-mini`, then `gemini-2.5-flash-lite` | `sonnet`, then `gpt-5.2`, then `gemini-2.5-flash`                           | Fix requires understanding beyond the immediate issue                         |

Task complexity signals:

- Touches 1-2 files with a complete spec: `haiku`, else `gpt-5.1-codex-mini`, else `gemini-2.5-flash-lite`
- Touches multiple files with integration concerns: `sonnet`, else `gpt-5.2`, else `gemini-2.5-flash`
- Requires design judgement or broad codebase understanding: inherited session model, else `opus`, else `gpt-5.4`, else `gemini-2.5-pro`

You **MUST NOT** pre-escalate. Start with `haiku`; if it is unavailable, use `gpt-5.1-codex-mini`; if that is unavailable and Google models are exposed, use `gemini-2.5-flash-lite`. If that fails or produces poor output, re-dispatch with `sonnet`; if it is unavailable, use `gpt-5.2`; if that is unavailable and Google models are exposed, use `gemini-2.5-flash`. One failed inexpensive attempt costs less than always paying for the expensive model.

## Answering Subagent Questions

When a subagent asks a question before or during its task, you **MUST** answer it clearly and completely before allowing the subagent to proceed. You **MUST NOT** rush a subagent into implementation, and you **MUST NOT** ignore a question in the hope the subagent will work it out alone.

## Process Discipline

When orchestrating subagents, you **MUST NOT**:

- Skip reviews, whether combined or separate
- Proceed to the next task while a review has unfixed issues
- Accept "close enough" on spec compliance. If the reviewer found issues, the task is not done.
- Let the implementer's self-review replace the external review. Both are required.
- Force the same model to retry a failed task without changing anything (more context, different model, smaller scope, or escalation to the human)
- Attempt to fix a subagent's output manually in the orchestrator context. Re-dispatch with a better context instead. Manual fixes pollute the orchestrator's context and defeat the isolation.

## Escalation

If a subagent reports BLOCKED or fails repeatedly, you **MUST** do one of the following and nothing else:

- Provide more context and re-dispatch
- Re-dispatch with a more capable model
- Split the task into smaller pieces
- Stop and escalate to the human per `../../rules/common/workflow.md`

You **MUST NOT** ignore an escalation. You **MUST NOT** pretend a failed task succeeded.
