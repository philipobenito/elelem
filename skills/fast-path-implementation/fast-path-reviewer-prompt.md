# Fast Path Combined Reviewer Prompt Template

Use this template when dispatching a combined reviewer for fast-path (SIMPLE) work.

**Purpose:** Verify the implementation matches the spec AND meets quality standards in a single pass.

**Only used when complexity triage classified the work as SIMPLE.**

**Subagent type selection:** Replace `[REVIEWER_SUBAGENT_TYPE]` with the most specific reviewer type available for the task per `instructions/common/subagents.md`. Default to `code-reviewer`. For language- or framework-specific changes, prefer a specialised reviewer if one exists. Use `general-purpose` only when no specialised reviewer fits.

```
{{DISPATCH_AGENT_TOOL}} ([REVIEWER_SUBAGENT_TYPE]):
  description: "Combined review for fast-path implementation"
  prompt: |
    You are reviewing a batch of changes that were triaged as SIMPLE using strict
    complexity criteria. Your job is to verify both spec compliance AND code quality
    in a single pass.

    ## What Was Requested

    [FULL TEXT of all requirements]

    ## Complexity Triage Result

    [Paste the triage evidence table that justified the fast path]

    ## What Implementer Claims They Built

    [From implementer's report]

    ## FIRST: Verify the Triage Was Correct

    Before reviewing the changes themselves, verify that the fast-path classification
    was appropriate. Read the actual code changes and check:

    - Are the changes genuinely uniform (same kind of edit across files)?
    - Is there any new logic, control flow, or callable units?
    - Is there any new public surface area (exports, endpoints, contracts)?
    - Can each change be understood without reference to other changes?

    If the actual changes are more complex than the triage suggested, stop here.
    Report TRIAGE_INVALID with a specific explanation of which criterion was wrong
    and why. The controller will switch to the full path.

    ## THEN: Review Both Dimensions

    If the triage is valid, review:

    **Spec Compliance:**
    - Did they implement everything requested?
    - Did they add anything not requested?
    - Did they misinterpret any requirements?
    - Verify by reading code, not by trusting the report.

    **Code Quality:**
    - Is the code clean and consistent with the surrounding codebase?
    - Are there any style, naming, or convention violations?
    - Is there unnecessary complexity introduced?
    - For changes that affect tests, do the tests verify the right things?
    - Did this implementation create new files that are already large or significantly
      grow existing files?

    Report:
    - [PASS] Approved (spec compliant and quality acceptable)
    - [FAIL] Issues found: [list specifically, with file:line references]
    - [TRIAGE_INVALID] This work is more complex than triaged: [which criterion fails and why]
```
