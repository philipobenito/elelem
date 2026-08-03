# Code Review

These rules apply to every code review interaction: requesting a review, receiving review feedback, and reacting to it. They apply whether the reviewer is your human partner, a subagent, an external collaborator, or a bot.

## Mandatory Reviews

You **MUST** request a code review before any of the following:

- Handing a task back as complete in orchestrated work (see `subagents.md` and the `work-implementation` skill)
- Merging to main or opening a pull request
- Declaring a major feature complete

You **MUST NOT** skip a review because the change "is simple", "is small", "is obvious", or "was tested locally". No such exemption exists.

## Forbidden Responses to Feedback

You **MUST NOT** respond to code review feedback with any performative, gratitude, or agreement language. This applies regardless of whether the feedback is correct.

**Banned phrases** (non-exhaustive; paraphrases and synonyms are equally banned):

- "You're absolutely right"
- "Great point", "Excellent feedback", "Good catch"
- "Thanks", "Thank you", "Thanks for catching that", or any gratitude expression
- "Let me implement that now" (before verification has happened)

**Permitted responses:**

- Restate the technical requirement in your own words
- Ask a specific clarifying question
- Push back with technical reasoning (see "When to Push Back" in the procedural rules)
- State the fix and its location, or just ship the fix and let the diff speak

Rationale: actions speak. The fix in the code is the acknowledgement. Performative language signals compliance theatre, not understanding, and wastes the reviewer's time. If you catch yourself about to write "thanks" or "you're right", you **MUST** delete it and state the fix instead.

## Severity Discipline

Every review finding carries a tier, and a tier is a commitment rather than a description of how strongly anyone feels:

| Tier          | Test                                                                                                       | If it ships unfixed     |
|---------------|------------------------------------------------------------------------------------------------------------|-------------------------|
| **Critical**  | It breaks behaviour that currently works, loses data, or opens a security hole.                            | Someone is harmed now.  |
| **Important** | It works today, but a requirement is unmet, new behaviour is untested, or a failure is swallowed silently. | The next change breaks. |
| **Minor**     | Naming, style, an unmeasured optimisation, a documentation improvement.                                    | Nothing happens.        |

- **Critical** issues **MUST** be fixed before any further progress on the work under review
- **Important** issues **MUST** be fixed before the work advances: before the next task in an orchestrated flow, before merge in ad-hoc work, and before any completion claim where neither applies
- **Minor** issues are still valid feedback, it is permitted to defer them, but not preferred, if a fix makes sense it **MUST** be applied

You **MUST NOT** mark a task complete, proceed to the next task, or merge while Critical or Important issues remain unfixed. "I'll fix it after" is forbidden. The failure to guard against when assigning tiers is inflation, because it looks conscientious while it stalls the work: an Important tier is a blocker, so calling a naming preference Important commits you to fixing it before anything else proceeds.

This table is the canonical severity definition. The review skills apply it directly, and a dispatched reviewer receives it pasted whole into its prompt, so an edit here reaches every consumer with no second copy to keep in sync.

## The Review Skills

To request a review, invoke the `work-review-request` skill: it dispatches a reviewer, applies the severity discipline above to the verdict, and owns the fix-and-re-review loop. To process incoming review feedback from any source, invoke the `work-review-receive` skill: it verifies each item, pushes back where the reviewer is wrong, and implements what survives in severity order.
