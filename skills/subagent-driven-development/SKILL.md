---
name: subagent-driven-development
description: Executes approved workflow waves using bounded specialist workers, default independent reviews and verification barriers.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Subagent-Driven Development

Execute an approved plan through complete, safe waves. By default, waves have
an independent `READY` review before dispatch. This skill is an
execution phase, not an architecture or decomposition phase. The workflow
coordinator owns phase transitions and shared workflow state. See
`../workflow-coordinator/SKILL.md`, `../_shared/workflow-artifacts.md`,
`../_shared/task-briefs.md`, `../_shared/wave-readiness.md`,
`../_shared/subagent-dispatch.md`, and `../../rules/common/subagents.md`.

## Entry and prerequisites

Before dispatch or reuse, apply `../_shared/phase-evidence.md` to ordered
upstream evidence. Return upstream gaps to the coordinator; approval and a
readiness label cannot repair omitted procedures or authorise fake backfill.

If there is no active valid workflow, invoke `workflow-coordinator` through
`{{INVOKE_SKILL_TOOL}}`; do not start an independent execution pipeline. Require
an explicitly user-approved plan revision and completed wave planning. By
default, require an independent `READY` verdict. If the user explicitly
authorised skipping only the readiness review, accept the recorded scoped skip
instead, but independently confirm that the persisted schedule and task briefs
are complete and satisfy the wave ownership, dependency, resource, input and
capacity constraints in `../_shared/wave-readiness.md`. A skipped review is not
a `READY` verdict. Confirm approval and the applicable planning record remain
valid against the recorded baseline. Never infer design approval from a review
verdict, skip or silence.

If the user explicitly skipped wave planning, accept only one complete,
fully specified task brief with exact scope and inputs. Do not invent tasks,
decompose architecture, or improvise concurrency. An explicit skip of any other
phase must have recorded scope, reason and consequence. A skipped review is not
approval; skipped checks must never be described as passed or verified. A
skip-authorised task may be accepted for explicitly authorised downstream work
without being marked verified, but only after checking that its outputs are
safe and sufficient for that dependent task. A review, check or wave skip does
not waive dependent safety requirements automatically; unknown critical inputs
block dispatch.

All workflow phases run by default. Never infer that a small task authorises
skipping a phase. Complexity triage may advise task sizing or classification,
but it never routes execution or bypasses a phase. `fast-path-implementation`
is only a compatibility entry point for a single task explicitly scheduled by
the coordinator, and follows this executor's reviews and checks.

Ask once for Git preference only if the coordinator has not recorded it. The
default is to leave changes uncommitted. Do not ask for routine task or wave
approvals or commit prompts. If the recorded preference is ask-before-commit,
defer commits and report that preference rather than interrupting execution.
Only the coordinator may commit, and only according to the recorded preference
after the relevant checks; workers do not perform Git operations. Never push.

## Consume approved waves

Use the persisted task briefs and dependency graph as the execution contract;
do not recreate or broaden them. Each brief defines exact allowed writes,
stable reads, prohibited concurrent reads, dependencies, resources, acceptance
criteria, verification commands, specialist type and model tier. Same-wave
tasks must have disjoint writes and must not consume another task's changing
files or results. Stable shared reads are allowed. Respect resource constraints
and verified harness concurrency. Invoke the dispatch procedure in
`../_shared/subagent-dispatch.md` for each worker, including concrete model
identifiers confirmed by the harness. Use bounded lower-cost capable specialist
workers; do not invent model identifiers or infer routing from metadata.

Send each worker only its self-contained brief and required source context. Do
not pass session history as a substitute. Specify its exact writes, stable
reads, side effects and resource limits. Workers cannot modify shared workflow
state, commit, push, create branches, use worktrees or use elevated privileges.
Workers return structured results using `../_shared/task-briefs.md`.

Dispatch independent tasks in a wave in the same turn, or use only a background
mechanism whose availability and completion semantics are verified by the
harness. Do not invent a dispatch tool or assume that sequential calls are
concurrent. If concurrency is unavailable, report the limitation and follow
the approved schedule only where serial execution is valid; do not silently
substitute a different plan.

Before the first RED step, the coordinator records or validates the immutable
task-start HEAD and relevant dirty or untracked contents in `workflow.md`.
Preserve that baseline separately from later task and audit snapshots.

## Test pruning audit and application

The coordinator owns and executes one cumulative test-pruning audit within the
executor phase after implementation, task reviews and wave barriers, before
final cumulative review and verification.
The union of actual test-bearing paths changed by tasks and corrections defines
its scope. Follow `../_shared/test-pruning.md` for full inventory, safety gates,
source retrieval, audit evidence, recovery, and invalidation. An empty scope is
`NOT APPLICABLE`; a TDD-only skip does not skip the audit.

After relevant writers stop, the coordinator freezes inputs, runs pre-prune
checks and alone dispatches the independent read-only auditor. The coordinator
records exact source and recovery context and assigns supported removal or
restoration to a bounded implementation worker. After it stops, inspect the
diff, run post-prune checks, and record the accepted snapshot. No nested audit
dispatch or worker self-audit is allowed. Task review and checks proceed before
this audit and do not claim it occurred. The executor returns current audit,
final review and verification evidence to the coordinator for recording or
reuse; do not automatically repeat a gate with matching fresh evidence.

## Task lifecycle and barriers

For every task, independently review the actual changes against its brief and
quality requirements by default. Use `./reviewer-prompt.md` and the current
dispatch procedure. If the user explicitly skipped a task review, do not
dispatch a reviewer for that scope; record the review as `SKIPPED`, including
its authorisation, scope and consequence. Do not imply a review verdict or
approval. Otherwise, review outcomes are not user approval. Critical and
important issues must be resolved before completion; delegate in-scope
corrections to a worker within the same boundaries, then re-review. A missing
requirement, contract or architecture decision is a blocker to return to
planning, not a prompt to silently redesign.

Batch related in-scope review corrections within the approved task boundaries;
retain independent re-review and fresh task checks after the batch.

After review or its recorded skip, the orchestrator reads the actual changed
paths and evidence, then runs fresh task verification by default. Do not trust
a worker's report alone. Honour an explicitly authorised verification skip only
for its recorded scope, and record that verification as `SKIPPED` with its
authorisation and consequence. Run all other applicable checks; a scoped skip
does not waive checks outside its scope. Task-local checks may run while other
tasks are active only when every input is known stable. Freeze the task's scope
and files while checking them. Do not run broad checks while any relevant
writer remains active.
Keep task lifecycle status separate from review and verification results. A task
with an authorised skipped review or check may be accepted for explicitly
authorised downstream work, but must not be labelled `verified`; it becomes
`integrated` only after the required verification and wave integration checks
actually run and pass. Never record a skipped check as passed.

Report verified task progress as it becomes available, without routine approval
prompts. If a check requires outputs from other tasks, defer it explicitly until
the safe wave barrier; do not label it passed early. Complete the wave's
integration checks after all its writers stop. Do not dispatch a dependent wave
until its prerequisites and required barrier checks are satisfied. Preserve
the coordinator's task status and evidence records; workers do not write them.

## TDD and worker evidence

For code that changes observable behaviour, require the TDD cycle and specific
RED-to-GREEN evidence described in `../test-driven-development/SKILL.md` and
`./implementer-prompt.md` by default. Require a genuine failing test before
production code, its expected failure, and a fresh passing run afterward. Do
not accept "tests pass" as RED evidence. Honour an explicit, scoped user TDD
skip, record its scope and consequence, and report the TDD evidence as skipped,
not passed. The TDD skip does not waive other checks outside its scope.
User-authorised documentation or configuration work may use the
explicit non-code exception in the task brief; do not invent tests or fabricate
TDD evidence for it. Pure refactors retain existing checks unless explicitly
skipped by the user.

## Blockers and scope control

Workers report `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT` or `BLOCKED`. Read
the actual changes and verify evidence for every returned result. `NEEDS_CONTEXT`
requires supplying existing, authorised context, not guessing. Any real blocker
stops all new dispatch globally. Cancel active work only if safe cancellation is
supported; otherwise allow it to settle and do not claim it was cancelled.
Preserve workflow state and report the blocker to the user. Do not silently
retry at a higher-cost model, redesign, expand scope, or patch worker code in
the orchestrator context. If the plan or architecture is inadequate, return to
the coordinator and planning for user-authorised resolution.

## Final feature review and verification

After the cumulative audit and all requested tasks and integration barriers are resolved, invoke
`requesting-code-review` for the cumulative, current uncommitted changes,
including tracked and untracked files, by default. If the user explicitly
skipped final review, record that scoped skip and do not imply a review verdict
or approval. The review must inspect actual changes; `BASE..HEAD` alone is
insufficient when work is uncommitted. Resolve critical and important findings
by delegating within approved task boundaries and repeat the relevant review
and checks. If later corrections affect audit evidence, refresh the inventory,
perform targeted independent rechecks and repeat affected review and checks
before final verification. Record minor findings for the user.

The final cumulative review must inspect audit evidence and the actual current
diff including pruning, using the final audit evidence review criteria in the
reviewer prompt. Task review is separate and must not claim a deferred audit.

For the final review dispatch, supply the audit record, approved scope, exact
audit skip provenance or `none`, the `./reviewer-prompt.md` final audit evidence
review criteria, and the actual post-prune diff including tracked and untracked
changes. Populate `requesting-code-review`'s DESCRIPTION with these inputs and
an explicit instruction to inspect the audit evidence against the supplied
criteria. Include the current audit status, including `NOT APPLICABLE` or an
authorised `SKIPPED` scope where applicable. Do not dispatch with missing or
ambiguous required inputs; report a blocker instead. The final review consumes
these inputs in addition to the normal review boundaries, not instead of them.

Then invoke `verification-before-completion` against the full current state by
default. Honour an explicitly authorised final verification skip only for its
recorded scope, and record it as `SKIPPED`; do not imply that checks passed or
verification occurred. Run all other applicable checks and report the skipped
scope as unverified. Do not label the full workflow verified while a required
final check is skipped. Run the project's required complete checks only after
relevant writers stop. Keep final review, final verification and any explicitly
skipped gates distinct. Report task and wave status, actual changed paths,
review findings, commands and outputs,
TDD evidence where applicable, deferred checks, and any authorised skips and
their consequences. Follow the coordinator's clean-up phase separately.

Persisted workflow state is canonical. When the harness supports it, the
coordinator mirrors task progress through `{{TASK_TRACKER_TOOL}}`; the mirror is
for user-visible progress only and never becomes a separate source of truth.
Do not invent tracker parameters or let workers update the tracker.

## Prompt templates

- `./implementer-prompt.md`: bounded worker prompt for approved tasks.
- `./reviewer-prompt.md`: independent per-task review prompt.
- `../fast-path-implementation/fast-path-reviewer-prompt.md`: compatibility
  template for a coordinator-scheduled single task.
