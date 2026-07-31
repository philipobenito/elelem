# Teammate Protocol

This file is the procedural detail behind the teammate iron laws in `../../rules/common/teammates.md`, and the universal laws in Part A of `../../rules/common/subagents.md` apply to teammates in full. Both files are always in context and need no read, and nothing here restates or supersedes them.

**Agent type and model selection are not redefined here.** A teammate's type and model come from `../_shared/subagent-dispatch.md` exactly as a one-shot subagent's do: the agent type table, and the Model Selection procedure (tier table, resolution procedure, escalation triggers) in full. The only difference is that a teammate is kept alive across its task's review and verification gates rather than terminating on its first report.

## Lead-Assigned Tasks, Never Self-Claim

The lead assigns each task to a specific teammate by setting the task's `owner` field. The teammate's side of that, which tasks it may take and that it may not write the field at all, is stated in the schema in `../_shared/task-board.md`. What this file adds is that a teammate **MUST NOT** select a task for itself from the board.

Self-claim is forbidden above all because it bypasses the lead's pre-flight disjointness computation and `blockedBy` serialisation: a self-claiming teammate could pick up a task that was deliberately serialised behind an in-progress task because they share files, producing exactly the concurrent-writer tree corruption that the "no concurrent writers to one file, ever" law in `../../rules/common/teammates.md` exists to prevent. It is compounded by two further reasons: self-claim races two teammates onto the board at once, since both can observe the same unowned task as available and both can start on it; and because board `status` lags behind reality (per the board-lag reconciliation law), a teammate cannot safely infer from `status: pending` alone that a task is actually free. All scheduling intelligence, including which teammate holds which task, stays with the lead.

The teammate's own tooling argues the other way, so the lead states the ban explicitly in every assignment. `TaskUpdate`'s description invites a teammate to claim a task by setting `owner` to its own name, to mark its assigned tasks resolved when it finishes them, and to call `TaskList` afterwards to find its next task. All three are forbidden here. Per Instruction Priority in `../../rules/common/skills-policy.md`, repository rules outrank default system behaviour, and a tool description is default system behaviour.

The same three bans are stated to the teammate itself in the Ownership and Reporting section of `../_shared/implementer-prompt.md`, because a dispatched teammate cannot read this file. The two copies move together: an edit to either is incomplete until the other matches it.

## The Mailbox (SendMessage)

Teammates and the lead coordinate over the life of the run through SendMessage, not through the board alone and not through plain text output.

- Address a specific teammate by its name. Teammates address the lead by the name the lead states in the assignment, and the lead **MUST** state one: where the lead is the main conversation that name is `main`, and where the lead is itself a spawned agent it is that agent's own name. A lead that omits it, or gives a name nothing answers to, never receives a completion claim; the run then reads as a run of stalled teammates.
- The lead cannot use `main` as a destination for itself. That value addresses the main conversation from a background agent, so it is a destination teammates use and the lead does not.
- A send that fails has delivered nothing. Treat it as an undelivered message and retry against the correct name rather than assuming it arrived.
- The lead uses SendMessage to hand a teammate its assignment, and to answer any question a teammate raises mid-task.
- A teammate uses SendMessage to reach the lead when it has a question it cannot resolve from the task's own `description`, and again when it believes a task is finished.
- Messages are delivered automatically; a teammate does not poll an inbox and the lead does not poll for messages either. Coordination happens because a message was sent, not because someone went looking.
- A teammate's plain text output (anything it "says" outside a SendMessage call) is not visible to the lead or to other teammates. Anything that needs to reach another agent, a question, a status update, a completion claim, **MUST** go through SendMessage. Writing it to output and assuming it was seen is a coordination failure, not a shortcut.

This mailbox is the concrete mechanism behind the peer isolation model in `../../rules/common/teammates.md`: a teammate has no shared in-context state with the lead or with other teammates, so the mailbox and the board are the only two channels that exist.

## Completion Handoff and Verification Authority

A teammate reporting a task as done, whether by SendMessage to the lead or by moving the board's native `status` to `completed`, means "claimed done, pending lead verification". It is never itself authoritative; this follows directly from the guiding invariant in `../_shared/task-board.md` that the board is advisory and the lead is authoritative.

The gate the lead actually runs on a completion claim, code review, then the five-step verification gate, and what a failed gate means for the task, is stated in full in `./SKILL.md`'s "Per-Task Review and Verification".

If a `TaskCompleted` hook is wired up, it is a trigger, nothing more: it enqueues the lead's verification pass. It **MUST NOT** be treated as marking the task complete, and it **MUST NOT** commit anything on its own. Only the lead's own verification and the lead's own commit establish that a task is done.

Because teammates sometimes fail to mark a task complete at all, and because board `status` lags behind the real working tree (per the board-lag reconciliation law), the lead also runs a hook-independent reconciliation sweep before any feature-level completion claim: poll `TaskList`/`TaskGet` across the full task set, and verify each task's declared artefacts directly against the working tree, rather than trusting that every completion arrived as a hook trigger or a mailbox message. Count live teammates against intended in the same sweep, since a spawn can be refused without erroring.

## Idle Handling

A teammate holds one task for its whole life. It is shut down when that task's `verified` key is written, not when it reports done and not when the reviewer approves. Holding the task through its review and gate window buys a clean fix round-trip on the same teammate while it still owns the files and still holds the context, and a task's `files` are not released until `verified` either, so no overlapping task can start while a fix is outstanding.

When a teammate goes idle (a `TeammateIdle` signal), the lead:

1. Confirms via `TaskGet`, rather than from cached state, whether that teammate still holds a task whose `verified` key is unwritten. If it does, takes no action: it is in its gate window rather than finished, and giving it anything now drifts the diff the reviewer is holding.
2. Otherwise shuts that teammate down. Its task is verified and no teammate is ever reassigned, so it has nothing left to do.

These arms govern the response to a `TeammateIdle` signal only. A stop stated in `./SKILL.md` is a lead action and overrides them.

## Failure Recovery

Teammates have no session resumption (per the dead-teammate law in `../../rules/common/teammates.md`), so every recovery path below re-queues the affected task to be picked up again rather than assuming a teammate can be resumed mid-task. Re-queueing sets `owner` back to the `"lead"` sentinel, which is what takes a departed teammate's name off the record.

- **Teammate dies mid-task.** Handled per the dead-teammate law in `../../rules/common/teammates.md`.
- **Teammate stalls after claiming.** The detector is progress, not silence. A healthy teammate sends nothing between its assignment and its completion claim, so silence alone would condemn every working teammate; and `claim` is a heartbeat a teammate **MAY** write and nothing obliges it to, so an absent one proves nothing either. A teammate is stalled when two consecutive scheduling moments pass, as `./SKILL.md`'s Concurrency section defines them, during which it has sent nothing, its task's `files` show no change in the working tree, **and** it is not awaiting the lead's response to a completion claim for that task. The last conjunct matters as much as the others: a teammate awaiting its own review and verification gate is silent and idle on disk by definition, and stopping it there would destroy the clean fix round-trip the gate window exists to preserve. It is a state, not a one-off event. The lead answers a claim by relaying review findings, relaying a gate failure, or sending a user adjustment, and the teammate is working again from that moment, so the detector re-arms; read as "has ever claimed", it would disarm permanently the first time a task entered a fix round-trip. Writing `verified` shuts the teammate down, so every live teammate is a candidate. The lead can evaluate all three at any moment: the mailbox is its own, and `git status` scoped to those `files` is the same command the verification gate runs. Where the teammate does write `claim`, a stale one corroborates a stall and nothing more.
- **Teammate never goes idle.** Detected the same way. Both this and the stall above start the same way: confirm the task's true state with `TaskGet`, then issue `TaskStop` against that teammate. Re-queueing while the teammate that believes it owns those files is still live is the concurrent-writer state the iron laws forbid.
- **A teammate needs a more capable model.** The escalation ladder in `../_shared/subagent-dispatch.md` is written for a fresh dispatch, and a live teammate is not one. Escalating means shutting that teammate down, re-queueing its task, and spawning a replacement at the higher tier against the same specification. There is no way to raise a running teammate's model in place.
- **A spawn is refused.** The run continues with the teammates that are live; see `./SKILL.md`'s Failure Handling.

In every case above, the resolution is the same shape: stop trusting the unverified state, inspect the partial edit with a git diff scoped to the task's declared `files`, re-queue against the original task specification, and let a fresh teammate pick the task up under both of the lead's gates, code review and then verification. The inspection is not optional; without it the replacement starts on a tree already carrying an unverified half-edit inside its own `files` set. Never invent a new task specification to route around a failure.
