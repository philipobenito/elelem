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

Default every subagent dispatch to `model: "haiku"`. Escalate only when you have specific evidence the task requires more capability.

| Role                                | Default  | Escalate to | Escalation trigger                                                |
|-------------------------------------|----------|-------------|-------------------------------------------------------------------|
| Implementer (clear spec, 1-3 files) | `haiku`  | `sonnet`    | Task failed with haiku, or needs multi-file integration reasoning |
| Implementer (integration, judgment) | `sonnet` | inherited   | Multi-file coordination, pattern matching, debugging              |
| Reviewer (standard)                 | `haiku`  | `sonnet`    | Architecturally complex code requiring deep reasoning             |
| Fix subagent                        | `haiku`  | `sonnet`    | Fix requires understanding beyond the immediate issue             |

Task complexity signals:

- Touches 1-2 files with a complete spec: `haiku`
- Touches multiple files with integration concerns: `sonnet`
- Requires design judgement or broad codebase understanding: inherited

You **MUST NOT** pre-escalate. Start with `haiku`. If it fails or produces poor output, re-dispatch with `sonnet`. One failed inexpensive attempt costs less than always paying for the expensive model.

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
