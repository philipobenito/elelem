---
name: receiving-code-review
description: Processes incoming code review feedback by verifying each item against the codebase, clarifying anything unclear, and implementing in severity order. Enforces the forbidden-response rules and the pushback requirement when a suggestion is technically wrong.
---

# Receiving Code Review

The iron-law rules (when reviews are mandatory, forbidden response phrases) live in `../../rules/common/code-review.md`. The procedural rules that bind once this skill is running (verify before acting, clarify before partial implementation, YAGNI on "implement properly", when to push back, severity discipline, GitHub inline reply procedure) live in `../_shared/code-review.md`. This skill is the procedure that applies those rules to a concrete batch of feedback.

Before running the procedure below, you **MUST** read `../_shared/code-review.md` using the Read tool if you have not already read it in this session.

## The Response Procedure

Run these six steps, in order, on every piece of review feedback.

1. **Read the complete feedback.** Do not react, do not start implementing, do not respond. Read every item to the end.
2. **Restate or ask.** For each item, either restate the technical requirement in your own words or identify it as unclear. If any item is unclear, stop and ask for clarification before proceeding to step 3 on any item. See `../_shared/code-review.md` on partial implementation.
3. **Verify each item against the codebase.** For external reviewers, check that the suggestion is correct for this stack, does not break existing behaviour, does not conflict with a prior decision, and does not violate YAGNI on unused code. For your human partner, trust the correctness but still confirm the scope.
4. **Evaluate.** For each item, decide: accept and implement, push back with technical reasoning, or ask a follow-up question. See `../_shared/code-review.md` for the conditions under which pushback is mandatory.
5. **Respond.** State the decision per item: the fix you will make and where, the question you need answered, or the technical reason you are pushing back. Forbidden responses are listed in `../../rules/common/code-review.md`.
6. **Implement in severity order.** Clarify anything still unclear first. Then fix blocking issues (Critical, breakage, security), then simple fixes (typos, imports), then complex fixes (refactors, logic). Test each fix individually and confirm no regressions before moving to the next.

## Source-Specific Procedure

### From your human partner

- Trusted source. Skip the codebase-verification step in 3; go straight to clarifying scope if needed, then implement.
- Still forbidden: performative agreement, thanks, "you're absolutely right".
- If the partner's instruction conflicts with something you observed in the code, state the observation and ask rather than silently reinterpreting.

### From external reviewers (including subagent reviewers and bots)

- Not trusted by default. Every item goes through step 3 verification.
- Run `grep`, read the referenced files, check test coverage, check version and platform constraints before accepting a suggestion.
- If a suggestion conflicts with an architectural decision your human partner previously made, stop and escalate to the partner before implementing either side.
- If you cannot verify an item without more information, state the limitation explicitly: "I cannot verify this without X. Should I investigate, ask, or proceed?"

## Worked Examples

### Performative vs technical

Reviewer: "Remove the legacy code path."

Forbidden: "You're absolutely right! Let me remove that now."

Correct: "Checking. The build target is macOS 10.15+; the non-legacy API requires 13+. The legacy path is needed for backward compatibility. The current legacy branch uses the wrong bundle ID. Fix the bundle ID or drop pre-13 support and delete the legacy path. Which?"

### YAGNI on "implement properly"

Reviewer: "Implement proper metrics tracking with a database, date filters, and CSV export."

Correct: "Grepped the codebase. Nothing calls the `/metrics` endpoint. Proposing removal under YAGNI. Is there usage I am missing?"

### Unclear item in a batch

Partner: "Fix items 1 through 6."

You understand 1, 2, 3, and 6. You do not understand 4 and 5.

Forbidden: implement 1, 2, 3, 6 now and ask about 4, 5 later.

Correct: "I understand items 1, 2, 3, 6. I need clarification on items 4 and 5 before implementing any of them in case they are related."

### Gracefully correcting your own pushback

You pushed back on a suggestion. After further checking, the reviewer was right.

Correct: "Verified. You were right: `foo()` does propagate the cancellation token when called from the async path. My initial reading missed the wrapper in `bar.ts:88`. Implementing."

Forbidden: long apology, re-litigation of why you pushed back, over-explanation.

### GitHub inline reply

An inline comment exists on `widget.ts:42` in PR #123.

Correct: `gh api repos/{owner}/{repo}/pulls/123/comments/{comment_id}/replies -f body='Fixed in widget.ts:42. Bundle ID guard added and tested against 10.15 and 13.'`

Forbidden: top-level PR comment that references the line in prose.

## Escape Hatch

If you are uncomfortable pushing back out loud, signal with the phrase "Strange things are afoot at the Circle K". Your human partner will pick up on it and open the conversation for you. This does not exempt you from the pushback requirement in `../_shared/code-review.md`; it routes the pushback through a different channel.
