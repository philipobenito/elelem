# Teammates

This file governs the persistent-peer model: teammates are long-running Claude Code sessions that coordinate as peers with the lead, sharing one working tree, one task board, and one mailbox. One-shot subagents (dispatched for a single task, no resumption, no peer coordination) are governed by `subagents.md`, not this file. The two files cross-reference and do not overlap; do not duplicate rules between them.

## Universal Laws Apply

The universal laws in `subagents.md` (Part A: worktree ban, privilege ban, git ownership, model identifiers) apply to teammates in full. They are not restated here. Read `subagents.md` Part A before dispatching or coordinating with a teammate.

## Peer Isolation Model

A teammate does not inherit the lead's session history, the same as a one-shot subagent. Unlike a one-shot subagent, a teammate is long-running and must coordinate with the lead and other teammates over time. That coordination happens **only** through the shared task board and the SendMessage mailbox. You **MUST NOT** assume a teammate has visibility into anything not written to the board or sent via mailbox; there is no shared in-context state between peers.

## No Concurrent Writers to One File, Ever

Teammates share a single working tree; there is no worktree isolation between them (the worktree ban in `subagents.md` still applies to how any individual agent is dispatched, but it does not create per-teammate isolation). Because of this, two teammates **MUST NEVER** edit the same file at the same time. This is an iron law, not a guideline: a collision here corrupts the shared tree for everyone.

## Exclusive Per-Task File Ownership

Each task **MUST** declare the set of files it owns, via the lead-only `files` metadata key defined in `skills/_shared/task-board.md`. The lead assigns tasks so that no two concurrently active tasks share a file. Work that is coupled by a shared file **MUST** be serialised with `blockedBy` edges rather than run in parallel. A teammate **MUST NOT** touch a file outside its task's declared `files` set.

## Git Ownership

Git ownership follows the universal law in `subagents.md`: only the lead commits. See Part A.

## Board-Lag Reconciliation

Task board status can lag behind reality. Before treating a task as truly terminal, freeing its files for reassignment, or treating a dependency as satisfied, the lead **MUST** confirm state via `TaskGet`, not cached or remembered state. At merge time the lead reconciles the diff against the real working tree, not against the board's account of what changed.

## Dead-Teammate Handling

Teammates have no session resumption: a teammate that dies mid-task leaves behind an unverified partial edit. The lead **MUST** treat that task as suspect, inspect the diff directly, and **MUST NOT** build further work on top of a half-finished edit. Reverting a partial edit requires explicit user approval before it happens. Once resolved (reverted or completed by another teammate), the task is re-queued.

## Procedure

The operational procedure for claiming tasks, running the mailbox protocol, and handling conflicts lives in `skills/team-driven-development/` and `skills/_shared/teammate-protocol.md`. Those are the procedure homes for this model; this file states the iron laws that bind regardless of which skill is orchestrating.
