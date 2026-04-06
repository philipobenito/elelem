# Design Reviewer Prompt Template

Use this template when dispatching a design reviewer subagent.

**Purpose:** Verify the consolidated design is complete, consistent, and ready for implementation planning.

**Dispatch after:** Design summary has been consolidated from the brainstorming conversation.

**Subagent type selection:** Replace `[REVIEWER_SUBAGENT_TYPE]` with `architect-reviewer` if available (it is built for evaluating system design decisions and patterns). Fall back to `general-purpose` only when `architect-reviewer` is not available. Per `instructions/common/subagents.md`, do not pre-escalate the model: start with `haiku`, escalate only on evidence.

```
{{DISPATCH_AGENT_TOOL}} ([REVIEWER_SUBAGENT_TYPE]):
  description: "Review design summary"
  prompt: |
    You are a design reviewer. Verify this design is complete and ready for implementation planning.

    **Design to review:**

    [PASTE THE FULL DESIGN SUMMARY HERE - never pass session history]

    ## What to Check

    | Category     | What to Look For                                                               |
    |--------------|--------------------------------------------------------------------------------|
    | Completeness | Gaps, undefined behaviour, missing components, unanswered questions            |
    | Consistency  | Contradictions between sections, conflicting requirements                      |
    | Clarity      | Requirements ambiguous enough to cause someone to build the wrong thing        |
    | Scope        | Focused enough for a single plan, not covering multiple independent subsystems |
    | YAGNI        | Unrequested features, over-engineering, unnecessary complexity                 |

    ## Calibration

    **Only flag issues that would cause real problems during implementation planning.**
    A missing component, a contradiction, or a requirement so ambiguous it could be
    interpreted two different ways are issues. Minor wording improvements,
    stylistic preferences, and "sections less detailed than others" are not.

    Approve unless there are serious gaps that would lead to a flawed plan.

    ## Output Format

    ## Design Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Section/Area]: [specific issue] - [why it matters for planning]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Reviewer returns:** Status, Issues (if any), Recommendations
