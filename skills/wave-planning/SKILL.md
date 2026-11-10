---
name: wave-planning
description: "Decomposes an explicitly approved design into bounded tasks and reviews wave readiness by default before dispatch."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Wave Planning

Turn an explicitly approved design into complete, bounded tasks and safe
execution waves. Conversational planning and readiness review require
high-capability reasoning. Verify that the active primary-session model is
appropriate before conversational planning. Metadata does not switch the
active model. If unsuitable, stop and ask the user to switch models; do not
switch silently. Record the confirmed model and reuse that confirmation while
it remains active, without prompting again. Delegated preparation and reviewer
selection follow `../_shared/subagent-dispatch.md`: enumerate supported models
and verify explicit routing and required capability. Their policy is unchanged
by implementation configuration or its fallback; missing required preparation
or reviewer capability remains a blocker.

## Preconditions

Require an approved plan revision with its user approval source reference, or
an explicitly authorised complete task brief for the single-task skip path.
Check workflow baseline and approval validity using
`../_shared/workflow-artifacts.md`. Missing or stale inputs block planning.
Do not infer approval from a review verdict, silence, prior conversation or
implementation request.

## Decomposition

Map every approved requirement to one or more tasks, including integration,
tests, error cases and final verification requirements. Capture the complete
task contract using `../_shared/task-briefs.md`. Define task dependencies as a
directed acyclic graph; contracts and foundations precede consumers, and
integration is explicit work. One-task waves are valid. Do not impose a fixed
file-count limit or ask bounded workers to discover architecture.

Prefer cohesive bounded tasks that allow multiple genuine sequential RED/GREEN cycles
per worker. Do not manufacture splits or unapproved architecture to increase width.

For each task, name exact allowed writes and known formatter, generator, build
and test outputs; stable reads; interfaces and assumptions; dependencies;
acceptance criteria; verification commands; and specialist type with its own
rationale, independent of the model. Assign the lowest capable implementation tier
(`low`, `medium` or `high`) with a short task-specific rationale. Include resource
constraints such as ports, databases, fixtures,
temporary outputs and global tools. Same-wave writes must not overlap. A task
must not read a file another concurrent task can change. Shared stable reads
are allowed. Do not schedule tasks whose external resources conflict.

Require native resolution under `../_shared/subagent-dispatch.md` before first
implementation dispatch, including only its warned, checked current-model
configuration fallback.
Use `../_shared/task-briefs.md` for selection provenance and the coordinator's
retained actual task pin. Do not choose concrete models during decomposition,
infer reasoning effort from a tier, or change specialist to obtain a model.

Assign stable wave identifiers and cap concurrency at verified harness and
resource capacity. If capacity cannot be verified, report the limitation and
do not assume parallelism. Skipping wave planning permits one bounded,
complete, fully specified task only; do not improvise a wave plan or parallel
dispatch.

Place ready independent tasks in the earliest safe wave up to verified harness
and resource capacity. Record concrete reasons for serialisation, including
concurrency one, from dependencies, ownership, stable reads or resource limits.

## Readiness review and explicit skips

Wave planning remains required unless the user explicitly skips that phase.
Skipping only the independent readiness review does not skip wave planning.
The planner must still complete and validate the requirement map, task briefs,
dependency graph, ownership, stable inputs, resource model, capacity and
verification barriers described above and in `../_shared/wave-readiness.md`.
Missing or unknown critical inputs, unsafe ownership or resource conflicts, and
unverified capacity remain blockers, not matters a skip can waive.

By default, before any dispatch, obtain an independent high-capability review
of the full waves, task briefs, dependency graph and resource model. This review
is separate from design review and does not require another user prompt when it
only changes scheduling. Use `../_shared/wave-readiness.md`. If the user
explicitly authorised skipping only this readiness review, do not invoke a
reviewer or claim `READY`; record the review as `SKIPPED` with the authorisation,
scope, reason and consequence. The planning record must make clear that the
schedule is planner-completed but has no independent readiness verdict. A skip
does not approve a design or authorise a design change. If requirements,
architecture, contracts or external expectations are missing, stop and return
to planning and renewed user approval as needed. Do not turn an architectural
gap into an unapproved task.

Return the proposed `waves.md` contents and revision, the readiness record
(independent verdict `READY` or `GAPS`, or authorised review status
`SKIPPED`), and any scheduling-only adjustments to the coordinator for
persistence. The coordinator alone writes shared workflow files. `READY` may
only be recorded when returned by the independent reviewer; do not convert
planner checks or a skip into that verdict. Do not dispatch implementation
agents; the coordinator owns transitions and execution hand-off.

The readiness reviewer returns the verdict and findings to this Wave Planning
procedure for reconciliation. Return the reconciled schedule, readiness result
and blockers to the coordinator. This ends Wave Planning, not the overall
workflow. The coordinator records the schedule and next action in existing
`workflow.md` and proceeds to execution without routine prompting only after
the approved-plan, readiness or explicitly scoped skip, capability and safety
gates are satisfied. A `SKIPPED` review is not `READY`.
