# Phase Evidence Gate

The coordinator owns this procedural gate, not runtime enforcement. Phase
skills own their procedures; `./workflow-artifacts.md` owns persistence.
Apply at entry, transitions, handover, resume, reuse and execution, not as
per-tool-call checks or an additional reviewer.

## Evidence record

Keep concise phase evidence in existing `workflow.md` records, with no separate
report or transcript copying. For each applicable phase, record:

- Scope, revision and current assumptions to which the evidence applies.
- Actual procedure provenance: invoked skill/method and accessible session,
  message, artefact or command references showing its required work occurred.
- Outputs and required user choices, with their source references.
- Current validity and any affected downstream dependencies.
- For a skip, the exact-source user instruction and its scope, reason and
  consequence. Follow instruction precedence and retain unskipped obligations.

Use existing statuses; a status label is not evidence. Loading a skill, reading
code or writing a summary cannot establish procedural work. Likewise, later
review or approval cannot establish omitted procedures.

## Boundary validation

Before advancing, validate applicable upstream phases in order against their
own procedures and the current scope, revision and current assumptions:

- Research: evidence of required dialogue, findings/options discussed and user
  direction, or a separately user-selected alternative with its procedure and
  outputs. Planning committee selection cannot retrospectively authorise
  autonomous Research.
- Planning: explicit method selection, selected-mode invocation and proposal
  provenance. `brainstorming-skip` is lightweight Planning, not a phase skip.
- Other phases: required procedures, outputs, verdicts, approval or checks valid
  for the current inputs
  under their owning skills, or an exact-source scoped skip. Keep review
  verdicts, explicit user approval and verification distinct.

An instruction to implement or a model/mode switch is not a phase skip. An
explicit skip covers only its named scope. Missing dependent inputs still block;
neither approval nor a skip invents them. Executors and ticket entry points
return upstream gaps to the coordinator rather than repairing them inline.

## Reuse and recovery

### Context maintenance evidence

In the existing `workflow.md` phase entries, record the mechanism, phases and
revision, capability and inheritance evidence, and a completion reference or
error, unavailable, deferred or no-op outcome. Include the relevant input and
recoverability checkpoint references, cause and next action, without copying
the ledger or transcript. Keep maintenance outcomes distinct from phase status.

Retain original evidence and permission references through reduction;
inaccessible or stale provenance blocks the affected transition and destructive
reduction. Skill invocation or a state-file write is not context reduction.
Completed compaction is not measured token reduction. Record only observed
facts and usage metrics when exposed, with their source; absent measurements
remain unverified. A request acknowledgement alone is not completion evidence.

### Evidence validity

Record legitimate prior evidence later only with accessible provenance showing
the procedure actually occurred. Reuse it only after validating scope, revision
and assumptions against the baseline and accepted checkpoints. An absent local
record alone does not invalidate real evidence; an inaccessible or unsupported
claim cannot satisfy the gate.

Verification validity follows the exact command, working directory, checked
scope and input identities, not conversational turns. Apply
`../../rules/common/verification.md` and the `verification-before-completion`
gate. Preserve accessible references to actual captured output, exit status,
execution provenance, verifier identity and independence, and the relevant
environment or mutable resource assumptions. A new message or resumed session
alone does not invalidate matching evidence. Revalidate evidence against the
current scope and inputs before reusing it; report reused output as prior
execution, not newly run.

Relevant changes invalidate affected evidence. Demonstrably unrelated changes
preserve unaffected evidence. If input equivalence, mutable resource state or
dependency scope is missing or uncertain, rerun the affected check, conservatively
when scope is unknown. A task report or self-report is not execution or
independent verification evidence. Final integrated checks cover combined
settled inputs after relevant writers, pruning edits and review corrections;
matching evidence for those exact inputs can be revalidated and reused.

On a gap, stop the affected transition or dispatch and return to the earliest
unsupported phase. Preserve useful findings, code, user work and genuinely
valid evidence. Do not invent history or backfill unsupported claims. Run the
missing procedure or honour an explicit scoped user skip, then revalidate
affected downstream reviews, approval and readiness before continuing. Only
affected evidence needs renewal; valid work is not automatically discarded or
repeated. If an input remains missing, keep dependent work blocked and record
the gap and recovery boundary in the existing workflow state.
