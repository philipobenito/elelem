---
name: dispatching-parallel-agents
description: Provides safe concurrent dispatch for independent read-only investigations and implementation tasks in approved waves with an independent READY verdict or an explicitly authorised, planner-checked readiness-review skip.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Dispatching Parallel Agents

This skill is a reusable dispatch mechanism, not an independent implementation
pipeline or a way to bypass workflow phases. For implementation, the
`workflow-coordinator` owns execution and
`subagent-driven-development` consumes the approved wave schedule. See
`../workflow-coordinator/SKILL.md`, `../subagent-driven-development/SKILL.md`,
`../_shared/task-briefs.md`, `../_shared/wave-readiness.md`,
`../_shared/subagent-dispatch.md`, and `../../rules/common/subagents.md`.

## Permitted use

Parallel read-only investigations may run under a clearly bounded, authorised
scope when each investigation can proceed independently. They do not require
an implementation plan, but must not write files or state. For implementation,
parallel dispatch requires an approved plan and a schedule with an independent
`READY` verdict, or an explicitly user-authorised, scoped readiness-review skip
recorded as `SKIPPED`. In the skip case, the coordinator and executor must
confirm that the planner completed the schedule and all ownership, dependency,
resource, input and capacity checks. Apply the canonical gate in
`../_shared/wave-readiness.md` and
`../subagent-driven-development/SKILL.md`; do not create a separate readiness
rule here. Skipping wave planning is distinct: it permits only its one complete
task and never authorises improvised concurrency.

Before any dispatch, use the current shared dispatch procedure to select the
most specific suitable agent and verify concrete model identifiers and
routing. Never pass inherited session history as a substitute for a
self-contained prompt. Metadata does not switch models. For implementation,
workers use the bounded lower-cost capable tier, while independent reviews use
the workflow's required review tier.

## Independence and task contracts

For read-only investigations, establish that findings are independently
reachable and agents will not modify shared state. Shared stable reads are
permitted; disjoint reads are not a requirement. If one investigation's result
is needed to direct another, run them in dependency order instead.

For implementation tasks, use the approved wave schedule's exact briefs and
dependency graph. Same-wave writes must be disjoint, and no task may read a
file that another active task can change. Shared stable reads are allowed.
Account for formatters, generators, fixtures, build outputs, tests, ports,
databases, temporary files and global tools. Do not re-decompose architecture,
infer dependencies, or broaden a task during dispatch.

## Dispatch and reconciliation

1. Provide each agent a self-contained scope, necessary stable context,
   permitted reads and writes, side-effect/resource limits, and a structured
   return format. For implementation, the complete approved task brief is the
   contract. Agents do not write shared workflow state or perform Git
   operations. Worktrees and elevated privileges are prohibited.
2. Issue independent dispatches in the same turn, or use only a background
   mechanism whose availability and completion semantics are verified by the
   harness. Do not invent tools or call sequential dispatch concurrent.
3. Read each complete return and inspect actual changes for implementation
   work. Reconcile findings and changed paths. Do not treat convergence as
   proof, or accept a report without examining its evidence.
4. Task-local checks may run during other tasks only when all inputs are
   stable. Freeze the reviewed task's files and scope while checking. Defer
   checks that depend on other tasks until a safe wave barrier. Do not run broad
   checks while relevant writers remain active. Integrated completion requires
   the wave's required checks after its writers stop.

Workers report `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT` or `BLOCKED` as
defined by `../_shared/task-briefs.md`. Classify blocker scope under
`../_shared/subagent-dispatch.md`: pause affected work and its dependency
closure. A proven global safety failure stops all new dispatch. Unknown impact
pauses potentially affected work. If no safe boundary can be demonstrated,
provisionally pause all new dispatch until scope is established. Do not classify
that uncertainty as a proven global safety failure. Continue already-authorised
work only when independence and eligibility are demonstrated.
Cancel affected active work only if the harness supports safe cancellation;
otherwise let it settle without claiming it was cancelled or accepting stale
outputs. Preserve state and report the blocker. Do not silently retry with a
more expensive model, redesign, expand scope or apply worker changes manually.
In-scope review corrections are
delegated within their existing task boundaries; findings block affected task
acceptance, not eligible independent progress. Architectural gaps return to
planning and require renewed user approval where the design changes.

For implementation, this skill does not replace independent task review,
orchestrator verification, wave integration barriers, cumulative final review
or final verification. The executor and coordinator own those steps. Final
review must inspect tracked and untracked current changes; a committed range
alone is insufficient when work is uncommitted.
