# Code Review

## Mandatory Reviews

You **MUST** request a review before handing a task back as complete in orchestrated work, merging to main or opening a pull request, or declaring a major feature complete. You **MUST NOT** skip a review because the change "is simple", "is small", "is obvious", or "was tested locally"; no such exemption exists. `work-review-request` requests one; `work-review-receive` processes incoming feedback from any source.

## Forbidden Responses to Feedback

You **MUST NOT** respond to review feedback with performative, gratitude, or agreement language, whether or not the feedback is correct: "You're absolutely right", "great point", "good catch", "thanks", and all paraphrases are banned. Restate the requirement in your own words, ask a specific clarifying question, push back with technical reasoning, or state the fix and its location. The fix in the code is the acknowledgement; performative language is compliance theatre.

## Severity Discipline

Every finding carries a tier; a tier is a commitment, not a description of how strongly anyone feels:

| Tier          | Test                                                                                                       | If it ships unfixed     |
|---------------|------------------------------------------------------------------------------------------------------------|-------------------------|
| **Critical**  | It breaks behaviour that currently works, loses data, or opens a security hole.                            | Someone is harmed now.  |
| **Important** | It works today, but a requirement is unmet, new behaviour is untested, or a failure is swallowed silently. | The next change breaks. |
| **Minor**     | Naming, style, an unmeasured optimisation, a documentation improvement.                                    | Nothing happens.        |

- **Critical** issues **MUST** be fixed before any further progress
- **Important** issues **MUST** be fixed before the work advances: the next task, a merge, or a completion claim
- **Minor** issues may be deferred, but where a fix makes sense it **MUST** be applied

You **MUST NOT** mark a task complete, proceed, or merge while Critical or Important issues remain unfixed. The failure to guard against when assigning tiers is inflation, because it looks conscientious while it stalls the work: an Important tier is a blocker, so calling a naming preference Important commits you to fixing it before anything else proceeds.

This table is the canonical severity definition: the review skills apply it directly and a dispatched reviewer receives it pasted whole, so an edit here reaches every consumer.
