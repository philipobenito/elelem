# Independent Task Reviewer Prompt Template

Use for an independent review of a worker's actual task changes. This is a
read-only review, separate from worker self-review and orchestrator
verification. Select a suitable reviewer under
`../_shared/subagent-dispatch.md`; reviews require the high-capability tier
specified by the workflow design. Verify the concrete model identifier and
routing. Do not infer model switching from metadata. The coordinator must
honour an explicitly authorised task-review skip and not dispatch this prompt
for the skipped scope. A skip is recorded by the coordinator, not converted by
the reviewer into a verdict. If the supplied context records that the review
was skipped, do not issue `READY`, `CHANGES_REQUIRED` or `BLOCKED` as a review
verdict; report that no review was performed and defer to the coordinator's
recorded skip.

```text
{{DISPATCH_AGENT_TOOL}} ([REVIEWER_SUBAGENT_TYPE]):
  description: "Review [TASK_ID]: [task name]"
  prompt: |
    Independently review the actual changes for this approved task. Do not
    modify files, run competing writers, or trust the worker's report as proof.

    ## Approved task brief

    [Paste the complete task brief, including mapped requirements, exclusions,
    exact allowed writes, acceptance criteria, stable inputs and relevant
    contracts.]

    ## Pruning-audit skip record

    The coordinator supplies exact user-authorised pruning-audit skip records,
    or `none` when no pruning-audit skip was authorised:
    [PRUNING_AUDIT_SKIP_RECORDS_OR_NONE]
    Each record includes the exact source and instruction text, skipped
    test-bearing file/case scope, reason and consequence. If the skip record is
    absent or incomplete, report BLOCKED. Do not infer an authorised skip from
    a missing record or audit evidence.

    ## Worker report

    [Paste the worker's structured report and verification evidence.]

    ## Actual change set

    [Provide the exact changed paths and available diff or file contents. Read
    the actual files in the review scope. Do not use session history as a
    substitute for the task brief or changes.]

    ## Review

    Check the actual implementation against each acceptance criterion and
    mapped requirement. Identify omissions, scope violations, unrequested
    behaviour, contract mismatches, defects, maintainability problems and
    relevant test gaps. Check that changes are confined to allowed paths.
    Assess TDD evidence where behaviour changed, but do not treat reported
    commands as fresh independent verification. Do not expand the approved
    design or suggest unrelated clean-up.

    ## Explicit pruning-audit skips

    For each user-authorised pruning-audit skip, verify that the supplied
    workflow record identifies the exact user authorisation and the skipped
    file/case scope. Inspect the actual diff and confirm no removal or merge
    was applied in that scope. Report the pruning audit as `SKIPPED` and
    unverified; it is not pruning-audit evidence or approval. Do not dispatch
    or repeat a pruning audit for the skipped scope, or invent KEEP, REMOVE, or
    MERGE decisions for it. If a removal or merge was applied in skipped scope,
    report the scope violation without claiming audit evidence. Continue
    reviewing all task changes, including changes in files with skipped pruning
    audits. Only skip pruning-evidence inspection for the explicitly skipped
    file/case scope. Continue all unskipped checks. Apply the pruning-evidence
    review below only to unskipped test-bearing scopes.

    For a task that touched test-bearing files, inspect the pruning evidence
    under `../_shared/test-pruning.md`. Check that scope came from actual task
    changes and includes every test and parameterised case in each touched
    test-bearing file, including older cases. Inspect the immutable baseline,
    frozen active instruction-source identities and applicable project test
    rules, stable input identities, pre-prune checks, non-zero per-file and
    total discovery counts, runner-appropriate execution evidence, and the
    accepted post-prune snapshot. For indirect runners, require trace-to-case
    execution evidence. For direct runners, accept actual check output and
    discovery evidence without requiring a trace. Check that the independent
    auditor returned one KEEP, REMOVE, or MERGE for each case under the complete
    current canonical Meaningful Assertions section and applicable project
    rules. For removals,
    assess the stated category and authorised removal rationale, survivor
    requirements, and scoped recovery. For each merge, verify the source,
    current-audit KEEP survivor, assertion, production line, reachable path,
    and failure reason; confirm unsupported merges were withheld and combined
    authorised edits are reflected in the accepted post-prune snapshot. Check
    decision dependencies and transitive invalidation evidence for later
    survivor changes. No file or last test may be deleted, and post-prune
    discovery counts must match actual applied decisions and remain non-zero per
    file and in total.

    When archived removed-source reassessments are included, verify exact
    preserved source and context, pre-removal snapshot identity, and actual
    prior check and discovery evidence for each archived source. Verify the
    original runner and whether historical tracing applied. Require historical
    trace evidence only for an indirect original runner; for a direct original
    runner, prior check and discovery evidence is sufficient without a trace.
    Missing or unstable required archived evidence blocks reassessment. Do not
    fabricate prior evidence or require an archived case to execute now.

    Check approved-behaviour coverage against decisions actually applied and
    withheld. Required approved behaviour without retained coverage is an
    Important finding. Report unrelated pre-existing gaps separately without
    expanding scope. This review checks recorded audit evidence; do not dispatch
    or repeat the independent pruning audit unless its inputs changed and the
    coordinator requests a fresh audit under the approved procedure.

    For each finding, provide severity (Critical, Important or Minor), exact
    path and line or a precise location, evidence, impact, and a bounded
    correction when one fits the task contract. Missing requirements or
    architecture are blockers to return to planning, not permission to design
    or implement a new contract.

    ## Report

    Return one verdict:
    - READY: no unresolved Critical or Important findings; list any Minor
      findings and why they do not block this task.
    - CHANGES_REQUIRED: list every Critical and Important finding with evidence
      and bounded correction guidance.
    - BLOCKED: explain what required context or approved contract is absent.

    This verdict is not user approval, task verification or wave integration.
```
