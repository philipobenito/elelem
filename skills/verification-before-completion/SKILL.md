---
name: verification-before-completion
description: Runs the gate function that validates or executes checks against current relevant inputs before a completion claim. Reads actual output, compares it with the claim, and cites evidence with its reuse status.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Verification Before Completion

The iron-law rules (the iron law itself, what counts as a completion claim, when the rule fires) live in `../../rules/common/verification.md`. The procedural rules that bind once this skill is running (the common-failures table, the rationalisation prevention table, the red-flags stop list) live in `RULES.md` alongside this file. This skill is the procedure that produces the evidence those rules require.

Before running the gate function below, you **MUST** read `RULES.md` (sibling file in this skill directory) using the Read tool if you have not already read it in this session.

## The Gate Function

Run these steps in order for every claim. Skipping any step means the gate has
not been passed, and you **MUST NOT** state the claim.

1. **Identify the claim and check.** Name the exact command and arguments,
   working directory and checked scope that would prove the claim. Identify
   relevant source, test, configuration, dependency, fixture and generated
   inputs, including dirty and untracked contents, as well as material
   environment and mutable resource assumptions. A commit identity alone does
   not establish dirty-input identity.
2. **Locate and validate execution evidence.** Find actual captured output,
   exit status, accessible provenance, verifier identity and independence. Check
   that the evidence covers the identified scope and that relevant input
   identities and assumptions still match. A new message or resumed session
   alone does not invalidate matching evidence. Demonstrably unrelated changes
   preserve unaffected evidence.
3. **Run or revalidate.** If matching evidence is available, revalidate it for
   this claim and retain its original execution identity. If evidence is
   missing, inaccessible, incomplete, or input or mutable resource equivalence
   is uncertain, execute the affected check. Rerun conservatively when the
   dependency scope cannot be established.
4. **Read and compare.** Read the actual output and exit status, including
   relevant counts and errors, then compare them with the exact claim. A worker
   report or self-report cannot replace required independent diff inspection or
   checks. Final integrated verification covers combined settled inputs after
   relevant writers, pruning edits and review corrections. Matching evidence
   for those exact inputs may be revalidated and reused; task-local output is
   not a substitute.
5. **Cite the evidence.** State the command, scope, result and accessible output
   reference, and say whether the output was reused or newly executed. Never
   describe reused output as newly run. A claim without cited evidence has not
   passed the gate.

If step 4 fails, you **MUST** state the actual status with the evidence, not the claim you hoped to make.

## Worked Examples

### Tests

1. Identify: `uv run pytest tests/test_widget.py -x`, its working directory,
   test scope and relevant input identities.
2. Locate actual output and validate its provenance and current input identities.
3. Reuse the matching output if still valid, or execute the test if not.
4. Read `12 passed in 0.43s`, exit 0, and compare it with the claim.
5. State whether the output was reused or newly run, citing the command and
   accessible output.

Incorrect: claiming a reused check was newly executed, or citing no output and
input-validity evidence.

### Build

1. Identify: `pnpm build`
2. Locate its actual output and validate provenance and current input identities.
3. Reuse matching output or execute the build if evidence is missing or invalid.
4. Read: exit 0, no TypeScript errors, bundle emitted
5. Compare the output with the claim and state whether it was reused or newly run.

Incorrect: "Linter passed, build should be fine." The linter is not the build.

### Regression Test for a Bug Fix

See `../../rules/common/testing.md` for the full red-green rules. The verification-layer procedure is:

1. Identify the reproducing test, its relevant inputs and the intended defect.
2. Validate the original observed RED output and the current GREEN output. The
   RED must be an intended failure, not a syntax, import or unrelated error;
   the GREEN must exercise a materially equivalent test and current relevant
   implementation, with a supported relationship between the correction and
   the observed defect. The RED and GREEN intentionally refer to different
   production revisions.
3. If the original RED is missing or questionable, seek an authorised safe,
   isolated counterfactual or equivalent regression demonstration. Do not
   disturb unrelated work or assume a universal revert/restore procedure. If a
   safe demonstration is unavailable or unauthorised, block the regression
   coverage claim.
4. Cite both actual outputs, their input identities and provenance, or report
   that the claim is blocked. A current GREEN alone does not prove the intended
   regression was exercised.

### Subagent Handback

1. Identify the VCS diff command and the verification claims in the task brief.
2. Inspect the actual diff and validate the reported check's execution identity,
   scope, provenance and independence. Worker self-reports never establish
   independent verification.
3. Reuse matching independent evidence after input validation, or execute the
   required independent checks against stable current inputs.
4. Compare the changes and evidence with the task contract. Cite original output
   and whether it was reused or newly executed. See
   `../../rules/common/subagents.md`.

### Requirements Checklist

1. Identify: the approved design, epic body, or ticket containing the acceptance criteria
2. Run: read the criteria line by line, compare each to the current state of the code or behaviour
3. Read: note which criteria are met, which are partial, which are missing
4. Compare: the claim "requirements met" requires every criterion to be met
5. State: either a full checklist with each criterion marked met with its evidence, or a gap report naming what is missing

"Tests pass, so the requirements are met" is not enough. Tests verify the tests; the checklist verifies the requirements.

## Completion Gate

You have passed the gate for a given claim only if, in the current gate:

- You named the exact command, working directory, scope and relevant inputs
- You located and validated actual execution evidence against those inputs
- You ran the affected check when evidence or input equivalence was uncertain
- You read and compared actual output and exit status
- You cited the evidence and identified it as reused or newly executed
- The output proves the exact claim
- Any required independent and final integrated checks cover their specified inputs

Any other state is a gate failure. On a gate failure, you **MUST NOT** make the claim. Correct the evidence gap, rerun affected checks when required, or report the actual status honestly.
