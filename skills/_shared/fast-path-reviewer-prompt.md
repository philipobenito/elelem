# Fast Path Combined Reviewer Prompt Template

Use this template when dispatching a combined reviewer for fast-path (SIMPLE) work.

**Purpose:** Verify the implementation matches the spec AND meets quality standards in a single pass.

**Only used when complexity triage classified the work as SIMPLE.**

```yaml
Agent (general-purpose):
  description: "Combined review for fast-path implementation"
  prompt: |
    You are reviewing a batch of changes that were triaged as SIMPLE using strict
    complexity criteria. Your job is to verify both spec compliance AND code quality
    in a single pass.

    ## What Was Requested

    [FULL TEXT of all requirements]

    ## Complexity Triage Result

    [Paste the triage evidence table that justified the fast path]

    If any row in that table is marked N, a user overrode a COMPLEX verdict. The row was
    left failing on purpose so you could test it against the real diff rather than take
    the override on trust. Weigh that row first.

    ## What Implementer Claims They Built

    [From implementer's report]

    ## Previous Review Rounds

    [On a re-review, paste your previous findings and what the implementer changed in
    response. Omit this section entirely on the first review.]

    ## FIRST: Verify the Triage Was Correct

    Before reviewing the changes themselves, verify that the fast-path classification
    was appropriate. The triage was a prediction made before this code existed; you are
    reading the code, so your evidence is stronger than the table's. Work through all
    six criteria against the actual diff:

    1. **Uniform change type**: are the changes genuinely the same kind of edit applied
       across locations, or do they mix concerns (docs plus feature code, config plus
       new logic)?
    2. **No new logic**: is there any new function, class, conditional, loop, error
       handling, or business rule?
    3. **No new interfaces**: is there any new export, endpoint, contract, event, or
       other public surface area?
    4. **Deterministic from spec**: did any change require a design decision, judgement
       call, or contextual understanding beyond the immediate edit? Look for choices the
       implementer had to make, especially ones its report mentions making.
    5. **Independently verifiable**: can each change be understood and checked by reading
       it in isolation, or does one change's correctness depend on another in a different
       file?
    6. **Small total delta**: run `git diff --stat` and count the substantive changed
       lines. The cap is 50, and the criterion also rejects any count landing between 40
       and 50, because estimation error at that boundary is wider than the margin.

    Criterion 6 deserves particular attention, because it is the one the triage could
    only estimate and you can measure. A count above 50, or inside the rejected 40 to 50
    band, falsifies the classification no matter how cleanly the other five hold.

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
    - Did this implementation create new files that are already large or significantly
      grow existing files?

    **Testing expectations on this path:**

    Criterion 2 means work triaged SIMPLE introduces no observable behaviour, so there
    is no new behaviour for a test to cover. The absence of new tests is therefore
    correct here rather than a gap, and you must not report FAIL for missing tests.

    A new test that *was* added is the finding worth reporting: on this path it usually
    means new behaviour arrived, which is a TRIAGE_INVALID condition under criterion 2.
    Where the diff touches tests that already existed, check that the change keeps them
    verifying the right thing. Whether the existing suite still passes is the
    orchestrator's gate to run, not yours.

    Report:
    - [PASS] Approved (spec compliant and quality acceptable)
    - [FAIL] Issues found: [list specifically, with file:line references]
    - [TRIAGE_INVALID] This work is more complex than triaged: [which criterion fails and why]
```
