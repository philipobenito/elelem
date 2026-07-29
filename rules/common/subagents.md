# Subagents

This file has two parts. Part A holds the universal laws that apply to **any** delegated agent, whether a one-shot subagent (this file) or a persistent teammate (`teammates.md`). Part B holds the rules specific to the one-shot subagent model: a subagent dispatched for a single task, with no session resumption and no peer coordination.

The persistent-teammate model (shared task board, mailbox, exclusive file ownership across a live working tree) is governed entirely by `teammates.md`, not by this file. If you are dispatching a teammate rather than a one-shot subagent, read that file instead; it references the universal laws below by pointer rather than restating them.

## Part A: Universal Laws (Any Delegated Agent)

These rules apply to every delegated agent, regardless of which model dispatched it or which skill is doing the dispatching.

### Authorisation

Dispatch instructed by an invoked skill is user-requested by definition. When a skill's procedure calls for a delegated agent, the user's invocation of that skill **is** the request, and you **MUST NOT** ask the user to approve the dispatch again before making it.

Authorisation propagates down a skill chain. A user invoking `work-on-ticket` authorises the orchestration skill it hands off to, the triage that orchestrator runs, and the review skills invoked before completion. One invocation authorises every dispatch the chain's procedures call for, however deep the chain runs.

A harness default that discourages unprompted agent dispatch does not override this. Per the Instruction Priority in `skills-policy.md`, rules and skills in this repository outrank default system behaviour, and the skills listed in `skills/_shared/subagent-dispatch.md` dispatch as a mandatory step of their procedure rather than as an optional optimisation.

This authorises only dispatch a skill's procedure calls for. Dispatching because a search looks broad, or because a task feels parallelisable, is your own decision rather than a skill's, is not covered here, and does not waive the skill check that `skills-policy.md` requires first.

### Worktrees

You **MUST NOT** use `isolation: "worktree"` on any agent dispatched from a user-authored skill. This applies to implementer, reviewer, investigator, and committee agents alike. Read-only investigators do not need worktree isolation because they do not write files; sequential implementers do not benefit either. There is no scenario inside the user-authored skill set where a worktree is the right choice; the rule is unconditional.

### Privilege

Delegated agents **MUST NOT** use `sudo` or any elevated-privilege command. If a task requires elevation, the orchestrator surfaces it to the human partner.

### Git Ownership

Only the lead/orchestrator commits. A delegated agent, whether a one-shot subagent or a persistent teammate, **MUST NOT** commit, branch, push, or perform any destructive git operation. The lead/orchestrator owns all git state in both models: delegated agents implement, test, and report back; the lead decides when to commit based on the user's upfront instructions.

### Model Identifiers

You **MUST NOT** write a model identifier you have not confirmed the current environment exposes. Recognising the shape of an identifier is not the same as confirming it exists; constructing an identifier from a pattern is inventing it.

### Agent Types

You **MUST** dispatch every delegated agent as a harness built-in type, per the table in `skills/_shared/subagent-dispatch.md`. You **MUST NOT** select an installed or plugin-supplied agent definition, and you **MUST NOT** pick a type on the basis of the task's language, framework, or domain.

An installed definition carries its own tool permissions, which no dispatch can verify beforehand: an agent silently missing `SendMessage` fails mid-task rather than at the call site.

## Part B: One-Shot Subagent Model

These rules apply specifically to one-shot subagents: agents dispatched for a single task that terminate on completion, with no resumption and no peer-to-peer coordination. For the persistent-teammate model, see `teammates.md`.

### Context Isolation

You **MUST NOT** let a one-shot subagent inherit your session history. Every dispatch starts from a clean slate. You **MUST** construct exactly the context the subagent needs: the task description, the relevant files or file contents, the acceptance criteria, and any constraints. Do not assume the subagent knows anything you have not told it in the dispatch.

You **MUST NOT** instruct a subagent to "discover" context on its own when you can provide it directly. Subagents exploring the codebase to rebuild context you already hold is a waste.

## Procedural Rules

The procedural rules that bind once a skill is dispatching a one-shot subagent, the agent type lookup, model selection with identifier resolution and verification (tier table, resolution procedure, and escalation triggers), answering subagent questions, process discipline, and escalation handling, live in `skills/_shared/subagent-dispatch.md` and load when any dispatching skill is invoked.
