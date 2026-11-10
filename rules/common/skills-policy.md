# Skills

## Workflow entry and phase skills

Use `workflow-coordinator` as the entry point before implementation. It owns
phase transitions and shared state, and invokes the detailed phase skills.
Within an active workflow, `brainstorming` is only the Planning method
selector. Do not invoke its router again before an edit when the active
workflow already has a validated approved design.

Use `skills/_shared/phase-evidence.md` for procedural evidence, exact-source
scoped skips, valid reuse and recovery at workflow boundaries. Invocation alone
does not satisfy a phase; perform its required procedure and retain provenance.

Skills are required workflow procedures. Invoke relevant skills through
`{{INVOKE_SKILL_TOOL}}`; do not substitute reading their files for invocation.
Each workflow phase runs by default. Only an explicit user instruction scoped
to this work may skip a phase or method. Record the scope, reason and
consequences. Do not infer a skip from urgency, simplicity or familiarity.
Every phase, including reviews, checks and clean-up, may be explicitly
skipped, but a skip is not approval, evidence or a reason to make a false
completion claim. A skipped phase does not supply missing required inputs.

There is no complexity-based automatic bypass. Validate an already-approved
research result or design before it satisfies a phase. The coordinator must
not replace a phase skill's procedure with its own summary or manual substitute.

## Invocation order

The coordinator determines applicable phases and invokes their skills in the
workflow order: Research, Planning via the selected `brainstorming` mode,
design review, explicit user approval, Wave Planning and readiness review,
implementation, task reviews and checks, final review, final test pruning,
final verification,
and clean-up. A user may explicitly skip any phase. Do not request routine
task or wave approvals after the approved design and READY schedule.

The coordinator owns the separate final test-pruning task after task reviews,
wave barriers and cumulative final reviewer `PASS`, before final verification.
Follow the shared test-pruning procedure; a task review does not claim this
deferred audit.

For bug fixes, use `debugging` by default to reproduce the issue and establish
root cause. An explicit scoped skip does not create evidence or permit a false
fix claim. Use `test-driven-development` by default for implementation changes
that require it; an explicit scoped TDD skip follows the user's instruction,
subject to the same evidence and claim constraints. Before any claim that work
is verified, passing, fixed or ready, use `verification-before-completion`.
Before completion, use `requesting-code-review` unless review was explicitly
skipped. In coordinated implementation, task and cumulative reviews are
distinct workflow phases; invoke the required skill for each applicable
review.

For a ticket, `work-on-ticket` may recover the approved design and hand it to
the coordinator. It does not bypass validation, missing inputs, or explicit
approval requirements. A status question uses `verification-before-completion`
before any passing or completion claim.

Invoke `test-pruning` once as a separate final task only after cumulative final
reviewer `PASS`, not user approval. Its shared helper owns the final union
inventory, audit and safe application. Ordinary TDD/implementation/task review
has no whole-file inventory or pruning-evidence prerequisite. Require bounded
independent pruning-delta review only for actual edits, then final verification
after the last edit and review correction. Do not automatically loop cumulative
review and pruning. Record scoped skips; a review skip is not `PASS` and needs
explicit sequencing authorisation before pruning. A pruning skip authorises no
pruning removals and skips neither review nor verification. Failures block
completion; targeted invalidation/recovery does not schedule another routine audit.

## Instruction precedence

System instructions take precedence over developer instructions, which take
precedence over user instructions, followed by repository rules and default
behaviour. Do not claim that a user instruction overrides a higher-priority
instruction. Within these constraints, an explicit scoped user skip governs
the applicable workflow phase or method; it cannot bypass harness restrictions,
authorise false claims, or provide missing inputs.

## Subagent exemption

Subagents dispatched for a specific task do not run a skill-discovery scan.
The coordinator owns phase and skill selection; workers follow their supplied
brief and dispatch instructions. A dispatch may explicitly require a worker to
invoke a named skill, subject to the harness and the user's scoped choices.

Do not bypass a relevant procedure because it looks simple, familiar or faster
to do manually. The scoped-skip process is the only workflow exception, and
requires an explicit user instruction recorded in state.
