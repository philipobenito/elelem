---
name: work-review-receive
description: "Turns code review feedback into verified, implemented changes: verifies each item against the codebase, pushes back with technical reasoning where the reviewer is wrong, and implements what survives in severity order. Use this whenever review feedback arrives from any source, whether a pull request comment, a reviewer subagent, a bot, or your human partner telling you what is wrong with the code, and whenever the user pastes review comments and asks you to address them. Invoked by `work-review-request` to act on its reviewer's findings. Enforces the ban on performative agreement and the requirement to push back rather than silently implement a suggestion you believe is wrong."
---

# Receiving Code Review

Takes a batch of review feedback and returns implemented fixes, reasoned pushback, or the questions that have to be answered first. Everything this skill needs is below; nothing here requires reading any other file.

## Source Trust Rules

Who gave the feedback decides how much verification it needs. Severity does not: an Important finding from a bot still needs checking, and a passing remark from your human partner still does not.

### From Your Human Partner

Trusted. Skip codebase verification and go straight to clarifying scope where it is unclear, then implement. Performative agreement, thanks, and "you're absolutely right" remain forbidden.

Where the partner's instruction conflicts with something you observed in the code, state the observation and ask. Silently reinterpreting an instruction to fit what you found is the failure mode here, and it produces a change neither of you intended.

### From Everyone Else, Including Subagent Reviewers and Bots

Not trusted by default. External feedback is a suggestion to evaluate, not an order to execute. Every item needs verification against the codebase before you act on it: read the referenced files, grep for the callers, check the tests, check the version and platform constraints.

Where a suggestion conflicts with an architectural decision your human partner previously made, stop and escalate rather than implementing either side. Where you cannot verify an item at all, say so explicitly: "I cannot verify this without X. Should I investigate, ask, or proceed?"

## The Response Procedure

1. **Read all of it first.** Every item, to the end. Do not react, do not start implementing, do not respond. A batch of review items is frequently one problem described from several angles, and you cannot see that from the first item.

2. **Assign severity if the feedback has none.** A reviewer dispatched by `work-review-request` or by an orchestration workflow returns Critical, Important and Minor natively, so this step is usually a no-op for one. It is the other sources that arrive untiered: a bot's comments, or a partner listing three problems in a message. Ordering the work still needs tiers, so assign each item one from the severity table in the always-on code review rules, and state the tier you assigned with your reason, so the reviewer or partner can correct it. Skip this where the feedback is already categorised.

3. **Verify each item against the codebase**, applying the source trust rules above. Restate each item in your own words as you go: if you cannot, you have not understood it yet, and that is worth knowing now rather than after you have changed code. Check that the suggestion is correct for this stack, version, and platform, that it does not break existing behaviour, that it does not conflict with a prior decision, and that it does not build out code nothing calls.

4. **Sort each item** into one of three outcomes: accept and implement, push back with technical reasoning, or genuinely unclear. "When Pushback Is Not Optional" below sets out the conditions under which the second is mandatory.

   Verification comes before this sort on purpose. Until you have read the code, an item that is simply wrong about the codebase is indistinguishable from one you have failed to understand, and the two take opposite routes: one gets pushback, the other gets a question. Sorting first means guessing which.

5. **Stop and ask if anything is genuinely unclear.** Ask about every unclear item at once, and implement nothing, including the items you do understand. Review items are frequently related, so an implementation built on partial understanding produces a wrong implementation that also looks like progress.

6. **Respond per item**: the fix you will make and where, the question you need answered, or the technical reason you are pushing back. The forbidden responses in the always-on code review rules, performative agreement, gratitude, "you're absolutely right", apply to every item.

7. **Implement in severity order**: blocking issues first, then simple fixes, then complex ones. Test each fix individually and confirm no regressions before starting the next. A batch of fixes verified only at the end cannot tell you which one broke something.

## When Pushback Is Not Optional

You **MUST** push back when any of the following is true:

- The suggestion breaks existing functionality
- The reviewer lacks context that changes the calculus: legacy compatibility, platform support, a prior decision
- The code path is unused and the suggestion violates YAGNI
- The suggestion is technically incorrect for this stack, framework, or runtime version

Pushback **MUST** be grounded in technical reasoning: cite the file, the test, the version constraint, or the prior decision. Defensive or emotional pushback is forbidden, and so is silence: you **MUST NOT** implement a suggestion you believe is wrong without pushing back first.

The YAGNI case has a mandatory first step. When a reviewer suggests implementing a feature "properly", "fully", or "the right way", grep the codebase for actual usage of the code in question before doing anything else. If nothing calls it, the correct response is to propose removal, not to build out the suggested feature. Only when usage exists do you implement the suggestion.

If you pushed back and were wrong, state the correction factually in one or two sentences, cite what changed your mind, and move on. No apology, no re-litigation, no over-explanation.

## GitHub Inline Replies

When replying to an inline review comment on a GitHub pull request, reply in the comment thread using `gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`. You **MUST NOT** respond as a top-level PR comment: a top-level reply detaches the response from the comment it answers and makes the review thread unreadable.

## Return Contract

This skill is usually invoked by `work-review-request` inside its fix-and-re-review loop, and that loop needs to know which of these it got.

**Applied.** Every accepted item is implemented and individually verified; every pushed-back item is closed with reasoning the reviewer did not contest. The caller re-reviews the result.

**Clarification required.** One or more items are unclear and nothing has been implemented, including the clear items. The caller takes the questions to the user. This blocks its loop by design: re-dispatching a reviewer answers nothing, because the reviewer is not the one holding the missing context.

**Pushback pending.** Items were pushed back and need an answer before the batch can close. The caller carries the reasoning to whoever produced the feedback.

**Escalated.** An item conflicts with an architectural decision the human partner previously made. Nothing has been implemented on either side of the conflict. The caller stops and puts it to the user.

## Worked Examples

### Performative vs Technical

Reviewer: "Remove the legacy code path."

Forbidden: "You're absolutely right! Let me remove that now."

Correct: "Checking. The build target is macOS 10.15+; the non-legacy API requires 13+. The legacy path is needed for backward compatibility. The current legacy branch uses the wrong bundle ID. Fix the bundle ID or drop pre-13 support and delete the legacy path. Which?"

### YAGNI on "Implement Properly"

Reviewer: "Implement proper metrics tracking with a database, date filters, and CSV export."

Correct: "Grepped the codebase. Nothing calls the `/metrics` endpoint. Proposing removal under YAGNI. Is there usage I am missing?"

### Unclear Item in a Batch

Partner: "Fix items 1 through 6."

You understand 1, 2, 3, and 6. You do not understand 4 and 5.

Forbidden: implement 1, 2, 3, 6 now and ask about 4, 5 later.

Correct: "I understand items 1, 2, 3, 6. I need clarification on items 4 and 5 before implementing any of them in case they are related."

### Uncategorised Feedback

A bot leaves three comments with no severities: a swallowed write error, an inconsistent variable name, and a new function with no test.

Correct: "Assigning severity before starting. The swallowed error at `repair.ts:64` is Important: it works today but reports success on a failed write, so the next run trusts a bad index. The missing test on `verifyIndex()` is Important: new behaviour, nothing covering it. The naming inconsistency is Minor. Fixing the two Important items now, logging the Minor one."

### Gracefully Correcting Your Own Pushback

You pushed back on a suggestion. After further checking, the reviewer was right.

Correct: "Verified. You were right: `foo()` does propagate the cancellation token when called from the async path. My initial reading missed the wrapper in `bar.ts:88`. Implementing."

Forbidden: long apology, re-litigation of why you pushed back, over-explanation.

### GitHub Inline Reply

An inline comment exists on `widget.ts:42` in PR #123.

Correct: `gh api repos/{owner}/{repo}/pulls/123/comments/{comment_id}/replies -f body='Fixed in widget.ts:42. Bundle ID guard added and tested against 10.15 and 13.'`

Forbidden: top-level PR comment that references the line in prose.

## Red Flags

Every thought below means stop:

- "I will implement the ones I understand and ask about the rest." That is the partial implementation the procedure exists to prevent.
- "The reviewer is probably right, it is faster to just do it." Faster only if it is right. An unverified fix to a non-issue is a change nobody asked for, and it now needs reviewing too.
- "Pushing back will look like I am making excuses." Silence on a suggestion you believe is wrong is forbidden. Cite the file, the test, or the version constraint and the reasoning stands on its own.
- "This one is obviously Minor, I will fix it while I am here." Fix it or defer it, but say which. Silent scope growth is what the severity tiers exist to make visible.
- You are about to write "good catch", "great point", or any form of thanks. Delete it and state the fix instead. The fix in the code is the acknowledgement.

## Common Mistakes

| Mistake                                                           | Why it is wrong                                                                                                                          |
|-------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Sorting items as unclear before verifying them                    | An item that is wrong about the code looks identical to one you have not understood. They take opposite routes: pushback, or a question. |
| Implementing a subagent or bot suggestion without checking it     | External feedback is a suggestion to evaluate, not an order to execute.                                                                  |
| Verifying feedback from your human partner                        | The partner is trusted. Clarify scope where it is unclear, but do not audit the instruction.                                             |
| Treating uncategorised feedback as though it had no severity      | Order still matters. Assign the tiers yourself and say what you assigned, so it can be corrected.                                        |
| Fixing everything at once and testing at the end                  | When something breaks you cannot tell which fix did it, and the batch has to be unpicked.                                                |
| Building out a feature a reviewer called for on unused code       | The YAGNI check comes first: grep for callers. If nothing calls it, propose removal rather than expansion.                               |
| Implementing both sides of a conflict with a prior decision       | That is not a fix, it is a second decision made without the person who made the first. Escalate.                                         |
| Answering a review item by changing what the reviewer asked about | Answer what was raised. Rewriting the surrounding code to make the finding moot is scope growth wearing a fix as a disguise.             |
