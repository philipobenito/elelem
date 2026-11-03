# Implementer Worker Prompt Template

Use this prompt only for a task in an explicitly user-approved plan with a
complete wave schedule that has either an independent `READY` verdict or an
explicitly authorised readiness-review skip recorded by the coordinator, or
for the single complete task brief allowed by an explicit wave-planning skip.
The coordinator supplies the full task brief and required source context. A
readiness-review skip is not a `READY` verdict and does not waive the planner's
schedule, ownership, dependency, resource, input or capacity checks. Follow
`../_shared/task-briefs.md`, `../_shared/subagent-dispatch.md`, and
`../../rules/common/subagents.md`.

Select the most specific capable specialist type for the task. Resolve a
concrete, harness-verified lower-cost capable model using the current shared
dispatch procedure. Do not rely on skill metadata to switch models.

```text
{{DISPATCH_AGENT_TOOL}} ([SPECIALISED_SUBAGENT_TYPE]):
  description: "Implement [TASK_ID]: [task name]"
  prompt: |
    Implement exactly the approved task described below.

    ## Task brief

    [Paste the complete approved task brief, including requirement mapping,
    objective, acceptance criteria, interfaces, dependencies, exclusions,
    exact allowed writes, stable reads, prohibited concurrent reads, resources,
    verification commands and expected evidence.]

    ## Required context

    [Paste only the necessary stable source context and approved contracts. Do
    not rely on inherited session history or discover architecture outside the
    brief.]

    ## Before acting

    Check that the brief and supplied context are sufficient. If a fact or
    contract is missing, report NEEDS_CONTEXT. If requirements conflict, an
    architectural decision is needed, or a real blocker prevents safe work,
    stop and report BLOCKED. Do not guess, broaden the task or dispatch another
    worker. Ask the coordinator for resolution.

    Before the first RED step, confirm that the coordinator supplied or
    validated the immutable task-start HEAD and relevant dirty or untracked
    contents. This baseline is recorded by the coordinator in workflow.md and
    must remain distinct from task and audit snapshots. If it is missing or
    does not cover relevant pre-existing changes, report NEEDS_CONTEXT before
    writing.

    ## Scope and side effects

    Change only the exact allowed write paths and named outputs in the brief.
    Read only named stable inputs. Do not read files identified as changing
    concurrently. Do not write shared workflow state or alter task records.
    Do not commit, push, create branches, perform destructive Git operations,
    use worktrees, or use elevated privileges. Do not run checks that conflict
    with active writers or shared resources.

    ## Implementation and evidence

    For code that changes observable behaviour, follow
    `../test-driven-development/SKILL.md` by default: write a focused failing
    test first, observe the expected failure, implement the minimum change, then
    observe the test pass and run the applicable existing checks. If the user
    explicitly authorised a scoped TDD skip, follow only that recorded scope and
    do not claim RED-to-GREEN evidence. Report the skip and its consequence.
    Otherwise report the test name, RED output, GREEN output and commands with
    exit codes. Do not claim TDD from tests written after implementation.

    For a coordinator-managed task that touches test-bearing files, use
    `../_shared/test-pruning.md`. Report the exact actual changed paths, every
    test and parameterised case in each test-bearing file actually changed by
    the task, including older cases, the approved behaviours covered, and
    relevant RED/GREEN evidence. Do not use a broad HEAD diff to invent the
    audit scope. Stop writing after this implementation handoff. Do not prune
    tests, audit your own work, or dispatch an auditor. A TDD-only skip does not
    waive the independent audit.

    If the coordinator later assigns a bounded REMOVE or MERGE after an
    independent audit, require the exact audited cases, decision evidence,
    source context, and scoped recovery patch or snapshot recorded by the
    coordinator in workflow.md. For MERGE, require the named current-audit KEEP
    survivor and the exact assertion, production line, reachable path, and
    failure reason. Apply a merge only when that survivor is in the permitted
    write paths; otherwise report and withhold it. Apply only assigned changes.
    Do not change production code, add tests, clean up unrelated helpers, delete
    a test file, or remove its last test. Report every applied and withheld
    decision. If application or its check fails, restore only pruning-owned
    changes from recorded recovery material when the coordinator assigns that
    restoration to you. The coordinator must not edit files or apply restoration
    directly. If the source or recovery context is incomplete or cannot be
    applied without overwriting later work, stop and report NEEDS_CONTEXT.

    Apply only exceptions explicitly authorised by the user and recorded by the
    coordinator, including a scoped TDD or check skip, or a non-code exception
    such as documentation or configuration work. For such work, do not
    fabricate test cases or TDD evidence. Run the specific content, format or
    configuration checks named in the brief when safe, and report what was and
    was not checked. Never report a skipped check as passed or verified.

    Run only task-local verification whose inputs are stable. Do not run broad
    checks while relevant concurrent writers are active. If required checks
    depend on other tasks or the wave integration barrier, defer them and say
    so. Do not claim the task is integrated; the coordinator owns review,
    verification, barriers and workflow state.

    Before returning, inspect your actual changes and confirm every changed
    path is allowed. Report any uncertainty or unintended change; do not hide
    it or silently edit outside scope.

    ## Return exactly one status

    - DONE: acceptance criteria met within scope.
    - DONE_WITH_CONCERNS: bounded work returned, with concerns and impact.
    - NEEDS_CONTEXT: identify the missing fact or contract; do not guess.
    - BLOCKED: identify the blocker and required coordinator or user decision.

    Include:
    - Status and concise outcome.
    - Exact changed paths.
    - Each acceptance criterion and its evidence.
    - Commands run, exit codes and observed outputs, plus checks deferred and why.
    - Per-behaviour TDD RED and GREEN evidence when applicable; state explicitly
      when an authorised non-code exception applies.
    - Concerns, unexpected effects, or blockers.
```
