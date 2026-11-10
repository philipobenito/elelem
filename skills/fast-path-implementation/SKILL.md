---
name: fast-path-implementation
description: Compatibility entry point for one bounded task explicitly scheduled by the workflow coordinator in an approved wave with an independent READY verdict or an explicitly authorised, planner-checked readiness-review skip; reuses standard execution gates and scoped skips.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Fast-Path Implementation

This skill does not own a separate execution pipeline and cannot bypass
workflow phases, reviews or checks. It is only a compatibility entry point for
one bounded task explicitly scheduled by `workflow-coordinator` within an
approved plan and a wave with an independent `READY` verdict, or an explicitly
user-authorised readiness-review skip recorded as `SKIPPED`. For the skip, the
coordinator and executor must confirm the planner completed the schedule and
all ownership, dependency, resource, input and capacity checks. Use the
canonical gate in `../_shared/wave-readiness.md` and
`../subagent-driven-development/SKILL.md`, rather than duplicating its rules
here. Skipping wave planning is distinct and permits only its single complete
task. If no active valid workflow exists, invoke `workflow-coordinator` through
`{{INVOKE_SKILL_TOOL}}`.

Before execution, apply `../_shared/phase-evidence.md` to ordered upstream
evidence. Return upstream gaps to the coordinator; do not reconstruct missing
procedures inline or treat a request to implement as a phase skip.

Complexity triage is advisory. A SIMPLE classification does not authorise this
skill, skip a phase, change the approved schedule or reduce review and
verification requirements. The user must explicitly authorise any scoped phase
skip, and the coordinator records its scope, reason and consequence. Never
infer a skip from task size.

For the scheduled task, use the standard bounded worker brief and dispatch
procedure in `../subagent-driven-development/SKILL.md`,
`../subagent-driven-development/implementer-prompt.md`,
`../_shared/task-briefs.md` and `../_shared/subagent-dispatch.md`. Honour exact
write paths, stable reads, dependencies, resources and worker Git restrictions.
Do not improvise batch scope or parallel dispatch.

By default, run the same independent task review using
`./fast-path-reviewer-prompt.md`, fresh orchestrator verification, any required
integration barrier, then final cumulative review. Only after cumulative final
reviewer `PASS`, run the coordinator-owned separate final test-pruning task,
bounded independent pruning-delta review only for actual pruning edits, and
final verification after the last edit and review correction, as the standard
executor. Honour only explicitly authorised, scoped review or check
skips recorded by the coordinator. For a skipped task review, do not invoke the
reviewer prompt or fabricate a verdict. Record skipped reviews and checks as
`SKIPPED`, with their authorisation and consequence; a skipped review is not
approval, and skipped checks are not passed and remain unverified. Run all
applicable gates outside the skipped scope. Resolve Critical and Important
findings by delegating within the approved task boundaries; an architectural
gap returns to planning. A worker return or reviewer verdict alone is not
verified or integrated completion. Read actual changes and evidence; do not
patch worker output manually.

The coordinator owns progress, workflow state, Git preference and phase
transitions. Do not ask for routine task or commit approvals. The default is to
leave changes uncommitted. If the user's recorded preference is ask-before-
commit, defer commits and report them rather than interrupting the task flow.
Never push. Follow the standard blocker policy: stop new dispatch globally,
cancel active work only when safe cancellation is supported, otherwise let it
settle, preserve state and report the blocker.

## Reviewer prompt

Use `./fast-path-reviewer-prompt.md` as a concise single-task review template.
It does not change the standard review severity threshold or replace final
feature-level review and verification.
