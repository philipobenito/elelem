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
- Push back with technical reasoning (see "When to Push Back" in the procedural rules)
- State the fix and its location, or just ship the fix and let the diff speak

Rationale: actions speak. The fix in the code is the acknowledgement. Performative language signals compliance theatre, not understanding, and wastes the reviewer's time. If you catch yourself about to write "thanks" or "you're right", you **MUST** delete it and state the fix instead.

## Procedural Rules

The procedural rules that bind once a code review skill is running, verify-before-acting, clarify-before-partial-implementation, the YAGNI check on "implement properly", when to push back, severity discipline, and the GitHub inline reply procedure, live in `skills/_shared/code-review.md` and load when either `requesting-code-review` or `receiving-code-review` is invoked. To request a review, invoke the `requesting-code-review` skill. To process incoming review feedback, invoke the `receiving-code-review` skill.
