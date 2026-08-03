# Subagents

These rules bind every delegated agent, whether dispatched directly through the `Agent` tool or from inside a workflow script. A delegated agent is dispatched for a task, terminates on completion, and coordinates through what it is given and what it returns.

### Authorisation

Dispatch instructed by an invoked skill is user-requested by definition. When a skill's procedure calls for a delegated agent, the user's invocation of that skill **is** the request, and you **MUST NOT** ask the user to approve the dispatch again before making it. Authorisation propagates down a skill chain: one invocation authorises every dispatch the chain's procedures call for, however deep the chain runs, including the agents a workflow script launches.

This authorises only dispatch a skill's procedure calls for. Dispatching because a search looks broad, or because a task feels parallelisable, is your own decision rather than a skill's, and is not covered here.

### Worktrees

Worktree isolation (`isolation: "worktree"`) is permitted exactly where it buys real concurrency: concurrent implementers who would otherwise contend on a shared mutable artefact (a port, a test database, a cache, a build output, a lockfile) or whose test runs would collide on one tree. The dispatching skill owns the consequence: an isolated agent's changes land in its own worktree on its own branch, and only the lead brings them into the main tree and removes the worktree afterwards; nothing merges itself. Isolation converts a same-file write collision into a merge conflict rather than removing it, so genuinely overlapping write sets are serialised, never isolated. Read-only agents (reviewers pointed at a named tree, investigators) gain nothing from isolation and **MUST NOT** use it, and sequential dispatches do not benefit either.

### Privilege

Delegated agents **MUST NOT** use `sudo` or any elevated-privilege command. If a task requires elevation, the orchestrator surfaces it to the human partner.

### Git Ownership

Only the lead/orchestrator commits. A delegated agent **MUST NOT** commit, branch, push, or perform any destructive git operation, in the main tree or in a worktree. Delegated agents implement, test, and report back; the lead decides when to commit based on the user's upfront instructions.

### Model Identifiers

You **MUST NOT** write a model identifier you have not confirmed the current environment exposes. Recognising the shape of an identifier is not the same as confirming it exists; constructing an identifier from a pattern is inventing it.

### Agent Types

You **MUST** dispatch every directly dispatched agent as a harness built-in type, the one named in the dispatching skill's own prompt template. You **MUST NOT** select an installed or plugin-supplied agent definition, and you **MUST NOT** pick a type on the basis of the task's language, framework, or domain. An installed definition carries its own tool permissions, which no dispatch can verify beforehand: an agent silently missing a tool fails mid-task rather than at the call site. Agents launched from a workflow script use the script's default agent type unless the script says otherwise.

### Context Isolation

A delegated agent does not inherit your session history. Every dispatch starts from a clean slate, so you **MUST** construct exactly the context the agent needs: the task description, the relevant content pasted rather than referenced, the acceptance criteria, and any constraints. You **MUST NOT** instruct an agent to "discover" context on its own when you can provide it directly; agents exploring the codebase to rebuild context you already hold is a waste.

### Skills

A delegated agent **MUST NOT** run skill discovery against its dispatch prompt. The orchestrator owns skill invocation; the agent executes the task as dispatched, using the context, constraints, and procedures the prompt provides. If the dispatch prompt names a specific skill, the agent **MUST** invoke that skill; otherwise it invokes none.

## Dispatch Detail Lives in the Skills

Each dispatching skill carries its own dispatch detail, the agent type its prompt templates name, model selection with identifier resolution, and its retry and escalation handling, and that detail loads when the skill is invoked.
