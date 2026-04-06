# Combined Reviewer Prompt Template

Use this template when dispatching a reviewer subagent on the full path.

**Purpose:** Verify the implementation matches the spec AND meets quality standards in a single pass.

**Subagent type selection:** Replace `[REVIEWER_SUBAGENT_TYPE]` with the most specific reviewer type available for the task per `instructions/common/subagents.md`. Default to `code-reviewer`. For language- or framework-specific changes, prefer a specialised reviewer if one exists. Use `general-purpose` only when no specialised reviewer fits.

```
{{DISPATCH_AGENT_TOOL}} ([REVIEWER_SUBAGENT_TYPE]):
  description: "Review Task N: [task name]"
  prompt: |
    You are reviewing an implementation for both spec compliance and code quality.

    ## What Was Requested

    [FULL TEXT of task requirements / acceptance criteria]

    ## What Implementer Claims They Built

    [From implementer's report]

    ## CRITICAL: Do Not Trust the Report

    The implementer's report may be incomplete, inaccurate, or optimistic.
    You MUST verify everything independently by reading the actual code.

    **DO NOT:**
    - Take their word for what they implemented
    - Trust their claims about completeness
    - Accept their interpretation of requirements

    **DO:**
    - Read the actual code they wrote
    - Compare actual implementation to requirements line by line
    - Check for missing pieces they claimed to implement
    - Look for extra features they didn't mention

    ## Your Job

    Read the implementation code and verify both dimensions:

    ### Spec Compliance

    **Missing requirements:**
    - Did they implement everything that was requested?
    - Are there requirements they skipped or missed?
    - Did they claim something works but didn't actually implement it?

    **Extra/unneeded work:**
    - Did they build things that weren't requested?
    - Did they over-engineer or add unnecessary features?
    - Did they add "nice to haves" that weren't in spec?

    **Misunderstandings:**
    - Did they interpret requirements differently than intended?
    - Did they solve the wrong problem?

    ### Code Quality

    - Is the code clean and consistent with the surrounding codebase?
    - Does each file have one clear responsibility with a well-defined interface?
    - Are units decomposed so they can be understood and tested independently?
    - Is the implementation following the file structure from the plan?
    - Are there any style, naming, or convention violations?
    - Is there unnecessary complexity introduced?
    - For changes that affect tests, do the tests verify the right things?
    - Did this implementation create new files that are already large or significantly
      grow existing files? (Don't flag pre-existing file sizes, focus on what this
      change contributed.)

    **Verify by reading code, not by trusting the report.**

    ## Report

    - [PASS] Approved (spec compliant and quality acceptable)
    - [FAIL] Issues found: [list specifically, with file:line references, categorised
      as spec compliance or code quality issues]
```
