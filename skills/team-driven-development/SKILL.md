---
name: team-driven-development
description: Implement an approved design in parallel across Agent Teams teammates, with the lead owning git, verification, and user checkpoints; degrades to subagent-driven-development when teammates are unavailable
---

# Team-Driven Development

Implement an approved design by decomposing it exactly as `../subagent-driven-development/SKILL.md` does, then executing ready tasks in parallel across persistent teammates, with the lead retaining sole authority over git, verification, and user checkpoints throughout.

This skill is a thin parallel wrapper over `../subagent-driven-development/SKILL.md` (SDD): it reuses SDD's task decomposition, per-task code review and verification gate, user checkpoint, and final feature-level review by reference, and adds only the machinery specific to the persistent-peer model, spawning teammates, lead-assigning work, and draining completed work through a serialised checkpoint queue. The operational protocol for how teammates and the lead coordinate (lead-assign, pre-flight ownership check, mailbox, completion handoff, idle handling, failure recovery) lives in `../_shared/teammate-protocol.md`; read it before running the procedure below. The iron laws that bind regardless of which skill is orchestrating (peer isolation, no concurrent writers, exclusive file ownership, board-lag reconciliation, dead-teammate handling) live in `../../rules/common/teammates.md`, with the universal laws shared with one-shot subagents (worktree ban, privilege ban, git ownership, model identifiers) in Part A of `../../rules/common/subagents.md`. Neither file is restated here.

## Process Overview

1. Probe the capability gate; fall back to `../subagent-driven-development/SKILL.md` if teammates are unavailable
2. Decompose the design exactly as SDD does, reused unchanged
3. Ask the concurrency preference once, after decomposition and the pre-flight check
4. Compute the tasks that are ready to run and spawn or reassign teammates up to the concurrency clamp
5. On each completion claim, the lead runs code review, then the verification gate
6. Drain verified tasks through the serialised checkpoint queue, one at a time
7. Shut down every teammate, then run the final feature-level review and report completion

## When to Run

This skill is a sibling to SDD, not a mode of it: SDD is invoked directly for sequential work, and this skill is invoked directly when parallel teammates are the right fit. It is also not `../dispatching-parallel-agents/SKILL.md`, which is a stateless, one-shot fan-out for a single message with no board, no persistence, and no ongoing coordination; this skill runs a multi-task feature over a shared task board and mailbox for the life of the session.

Use this skill only when all of the following hold:

- The work is a sustained feature whose approved design decomposes (per SDD's Task Decomposition) into tasks that are mostly independent, touching disjoint file sets.
- Persistent peers coordinating over a shared board add real value, because enough ready, unblocked, file-disjoint work exists at once to justify more than one agent on the board concurrently.
- There is no shared mutable test/build state that concurrent teammates would contend for (see "Shared-Tree Execution Safety" below). A project where every task exercises the same such state is a poor candidate.

Route elsewhere otherwise: tightly coupled or strictly ordered work goes to `../subagent-driven-development/SKILL.md`; a single-message, stateless fan-out with zero shared files and no persisted board goes to `../dispatching-parallel-agents/SKILL.md`. Routing between the orchestration skills is governed by `../../rules/common/skills-policy.md`.

## Capability Gate

Before doing anything else, probe whether Agent Teams is actually available:

1. Confirm `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set.
2. Confirm a real spawn attempt succeeds.

If either check fails, announce a single-line fallback, for example "Teammates unavailable, running sequentially via subagent-driven-development.", hand off the approved design to `../subagent-driven-development/SKILL.md`, and stop. Do not retry the probe, and do not attempt a partial or mixed run.

This gate runs first, before decomposition, before any `TaskCreate` call, and before any teammate is spawned. Task decomposition is identical to SDD's and is path-agnostic, so falling back here costs throughput, not correctness: every task that would have run as a teammate assignment instead runs as a one-shot subagent dispatch against the same specification.

## Decompose (Reuse SDD)

Run SDD's Triage and Path Selection, then its Task Decomposition, unchanged: commit preference, `complexity-triage`, and, for COMPLEX work, file structure, task granularity, and task ordering. If the classification is SIMPLE, hand off to `fast-path-implementation` exactly as SDD would, and stop.

Create the board with `TaskCreate` per `../_shared/task-board.md`; do not invent additional fields or redefine any that file already covers.

Before any teammate is spawned, run the teammate-specific pre-flight: the lead first records each task's exclusive `files` set in the lead-only `files` metadata key, then runs the pre-flight ownership check in `../_shared/teammate-protocol.md`, which asserts pairwise file-disjointness across the tasks about to go live and serialises any file-sharing tasks behind a `blockedBy` edge. Only once that check passes does the lead proceed to spawning.

## Concurrency Preference

After decomposition classifies the work COMPLEX and the pre-flight check passes, and before spawning any teammate, ask the user once how many implementer teammates may run concurrently, via `AskUserQuestion`. This is separate from, and asked after, SDD's reused commit-preference question, and is never reached on a SIMPLE classification. The choice is session-wide: set once, re-applied as more tasks become ready, never re-asked each time the set of ready tasks changes.

| Option                          | Meaning                                                                                                                     |
|---------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| Maximum available (recommended) | One teammate per ready, file-disjoint task, up to the number of ready, file-disjoint tasks. Fastest; heaviest resource use. |
| Up to three at once             | At most three concurrent implementers, even with more ready work available. A middle ground for a first run.                |
| Up to two at once               | At most two concurrent implementers. Slower, and easier to follow along with.                                               |
| One at a time                   | A single teammate at a time. Close to running SDD sequentially; prefer SDD directly for a permanent choice.                 |

Each option is a ceiling, not a guarantee: the live count of implementer teammates never exceeds `min(preference, number of ready, file-disjoint tasks)` (defined fully in "Spawn and Assign"). The per-task reviewer is a one-shot subagent and never counts against this ceiling. "Maximum available" speeds how quickly tasks reach the completed-claim state, not end-to-end wall-clock; the drain stays serial regardless of concurrency.

## Spawn and Assign

The tasks that are ready to run are those unblocked per `blockedBy` and file-disjoint from every other ready task. The number of ready, file-disjoint tasks is the hard upper bound on concurrency: there can never be more live implementer teammates than ready, unblocked, file-disjoint tasks. Within that bound, live implementer teammates equal `min(concurrency preference, number of ready, file-disjoint tasks)`.

The clamp counts live teammates, not how many are started each time tasks unblock. Teammates persist as tasks unblock and complete: an idle teammate whose task is verified is reassigned the next ready task rather than respawned, and a new teammate is spawned only when a ready task has no free live teammate to take it and the live count is still below the clamp.

Select each teammate's agent type and model exactly as a one-shot subagent's, per `../_shared/subagent-dispatch.md`; only the lifecycle differs (spawned once, kept alive across tasks), per `../_shared/teammate-protocol.md`.

Assignment is lead-assign only: the lead sets each task's `owner` and delivers the assignment over SendMessage. Self-claiming is forbidden; see `../_shared/teammate-protocol.md`.

## Per-Task Review and Verification (Lead Is Sole Authority)

A teammate reporting a task done, whether via SendMessage or by moving board `status` to `completed`, is a claim pending lead review and verification, nothing more, per `../_shared/task-board.md`'s invariant that the board is advisory and the lead is authoritative. On each claim the lead runs the same two gates SDD runs, in the same order.

**Code review (advisory).** The lead dispatches a one-shot reviewer subagent against `../subagent-driven-development/reviewer-prompt.md`, type and model selected per `../_shared/subagent-dispatch.md`, scoped to the lead-captured working-tree diff of the task's declared `files`. This reviewer is a one-shot: it owns no files, holds no board state, is never assigned board work, and needs no shutdown before the final review. Its verdict is advisory and never a substitute for the verification gate. On rejection, the lead relays findings over SendMessage to the same owning teammate (owner and files unchanged) to fix and re-report; only if that teammate has died does it fall to the re-queue in `../_shared/teammate-protocol.md`'s Failure Recovery. Every fix, from either gate, re-enters at code review: unreviewed code must never reach the verification gate.

**Verification gate (authoritative).** Only after the reviewer approves does the lead run SDD's Verification Gate, scoped to the task's `files`. If the working tree has drifted from the diff the reviewer saw, the approval is void and the lead re-reviews before verifying. Only after the gate passes does the lead write the lead-only `verified` key via `TaskUpdate`, and, once committed, `commit_sha` for this task and `base_sha` for the next (per `../_shared/task-board.md`).

Review state is not a board field: it is the seam between `status: completed` and the lead-only `verified` key. A completed-but-unverified task still owes review and the gate, and a task is drained only once `verified` is written.

One-open-task rule: the lead does not assign a teammate its next task until the current task's `verified` key is written. This overrides step 2 of Idle Handling in `../_shared/teammate-protocol.md` for a teammate whose own latest claim is not yet verified; it buys a clean review-fix round-trip on the same teammate while it still owns the files, at the cost of that teammate idling through its review-and-gate window.

If a `TaskCompleted` hook is wired, it is a trigger only, per `../_shared/teammate-protocol.md`. Before any feature-level completion claim, the lead runs the reconciliation sweep from that same section, since board status lags reality.

## Serialised Checkpoint Queue

Implementation runs in parallel, but the lead drains verified tasks through SDD's user checkpoint one at a time, in deterministic order: topological by `blockedBy`, ties broken by index in the original decomposition. Never drain in completion order.

A task may be committed only once its `verified` key is true and every `blockedBy` dependency has already been committed; a task that finishes early with an uncommitted dependency waits.

For each drained task, run SDD's User Checkpoint unchanged, one at a time. Auto-commit commits at this serialised boundary, in board order, not when a teammate reports done. The number and authority of human approval points equal sequential SDD (commit preference once, a per-task checkpoint per drained task, the final report); parallel execution adds, removes, or reorders no user-facing decision.

A teammate's mid-task clarifying-question exchange with the lead is lead-internal, over the mailbox, the parallel analogue of an SDD implementer's clarifying question, answered per `../_shared/subagent-dispatch.md`. It **MUST NOT** surface to the user as a second design approval, and **MUST NOT** expand scope beyond the one up-front design approval.

## Shared-Tree Execution Safety

Teammates share one working tree with no per-teammate isolation, per `../../rules/common/teammates.md`. Concurrent test and build runs can therefore contend for the same port, cache, test database, generated artefact, or lockfile, even when the two tasks' source files are disjoint.

This widens the independence precondition: two tasks are safe to run concurrently only if they share no files and no mutable test/build state. During implementation, teammates run only their own owned, scoped tests, never the full suite; the authoritative test and build runs stay with the lead, the per-task scoped gate above and the single full-suite run against the merged tree in the final review. A project with unavoidable global test or build state is a poor candidate for this skill; route it to `../subagent-driven-development/SKILL.md` instead.

## Failure and Degradation

Every failure reduces to the shape in `../_shared/teammate-protocol.md`'s Failure Recovery: stop trusting unverified state, re-queue the task against its original spec, and let a fresh teammate or the sequential path pick it up under the lead's gate. Never invent a new spec to route around a failure, and never proceed on unverified work.

Two points are specific to this skill:

- A partial or runtime spawn failure degrades the whole run to `../subagent-driven-development/SKILL.md`, dispatching the remaining tasks from the same decomposition as one-shot subagents. It never continues as a mixed team of teammates and ad hoc subagents; that would reintroduce the concurrent-writer and ownership risks the pre-flight exists to prevent.
- A lead crash is unrecoverable: the lead holds the only authoritative verification and commit state, and teammates cannot resume a session on their own, per the dead-teammate law in `../../rules/common/teammates.md`. Only work verified and committed before the crash is durable.

## Final Feature-Level Review

Once every task is drained, shut down every teammate first, per `../_shared/teammate-protocol.md`'s Idle Handling, so the review runs against a settled tree with no in-flight writers. The lead then runs SDD's Final Feature-Level Review unchanged, against the merged tree, not the per-task scoped runs. This step is not reimplemented here.

## Common Mistakes

| Mistake                                                                              | Why it is wrong                                                                                |
|--------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Running a mixed team of teammates and ad hoc subagents after a spawn failure         | Reintroduces the concurrent-writer and ownership risks the pre-flight check exists to prevent. |
| Draining tasks in completion order instead of topological and index order            | Two teammates finishing in any order must not change what the user is asked, or when.          |
| Assigning a teammate its next task before its current task's verified key is written | The teammate could drift the diff the reviewer already approved.                               |
| A teammate self-claiming a task instead of waiting for lead-assignment               | Assignment is lead-assign only; self-claiming is forbidden.                                    |
| Surfacing a teammate's mid-task clarifying question as a second design approval      | It is a lead-internal exchange, not a new user-facing decision point.                          |
| Running the full test suite from a teammate instead of its owned, scoped tests       | The authoritative full-suite run stays with the lead, in the final review.                     |
| Skipping or retrying the capability gate probe                                       | The gate runs first and once; a partial or mixed run is never permitted.                       |
| Treating board status: completed as verified                                         | The board is advisory; only the lead-only verified key means the task is drained.              |

## Integration

- **`../subagent-driven-development/SKILL.md`**: supplies the decomposition, the per-task code review and verification gate, the user checkpoint, and the final feature-level review this skill reuses by reference; also supplies `reviewer-prompt.md` and is the fallback target when the capability gate fails or a run degrades.
- **`../dispatching-parallel-agents/SKILL.md`**: the stateless one-shot sibling for parallel work with no board and no persistence; not used by, and not a substitute for, this skill.
- **`../_shared/teammate-protocol.md`**: the operational procedure for lead-assignment, the pre-flight ownership check, the mailbox, completion handoff, idle handling, and failure recovery.
- **`../_shared/task-board.md`**: the board schema this skill's tasks are created and updated against.
- **`../_shared/subagent-dispatch.md`**: type and model selection for every teammate, unchanged from one-shot subagent dispatch.
- **`../../rules/common/teammates.md`** and **`../../rules/common/subagents.md`** Part A: the iron laws that bind this skill's every dispatch and every coordination step.
