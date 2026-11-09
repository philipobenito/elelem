# Workflow Artefacts and State

The coordinator alone owns shared workflow files. Keep them in
`.elelem/workflows/<ticket-or-slug>/` and create only files needed for the
current task:

- `workflow.md`: identity, state, registry, baseline, tasks, evidence, blockers.
- `research.md`: persisted research findings and references.
- `plan.md`: final design only after explicit user approval.
- `waves.md`: approved task briefs, waves and readiness verdict.

Do not replace, truncate or repurpose pre-existing content. Drafts remain in
conversation or authorised staging until writing there is permitted. If a
required file cannot be materialised, block before execution.

## State fields

`workflow.md` records, at minimum:

- Workflow identity, repository identity and active owner/coordination status.
- Confirmed active primary-session model and capability for conversational
  Research or Planning. Reconfirm only if the active model changes.
- Phase statuses, each one of `pending`, `active`, `satisfied`, `skipped`,
  `blocked` or `complete`.
- For every skip: user authorisation, exact scope, reason and consequence.
- Design-review verdict and readiness-review verdict, separate from user
  approval. Record approval as explicit, with plan revision and source
  reference. A verdict or skipped review is never approval.
- Registry of exact files created by this workflow, with whether each existed
  before the workflow. For authorised staging files, also record the exact
  authorised staging root. Do not register pre-existing files as created.
  Record any separate, explicit user permission to remove a pre-existing file
  with its exact path and scope.
- Repository baseline: revision, relevant working-tree changes and the
  implementation-relevant files, contracts and configuration observed. Keep
  the original starting baseline, including contents of relevant dirty paths,
  immutable throughout the workflow.
- Task status, owner, review result, verification result, evidence and blockers.
- Accepted-change checkpoints and wave integration results, including whether
  each checkpoint is verified or explicitly accepted-unverified.
- Current artefact revisions and links or references to evidence.

Keep the concise phase evidence required by `./phase-evidence.md` in these
existing `workflow.md` records. Preserve procedure and user-choice provenance,
exact-source scoped skips and current validity; do not create another report.

For each actual coordinator-managed phase or assigned-task handoff, preserve the
original baseline and exact skip provenance. The same active coordinator
records the validated result and next action in the existing phase or task entry
in `workflow.md`. Include returned scope, outcome, evidence, questions or
blockers as relevant. Do not create a separate handoff state file. On resume,
validate provenance and current validity of evidence, then continue from the
next required action without repeating valid completed phases or routine
prompts. A phase's
"stop after handoff" ends that phase procedure, not the overall workflow.

Task statuses use `queued`, `running`, `review`, `verified`, `integrated`,
`accepted-unverified`, `blocked` or `skipped`. `integrated` requires task review,
task verification and the appropriate wave integration check. A task with an
explicitly authorised review or verification skip may be recorded as
`accepted-unverified`, never as `verified` or `integrated`. Keep review,
verification and integration results separate. A wave integration result is
`verified`, `accepted-unverified`, `blocked` or `skipped`; it is
`accepted-unverified` when an explicitly authorised review or check was skipped.
Record every skip with its scope, reason and consequence. Never convert a skip
into a passing result or invent the inputs a skipped phase would have produced.

## Ignore and baseline

Before creating repository artefacts, inspect the root `.gitignore`. Ensure it
contains the exact entry `/.elelem/workflows/`, preserving all existing bytes
and adding no broad ignore. Do not change an existing rule unnecessarily.
Verify the intended workflow path with `git check-ignore`. If an ignore update
or workflow write is not allowed in current plan mode, write only to an
authorised staging location; do not direct another agent to write in the
repository. The coordinator records authorised staging paths and materialises
the required files only when permitted. Copy or materialise without replacing
any existing file; an existing destination is preserved and blocks that write
until resolved.

## Checkpoints and accepted changes

The original starting baseline is the state before workflow implementation,
not a moving comparison point. Capture relevant pre-existing dirty content as
part of it and preserve it; do not treat those changes as workflow output or
discard them. On resume, compute the expected implementation state by applying
the ordered accepted-change checkpoints to that original baseline. Exclude
workflow artefacts and the exact required ignore-rule change from this
comparison.

Create a checkpoint after a task's required review and verification, or after
an integrated wave's required integration check. If any review or check was
explicitly skipped, checkpoint only when the user authorises acceptance and
record the result as `accepted-unverified`. Record the exact changed paths, the
before and after content identifiers or an equivalent content snapshot or diff
reference, the task or wave that produced them, and the observed review,
verification and integration results. The checkpoint baseline is the expected
relevant repository state after applying that checkpoint, represented by
content identifiers or equivalent snapshots/references. References must
identify actual evidence; do not invent commits or other Git references for
uncommitted work. Preserve enough file-backed content or references to
reproduce the expected state.

On resume, compare current contents with the original baseline plus checkpoints.
Check changes from running or returned but not yet accepted tasks separately
against their allowed writes and recorded starting contents. Such changes are
not automatically accepted just because a task returned. Preserve user changes
and pre-existing dirty paths. If a changed path cannot safely be attributed to
an accepted task, user change, or recorded baseline, stop and ask rather than
overwriting, accepting, or discarding it.

Do not invalidate approved work merely because an approved task changed files.
Only unexpected changes or changes that invalidate recorded assumptions require
affected approval or readiness reassessment. A substantive design change
requires renewed explicit user approval. A schedule-only replanning requires a
fresh readiness review, unless the user explicitly skips that review. Never
accept a stale approval merely because its file still exists. Every phase is
user-skippable, but a skip is not approval and missing required inputs still
block downstream work.

Before taking ownership, inspect for active state with the same workflow
identity. Do not overwrite it or run a second coordinator on its active task.
Ask whether to resume that workflow or choose a unique identity. Preserve
unrelated and pre-existing work in all cases.

## Clean-up contract

Clean-up is a user-skippable phase. Default clean-up is allowed only after all
requested work passes final review and verification, or after each skipped
gate has explicit scope and consequence recorded and is disclosed. Skipping
clean-up leaves every artefact in place and reports that fact.

Use a manifest-only procedure over exact registered files, separately for the
repository workflow directory and each recorded authorised staging root.
Workflow-created files are eligible only when the registry says they did not
exist before the workflow and the user has not skipped clean-up. Before
deleting each path, reject absolute paths, `..` traversal, paths outside its
recorded root, and any symlink in the file or parent path. Re-check the
resolved parent remains inside that root. Preserve unregistered and unknown
files, including unknown directories. Do not recursively remove directories.
Never delete a harness-owned or pre-existing plan file unless a separate record
grants explicit user permission for that exact path and scope. Without that
permission, retain it and report clean-up pending; keep the registry needed to
resume clean-up.

After authorised clean-up has succeeded for both repository and staging files,
delete `workflow.md` last so a failure retains the recovery registry. If any
registered file is retained or clean-up fails, retain `workflow.md` and report
the remaining paths. Remove the workflow directory or staging directories only
if empty. Remove a staging directory only if this workflow created it and it is
empty. Never delete implementation files, archives, Git history or the ignore
rule. Artefact authorisation grants no authority over other files.

If clean-up fails, report it as incomplete or blocked, identify retained
recovery state and do not claim clean-up succeeded. Do not replace this
procedure with an automated deletion script.
