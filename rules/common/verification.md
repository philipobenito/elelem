# Verification

## The Iron Law

**You MUST NOT claim work is complete, fixed, passing, working, or ready without fresh verification evidence produced in the current message.**

"Fresh" means the verification command was run after the last change you made to the code it verifies. A run from a previous message, a previous task, or before your most recent edit does **not** count.

"Evidence" means the command's actual output: exit code, pass/fail counts, build status. Your belief that the command would pass is not evidence.

If you have not run the verification command in the current message, you **MUST NOT** state or imply that the work is done.

## Scope: What Counts as a Completion Claim

This rule applies to every statement that asserts or implies success, including but not limited to:

- Direct claims: "tests pass", "build succeeds", "it works", "fixed", "done", "complete", "ready"
- Satisfaction language: "Great!", "Perfect!", "All good", "Looks good"
- Hedged claims: "should pass", "should work now", "probably fine", "seems to work"
- Implicit claims: moving to the next task, committing, opening a PR, handing back to the user, marking a todo complete
- Paraphrases and synonyms belonging to any of the above

You **MUST NOT** evade this rule by choosing different wording. Spirit over letter. If the reader could take your message to mean the work is done, the rule applies.

## When the Rule Fires

You **MUST** run fresh verification before any of:

- Committing, pushing, opening, or updating a pull request
- Claiming a task, subtask, or todo is complete
- Moving on to the next task in a sequence
- Handing control back to the human partner with any implication of success
- Accepting a subagent's report that it succeeded (see `subagents.md`: trust nothing, verify the diff)
- Stating that a bug is fixed, a regression is closed, or a requirement is met

## Procedural Rules and Procedure

The procedural rules that bind once the `verification-before-completion` skill is running, the common-failures table, the rationalisation prevention table, and the red-flags stop list, live in `skills/verification-before-completion/RULES.md` and load when the skill is invoked. The executable Gate Function lives in `skills/verification-before-completion/SKILL.md`.
