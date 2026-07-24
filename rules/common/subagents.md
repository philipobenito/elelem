# Subagents

This file has two parts. Part A holds the universal laws that apply to **any** delegated agent, whether a one-shot subagent (this file) or a persistent teammate (`teammates.md`). Part B holds the rules specific to the one-shot subagent model: a subagent dispatched for a single task, with no session resumption and no peer coordination.

The persistent-teammate model (shared task board, mailbox, exclusive file ownership across a live working tree) is governed entirely by `teammates.md`, not by this file. If you are dispatching a teammate rather than a one-shot subagent, read that file instead; it references the universal laws below by pointer rather than restating them.

## Part A: Universal Laws (Any Delegated Agent)

These rules apply to every delegated agent, regardless of which model dispatched it or which skill is doing the dispatching.

### Worktrees

You **MUST NOT** use `isolation: "worktree"` on any agent dispatched from a user-authored skill. This applies to implementer, reviewer, investigator, and committee agents alike. Read-only investigators do not need worktree isolation because they do not write files; sequential implementers do not benefit either. There is no scenario inside the user-authored skill set where a worktree is the right choice; the rule is unconditional.

### Privilege

Delegated agents **MUST NOT** use `sudo` or any elevated-privilege command. If a task requires elevation, the orchestrator surfaces it to the human partner.

### Git Ownership

Only the lead/orchestrator commits. A delegated agent, whether a one-shot subagent or a persistent teammate, **MUST NOT** commit, branch, push, or perform any destructive git operation. The lead/orchestrator owns all git state in both models: delegated agents implement, test, and report back; the lead decides when to commit based on the user's upfront instructions.

### Model Identifiers

You **MUST NOT** write a model identifier you have not confirmed the current environment exposes. Recognising the shape of an identifier is not the same as confirming it exists; constructing an identifier from a pattern is inventing it.

## Part B: One-Shot Subagent Model

These rules apply specifically to one-shot subagents: agents dispatched for a single task that terminate on completion, with no resumption and no peer-to-peer coordination. For the persistent-teammate model, see `teammates.md`.

### Context Isolation

You **MUST NOT** let a one-shot subagent inherit your session history. Every dispatch starts from a clean slate. You **MUST** construct exactly the context the subagent needs: the task description, the relevant files or file contents, the acceptance criteria, and any constraints. Do not assume the subagent knows anything you have not told it in the dispatch.

You **MUST NOT** instruct a subagent to "discover" context on its own when you can provide it directly. Subagents exploring the codebase to rebuild context you already hold is a waste.

## Procedural Rules

The procedural rules that bind once a skill is dispatching a one-shot subagent, subagent type selection, model selection with identifier resolution and verification (tier table, resolution procedure, and escalation triggers), answering subagent questions, process discipline, and escalation handling, live in `skills/_shared/subagent-dispatch.md` and load when any dispatching skill is invoked.
