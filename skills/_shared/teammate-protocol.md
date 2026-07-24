# Teammate Protocol

This file is the procedural detail behind the teammate iron laws in `../../rules/common/teammates.md`. Those laws (peer isolation, no concurrent writers, exclusive per-task file ownership, git ownership, board-lag reconciliation, dead-teammate handling) bind whether or not this file is loaded; nothing here restates or supersedes them. Read `../../rules/common/teammates.md` before reading this file, and read `../../rules/common/subagents.md` Part A for the universal laws (worktree ban, privilege ban, git ownership, model identifiers) that apply to teammates in full.

**Type selection and model selection are not redefined here.** A teammate's agent type and model are chosen exactly the way a one-shot subagent's are: follow the Subagent Type Selection and Model Selection procedures (tier table, resolution procedure, escalation triggers) in `subagent-dispatch.md` in full. The only difference is that a teammate is spawned once and kept alive across multiple tasks rather than dispatched fresh per task; the selection procedure itself does not change.

What this file covers instead is what is specific to the persistent-peer model: how the lead assigns work, how ownership is declared and checked before any teammate starts, how the lead and teammates talk to each other over the run, what a completion claim from a teammate actually means, how the lead handles an idle teammate, and how the lead recovers when a teammate or the team runtime fails.

## Lead-Assigned Tasks, Never Self-Claim

The lead assigns each task to a specific teammate by setting the task's `owner` field, per the schema in `task-board.md`. A teammate **MUST NOT** self-select or claim an unassigned task from the board, and **MUST NOT** pick up a task owned by another teammate, even if it appears idle or stalled.

Self-claim is forbidden above all because it bypasses the lead's pre-flight disjointness computation and `blockedBy` serialisation (see "Exclusive File-Ownership Declaration and Pre-Flight Check" below): a self-claiming teammate could pick up a task that was deliberately serialised behind an in-progress task because they share files, producing exactly the concurrent-writer tree corruption that the "no concurrent writers to one file, ever" law in `../../rules/common/teammates.md` exists to prevent. This is a tree-corruption risk, not merely a duplicate-work risk, and it is the primary reason the rule exists. It is compounded by two further reasons: self-claim races two teammates onto the board at once, since both can observe the same unassigned task as available and both can start on it; and because board `status` lags behind reality (per the board-lag reconciliation law in `../../rules/common/teammates.md`), a teammate cannot safely infer from `status: pending` alone that a task is actually free. All scheduling intelligence, including which task a teammate picks up next, stays with the lead. A teammate that finishes a task or goes idle waits for the lead's next assignment; it does not scan the board and choose for itself.

## Exclusive File-Ownership Declaration and Pre-Flight Check

Before spawning any teammate, the lead runs a pre-flight ownership check over the full task decomposition:

1. For every task in the decomposition, read its lead-only `files` metadata key (per `task-board.md`).
2. Compute the union of every task's `files` set.
3. Assert the sets are pairwise disjoint: no file path appears in more than one task's `files` set among tasks that could run concurrently.
4. If an overlap is found, resolve it before any teammate starts, by one of:
   - Re-splitting the decomposition so the overlapping files fall under a single task, or
   - Serialising the overlapping tasks with a `blockedBy` edge so they never run at the same time.
5. Only once the check passes for the full set of tasks about to go live does the lead spawn teammates and hand out assignments.

This is the operational form of the "no concurrent writers" and exclusive-ownership laws in `../../rules/common/teammates.md`; those laws state the invariant, this procedure is how the lead proves it holds before any teammate touches the working tree.

Shared or aggregator files (a barrel export, an index, a shared config, a changelog) need explicit handling: name them in the decomposition and assign each one to exactly one task's `files` set. A task that only reads a shared file does not need to own it; a task that writes to it does, and every other task that would otherwise touch it is serialised behind that owner with `blockedBy`.

## The Mailbox (SendMessage)

Teammates and the lead coordinate over the life of the run through SendMessage, not through the board alone and not through plain text output.

- Address a specific teammate by its name; address the lead by sending to "main" (the lead's own conversation).
- The lead uses SendMessage to hand a teammate its assignment, and to answer any question a teammate raises mid-task.
- A teammate uses SendMessage to reach the lead when it has a question it cannot resolve from the task's own `description`, and again when it believes a task is finished (see "Completion Handoff and Verification Authority" below).
- Messages are delivered automatically; a teammate does not poll an inbox and the lead does not poll for messages either. Coordination happens because a message was sent, not because someone went looking.
- A teammate's plain text output (anything it "says" outside a SendMessage call) is not visible to the lead or to other teammates. Anything that needs to reach another agent, a question, a status update, a completion claim, **MUST** go through SendMessage. Writing it to output and assuming it was seen is a coordination failure, not a shortcut.

This mailbox is the concrete mechanism behind the peer isolation model in `../../rules/common/teammates.md`: a teammate has no shared in-context state with the lead or with other teammates, so the mailbox and the board are the only two channels that exist.

## Completion Handoff and Verification Authority

A teammate reporting a task as done, whether by SendMessage to the lead or by moving the board's native `status` to `completed`, means "claimed done, pending lead verification". It is never itself authoritative; this follows directly from the guiding invariant in `task-board.md` that the board is advisory and the lead is authoritative.

On receiving a completion claim, the lead:

1. Runs its own verification gate against the task, scoped to the files the task declared ownership of.
2. Only after that gate passes does the lead write the lead-only `verified` key, and, once the work is committed, `commit_sha`.
3. Treats a claim that fails verification the same as a failed task: see "Failure Recovery" below, not as a completed one.

If a `TaskCompleted` hook is wired up, it is a trigger, nothing more: it enqueues the lead's verification pass. It **MUST NOT** be treated as marking the task complete, and it **MUST NOT** commit anything on its own. Only the lead's own verification and the lead's own commit establish that a task is done.

Because teammates sometimes fail to mark a task complete at all, and because board `status` lags behind the real working tree (per the board-lag reconciliation law), the lead also runs a hook-independent reconciliation sweep before any feature-level completion claim: poll `TaskList`/`TaskGet` across the full task set, and verify each task's declared artefacts directly against the working tree, rather than trusting that every completion arrived as a hook trigger or a mailbox message.

## Idle Handling

When a teammate goes idle (a `TeammateIdle` signal), the lead:

1. Confirms, via `TaskGet`, the true state of the board rather than relying on cached state.
2. Assigns the next task that is both dependency-eligible (its `blockedBy` tasks are verified, not merely marked `completed`) and does not conflict on files with any task currently in flight on another teammate.
3. If no such task exists and the board is drained, begins shutdown for that teammate rather than leaving it idle indefinitely.

Every teammate is shut down before the lead runs the final feature-level review; the review runs against a settled working tree with no in-flight peer writers.

## Failure Recovery

Teammates have no session resumption (per the dead-teammate law in `../../rules/common/teammates.md`), so every recovery path below re-queues the affected task to be picked up again rather than assuming a teammate can be resumed mid-task.

- **Teammate dies mid-task.** Handled per the dead-teammate law in `../../rules/common/teammates.md`. Operationally, the lead scopes its git diff inspection to the task's declared `files` set when assessing the partial edit, then re-queues the task once the tree is resolved.
- **Teammate stalls after claiming.** The lead detects this from the teammate-advisory `claim` heartbeat going stale past a timeout. It reclaims the task from that teammate and re-queues it for reassignment.
- **Teammate never goes idle.** The lead applies a timeout, issues `TaskStop`, and re-queues the task once the teammate has stopped.
- **Runtime spawn failure, or the teammate mode is unavailable** (for example an experimental flag is off in the current environment). The lead degrades the entire run to the sequential one-shot subagent path via `subagent-driven-development`, dispatching the same task decomposition as one-shot subagents instead of teammates. The decomposition itself is path-agnostic: the same tasks, the same `files` ownership, the same acceptance criteria apply whether they run as teammate assignments or as sequential subagent dispatches.

In every case above, the resolution is the same shape: stop trusting the unverified state, re-queue against the original task specification, and let either a fresh teammate or the sequential path pick the task up under the lead's normal verification gate. None of these paths proceed on unverified work, and none of them invent a new task specification to route around the failure.
