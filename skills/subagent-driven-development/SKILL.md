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
criteria, verification commands, independent specialist type and rationale, and
lowest-capable implementation tier (`low`, `medium` or `high`) with rationale.
Same-wave tasks must have disjoint writes and must not consume another task's changing
files or results. Stable shared reads are allowed. Respect resource constraints
and verified harness concurrency. Use native resolution under
`../_shared/subagent-dispatch.md` for first implementation dispatch, with only its
warned, checked current-model configuration fallback. The coordinator records
the actual task pin and complete `../_shared/task-briefs.md` provenance before
dispatch. Do not independently choose another concrete model or change specialist
to obtain a model. Preparation and reviewer model policies are unchanged.

For in-scope corrections, consume the retained actual task pin, including fallback,
with fresh enumeration, availability, capability, routing and configuration-drift
checks under the shared procedure. Do not reselect the then-current-session model.
Relevant drift or any workflow model change requires explicit authorisation and
a revised recorded pin. Use the actual native schema to route the independent
specialist and retained selection explicitly, not omitted-model inheritance or
invented fields. Runtime retries and model switches by external plugins remain
outside this workflow-selection policy; do not disable or block solely because
of them or claim pins prevent runtime changes. Requested selection is not
observed execution evidence; worker self-report is not routing proof.

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

## Touched-path history

Ordinary implementation tasks return changed paths and rename mappings, not
whole-file test inventories. The coordinator accumulates actual touched-path
history across tasks and reviewer corrections, including reverted edits and
renames, against the immutable workflow baseline and task checkpoints. Task
review and task verification have no pruning-audit prerequisite. Defer the one
whole-file inventory and audit to the final task below.

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
retain independent re-review and fresh task checks after the batch. Correction
dispatch reuses the retained implementation pin above, including fallback; it
does not restart model selection.

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
requires supplying existing, authorised context, not guessing. Apply blocker
scopes in `../_shared/subagent-dispatch.md`: pause the affected task and
transitive dependants, affected shared-contract/resource consumers and
downstream dependants. A proven global safety failure stops all new dispatch.
Unknown impact pauses potentially affected work. If no safe boundary can be
demonstrated, provisionally pause all new dispatch until scope is established.
Do not classify that uncertainty as a proven global safety failure. Continue
only already-authorised work whose independence and eligibility are demonstrated.
A review finding blocks acceptance and completion of its affected task, not
eligible independent progress. Cancel affected active work only if safe cancellation is supported;
otherwise allow it to settle without claiming it was cancelled or accepting
stale outputs. Preserve workflow state and report the blocker to the user. Do
not silently retry at a higher-cost model, redesign, expand scope, or patch
worker code in the orchestrator context. If the plan or architecture is
inadequate, return to the coordinator and planning for user-authorised
resolution.

## Final feature review and verification

After all requested tasks, task reviews/checks and integration barriers are resolved, invoke
`requesting-code-review` for the cumulative, current uncommitted changes,
including tracked and untracked files, by default. If the user explicitly
skipped final review, record that scoped skip and do not imply a review verdict
or approval. The review must inspect actual changes; `BASE..HEAD` alone is
insufficient when work is uncommitted. Resolve critical and important findings
by delegating within approved task boundaries and repeat the relevant review
and checks. Record minor findings for the user.

At this consumer boundary, map to `PASS` only an actually performed favourable
cumulative review with Status `REVIEWED` and Ready to merge `Yes`, no unresolved
Critical or Important findings, and evidence for the exact current cumulative
revision. Retain the raw reviewer result and reviewer provenance, including
reviewer identity, session/source reference and reviewed revision. `REVIEWED`
alone is not sufficient. Adverse results, `With fixes`, `No`, `BLOCKED` and
`SKIPPED`, plus stale or missing results, never map to `PASS`. Missing provenance
or revision evidence also blocks that mapping. A skipped cumulative review needs
explicit sequencing authorisation to enter pruning without inventing `PASS`.

After the cumulative final reviewer result is validated as `PASS`, invoke `test-pruning`
through `{{INVOKE_SKILL_TOOL}}` as one separate final review-phase task. User
approval is not this trigger. Follow `../test-pruning/SKILL.md` and
`../_shared/test-pruning.md`; the coordinator alone owns audit dispatch and
state, with no nested audit dispatch. Freeze the union inventory once, run
stable pre-prune checks, obtain the independent audit, assign supported edits
to a bounded worker, and run post-prune checks. Empty scope is `NOT APPLICABLE`.
If final review was skipped, require explicit sequencing authorisation under
the helper before pruning; a skip is not a `PASS`. A pruning skip permits no
pruning edits and waives neither review nor verification.

Only actual pruning edits require an independent bounded pruning-delta review
of those edits and affected coverage. A no-change audit needs none. Resolve
in-scope findings within that delta; substantive corrections return to the
proper implementation/review boundary. Do not automatically repeat cumulative
review or restart pruning. Use targeted invalidation and evidence recovery
under the helper when necessary, not a review-prune loop.

Run final verification after the last pruning edit and review correction.
Invoke `verification-before-completion` against the full current state by
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

### Executor handoff

Workers return reports and evidence through the executor. Reconcile each
worker's scope, outcome, changed paths, checks, questions and blockers against
its brief; workers do not hand workflow state directly to the coordinator.
The executor validates the returned scope, outcome and evidence before
continuing safe task-local checks with stable inputs while other workers run.
Respect task dependencies and wave barriers, required independent reviews and
verification before returning the executor's reconciled result to the active
coordinator. A worker's "stop after handoff" ends that worker task, not the
overall workflow. The coordinator validates the executor handoff, records the
result and next action in existing `workflow.md`, then proceeds without routine
prompting when no gate or blocker requires a pause.

## Prompt templates

- `./implementer-prompt.md`: bounded worker prompt for approved tasks.
- `./reviewer-prompt.md`: independent per-task review prompt.
- `../fast-path-implementation/fast-path-reviewer-prompt.md`: compatibility
  template for a coordinator-scheduled single task.
