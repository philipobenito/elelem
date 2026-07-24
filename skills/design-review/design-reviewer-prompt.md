# Design Reviewer Prompt Template

Use this template when dispatching a design reviewer subagent.

**Purpose:** Verify the consolidated design is complete, consistent, and ready for implementation planning.

**Dispatch after:** The design summary has been consolidated by the calling brainstorming mode.

## Selecting the Subagent Type

`../_shared/subagent-dispatch.md` requires the most specific available type, and `../../rules/common/subagents.md` forbids writing an identifier you have not confirmed the current environment exposes. Agent type names are where that bites hardest: many are supplied by plugins and are namespaced (`voltagent-qa-sec:architect-reviewer`), so a bare name copied from any table may not resolve at all, and on a machine without that plugin no variant of it exists.

Resolve the type at dispatch time, every time:

1. Enumerate the `subagent_type` values this environment actually exposes.
2. Search that enumeration for an architecture, system design, or design review capability.
3. Take the most specific match, whatever its namespace.
4. Where nothing matches, fall back to `Plan`, which is present in every environment.

`Plan` is the fallback rather than `general-purpose` because it is built for weighing architectural trade-offs and is read-only by construction, which suits a reviewer that must not write anything.

The table below is a **worked example of what a match looks like, not an identifier to paste**. It records what one environment happened to expose; yours may namespace it differently, name it differently, or not have it at all.

| Example match        | As enumerated in one environment      |
|----------------------|---------------------------------------|
| `architect-reviewer` | `voltagent-qa-sec:architect-reviewer` |

## Selecting the Model

Resolve the model per `../_shared/subagent-dispatch.md`. Start at the Low-cost default tier. Design judgement is that file's stated signal for the High-capability tier, so escalation as far as that tier is available for this dispatch, one tier at a time and only on evidence. Do not pre-escalate on the assumption that a design will be hard.

## The Prompt

```
Agent ([REVIEWER_SUBAGENT_TYPE]):
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

    ## Reading the Repository

    The design summary is the only thing you receive from the session, and that
    isolation is about the conversation rather than the code. The repository is
    shared ground truth, not somebody's account of it, so you may read it.

    Read it to check claims the summary makes about existing code: a component it
    says it will modify, an interface it says it will extend, a convention it says
    it will follow. Keep the reading to those checks. A general tour of the
    codebase is not what you are for, and it will cost more than it finds.

    A claim you cannot verify is not an issue. Looking for `IngestWorker` and not
    finding it is worth raising; not being able to tell where to look is not.
    Manufacturing issues out of your own uncertainty is the failure mode this
    permission introduces, and it is worse than not reading at all.

    ## Calibration

    **Only flag issues that would cause real problems during implementation planning.**
    A missing component, a contradiction, or a requirement so ambiguous it could be
    interpreted two different ways are issues. Minor wording improvements,
    stylistic preferences, and "sections less detailed than others" are not.

    Approve unless there are serious gaps that would lead to a flawed plan.

    For every issue, state what the design would have to say to resolve it. The
    orchestrator uses that line to tell an issue the design already answers
    elsewhere from one that needs a decision nobody has made yet, and those two
    take different routes. Naming the resolution is not the same as choosing it:
    where several answers would each resolve the issue, say so and name them
    rather than picking one.

    ## Output Format

    ## Design Review

    **Status:** Approved | Issues Found

    **Issues (if any):**
    - [Section/Area]: [specific issue] - [why it matters for planning]
      Resolved by: [what the design would have to state; or the candidate answers, where more than one would do]

    **Recommendations (advisory, do not block approval):**
    - [suggestions for improvement]
```

**Reviewer returns:** Status, Issues (each with its resolution line), Recommendations

The "What to Check" table is duplicated in `SKILL.md`, which needs its own copy so the orchestrator can categorise what comes back. Keep the two in sync when editing either file.
