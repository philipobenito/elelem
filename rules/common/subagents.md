# Subagents

These rules bind every delegated agent, dispatched through the `Agent` tool or from inside a workflow script.

## Authorisation

Dispatch a skill's procedure calls for is user-requested by definition: invoking the skill is the request, propagating down the whole chain, including a workflow script's agents. You **MUST NOT** re-ask for approval. Dispatch no skill's procedure calls for is your own decision and not covered.

## Worktrees

`isolation: "worktree"` is permitted only where concurrent implementers would contend on a shared mutable artefact (a port, a test database, a build output, a lockfile) or collide on one tree's test runs. Only the lead merges an isolated agent's changes and removes the worktree. Genuinely overlapping write sets are serialised, never isolated, and read-only agents **MUST NOT** use isolation.

## Boundaries

- **Privilege.** No `sudo` or elevated-privilege commands; surface elevation needs to the human partner.
- **Git.** Only the lead commits: a delegated agent **MUST NOT** commit, branch, push, or run destructive git anywhere, main tree or worktree.
- **Model identifiers.** You **MUST NOT** write a model identifier you have not confirmed the current environment exposes; constructing one from a pattern is inventing it.
- **Agent types.** Dispatch as the harness built-in type named in the dispatching skill's prompt template, never an installed or plugin-supplied definition.
- **Skills.** Delegated agents do not run skill discovery; the orchestrator owns skill invocation. A skill named in the dispatch prompt is invoked; otherwise none.

## Context Isolation

A delegated agent starts from a clean slate. Provide exactly what it needs: the task, content pasted rather than referenced, acceptance criteria, constraints. You **MUST NOT** tell an agent to discover context you already hold. Dispatch detail (prompt templates, model selection, retries) lives in each dispatching skill.
