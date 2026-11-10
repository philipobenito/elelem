---
name: test-pruning
description: Runs the separate final test-pruning task after a passing cumulative final reviewer verdict, with independent audit and bounded application.
---

# Final Test Pruning

Invoke this skill through `{{INVOKE_SKILL_TOOL}}` as one separate final
review-phase task. Its trigger is the cumulative final reviewer's validated `PASS`,
not user approval. Ordinary implementation and task review do not run pruning.

Follow `../_shared/test-pruning.md` for the complete procedure, required inputs,
independent audit, supported application, evidence, skips and recovery. Do not
duplicate its mechanics here. The active coordinator owns state and audit
dispatch; the executor schedules the final task, the auditor is read-only, and
an assigned application worker has bounded writes. No nested delegation.

Use the helper's consumer adaptation of the actual reviewer result, not a
literal `PASS` field from the producer. Preserve raw evidence and provenance;
`REVIEWED` alone is not a favourable verdict.

Require the approved design, immutable workflow baseline and relevant task
checkpoints, actual touched-path history, stable final inputs and cumulative
review evidence. Missing inputs block, rather than starting another workflow.
An explicit review skip requires the helper's sequencing authorisation.

Return scope, outcome, evidence, questions and blockers through the executor to
the same coordinator. Do not claim final verification or clean-up; those follow
the final task and any required pruning-delta review.
