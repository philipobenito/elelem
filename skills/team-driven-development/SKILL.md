---
name: team-driven-development
description: Implement an approved design in parallel across Agent Teams teammates, with the lead owning git, verification, and user checkpoints; degrades to subagent-driven-development when teammates are unavailable
---

# Team-Driven Development

Implement an approved design by decomposing it into tasks exactly as `../subagent-driven-development/SKILL.md` does, then executing the ready tasks in parallel across persistent teammates instead of one subagent at a time. The lead retains sole authority over git, verification, and the user checkpoints throughout.

## What This Is

This skill is a thin parallel wrapper over `../subagent-driven-development/SKILL.md` (SDD). It reuses SDD's task decomposition, per-task verification gate, user checkpoint, and final feature-level review **by reference**; it does not reimplement any of them. What it adds is the machinery specific to the persistent-peer model: spawning teammates, lead-assigning work across them, and draining completed work through a serialised checkpoint queue so that parallel implementation still yields the same sequence of user-facing decisions SDD would have produced one task at a time.

It is a **sibling** skill to SDD, not a mode of it: SDD is invoked directly for sequential work, and this skill is invoked directly when parallel teammates are the right fit. It is also not `../dispatching-parallel-agents/SKILL.md`: that skill is a stateless, one-shot fan-out for a single message with no board, no persistence, and no ongoing coordination. This skill runs a multi-task feature over a shared task board and mailbox for the life of the session.

The operational protocol for how teammates and the lead coordinate (lead-assign, pre-flight ownership check, the mailbox, completion handoff, idle handling, failure recovery) lives in `../_shared/teammate-protocol.md`; read it before running the procedure below. The iron laws that bind regardless of which skill is orchestrating (peer isolation, no concurrent writers, exclusive file ownership, git ownership, board-lag reconciliation, dead-teammate handling) live in `../../rules/common/teammates.md`, with the universal laws shared with one-shot subagents (worktree ban, privilege ban, git ownership, model identifiers) in Part A of `../../rules/common/subagents.md`. Neither file is restated here.

## Front-Door Capability Gate

Before spawning any teammate, and before doing anything else in this skill, probe whether Agent Teams is actually available in the current environment:

1. Confirm `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set in the environment.
2. Confirm teammate spawning actually works (a spawn attempt succeeds rather than erroring or silently no-op-ing).

If either check fails, announce a single-line fallback, for example: "Teammates unavailable, running sequentially via subagent-driven-development." Then hand off the approved design directly to `../subagent-driven-development/SKILL.md` and stop. Do not retry the capability probe and do not attempt a partial or mixed run.

This gate runs first, before decomposition, before any `TaskCreate` call, before any teammate is spawned. The task decomposition this skill uses is identical to SDD's and is path-agnostic (per `../_shared/teammate-protocol.md`'s "Failure Recovery" section), so falling back here costs throughput, not correctness: every task that would have run as a teammate assignment runs instead as a one-shot subagent dispatch against the same specification.

## When to Run

Use this skill only when all of the following hold:

- The work is a sustained feature, not a single quick fix, whose approved design decomposes (per SDD's Task Decomposition) into tasks that are mostly independent of each other, i.e. they touch disjoint file sets.
- Persistent peers coordinating over a shared board add real value, because there is enough ready, unblocked, file-disjoint work at once to justify more than one agent working the board concurrently.
- There is no shared mutable test/build state that concurrent teammates would contend for (see "Shared-Tree Execution Safety" below). A project where every task must exercise the same port, cache, test database, generated artefact, or lockfile is a poor candidate.

Route elsewhere when this does not hold: if the tasks are tightly coupled or must run in a strict, interdependent order, use `../subagent-driven-development/SKILL.md` directly. If the work is a single-message, stateless fan-out with zero shared files and no need for a persisted board across turns, use `../dispatching-parallel-agents/SKILL.md` instead. Routing between the orchestration skills is governed by `../../rules/common/skills-policy.md`.

## Decompose (Reuse SDD)

Run SDD's Triage and Path Selection and Task Decomposition sections unchanged: commit preference, `complexity-triage`, and, for COMPLEX work, the file structure, task granularity, and task ordering steps. If the classification comes back SIMPLE, hand off to `fast-path-implementation` exactly as SDD would and stop; parallel teammates add nothing to work that a single fast-path pass already covers.

Create the task board with `TaskCreate` following the field mapping in `../_shared/task-board.md` exactly. Do not invent additional fields or redefine any that file already covers.

Add the teammate-specific pre-flight before any teammate is spawned: the lead first records each task's exclusive `files` set in the lead-only `files` metadata key (per `../_shared/task-board.md`), then runs the pre-flight ownership check in `../_shared/teammate-protocol.md`, which asserts pairwise disjointness across the tasks about to go live and serialises any file-sharing tasks behind a `blockedBy` edge. Only once that check passes does the lead proceed to spawning; the check's own procedure is not restated here.

## Spawn and Assign

Compute the ready wavefront: the tasks that are unblocked (`blockedBy` empty or already verified, per `../_shared/task-board.md`) and do not conflict on files with any other task in that same wavefront. Spawn one teammate per ready task, capped at a small conservative default of about two concurrent teammates. Raise the cap only with a stated reason (for example, a wide, well-isolated wavefront and a project with no shared mutable test/build state); never raise it by default.

Select each teammate's agent type and model exactly as a one-shot subagent's would be selected, per the Subagent Type Selection and Model Selection procedures in `../_shared/subagent-dispatch.md` (tier table, resolution procedure, escalation triggers). Teammate selection does not get a different procedure; only the lifecycle (spawned once, kept alive across tasks) differs, per `../_shared/teammate-protocol.md`.

Assignment is lead-assign only: the lead sets each task's `owner` to the teammate it is handing the task to and delivers the assignment over SendMessage. See `../_shared/teammate-protocol.md`'s "Lead-Assigned Tasks, Never Self-Claim" section for why self-claiming is forbidden.

## Per-Task Verification (Lead Is Sole Authority)

A teammate reporting a task done, by SendMessage or by moving the board's native `status` to `completed`, is a claim pending lead verification, nothing more, per `../_shared/task-board.md`'s guiding invariant that the board is advisory and the lead is authoritative.

On a completion claim, the lead runs SDD's Verification Gate section (`../subagent-driven-development/SKILL.md`) unchanged, scoped to the task's declared `files` set. Only after that gate passes does the lead write the lead-only `verified` key via `TaskUpdate`, and, once committed, `commit_sha` and `base_sha` (per `../_shared/task-board.md`).

If a `TaskCompleted` hook is wired up, it is a trigger only, per `../_shared/teammate-protocol.md`'s "Completion Handoff and Verification Authority" section.

Before any feature-level completion claim, the lead runs the reconciliation sweep from that same section of `../_shared/teammate-protocol.md`, since board `status` lags behind reality and a teammate can fail to report at all.

## Serialised Checkpoint Queue

Implementation runs in parallel across teammates, but the lead drains completed-and-verified tasks through the same user-facing checkpoint SDD uses, one at a time, in a deterministic order: topological order by `blockedBy`, ties broken by the task's index in the original decomposition. Never drain in completion order; two teammates finishing in whichever order they happen to finish must not change what the user is asked, or when.

A task may be committed only once both of the following hold: its lead-only `verified` key is `true`, and every task it depends on (per `blockedBy`) has already been committed. A task that finishes early but has an uncommitted dependency waits in the queue; the lead does not jump ahead of dependency order to keep a fast teammate busy.

For each task drained from the queue, the lead runs SDD's User Checkpoint section (`../subagent-driven-development/SKILL.md`) unchanged, one task at a time. Auto-commit still commits at this serialised boundary, in board order, not as soon as a teammate reports done. The number and authority of human approval points is identical to sequential SDD: the commit preference asked once, a per-task checkpoint per drained task, and the final completion report. Parallel execution changes how the work gets produced; it does not add, remove, or reorder a single user-facing decision point.

A teammate's `plan_approval` exchange with the lead, when a teammate asks the lead a clarifying question mid-task, is a lead-internal exchange over the mailbox. It is the parallel analogue of an implementer subagent's clarifying question in SDD's per-task pipeline, answered by the lead per `../_shared/subagent-dispatch.md`'s "Answering Subagent Questions". It **MUST NOT** surface to the user as a second design approval, and it **MUST NOT** be used to expand the task's scope beyond what the decomposition and the one up-front design approval already cover.

## Shared-Tree Execution Safety

Teammates share one working tree with no per-teammate isolation, per `../../rules/common/teammates.md`'s "No Concurrent Writers to One File, Ever" section. Because of this, concurrent test and build runs from two teammates can contend for the same port, cache, test database, generated artefact, or shared lockfile, even when the two tasks' source files are themselves disjoint.

This widens the independence precondition beyond file disjointness alone: two tasks are only safe to run concurrently as teammates when they share no files **and** share no mutable test/build state. During implementation, teammates run only their own owned, scoped tests, the ones exercising the files their task declared ownership of, never the project's full suite. The authoritative test and build runs stay with the lead: the per-task scoped gate described above, and the single full-suite run against the merged tree as part of the final feature-level review. A project with unavoidable global test or build state (a single shared test database with no per-run isolation, a fixed port every integration test binds to) is a poor candidate for this skill; route it to `../subagent-driven-development/SKILL.md` instead, per the "When to Run" routing above.

## Failure and Degradation

Every failure mode reduces to the same shape described in `../_shared/teammate-protocol.md`'s "Failure Recovery": stop trusting the unverified state, re-queue the affected task against its original specification, and let either a fresh teammate or the sequential path pick it up under the lead's normal verification gate. Nothing invents a new task specification to route around a failure, and nothing proceeds on unverified work.

Two points are specific to this skill's degradation posture:

- A partial or runtime spawn failure (a teammate fails to start, or the teammate mode itself becomes unavailable mid-run) degrades the **whole run** to `../subagent-driven-development/SKILL.md`, dispatching the remaining tasks from the same decomposition as one-shot subagents. It never continues as a mixed team of some teammates and some ad hoc subagents; that would reintroduce the concurrent-writer and ownership risks the pre-flight check exists to prevent.
- A lead crash is unrecoverable: the lead holds the only authoritative verification and commit state, and teammates cannot resume a session on their own (per the dead-teammate law in `../../rules/common/teammates.md`). Only work that was already verified and committed by the lead before the crash is durable; anything still in flight must be re-queued from scratch in a new session.

## Final Feature-Level Review

Once every task in the decomposition has been drained through the serialised checkpoint queue, shut down every teammate before proceeding, per `../_shared/teammate-protocol.md`'s "Idle Handling": the final review runs against a settled working tree with no in-flight peer writers.

With teammates shut down, the lead runs SDD's Final Feature-Level Review section (`../subagent-driven-development/SKILL.md`) exactly as written, against the merged tree, not the per-task scoped runs. This step is not reimplemented here; it is the same gate, run once, against the same kind of range, regardless of whether the tasks that produced that range ran sequentially or across teammates.

## Integration

- **`../subagent-driven-development/SKILL.md`**: supplies the decomposition, the per-task verification gate, the user checkpoint, and the final feature-level review that this skill reuses by reference; also the fallback target when the capability gate fails or a run degrades.
- **`../dispatching-parallel-agents/SKILL.md`**: the stateless one-shot sibling for parallel work with no board and no persistence; not used by, and not a substitute for, this skill.
- **`../_shared/teammate-protocol.md`**: the operational procedure for lead-assignment, the pre-flight ownership check, the mailbox, completion handoff, idle handling, and failure recovery.
- **`../_shared/task-board.md`**: the board schema this skill's tasks are created and updated against.
- **`../_shared/subagent-dispatch.md`**: type and model selection for every teammate, unchanged from one-shot subagent dispatch.
- **`../../rules/common/teammates.md`** and **`../../rules/common/subagents.md`** Part A: the iron laws that bind this skill's every dispatch and every coordination step.
