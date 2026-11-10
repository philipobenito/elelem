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

    No pruning evidence or whole-file inventory is a task-review prerequisite.
    Review ordinary test adequacy, required behaviour coverage and unintended
    coverage loss from the actual changes. Missing required coverage is an
    Important finding. Do not dispatch an auditor, require pruning skip records,
    or invent pruning decisions. Pruning is a separate final task after the
    cumulative final reviewer PASS, not a condition for this verdict.

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
