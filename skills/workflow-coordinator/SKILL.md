---
name: workflow-coordinator
description: "Coordinates research, approved design, wave execution, recovery and clean-up across workflow phase skills."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Workflow Coordinator

Owns workflow transitions and shared workflow state. Detailed research, design,
review, planning and execution procedures belong to their phase skills. Model
metadata expresses a capability target; it does not switch the active model.
Phase skills return findings and proposed content; the coordinator alone
persists shared workflow files. The intention is to keep context under control
by using workflow files and clean up between transistions.

## Entry and transitions

Apply `../_shared/phase-evidence.md` at entry, transitions, handover, resume,
reuse and execution. Validate ordered upstream evidence before advancing;
recover unsupported phases through that contract, not retrospective labels.
Enter before implementation-oriented proposals; Research hypotheses and
options are permitted without treating them as a proposed implementation plan.

Start a workflow from a direct request or resume an existing workflow. Use
`{{ASK_USER_QUESTION_TOOL}}` to resolve the task identity and any user choices.
Before dispatching an agent, read `../_shared/subagent-dispatch.md` and verify
the required model and routing capability as described there.

Before conversational Research or Planning, verify that the active primary
session model has the required high-capability reasoning. Skill metadata does
not switch that model. If it is not suitable, stop and ask the user to switch
models; do not switch silently. Record the confirmed model and reuse that
confirmation while it remains active, without prompting again. Verify explicit
dispatch models separately using the dispatch procedure.

The normal order is listed below. Invoke every phase through
`{{INVOKE_SKILL_TOOL}}`, using the skill name. The paths below identify
references and are not a substitute for invoking the skill through the
harness:

1. Research with the `research` skill (`../research/SKILL.md`).
2. Planning through the selected existing `brainstorming` mode.
3. Independent design review with the `design-review` skill
   (`../design-review/SKILL.md`).
4. Obtain explicit user approval, then persist the approved plan.
5. Wave planning with the `wave-planning` skill (`../wave-planning/SKILL.md`).
6. Execute approved tasks using the `subagent-driven-development` skill
   (`../subagent-driven-development/SKILL.md`). The coordinator owns and executes
   the cumulative test-pruning audit within the executor phase after task reviews
   and wave barriers, before final cumulative review and verification. Follow
   `../_shared/test-pruning.md` for scope, independent audit and recovery.
7. The executor returns current audit, final review and verification evidence to
   the coordinator. The coordinator records or reuses matching, fresh evidence;
   it does not automatically repeat these gates. Rerun a gate only when a
   relevant change invalidates its evidence or required evidence is missing,
   then clean up under the shared artefact contract.

Every phase is on by default. The user may explicitly skip any phase, including
reviews, checks and clean-up. Record each skip's scope, reason and consequence.
A skipped review is not an approval; skipped verification is never reported as
verified. Skipped clean-up retains registered artefacts and must be disclosed.
There is no complexity-based automatic bypass. A missing required input blocks
downstream work even when its producing phase was skipped.

Research and planning are conversational by default. Committee mode is an
explicit less-conversational choice, not an automatic alternative. After design
review and explicit user approval, wave planning and execution proceed without
routine task or wave approval prompts. Ask the user before changing approved
scope or architecture.

## State and ownership

Use `../_shared/workflow-artifacts.md` for paths, state fields, baseline,
resumption, ignore setup and safe clean-up. Only the coordinator creates or
changes shared state. Create files only when needed and preserve existing work.
Do not overwrite an existing active workflow: ask whether to resume it or use a
unique identity. A second coordinator must not own the same active task.

The state records phase status separately from review verdict and explicit
user approval. Approval includes the approved plan revision and source
reference. Reuse a prior approval only after checking its revision and current
implementation-relevant assumptions against the original repository baseline
plus ordered accepted-change checkpoints. Follow
`../_shared/workflow-artifacts.md` for checkpoint evidence and resume handling.
Expected approved task changes are not drift. Unexpected changes or invalidated
assumptions require affected approval or readiness reassessment. A substantive
design change requires renewed explicit user approval; schedule-only replanning
requires a fresh readiness review unless the user explicitly skips it.

Before any repository artefact is created, ensure the root `.gitignore` has
the exact `.elelem/` entry. Preserve all existing content, add no
broad ignore, and verify with `git check-ignore`. In plan mode, write only to
authorised locations. If repository writes are prohibited, use authorised
staging; never instruct a phase or worker to write to the repository. Failure
to materialise required workflow files is a blocker before execution.
Ask once for Git commit preference and record it in workflow state. Default to
leaving changes uncommitted, and never push.

## Execution and recovery

Wave planning finishes before dispatch. By default, its independent readiness
review must return `READY`. If the user explicitly authorised skipping only
that review, record its status as `SKIPPED` and require the executor to confirm
the complete planner-checked schedule and all ownership, dependency, resource,
input and capacity constraints from `../_shared/wave-readiness.md`; a skipped
review is not `READY`. Respect verified harness concurrency and model
capability. If required routing or capability is unavailable, report a blocker,
do not silently substitute. A skipped wave-planning phase permits one fully
specified bounded task only, not improvised parallel execution.

Track each task as queued, running, review, verified, integrated,
accepted-unverified, blocked or skipped. Implementation return alone is not
verified completion or an accepted change. Record task review, verification
and wave integration results separately. An explicitly authorised review or
check skip may be recorded as accepted-unverified, but must not be represented
as verified or integrated. Checkpoint only reviewed and verified work, or work
explicitly accepted-unverified under the user's recorded skip. On resume,
compare active or returned unaccepted task changes separately; do not
automatically accept them. On a real blocker, stop new dispatch. Cancel active
work only if safe cancellation is supported; otherwise let it settle without
claiming it stopped. Preserve state, report the blocker, and resume only after
its authorisation is resolved. Do not silently retry with a different model or
expand approved scope.

Final review, final verification and clean-up are separate phases. Default
behaviour is to run each. Clean-up is allowed after requested work has passed
final review and verification, or after explicit scoped skips are honestly
recorded. Apply the safety contract in `../_shared/workflow-artifacts.md`.
