# Single-Task Reviewer Prompt Template

Use this template for an independent review of a single task that the workflow
coordinator explicitly scheduled. It is the same substantive task review used
by the standard executor, not authority to bypass workflow phases or checks.
Do not invoke this prompt when the coordinator recorded an explicitly
authorised task-review skip. Record that review as `SKIPPED` without inventing
a reviewer verdict.
Follow `../_shared/subagent-dispatch.md` for reviewer type, concrete model
resolution and routing. Reviews use the high-capability tier specified by the
workflow design.

```text
{{DISPATCH_AGENT_TOOL}} ([REVIEWER_SUBAGENT_TYPE]):
  description: "Review [TASK_ID]: [task name]"
  prompt: |
    Independently review the actual changes for this approved task. Do not
    modify files or treat a complexity classification as authority to bypass
    any workflow phase.

    ## Approved task brief

    [Paste the full brief, including mapped requirements, exclusions, exact
    write paths, stable reads, acceptance criteria and relevant contracts.]

    ## Review stage

    [TASK_REVIEW_OR_FINAL_AUDIT_EVIDENCE_REVIEW]
    During task review the pruning evidence is deferred to the final audit;
    review the task changes and TDD evidence without requiring or claiming an
    audit. Apply the pruning-evidence instructions below only in final audit
    evidence review, after the coordinator has run or explicitly skipped it.

    ## Pruning-audit skip record

    For final audit evidence review, the coordinator supplies exact user-authorised pruning-audit skip records,
    or `none` when no pruning-audit skip was authorised:
    [PRUNING_AUDIT_SKIP_RECORDS_OR_NONE]
    Each record includes the exact source and instruction text, skipped
    test-bearing file/case scope, reason and consequence. If the skip record is
    absent or incomplete, report BLOCKED. Do not infer an authorised skip from
    a missing record or audit evidence.

    ## Worker report and evidence

    [Paste the structured worker report, verification commands and outputs,
    and TDD evidence when behaviour changed.]

    ## Actual changes

    [Provide exact changed paths and the available diff or file contents. Read
    actual files in scope. Do not trust the report as a substitute.]

    ## Review criteria

    Check each acceptance criterion and mapped requirement. Identify missing
    work, out-of-scope changes, unrequested behaviour, contract mismatches,
    correctness defects, maintainability concerns and relevant test gaps. Check
    that every changed path is allowed. Assess reported TDD evidence, but do not
    treat it as fresh independent verification. Do not suggest unrelated
    refactors or invent requirements.

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

    For final audit evidence review of test-bearing files, inspect the pruning evidence
    under `../_shared/test-pruning.md`. Check actual task and correction scope and the complete
    inventory of every test and parameterised case in each touched file,
    including older cases. Inspect the immutable baseline, frozen active
    instruction-source identities and applicable project test rules, stable
    input identities, pre-prune checks, non-zero per-file and total discovery
    counts, runner-appropriate execution evidence, and the accepted post-prune
    snapshot. For indirect runners, require trace-to-case execution evidence.
    For direct runners, accept actual check output and discovery evidence
    without requiring a trace. Check that the independent auditor returned one
    KEEP, REMOVE, or MERGE per case under the complete current canonical
    Meaningful Assertions section and applicable project rules. For removals,
    assess the stated category and
    authorised rationale, survivor requirements, and scoped recovery. For each
    merge, verify the source, current-audit KEEP survivor, assertion, production
    line, reachable path, and failure reason; confirm unsupported merges were
    withheld and combined authorised edits appear in the accepted snapshot.
    Check decision dependencies and transitive invalidation for later survivor
    changes. No file or last test may be deleted, and post-prune discovery
    counts must match actual applied decisions and remain non-zero per file and
    in total.
    When archived removed-source reassessments are included, verify exact
    preserved source and context, pre-removal snapshot identity, and actual
    prior check and discovery evidence for each archived source. Verify the
    original runner and whether historical tracing applied. Require historical
    trace evidence only for an indirect original runner; for a direct original
    runner, prior check and discovery evidence is sufficient without a trace.
    Missing or unstable required archived evidence blocks reassessment. Do not
    fabricate prior evidence or require an archived case to execute now.
    Check approved-behaviour coverage against decisions actually applied and
    withheld; missing required coverage is Important. Report unrelated existing
    gaps separately. Do not dispatch or repeat the audit unless its inputs
    changed and the coordinator requests it under the approved procedure.

    Classify each finding as Critical, Important or Minor. Give a precise path
    and location, supporting evidence, impact and bounded correction guidance
    where it fits the approved task. Missing architecture or a contract is a
    blocker to return to planning, not permission to invent a design.

    ## Report

    Return one verdict:
    - READY: no unresolved Critical or Important findings; list any Minor
      findings and why they do not block the task.
    - CHANGES_REQUIRED: list Critical and Important findings with evidence and
      bounded correction guidance.
    - BLOCKED: identify missing context or approved contract.

    The verdict is not user approval, fresh verification or wave integration.
```
