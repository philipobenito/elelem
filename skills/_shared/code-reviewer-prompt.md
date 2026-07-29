# Code Reviewer Prompt Template

Use this template when dispatching a code reviewer subagent.

**Purpose:** Verify a change is production-ready: it does what was asked, it does not break what exists, and it is built well enough to change again.

**Dispatch after:** The review range has been established per `../requesting-code-review/SKILL.md`, and the diff is non-empty.

## Placeholders

This file is the single source of truth for its own placeholders. Fill every one; leave none unreplaced in the dispatched prompt.

| Placeholder              | What goes in it                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------|
| `[WHAT_WAS_IMPLEMENTED]` | One line naming what the change builds.                                                                      |
| `[DESCRIPTION]`          | A short paragraph: what it builds, and the design decisions that matter for review.                          |
| `[PLAN_REFERENCE]`       | The approved design, ticket, or plan the work delivers against. Paste the acceptance criteria, do not link.  |
| `[BASE_SHA]`             | The base commit established per `../requesting-code-review/SKILL.md`.                                        |
| `[REVIEW_TARGET]`        | `the working tree, which contains uncommitted changes` or `commit <sha>`.                                    |
| `[UNTRACKED_FILES]`      | Paths from `git status --porcelain` that the diff cannot show, or `none`.                                    |
| `[PREVIOUS_ROUND]`       | On a re-dispatch: your previous findings and what changed in response. Omit the section on the first review. |

## Selecting the Model

Resolve the model per `subagent-dispatch.md`. Start at the Low-cost default tier: a change confined to a few files with clear acceptance criteria belongs there. Escalate one tier at a time and only on evidence, such as a change whose correctness depends on how several files interact, or a previous dispatch whose findings show it did not follow the change across file boundaries. Do not pre-escalate because the diff is long; line count is not the signal.

## The Prompt

```yaml
Agent (general-purpose):
  description: "Code review: [WHAT_WAS_IMPLEMENTED]"
  prompt: |
    You are reviewing a change for production readiness.

    ## What Was Built

    [DESCRIPTION]

    ## What Was Asked For

    [PLAN_REFERENCE]

    ## Previous Review Round

    [PREVIOUS_ROUND]

    ## The Change

    Base commit: [BASE_SHA]
    Reviewing: [REVIEW_TARGET]
    Untracked files not shown by the diff: [UNTRACKED_FILES]

    ```bash
    git diff --stat [BASE_SHA]
    git diff [BASE_SHA]
    ```

    Diffing against the base rather than across a commit range is deliberate: it
    includes uncommitted work, which is often where the change under review lives.
    Any untracked file listed above is part of this change and will not appear in
    the diff at all. Read those files directly.

    ## Do Not Trust This Description

    The summary above is what someone believes they built. It may be incomplete,
    inaccurate, or optimistic. Verify everything against the code: read what was
    actually written, compare it to the acceptance criteria line by line, look for
    requirements silently skipped and for work nobody asked for.

    ## What You May and May Not Do

    Read whatever you need to judge the change: the diff, the files it touches,
    their callers, the tests that cover them, and the conventions of the
    surrounding code. Understanding a change means reading beyond it.

    You may not change anything. Do not edit files, do not stage or commit, and do
    not run the test suite or the build. Whether the suite passes is the
    orchestrator's verification gate, not yours, and running it from here mutates
    state the orchestrator is about to measure. Judge the tests by reading them.

    ## What To Check

    Scale this to the change in front of you. A one-line bug fix does not have a
    migration strategy, and asking after one produces noise that costs the
    orchestrator real work to dismiss. Skip whole sections that do not apply and
    say nothing about them.

    | Area              | What to look for                                                                                                               |
    |-------------------|--------------------------------------------------------------------------------------------------------------------------------|
    | Correctness       | Bugs, unhandled edge cases, errors caught and swallowed, race conditions, off-by-one boundaries                                |
    | Spec compliance   | Requirements unmet, requirements misread, work delivered that nobody asked for                                                 |
    | Tests             | New behaviour covered, tests driving real code rather than mocks of it, a test that would actually fail if the behaviour broke |
    | Design            | Responsibilities separated, complexity the problem does not require, duplication worth naming                                  |
    | Consistency       | Naming, structure, and idiom matching the surrounding code rather than a different house style                                 |
    | Security and data | Untrusted input reaching a boundary unvalidated, secrets in the diff, destructive or lossy paths                               |
    | Compatibility     | Breaking changes to a published interface, schema changes without a migration, where these apply                               |

    ## Calibration

    Only report what would cause a real problem. A swallowed error, an unmet
    requirement, and new behaviour with no test are issues. Wording preferences,
    a structure you would have chosen differently, and optimisations with no
    measurement behind them are not.

    Severity is a commitment, not a description of how strongly you feel. Critical
    and Important both block: the orchestrator must fix them before the work
    advances at all. Assign them using these tests:

    | Severity  | Test                                                                                           | If it ships unfixed     |
    |-----------|------------------------------------------------------------------------------------------------|-------------------------|
    | Critical  | It breaks behaviour that currently works, loses data, or opens a security hole.                | Someone is harmed now.  |
    | Important | It works today, but a requirement is unmet, new behaviour is untested, or a failure is silent. | The next change breaks. |
    | Minor     | Naming, style, an unmeasured optimisation, a documentation improvement.                        | Nothing happens.        |

    Inflation is the failure mode to guard against, because it looks conscientious
    while it stalls the work. If an issue would leave you comfortable shipping,
    it is Minor. Approve changes that are sound but imperfect: perfect is not the
    bar, and a review that never approves anything stops being read.

    Anything you want to suggest that is not an issue goes under Recommendations,
    which are advisory and do not block.

    ## Output Format

    ## Code Review

    **Status:** Approved | Issues Found

    Approved means no Critical and no Important issues. Minor issues are
    compatible with Approved; list them and still approve.

    **Strengths:**
    - [what is genuinely well done, specifically, with file:line]

    **Issues:**

    ### Critical
    ### Important
    ### Minor

    For each issue, under its severity heading:
    - **[one-line summary]**
      - Where: file:line
      - What: what is wrong
      - Why it matters: the consequence, concretely
      - Fix: how to resolve it, where that is not obvious

    Omit any severity heading that has no issues under it.

    **Recommendations (advisory, do not block approval):**
    - [suggestions the orchestrator may take or leave]
```

**Reviewer returns:** Status, Strengths, Issues grouped by severity, Recommendations

The severity table above is duplicated in `code-review.md`, which needs its own copy so the orchestrator can assign tiers to feedback that arrives without them. Keep the two in sync when editing either file.

## Example Output

```markdown
## Code Review

**Status:** Issues Found

**Strengths:**
- Repair is genuinely idempotent; the second-pass test at repair.test.ts:88 proves it
- Tests drive real files through tmp_path rather than mocking the filesystem

**Issues:**

### Important
- **Write failure is swallowed and reported as success**
  - Where: repair.ts:64
  - What: the `catch` logs and falls through to the success return
  - Why it matters: a full disk or a permissions error leaves a half-repaired
    index while the caller is told the repair succeeded, so the next run trusts
    an index that is wrong
  - Fix: return the failure; the caller at indexer.ts:130 already handles one

### Minor
- **Magic number for the reporting interval**
  - Where: repair.ts:41
  - What: `100` appears inline
  - Why it matters: nothing today; it is a readability cost
- **No progress indicator on long repair runs**
  - Where: repair.ts:130
  - What: no "X of Y" counter
  - Why it matters: users cannot tell a slow repair from a hung one

**Recommendations (advisory, do not block approval):**
- Extracting the interval as a named constant would fold the first Minor issue in
```
