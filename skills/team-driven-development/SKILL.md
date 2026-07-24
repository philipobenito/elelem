---
name: team-driven-development
description: Implement an approved design in parallel across Agent Teams teammates, with the lead owning git, verification, and user checkpoints; degrades to subagent-driven-development when teammates are unavailable
---

# Team-Driven Development

Implement an approved design by decomposing it into tasks exactly as `../subagent-driven-development/SKILL.md` does, then executing the ready tasks in parallel across persistent teammates instead of one subagent at a time. The lead retains sole authority over git, verification, and the user checkpoints throughout.

## What This Is

This skill is a thin parallel wrapper over `../subagent-driven-development/SKILL.md` (SDD). It reuses SDD's task decomposition, per-task code review and verification gate, user checkpoint, and final feature-level review **by reference**; it does not reimplement any of them. What it adds is the machinery specific to the persistent-peer model: spawning teammates, lead-assigning work across them, and draining completed work through a serialised checkpoint queue so that parallel implementation still yields the same sequence of user-facing decisions SDD would have produced one task at a time.

It is a **sibling** skill to SDD, not a mode of it: SDD is invoked directly for sequential work, and this skill is invoked directly when parallel teammates are the right fit. It is also not `../dispatching-parallel-agents/SKILL.md`: that skill is a stateless, one-shot fan-out for a single message with no board, no persistence, and no ongoing coordination. This skill runs a multi-task feature over a shared task board and mailbox for the life of the session.

The operational protocol for how teammates and the lead coordinate (lead-assign, pre-flight ownership check, the mailbox, completion handoff, idle handling, failure recovery) lives in `../_shared/teammate-protocol.md`; read it before running the procedure below. The iron laws that bind regardless of which skill is orchestrating (peer isolation, no concurrent writers, exclusive file ownership, board-lag reconciliation, dead-teammate handling) live in `../../rules/common/teammates.md`, with the universal laws shared with one-shot subagents (worktree ban, privilege ban, git ownership, model identifiers) in Part A of `../../rules/common/subagents.md`. Neither file is restated here.

## Front-Door Capability Gate

Before spawning any teammate, and before doing anything else in this skill, probe whether Agent Teams is actually available in the current environment:

1. Confirm `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set in the environment.
2. Confirm teammate spawning actually works (a spawn attempt succeeds rather than erroring or silently doing nothing).

If either check fails, announce a single-line fallback, for example: "Teammates unavailable, running sequentially via subagent-driven-development." Then hand off the approved design directly to `../subagent-driven-development/SKILL.md` and stop. Do not retry the capability probe and do not attempt a partial or mixed run.

This gate runs first, before decomposition, before any `TaskCreate` call, before any teammate is spawned. The task decomposition this skill uses is identical to SDD's and is path-agnostic (per `../_shared/teammate-protocol.md`'s "Failure Recovery" section), so falling back here costs throughput, not correctness: every task that would have run as a teammate assignment runs instead as a one-shot subagent dispatch against the same specification.

## When to Run

Use this skill only when all of the following hold:

- The work is a sustained feature, not a single quick fix, whose approved design decomposes (per SDD's Task Decomposition) into tasks that are mostly independent of each other, i.e. they touch disjoint file sets.
- Persistent peers coordinating over a shared board add real value, because there is enough ready, unblocked, file-disjoint work at once to justify more than one agent working the board concurrently.
- There is no shared mutable test/build state that concurrent teammates would contend for (see "Shared-Tree Execution Safety" below, which lists the kinds of shared state at issue). A project where every task must exercise the same such state is a poor candidate.

Route elsewhere when this does not hold: if the tasks are tightly coupled or must run in a strict, interdependent order, use `../subagent-driven-development/SKILL.md` directly. If the work is a single-message, stateless fan-out with zero shared files and no need for a persisted board across turns, use `../dispatching-parallel-agents/SKILL.md` instead. Routing between the orchestration skills is governed by `../../rules/common/skills-policy.md`.

## Decompose (Reuse SDD)

Run SDD's Triage and Path Selection section, then its Task Decomposition section, unchanged: commit preference, `complexity-triage`, and, for COMPLEX work, the file structure, task granularity, and task ordering steps. If the classification comes back SIMPLE, hand off to `fast-path-implementation` exactly as SDD would and stop; parallel teammates add nothing to work that a single fast-path pass already covers.

Create the task board with `TaskCreate` following the field mapping in `../_shared/task-board.md` exactly. Do not invent additional fields or redefine any that file already covers.

Add the teammate-specific pre-flight before any teammate is spawned: the lead first records each task's exclusive `files` set in the lead-only `files` metadata key (per `../_shared/task-board.md`), then runs the pre-flight ownership check in `../_shared/teammate-protocol.md`, which asserts pairwise disjointness across the tasks about to go live and serialises any file-sharing tasks behind a `blockedBy` edge. Only once that check passes does the lead proceed to spawning; the check's own procedure is not restated here.

## Concurrency Preference

After decomposition classifies the work COMPLEX and the pre-flight ownership check passes, and before spawning any teammate, ask the user once how many implementer teammates may run concurrently. This is a team-only question with no SDD equivalent; it is separate from, and asked after, SDD's reused commit-preference question. On a SIMPLE classification the run has already handed off to `fast-path-implementation`, so this question is never reached.

Ask it with `AskUserQuestion`. The choice is session-wide: it is set once and reapplied to every wavefront as tasks unblock, exactly as the commit preference persists across every task. Do not re-ask it per wavefront. Each option is a ceiling, not a guarantee: the effective count never exceeds the current wavefront width, so a narrow wavefront reduces the live count without the choice changing (the clamp itself is applied in "Spawn and Assign").

| Option                          | Meaning                                                                                                                                                                                                                         |
|---------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Maximum available (recommended) | One implementer teammate per ready, file-disjoint task, up to the current wavefront width. Fastest; heaviest CPU, memory, and API use. Never unlimited, because the wavefront is the hard ceiling.                              |
| Up to three at once             | At most three concurrent implementers, even when more ready disjoint work exists. A middle ground for a first run or a moderately busy machine.                                                                                 |
| Up to two at once               | At most two concurrent implementers. Slower, and easier to follow along with.                                                                                                                                                   |
| One at a time                   | A single implementer teammate at a time. Minimal footprint; this is functionally close to running `../subagent-driven-development/SKILL.md` sequentially over the board, so prefer that skill directly if you always want this. |

This ceiling governs implementer teammates only. The per-task reviewer is a one-shot subagent the lead dispatches per completion claim (see "Per-Task Review and Verification"), so it never counts against this limit. Higher concurrency also amplifies the consequence of any shared mutable test/build-state contention that slipped past the pre-flight disjointness check, and it does not parallelise the serialised drain (the checkpoint queue, and the one reviewer dispatch and one verification gate per completion claim, all remain serial at the lead). "Maximum available" therefore speeds how quickly tasks reach the completed-claim state, not the end-to-end wall-clock.

## Spawn and Assign

Compute the ready wavefront: the tasks that are unblocked (`blockedBy` empty or already verified, per `../_shared/task-board.md`) and do not conflict on files with any other task in that same wavefront. The wavefront width is the hard upper bound on concurrency: you can never have more implementer teammates than there are ready, unblocked, file-disjoint tasks. Within that bound, the number of live implementer teammates, each concurrently holding exactly one open task (see "Per-Task Review and Verification"), is `min(concurrency preference, wavefront width)`, where the concurrency preference is the ceiling the user chose in "Concurrency Preference". The clamp counts live teammates, not per-wavefront spawns: teammates persist across wavefronts, so an idle teammate whose task is verified is reassigned the next ready task rather than respawned, and a new teammate is spawned only when a ready task has no free live teammate to take it and the live count is still below the clamp.

Select each teammate's agent type and model exactly as a one-shot subagent's would be selected, per the Subagent Type Selection and Model Selection procedures in `../_shared/subagent-dispatch.md` (tier table, resolution procedure, escalation triggers). Teammate selection does not get a different procedure; only the lifecycle (spawned once, kept alive across tasks) differs, per `../_shared/teammate-protocol.md`.

Assignment is lead-assign only: the lead sets each task's `owner` to the teammate it is handing the task to and delivers the assignment over SendMessage. See `../_shared/teammate-protocol.md`'s "Lead-Assigned Tasks, Never Self-Claim" section for why self-claiming is forbidden.

## Per-Task Review and Verification (Lead Is Sole Authority)

A teammate reporting a task done, by SendMessage or by moving the board's native `status` to `completed`, is a claim pending lead review and verification, nothing more, per `../_shared/task-board.md`'s guiding invariant that the board is advisory and the lead is authoritative. On each completion claim the lead runs the same two-gate per-task pipeline SDD runs, in the same order: code review, then verification. Parallel execution changes when the claims arrive, not what each claim must clear.

**Code review (advisory).** On a completion claim the lead dispatches a one-shot reviewer subagent against SDD's reviewer prompt (`../subagent-driven-development/reviewer-prompt.md`), selecting its type and model per `../_shared/subagent-dispatch.md` exactly as SDD does, scoped to the lead-captured working-tree diff of the task's declared `files` at the moment of the claim. This is a single reviewer role fired per completion claim, not a persistent teammate: it owns no files, holds no board state, and is never assigned work off the board, so the never-self-claim and lead-authority laws bind it trivially. The reviewer's verdict is advisory input to the lead; it never writes the board, and it is never a substitute for the verification gate below. Because the reviewer is a one-shot subagent, it also needs no shutdown before the final feature-level review; it has already terminated.

On a rejection, the lead relays the findings over SendMessage to the same owning implementer teammate, whose `owner` and `files` are unchanged, so there is nothing to re-establish; the teammate fixes and re-reports, and the lead re-reviews. Only if that teammate has died does the rejection fall through to the re-queue in `../_shared/teammate-protocol.md`'s "Failure Recovery". Every fix, whether it came from a review rejection or from a verification-gate failure, re-enters at code review: unreviewed code must never reach the verification gate.

**Verification gate (authoritative).** Only after the reviewer approves does the lead run SDD's Verification Gate section (`../subagent-driven-development/SKILL.md`) unchanged, scoped to the task's declared `files` set. If the working tree has drifted from the diff the reviewer saw, for example a shared or aggregator file changed underneath it, the approval is void and the lead re-reviews before verifying. Only after that gate passes does the lead write the lead-only `verified` key via `TaskUpdate`, and, once the task is committed, `commit_sha` for this task and `base_sha` for the task drained next (per `../_shared/task-board.md`).

Review state is not a board field: it lives in the seam between native `status: completed` and the lead-only `verified` key. A task that is `completed` with `verified` unset is one still owing review and the gate, and the reconciliation sweep treats it as such; re-review is read-only and idempotent, so when in doubt the lead reviews again. A task is drained to the checkpoint queue only once `verified` is written, so an unreviewed task can never be drained.

The lead holds each teammate to one open task: it does not assign a teammate its next task until the current task's `verified` key is written. This overrides step 2 of the reused Idle Handling procedure in `../_shared/teammate-protocol.md` for one case: a teammate whose own most recent completion claim is not yet `verified` is treated as still busy rather than idle, and is not assigned new work until the lead has reviewed, gated, and verified that claim. The benefit is a clean review-fix round-trip: a rejection always returns to the same teammate while it still exclusively owns exactly that task's files, needing no re-assignment or ownership re-establishment, and the teammate never moves on to other files that could drift the diff the reviewer approved. File disjointness itself is guaranteed by the pre-flight ownership check regardless of this rule. The throughput cost, a teammate idling through its own review-and-gate window, is the correctness trade this skill is built to pay.

If a `TaskCompleted` hook is wired up, it is a trigger only, per `../_shared/teammate-protocol.md`'s "Completion Handoff and Verification Authority" section.

Before any feature-level completion claim, the lead runs the reconciliation sweep from that same section of `../_shared/teammate-protocol.md`, since board `status` lags behind reality and a teammate can fail to report at all.

## Serialised Checkpoint Queue

Implementation runs in parallel across teammates, but the lead drains completed-and-verified tasks through the same user-facing checkpoint SDD uses, one at a time, in a deterministic order: topological order by `blockedBy`, ties broken by the task's index in the original decomposition. Never drain in completion order; two teammates finishing in any order must not change what the user is asked, or when.

A task may be committed only once both of the following hold: its lead-only `verified` key is `true`, and every task it depends on (per `blockedBy`) has already been committed. A task that finishes early but has an uncommitted dependency waits in the queue; the lead does not jump ahead of dependency order to keep a fast teammate busy.

For each task drained from the queue, the lead runs SDD's User Checkpoint section (`../subagent-driven-development/SKILL.md`) unchanged, one task at a time. Auto-commit still commits at this serialised boundary, in board order, not as soon as a teammate reports done. The number and authority of human approval points are identical to sequential SDD: the commit preference asked once, a per-task checkpoint per drained task, and the final completion report. Parallel execution changes how the work gets produced; it does not add, remove, or reorder a single user-facing decision point.

A teammate's mid-task clarifying-question exchange with the lead, when a teammate asks the lead a question before or during its work, is a lead-internal exchange over the mailbox. It is the parallel analogue of an implementer subagent's clarifying question in SDD's per-task pipeline, answered by the lead per `../_shared/subagent-dispatch.md`'s "Answering Subagent Questions". It **MUST NOT** surface to the user as a second design approval, and it **MUST NOT** be used to expand the task's scope beyond what the decomposition and the one up-front design approval already cover.

## Shared-Tree Execution Safety

Teammates share one working tree with no per-teammate isolation, per `../../rules/common/teammates.md`'s "No Concurrent Writers to One File, Ever" section. Because of this, concurrent test and build runs from two teammates can contend for the same port, cache, test database, generated artefact, or shared lockfile, even when the two tasks' source files are themselves disjoint.

This widens the independence precondition beyond file disjointness alone: two tasks are only safe to run concurrently as teammates when they share no files **and** share no mutable test/build state. During implementation, teammates run only their own owned, scoped tests, the ones exercising the files their task declared ownership of, never the project's full suite. The authoritative test and build runs stay with the lead: the per-task scoped gate described above, and the single full-suite run against the merged tree as part of the final feature-level review. A project with unavoidable global test or build state (a single shared test database with no per-run isolation, a fixed port every integration test binds to) is a poor candidate for this skill. Route it to `../subagent-driven-development/SKILL.md` instead, per the "When to Run" routing above.

## Failure and Degradation

Every failure mode reduces to the same shape described in `../_shared/teammate-protocol.md`'s "Failure Recovery": stop trusting the unverified state, re-queue the affected task against its original specification, and let either a fresh teammate or the sequential path pick it up under the lead's normal verification gate. Nothing invents a new task specification to route around a failure, and nothing proceeds on unverified work.

Two points are specific to this skill's degradation posture:

- A partial or runtime spawn failure (a teammate fails to start, or the teammate mode itself becomes unavailable mid-run) degrades the **whole run** to `../subagent-driven-development/SKILL.md`, dispatching the remaining tasks from the same decomposition as one-shot subagents. It never continues as a mixed team of some teammates and some ad hoc subagents; that would reintroduce the concurrent-writer and ownership risks the pre-flight check exists to prevent.
- A lead crash is unrecoverable: the lead holds the only authoritative verification and commit state, and teammates cannot resume a session on their own (per the dead-teammate law in `../../rules/common/teammates.md`). Only work that was already verified and committed by the lead before the crash is durable; anything still in flight must be re-queued from scratch in a new session.

## Final Feature-Level Review

Once every task in the decomposition has been drained through the serialised checkpoint queue, shut down every teammate before proceeding, per `../_shared/teammate-protocol.md`'s "Idle Handling": the final review runs against a settled working tree with no in-flight peer writers.

With teammates shut down, the lead runs SDD's Final Feature-Level Review section (`../subagent-driven-development/SKILL.md`) exactly as written, against the merged tree, not the per-task scoped runs. This step is not reimplemented here; it is the same gate, run once, against the same kind of range, regardless of whether the tasks that produced that range ran sequentially or across teammates.

## Integration

- **`../subagent-driven-development/SKILL.md`**: supplies the decomposition, the per-task code review and verification gate, the user checkpoint, and the final feature-level review that this skill reuses by reference; also supplies `reviewer-prompt.md` for the per-task review and is the fallback target when the capability gate fails or a run degrades.
- **`../dispatching-parallel-agents/SKILL.md`**: the stateless one-shot sibling for parallel work with no board and no persistence; not used by, and not a substitute for, this skill.
- **`../_shared/teammate-protocol.md`**: the operational procedure for lead-assignment, the pre-flight ownership check, the mailbox, completion handoff, idle handling, and failure recovery.
- **`../_shared/task-board.md`**: the board schema this skill's tasks are created and updated against.
- **`../_shared/subagent-dispatch.md`**: type and model selection for every teammate, unchanged from one-shot subagent dispatch.
- **`../../rules/common/teammates.md`** and **`../../rules/common/subagents.md`** Part A: the iron laws that bind this skill's every dispatch and every coordination step.
