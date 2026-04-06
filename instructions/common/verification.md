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

## Common Failures

| Claim                  | Required evidence                                       | Not sufficient                         |
|------------------------|---------------------------------------------------------|----------------------------------------|
| Tests pass             | Test command output in this message, exit 0, 0 failures | Previous run, "should pass", linter ok |
| Linter clean           | Linter output in this message, 0 errors, 0 warnings     | Partial file check, extrapolation      |
| Build succeeds         | Build command output in this message, exit 0            | Linter passing, logs "look fine"       |
| Bug fixed              | Failing test now passes; see `testing.md` for red-green | Code changed, assumed fixed            |
| Regression test works  | Red-green cycle executed per `testing.md`               | Test passed once after the fix         |
| Subagent task complete | VCS diff inspected, verification commands re-run        | Subagent's own "success" report        |
| Requirements met       | Line-by-line checklist against the approved design      | Tests passing in general               |

## Rationalisation Prevention

Every excuse below means **stop and run the verification**:

| Excuse                                    | Reality                                               |
|-------------------------------------------|-------------------------------------------------------|
| "It should work now"                      | Run the verification. "Should" is not evidence.       |
| "I'm confident"                           | Confidence is not evidence.                           |
| "Just this once"                          | No exceptions.                                        |
| "The linter passed"                       | The linter is not the compiler and not the tests.     |
| "The subagent said it succeeded"          | Verify independently. See `subagents.md`.             |
| "I'm tired"                               | Exhaustion is not an exemption.                       |
| "A partial check is enough"               | Partial checks prove nothing about the whole.         |
| "I verified earlier in the session"       | Not fresh. Run it again after the last change.        |
| "Different wording so the rule is moot"   | Spirit over letter. The rule applies to implications. |
| "The change is too small to break things" | Small changes break things. Run the verification.     |

## Red Flags: Stop Immediately

If any of the following is true, you **MUST** stop, run verification, and only then continue:

- You are about to write "should", "probably", "seems", "looks", or any hedged success wording
- You are about to express satisfaction ("Great", "Perfect", "Done") without having just read verification output
- You are about to commit, push, or open a PR without fresh verification in this message
- You are about to trust a subagent's self-report without inspecting the diff
- You are about to rely on verification output from earlier in the session
- You are about to say "just this once" or "this case is different"

## Procedure

For the executable procedure (the Gate Function), invoke the `verification-before-completion` skill. This file is the rule set the skill enforces. The rules here apply whether the skill has been invoked.
