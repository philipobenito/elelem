# Code Review - Procedural Rules

These rules apply once either of the code review skills (`requesting-code-review`, `receiving-code-review`) has been invoked. They are the procedural detail behind the iron laws in `../../rules/common/code-review.md`. The iron laws (when reviews are mandatory, the forbidden-response banned phrases) live in the always-on rule file and bind every interaction. The rules below govern *how* feedback is verified, evaluated, and acted on once you are inside a review skill.

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

### Assigning Tiers When the Feedback Has None

Most review feedback arrives without severity tiers. A reviewer dispatched through `requesting-code-review` returns Critical, Important and Minor, but the per-task reviewers in `orchestrated-implementation` and `fast-path-implementation` return only `[PASS]` or `[FAIL]`, and a human partner listing three problems in a message returns nothing at all. Ordering the work still needs tiers, so when they are absent you **MUST** assign them before touching anything, using these tests:

| Tier          | Test                                                                                                       | If it ships unfixed     |
|---------------|------------------------------------------------------------------------------------------------------------|-------------------------|
| **Critical**  | It breaks behaviour that currently works, loses data, or opens a security hole.                            | Someone is harmed now.  |
| **Important** | It works today, but a requirement is unmet, new behaviour is untested, or a failure is swallowed silently. | The next change breaks. |
| **Minor**     | Naming, style, an unmeasured optimisation, a documentation improvement.                                    | Nothing happens.        |

State the tier you assigned and the reason, so the reviewer or partner can correct you. The failure this table exists to prevent is inflation, and inflation is the cheaper mistake to make because it looks conscientious while it stalls the work: an Important tier is a blocker, so calling a naming preference Important commits you to fixing it before anything else proceeds.

### Acting on Tiers

- **Critical** issues **MUST** be fixed before any further progress on the work under review
- **Important** issues **MUST** be fixed before the work advances: before the next task in an orchestrated flow, before merge in ad-hoc work, and before any completion claim where neither applies
- **Minor** issues are still valid feedback, it is permitted to defer them, but not preferred, if a fix makes sense it **MUST** be applied

You **MUST NOT** mark a task complete, proceed to the next task, or merge while Critical or Important issues remain unfixed. "I'll fix it after" is forbidden.

## GitHub Inline Review Replies

When replying to an inline review comment on a GitHub pull request, you **MUST** reply in the comment thread using `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`. You **MUST NOT** respond as a top-level PR comment. Top-level replies detach the response from the comment it answers and make the review thread unreadable.
