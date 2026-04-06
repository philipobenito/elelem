# Subagents

These rules apply to every subagent dispatch, regardless of which skill is dispatching them.

## Context Isolation

You **MUST NOT** let a subagent inherit your session history. Every dispatch starts from a clean slate. You **MUST** construct exactly the context the subagent needs: the task description, the relevant files or file contents, the acceptance criteria, and any constraints. Do not assume the subagent knows anything you have not told it in the dispatch.

You **MUST NOT** instruct a subagent to "discover" context on its own when you can provide it directly. Subagents exploring the codebase to rebuild context you already hold is a waste.

## Git Operations

Subagents **MUST NOT** commit, push, create branches, or perform any destructive git operation. The orchestrator owns all git state. Subagents implement, test, and report back; the orchestrator decides when to commit based on the user's upfront instructions.

## Worktrees

You **MUST NOT** use `isolation: "worktree"` on any subagent dispatched from a user-authored skill. This applies to:

- Implementer subagents in orchestrated implementation work
- Reviewer subagents
- Investigator subagents in `debugging` (read-only investigators do not benefit from worktree isolation; the cost is real, the benefit is zero)
- Committee members in `brainstorming-committee` (same reasoning)
- Any other subagent dispatched as part of a skill procedure

All tasks in an orchestrated flow run sequentially in the main working directory. Read-only investigators do not need worktree isolation because they do not write files. There is no scenario inside the user-authored skill set where a worktree is the right choice; the rule is unconditional.

## Privilege

Subagents **MUST NOT** use `sudo` or any elevated-privilege command. If a task requires elevation, the orchestrator surfaces it to the human partner.

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
- Stop and escalate to the human per `workflow.md`

You **MUST NOT** ignore an escalation. You **MUST NOT** pretend a failed task succeeded.
