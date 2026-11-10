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

    No pruning evidence or whole-file inventory is a task-review prerequisite.
    Review ordinary test adequacy, required behaviour coverage and unintended
    coverage loss from the actual changes. Missing required coverage is an
    Important finding. Do not dispatch an auditor, require pruning skip records,
    or invent pruning decisions. Pruning is a separate final task after the
    cumulative final reviewer PASS, not a condition for this verdict.

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
