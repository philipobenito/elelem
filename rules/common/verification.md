# Verification

## The iron law

**You MUST NOT claim work is complete, fixed, passing, working, verified or
ready without evidence that the relevant check succeeded against the inputs
being claimed.**

Verification evidence is based on input validity, not conversational turns. A
gate must identify the exact command and arguments, working directory, checked
scope, relevant input identities, material environment and resource assumptions,
actual captured output and exit status, accessible provenance, and verifier
identity and independence. Relevant inputs include source, tests, configuration,
dependencies, fixtures and generated inputs, including dirty and untracked
contents. Use the baseline and accepted checkpoints or equivalent identity
evidence; a commit identity alone does not establish dirty-input identity.

The current gate must locate actual execution evidence and validate its scope,
input identities, provenance and assumptions. If they still match, the gate may
reuse the captured output across messages or resumed sessions. A new message or
resumed session alone does not invalidate evidence. Cite reused output as prior
execution, not as newly executed. If evidence is missing, inaccessible,
incomplete, or its relevant input or mutable resource equivalence is uncertain,
run the affected check. If the dependency scope is unknown, rerun conservatively.
Relevant changes invalidate affected evidence. Demonstrably unrelated changes
preserve unaffected evidence.

A worker report, self-report, review verdict, markdown structure check or belief
is not execution evidence and cannot replace required independent inspection or
checks. Final integrated checks cover combined settled inputs after relevant
writers, pruning edits and review corrections; matching evidence for those exact
inputs may be revalidated and reused.

If the user explicitly skips verification, record the exact scope, reason and
consequence. Mark it skipped and unverified, never passed or verified. You may
report that the requested workflow stopped with a verification phase skipped,
but must explicitly qualify the result as unverified and must not call the
work fixed, passing, complete or ready. A skip cannot waive this iron law or
authorise a misleading claim.

## Scope of claims

This rule applies to every statement that asserts or implies success, including
direct, hedged and implicit claims. Examples include tests passing, a build
succeeding, work being done or ready, a bug being fixed, a requirement being
met, or handing control back in a way that implies success. Do not evade this
rule by choosing different wording.

## When the rule fires

Use the verification gate before:

- Committing, pushing, opening or updating a pull request
- Claiming a task or subtask is complete
- Moving to the next task in a sequence
- Handing control back with any implication of success
- Accepting a subagent's report that it succeeded; inspect the diff and require
  applicable independent checks
- Stating that a bug is fixed, a regression is closed or a requirement is met

Invoke `verification-before-completion` for the verification procedure. It must
identify the claim and check, locate actual output, validate input-based
continued validity or execute the check, read and compare the output, then cite
the result and whether it was reused or newly run. In coordinated work,
task-local checks use stable inputs; broad checks wait until all relevant
writers stop. Explicitly skipped checks remain unverified.
