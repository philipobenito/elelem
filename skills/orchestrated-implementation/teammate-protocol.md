# Teammate Protocol

This file is the procedural detail behind the teammate iron laws in `../../rules/common/teammates.md`. Those laws (peer isolation, no concurrent writers, exclusive per-task file ownership, git ownership, board-lag reconciliation, dead-teammate handling) bind whether or not this file is loaded; nothing here restates or supersedes them. Read `../../rules/common/teammates.md` before reading this file, and read `../../rules/common/subagents.md` Part A for the universal laws (worktree ban, privilege ban, git ownership, model identifiers) that apply to teammates in full.

**Agent type and model selection are not redefined here.** A teammate's type and model come from `../_shared/subagent-dispatch.md` exactly as a one-shot subagent's do: the agent type table, and the Model Selection procedure (tier table, resolution procedure, escalation triggers) in full. The only difference is that a teammate is spawned once and kept alive across multiple tasks rather than dispatched fresh per task.

What this file covers instead is what is specific to the persistent-peer model: how the lead assigns work, how the lead and teammates talk to each other over the run, what a completion claim from a teammate actually means, how the lead handles an idle teammate, and how the lead recovers when a teammate fails. The pre-flight ownership check that proves file-disjointness before any teammate starts lives in `SKILL.md`, beside Spawn and Assign, because it is a one-off lead action at a fixed point in the schedule rather than a standing contract between lead and teammate.

## Lead-Assigned Tasks, Never Self-Claim

The lead assigns each task to a specific teammate by setting the task's `owner` field, per the schema in `../_shared/task-board.md`. A teammate **MUST NOT** take a task whose `owner` is not its own name, and **MUST NOT** select its own next task from the board.

Self-claim is forbidden above all because it bypasses the lead's pre-flight disjointness computation and `blockedBy` serialisation: a self-claiming teammate could pick up a task that was deliberately serialised behind an in-progress task because they share files, producing exactly the concurrent-writer tree corruption that the "no concurrent writers to one file, ever" law in `../../rules/common/teammates.md` exists to prevent. This is a tree-corruption risk, not merely a duplicate-work risk, and it is the primary reason the rule exists. It is compounded by two further reasons: self-claim races two teammates onto the board at once, since both can observe the same unowned task as available and both can start on it; and because board `status` lags behind reality (per the board-lag reconciliation law), a teammate cannot safely infer from `status: pending` alone that a task is actually free. All scheduling intelligence, including which task a teammate picks up next, stays with the lead. A teammate that finishes a task or goes idle waits for the lead's next assignment; it does not scan the board and choose for itself.

The teammate's own tooling argues the other way, so the lead states the ban explicitly in every assignment. `TaskUpdate`'s description invites a teammate to claim a task by setting `owner` to its own name, to mark its assigned tasks resolved when it finishes them, and to call `TaskList` afterwards to find its next task. All three are forbidden here. Per Instruction Priority in `../../rules/common/skills-policy.md`, repository rules outrank default system behaviour, and a tool description is default system behaviour.

## The Mailbox (SendMessage)

Teammates and the lead coordinate over the life of the run through SendMessage, not through the board alone and not through plain text output.

- Address a specific teammate by its name. Address the lead by the name it is running under, which the lead states in the assignment; `main` is not a valid destination for an agent that is itself the main conversation, and a send to it is rejected.
- A send that fails has delivered nothing. Treat it as an undelivered message and retry against the correct name rather than assuming it arrived.
- The lead uses SendMessage to hand a teammate its assignment, and to answer any question a teammate raises mid-task.
- A teammate uses SendMessage to reach the lead when it has a question it cannot resolve from the task's own `description`, and again when it believes a task is finished.
- Messages are delivered automatically; a teammate does not poll an inbox and the lead does not poll for messages either. Coordination happens because a message was sent, not because someone went looking.
- A teammate's plain text output (anything it "says" outside a SendMessage call) is not visible to the lead or to other teammates. Anything that needs to reach another agent, a question, a status update, a completion claim, **MUST** go through SendMessage. Writing it to output and assuming it was seen is a coordination failure, not a shortcut.

This mailbox is the concrete mechanism behind the peer isolation model in `../../rules/common/teammates.md`: a teammate has no shared in-context state with the lead or with other teammates, so the mailbox and the board are the only two channels that exist.

## Completion Handoff and Verification Authority

A teammate reporting a task as done, whether by SendMessage to the lead or by moving the board's native `status` to `completed`, means "claimed done, pending lead verification". It is never itself authoritative; this follows directly from the guiding invariant in `../_shared/task-board.md` that the board is advisory and the lead is authoritative.

On receiving a completion claim, the lead:

1. Runs code review and then its own verification gate against the task, both scoped to the files the task declared ownership of.
2. Only after that gate passes does the lead write the lead-only `verified` key, and, once the work is committed, `commit_sha`.
3. Treats a claim that fails verification the same as a failed task: see "Failure Recovery" below, not as a completed one.

If a `TaskCompleted` hook is wired up, it is a trigger, nothing more: it enqueues the lead's verification pass. It **MUST NOT** be treated as marking the task complete, and it **MUST NOT** commit anything on its own. Only the lead's own verification and the lead's own commit establish that a task is done.

Because teammates sometimes fail to mark a task complete at all, and because board `status` lags behind the real working tree (per the board-lag reconciliation law), the lead also runs a hook-independent reconciliation sweep before any feature-level completion claim: poll `TaskList`/`TaskGet` across the full task set, and verify each task's declared artefacts directly against the working tree, rather than trusting that every completion arrived as a hook trigger or a mailbox message. Count live teammates against intended in the same sweep, since a spawn can be refused without erroring.

## Idle Handling

A teammate holds one task at a time. It is freed when that task's `verified` key is written, not when it reports done and not when the reviewer approves. Holding the task through its review and gate window buys a clean fix round-trip on the same teammate while it still owns the files and still holds the context, and a task's `files` are not released until `verified` either, so no overlapping task can start while a fix is outstanding.

When a teammate goes idle (a `TeammateIdle` signal), the lead:

1. Confirms, via `TaskGet`, the true state of the board rather than relying on cached state.
2. Assigns the next task that is both dependency-eligible (its `blockedBy` tasks are verified, not merely marked `completed`) and does not conflict on files with any task currently in flight on another teammate.
3. If no such task exists and the board is drained, begins shutdown for that teammate rather than leaving it idle indefinitely.

Every teammate is shut down before the lead runs the final feature-level review; the review runs against a settled working tree with no in-flight peer writers.

## Failure Recovery

Teammates have no session resumption (per the dead-teammate law in `../../rules/common/teammates.md`), so every recovery path below re-queues the affected task to be picked up again rather than assuming a teammate can be resumed mid-task. Re-queueing sets `owner` back to the `"lead"` sentinel, which is what takes a departed teammate's name off the record.

- **Teammate dies mid-task.** Handled per the dead-teammate law in `../../rules/common/teammates.md`. Operationally, the lead scopes its git diff inspection to the task's declared `files` set when assessing the partial edit, then re-queues the task once the tree is resolved.
- **Teammate stalls after claiming.** The lead detects this from the teammate-advisory `claim` heartbeat going stale past a timeout. It reclaims the task from that teammate and re-queues it for reassignment.
- **Teammate never goes idle.** The lead applies a timeout, issues `TaskStop`, and re-queues the task once the teammate has stopped.
- **A teammate needs a more capable model.** The escalation ladder in `../_shared/subagent-dispatch.md` is written for a fresh dispatch, and a live teammate is not one. Escalating means shutting that teammate down, re-queueing its task, and spawning a replacement at the higher tier against the same specification. There is no way to raise a running teammate's model in place.
- **A spawn is refused.** The run continues with the teammates that are live; see `SKILL.md`'s Failure Handling.

In every case above, the resolution is the same shape: stop trusting the unverified state, re-queue against the original task specification, and let a fresh teammate pick the task up under the lead's normal verification gate. None of these paths proceed on unverified work, and none of them invent a new task specification to route around the failure.
