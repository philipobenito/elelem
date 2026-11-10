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
persists shared workflow files. Bound phase context through the shared input,
dispatch, persistence and evidence contracts below, not assumed isolation.

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
   (`../subagent-driven-development/SKILL.md`).
7. After the cumulative final reviewer result is validated as `PASS` under the
    shared helper's consumer adaptation, the executor invokes
    `test-pruning` as one separate final review-phase task, following
    `../test-pruning/SKILL.md` and `../_shared/test-pruning.md`. Only actual
    pruning edits require an independent bounded pruning-delta review. Final
    verification follows the last edit and review correction, then clean-up.
    The executor returns final review, pruning and verification evidence. The
    coordinator records or reuses matching, fresh evidence rather than invoking
    the same gate again, then cleans up under the shared artefact contract.
    Rerun a gate only when a relevant change invalidates its evidence or
    required evidence is missing.

Do not use user approval as the pruning trigger or require pruning evidence
before ordinary task review. Accumulate actual touched-path history from every
task and reviewer correction, including reverted edits and rename mappings;
build the final union inventory once after all relevant writers stop. Preserve
the immutable workflow baseline, pre-existing dirty/untracked contents and task
checkpoints. A final-review skip is not `PASS`: require explicit sequencing
authorisation before pruning. A pruning skip permits no pruning removals and
skips neither review nor verification. Failures block completion. Recover only
affected evidence, not an automatic cumulative-review/pruning loop.

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

### Coordinator-managed handoff continuation

At each actual phase or assigned-task handoff, resume the same active
coordinator. This is a phase/task boundary rule, not a check after each tool
call or interactive question. Validate the returned scope, outcome, evidence,
questions and blockers against user instructions, approval, the current phase,
approved revision and relevant workflow state. Record the result and next
action in existing `workflow.md`, in the applicable phase or task entry.

After recording the validated result, construct only the next phase's necessary
inputs under `../_shared/task-briefs.md`, then assess safe native context
maintenance below before invoking that phase. Complete implementation briefs
and required broad-review inputs remain intact.

If the return is sufficient and the next required phase has no outstanding
user choice or approval, invoke that phase through `{{INVOKE_SKILL_TOOL}}`
without routine prompting. Continue only along the approved workflow order and
do not skip or bypass any review, approval, TDD, debugging, verification or
explicit-skip gate. A status label or returned report is not evidence by itself.

Pause when the phase requires a user choice or approval, actual Plan-mode
restrictions prevent the next action, a real blocker or interruption occurs,
evidence is missing, state is unsafe, required capability is unavailable, or an
outstanding dependency leaves no safe independent work. Record the blocker and
next action; do not repeatedly retry unchanged work or dispatch dependants.
Stable task-local checks may continue while other workers run, but only against
stable inputs and within dependency and wave barriers.

Nested investigators and reviewers return to their owning phase for
reconciliation before that phase hands its result to the coordinator. Assigned
workers return through `subagent-driven-development`, which validates their
reports and checks before its coordinator handoff. Preserve existing
coordinator-owned dispatch paths. Never invoke a coordinator recursively or
create another owner for the same workflow. A phase's instruction to stop after
handoff ends that phase procedure only; the coordinator then resumes the
workflow. On cross-session resumption, validate the existing state and evidence.
Before retrying interrupted work that may have caused an external side effect,
determine from available evidence whether the side effect actually occurred. If
its outcome is unknown or repeating would be unsafe, pause and surface the
uncertainty rather than duplicate the action. Reuse still-valid work, and
continue at the next required action without repeating satisfied phases or
routine prompts.

### Native context maintenance

Consider native compaction at settled phase boundaries when completed-phase
detail is no longer needed and would otherwise carry forward. Use observable
usage metrics where available, with no universal threshold. This is not after
every tool call, question or small task return.

Retain conversational primary-session phases. Do not move the coordinator or
executor wholesale into nested children or change dialogue defaults. Fixed
applicable instructions, tools and managed policy remain loaded. Delegated
isolation follows `../_shared/subagent-dispatch.md`; invoking a skill is not a
reset.

Record `deferred` while active tasks or callbacks, uncertain external side
effects or unsettled inputs make reduction unsafe. Resolve those safety
conditions before maintenance or dependent actions; only safe independent work
may continue. Record `no-op` when there is no meaningful history to discard;
this is not a failure and needs no manual fallback.

Before reduction, require the recoverability checkpoint in
`../_shared/workflow-artifacts.md` and valid original provenance under
`../_shared/phase-evidence.md`. Automatic compaction requires an existing safe
native control for the known current session, authorised access and observable
completion. External SDK/API documentation alone does not establish live
capability. No improvised shell/API self-calls, guessed session IDs or second
session owner. Reuse capability checks only under the unchanged-harness rule in
`../_shared/subagent-dispatch.md`.

When safe and supported, request native compaction automatically. Request
acceptance is not completion. Await the native completion signal, then reload
only relevant current state and validate ownership, revision, approval and
evidence under the shared resume contract. Record the observed result and
continue at the next required action without routine prompts, preserving all
workflow gates. Completion and measured reduction remain separate evidence.

On error or unavailable native control, preserve the checkpoint, pause the
dependent transition, explain the cause and offer native manual compaction. Do
not blindly retry, silently downgrade or claim reduction. Manual recovery
requires observable completion where available and normal state validation. If
reduction cannot be established, label it unverified and require explicit
authorisation for unreduced continuation. Fallback permission does not skip
other gates. Record the outcome and provenance in the existing phase entry as
specified by `../_shared/phase-evidence.md`.

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

Final review, the final pruning task, final verification and clean-up are
separate phases. Default behaviour is to run each. Clean-up is allowed after requested work has passed
final review and verification, or after explicit scoped skips are honestly
recorded. Apply the safety contract in `../_shared/workflow-artifacts.md`.
