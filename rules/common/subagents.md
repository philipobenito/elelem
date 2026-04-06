# Subagents

These rules apply to every subagent dispatch, regardless of which skill is dispatching them.

## Context Isolation

You **MUST NOT** let a subagent inherit your session history. Every dispatch starts from a clean slate. You **MUST** construct exactly the context the subagent needs: the task description, the relevant files or file contents, the acceptance criteria, and any constraints. Do not assume the subagent knows anything you have not told it in the dispatch.

You **MUST NOT** instruct a subagent to "discover" context on its own when you can provide it directly. Subagents exploring the codebase to rebuild context you already hold is a waste.

## Git Operations

Subagents **MUST NOT** commit, push, create branches, or perform any destructive git operation. The orchestrator owns all git state. Subagents implement, test, and report back; the orchestrator decides when to commit based on the user's upfront instructions.

## Worktrees

You **MUST NOT** use `isolation: "worktree"` on any subagent dispatched from a user-authored skill. This applies to implementer, reviewer, investigator, and committee subagents alike. Read-only investigators do not need worktree isolation because they do not write files; sequential implementers do not benefit either. There is no scenario inside the user-authored skill set where a worktree is the right choice; the rule is unconditional.

## Privilege

Subagents **MUST NOT** use `sudo` or any elevated-privilege command. If a task requires elevation, the orchestrator surfaces it to the human partner.

## Procedural Rules

The procedural rules that bind once a skill is dispatching a subagent, subagent type selection, model selection (table and escalation triggers), answering subagent questions, process discipline, and escalation handling, live in `skills/_shared/subagent-dispatch.md` and load when any dispatching skill is invoked.
