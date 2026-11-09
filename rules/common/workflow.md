# Workflow

## Entry and phase defaults

The `workflow-coordinator` skill is the entry point before implementation-oriented
proposals and implementation. Research hypotheses and options remain permitted. It
owns transitions and shared state; phase skills own their detailed procedures.
The `brainstorming` router is only the Planning method selector within that
workflow. Do not send the user through it again when an active workflow already
contains an approved, current design for the requested work.

Apply `skills/_shared/phase-evidence.md` at workflow boundaries. Phase status,
skill loading and later approval do not prove required procedures occurred.

Every phase runs by default: Research, Planning, design review, Wave Planning,
readiness review, implementation, task reviews and checks, final review,
final verification, and clean-up. Only an explicit, scoped user instruction
may skip a phase. Record its scope, reason and consequences. Every phase is
skippable, including reviews, checks and clean-up, but a skipped review is not
approval and skipped verification is not evidence. Do not imply a skipped gate
passed. No complexity heuristic may automatically bypass a phase.

An existing approved research result or design may satisfy its phase only
after validating its source, scope, revision and current assumptions. A review
verdict is separate from explicit user design approval. Skipping a producing
phase does not supply its missing required output: missing inputs block
downstream work. Approval is required before implementation and is distinct
from review verdicts and phase skips.

## Research, planning and approval

Research and Planning are conversational by default. Confirm that the active
primary-session model has high-capability reasoning before conversational
preparation; skill metadata does not switch models. If it is insufficient, ask
the user to switch rather than silently replacing the user-facing conversation
with a detached agent. Design review and wave readiness review are independent
high-capability reviews. Substantive design changes return to Planning and
require renewed explicit user approval.

The coordinator records an approved design, its revision and approval source
before implementation. For bug fixes, the design includes the reproduction
approach and intended change. Preserve project test requirements, including a
failing regression test before a fix, unless the user explicitly scopes a TDD
skip. A skip does not create missing evidence or permit a false completion
claim.

## Workflow artefacts and permissions

Store approved workflow state and artefacts under
`.elelem/workflows/<ticket-or-slug>/`, creating only what the task needs:
`workflow.md`, `research.md`, `plan.md` and `waves.md`. Before creating any
repository artefact, ensure the root `.gitignore` contains the exact
`/.elelem/workflows/` entry and verify the path is ignored. Record exact files
created and preserve pre-existing or unrelated files. Keep artefacts
uncommitted. Do not retain a persistent plan archive; clean up registered
workflow-created files after successful ticket completion, unless the user
explicitly skips clean-up. Apply the safe clean-up procedure in
`skills/_shared/workflow-artifacts.md`.

Respect plan-mode write permissions. Write only to authorised locations; when
repository writes are prohibited, use authorised staging and do not instruct
workers to write in the repository. Failure to materialise required workflow
files blocks execution. Preserve the user's Git preference, defaulting to
leaving changes uncommitted. Never push.

## Wave execution

Implementation starts only after explicit design approval and a `READY` wave
schedule, unless the user explicitly skips a phase. If Wave Planning is
skipped, require one complete, bounded task brief and do not improvise parallel
work. Task briefs specify exact disjoint write paths, stable reads, interfaces,
dependencies, acceptance criteria and verification. Account for side effects
from tests, formatters, generators, fixtures, tools and shared resources. Same-
wave tasks must not read one another's changing files.

Run independent tasks concurrently when harness routing and concurrency are
verified. Each task receives independent review and fresh task-local checks.
After all writers in a wave stop, run its integration barrier before starting
the next wave. Final review and fresh verification follow all waves. Do not ask
for routine task or wave approvals. Keep the coordinator thin: invoke phase
skills and track state, rather than rereading or substituting for their
procedures.

## Coordinator-managed handoffs

At each actual coordinator-managed phase or assigned-task handoff, the same
active coordinator validates the returned scope, outcome, evidence, questions
and blockers against the current phase, user instructions, approval and relevant
workflow state. This standing rule applies to phase or task handoffs, not to
each tool call or each interactive question. Record the result and next action
in the existing `workflow.md`.

When the return supports the next required phase, invoke that phase without
routine prompting. Pause for an actual user choice or approval, a Plan-mode
limitation, a real blocker, missing evidence, unsafe state, unavailable
capability, interruption, or an outstanding dependency when no safe independent
work remains. Preserve all existing approval, review, verification, TDD,
debugging and scoped-skip gates. Continuation never skips a phase or treats a
status label or worker report as evidence.

Nested investigators and reviewers return to their owning phase for
reconciliation before that phase hands off to the coordinator. Assigned workers
return through the executor, except for pre-existing coordinator-owned dispatch.
Safe task-local checks with stable inputs may continue while other workers run;
dependency and wave barriers still apply. Do not recursively invoke another
coordinator or create a second owner for the active workflow. "Stop after
handoff" ends the current phase procedure, not the overall workflow.

## Blockers and recovery

A real blocker stops new dispatch. Cancel running work only when safe
cancellation is supported; otherwise let it settle without claiming it
stopped. Preserve workflow state and report the blocker. Do not silently
redesign, expand approved scope, or change model tier. In-scope review
corrections may be delegated under the approved task contract. Resume only
after required authorisation is resolved.
