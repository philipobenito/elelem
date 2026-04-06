# Code Review

These rules apply to every code review interaction: requesting a review, receiving review feedback, and reacting to it. They apply whether the reviewer is your human partner, a subagent, an external collaborator, or a bot.

## Mandatory Reviews

You **MUST** request a code review before any of the following:

- Handing a task back as complete in orchestrated work (see `subagents.md` and the `subagent-driven-development` skill)
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
- Push back with technical reasoning (see "When to Push Back" below)
- State the fix and its location, or just ship the fix and let the diff speak

Rationale: actions speak. The fix in the code is the acknowledgement. Performative language signals compliance theatre, not understanding, and wastes the reviewer's time. If you catch yourself about to write "thanks" or "you're right", you **MUST** delete it and state the fix instead.

## Verify Before Acting

External feedback (including feedback from subagents and bots) is a suggestion to evaluate, not an order to execute. Before implementing any suggestion from a source other than your human partner, you **MUST**:

1. Check the suggestion against the current state of the codebase
2. Confirm the suggestion does not break existing functionality
3. Confirm the suggestion is correct for this stack, version, and platform
4. Confirm the suggestion does not conflict with a prior decision by your human partner

If you cannot verify a suggestion without additional information, you **MUST** say so explicitly and ask for instructions rather than implementing on guesswork.

Feedback from your human partner is trusted: you do not need to verify its correctness, but you **MUST** still clarify any item whose scope or intent is unclear before implementing.

## Clarify Before Partial Implementation

When feedback contains multiple items and any item is unclear, you **MUST NOT** implement any of the items until the unclear ones are clarified. Items in a review are frequently related; a partial implementation built on partial understanding produces a wrong implementation.

The correct response is: "I understand items X, Y, Z. I need clarification on items A and B before implementing any of this."

## YAGNI Check on "Implement Properly"

When a reviewer suggests implementing a feature "properly", "fully", or "the right way", you **MUST** first grep the codebase for actual usage of the code in question. If nothing calls it, the correct response is to propose removal under YAGNI, not to build out the suggested feature. Only when usage exists do you implement the suggestion.

## When to Push Back

You **MUST** push back on a suggestion when any of the following is true:

- The suggestion breaks existing functionality
- The reviewer lacks context that changes the calculus (legacy compatibility, platform support, prior decisions)
- The code path is unused and the suggestion violates YAGNI
- The suggestion is technically incorrect for this stack, framework, or runtime version
- The suggestion conflicts with an architectural decision your human partner has previously made

Pushback **MUST** be grounded in technical reasoning: cite the file, the test, the version constraint, or the prior decision. Defensive or emotional pushback is forbidden. Silence is also forbidden: you **MUST NOT** implement a suggestion you believe is wrong without pushing back first.

If you pushed back and were wrong, state the correction factually in one or two sentences, cite what changed your mind, and move on. No apology, no re-litigation, no over-explanation.

## Severity Discipline

When you receive a categorised review (Critical / Important / Minor, or equivalent):

- **Critical** issues **MUST** be fixed before any further progress on the work under review
- **Important** issues **MUST** be fixed before the next task in an orchestrated flow, or before merge in ad-hoc work
- **Minor** issues **MAY** be deferred with an explicit note

You **MUST NOT** mark a task complete, proceed to the next task, or merge while Critical or Important issues remain unfixed. "I'll fix it after" is forbidden.

## GitHub Inline Review Replies

When replying to an inline review comment on a GitHub pull request, you **MUST** reply in the comment thread using `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`. You **MUST NOT** respond as a top-level PR comment. Top-level replies detach the response from the comment it answers and make the review thread unreadable.

## Procedures

- To request a review, invoke the `requesting-code-review` skill.
- To process incoming review feedback, invoke the `receiving-code-review` skill.

Both skills cite this file. The rules here apply whether the skills have been invoked.
