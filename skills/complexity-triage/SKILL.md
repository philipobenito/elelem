---
name: complexity-triage
description: Classifies one approved design as SIMPLE or COMPLEX so an orchestrator knows whether the fast path is open. Invoked by `subagent-driven-development` and `team-driven-development` before task decomposition, and required by `fast-path-implementation` as its precondition. Reads the affected code to gather evidence against six binary criteria. Defaults to COMPLEX; SIMPLE must be earned with specific observations.
---

# Complexity Triage

Classify an approved design as SIMPLE or COMPLEX so the caller knows which implementation path to take. The default is COMPLEX. SIMPLE is not a shortcut; it is a conclusion reached only after every criterion passes with specific evidence.

The strictness is calibrated to what SIMPLE unlocks. `fast-path-implementation` collapses an entire design into one implementer dispatch, one review, and one checkpoint. That is the right shape for a batch of mechanical edits and the wrong shape for anything needing a decision made partway through.

## Preconditions

An approved design, from the `brainstorming` router via any of its modes, from `work-on-ticket`, or from a committed specification. This skill runs inside the orchestrator (`subagent-driven-development` step 2, or the equivalent step in `team-driven-development`), not before it.

Triage runs **once, against the whole design**, never per task. Criterion 1 asks whether the entire change set is one uniform batch, so a design holding two different kinds of edit fails it by construction. Once the verdict is COMPLEX, decomposition is the response to that verdict rather than an invitation to re-ask the question of each resulting task.

## Procedure

1. **List the change set.** From the design, name every file to be created or modified and what changes in each. If the design does not name files, derive the list in step 2.

2. **Read the affected code.** A classification made from the design text alone is a prediction about code you have not opened. Criterion 6 cannot be answered without seeing the lines that will change, and a `brainstorming-skip` design carries no file-level detail at all, so on that route this step is the only source of evidence there is.

   The reading is bounded by its own purpose: enough to fill every evidence cell, no further. If you find yourself tracing call graphs or reasoning about runtime behaviour rather than counting and comparing edits, stop. That difficulty is the verdict. Work that takes investigation to classify is COMPLEX, so record it and move on.

3. **Fill in every row of the evidence table** before writing any classification. Reaching a verdict first and justifying it backwards is how a table of six criteria decays into a formality.

4. **Classify.** All six pass, SIMPLE. Any single failure, COMPLEX.

5. **Present the table to the user**, then return the result to the caller per the Return Contract. Presentation belongs to this skill, so callers do not repeat it.

## The Criteria

**ALL** criteria must be true for the classification to be SIMPLE. A single failure means COMPLEX, no exceptions.

| # | Criterion                    | Definition                                                                             | Fails if                                                                                                     |
|---|------------------------------|----------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| 1 | **Uniform change type**      | Every change is the same kind of edit applied across locations                         | Changes mix different concerns (e.g. docs + feature code, config + new logic)                                |
| 2 | **No new logic**             | Zero new functions, classes, conditionals, loops, error handling, or business rules    | Any new control flow or callable unit is introduced                                                          |
| 3 | **No new interfaces**        | No new exports, API endpoints, contracts, events, or public surface area               | Any new public-facing surface is created                                                                     |
| 4 | **Deterministic from spec**  | The correct change at each location is fully specified with no room for interpretation | Any change requires a design decision, judgement call, or contextual understanding beyond the immediate edit |
| 5 | **Independently verifiable** | Each change can be verified by reading it in isolation                                 | Correctness of one change depends on another change in a different file                                      |
| 6 | **Small total delta**        | 50 lines or fewer of substantive change across all files, counted rather than felt     | The count exceeds 50, lands between 40 and 50, or cannot be produced at all                                  |

Criterion 6 rejects the 40 to 50 band deliberately. Estimation error at the boundary is larger than the margin, so a count that close is not deciding the verdict, the estimate is. Push it back to the full path and lose nothing.

Criterion 2 has a consequence worth stating outright: SIMPLE work changes no observable behaviour. It follows that there is no new behaviour for a test to cover, which is why the failing-test-first requirement in `../../rules/common/testing.md` produces no test work on this path. The reverse holds as a signal: an implementer reporting new behaviour on the fast path has demonstrated the triage was wrong, whatever the table said.

## Presenting the Evidence

Present the triage table before the caller acts on it. The user needs to see the reasoning, and this is where an override becomes possible.

Format:

```
Complexity Triage

| # | Criterion                | Evidence                          | Pass |
|---|--------------------------|-----------------------------------|------|
| 1 | Uniform change type      | [specific observation]            | Y/N  |
| 2 | No new logic             | [specific observation]            | Y/N  |
| 3 | No new interfaces        | [specific observation]            | Y/N  |
| 4 | Deterministic from spec  | [specific observation]            | Y/N  |
| 5 | Independently verifiable | [specific observation]            | Y/N  |
| 6 | Small total delta        | [line count with counting method] | Y/N  |

Classification: SIMPLE / COMPLEX
Justification: [one sentence]
```

## Evidence Standards

The evidence column **MUST** contain specific observations from the code you read, not restatements of the criterion.

Rejected as insufficient evidence (the criterion fails):

- "Changes are uniform" (restates the criterion, says nothing specific)
- "No significant new logic" (the qualifier "significant" reveals ambiguity)
- "Scope is small" (no numbers, no reasoning)

Acceptable:

- "All 6 files: replace version string '2.3.0' with '2.4.0' in the module docstring header"
- "Zero new functions, conditionals, or loops; each change is a string literal replacement"
- "Approximately 18 lines total: 6 files x 3 lines each (version, date, changelog link)"

If a criterion needs qualifying language ("mostly", "generally", "essentially", "largely", "primarily") to pass, the criterion fails. The fast path exists for work that is unambiguously simple.

Numeric approximation is not hedging, and the distinction is what the qualifier attaches to. "Approximately 18 lines" qualifies a measurement and states its precision, which is exactly what criterion 6 asks for. "Mostly uniform" qualifies the verdict itself and so reports that the criterion does not cleanly hold. The first is evidence; the second is the absence of it.

## Reclassifying During Implementation

A triage verdict is a prediction made before the code exists. Two things can falsify it once implementation starts, and both end the fast path.

- **The reviewer reports `TRIAGE_INVALID`.** The combined reviewer dispatched by `fast-path-implementation` re-checks the classification against the actual diff and names the criterion that failed (see `../fast-path-implementation/fast-path-reviewer-prompt.md`). This check is stronger than the one in this skill, because it reads code that exists rather than predicting code that does not, and it is run by an agent with no stake in the answer. It is a stop, not an advisory.
- **The orchestrator sees it directly.** If the work is plainly more complex than the table concluded, stop without waiting for a reviewer to say so.

Either route ends the same way: reclassify as COMPLEX and hand back to `subagent-driven-development` for re-decomposition. The sunk cost of the interrupted attempt is negligible, because nothing is committed before the fast path's checkpoint, and it is far cheaper than pushing complex work through a review shaped for mechanical edits.

## Return Contract

This section is addressed to whichever skill invoked this one. It lives here rather than being restated in each caller because invoking this skill is what loads the file, so the caller holds the text at the moment it needs it.

**SIMPLE.** The caller receives the classification and the completed evidence table, and hands off to `fast-path-implementation`. The table travels with the handoff, because `fast-path-reviewer-prompt.md` asks for it by name so the reviewer can re-check the classification against the diff.

**COMPLEX.** The caller receives the classification and the table, and continues with its own task decomposition. The caller **MUST NOT** re-invoke this skill against the resulting tasks; see Preconditions for why.

**User override.** The user outranks this skill (see Instruction Priority in `../../rules/common/skills-policy.md`), so a user who directs a different path gets it. Overriding SIMPLE to COMPLEX needs no justification, since it moves to the more careful path. Overriding COMPLEX to SIMPLE is the direction carrying risk, so the table travels **with its failing rows intact** rather than being rewritten to agree with the user. The fast-path reviewer then sees exactly which criterion was set aside and can report `TRIAGE_INVALID` against it. The caller records the override when handing off.

**Presenting is not a blocking question.** Present the table and continue rather than stopping for approval. The user's window to redirect stays open because nothing is committed before the fast path's own checkpoint, and pausing on every design would tax every caller for a verdict that is usually uncontroversial.

## Worked Example: SIMPLE

```
Complexity Triage

| # | Criterion                | Evidence                                                                        | Pass |
|---|--------------------------|---------------------------------------------------------------------------------|------|
| 1 | Uniform change type      | All 8 files: replace "Copyright 2025" with "Copyright 2026" in file header      | Y    |
| 2 | No new logic             | Zero new functions or control flow; each change is a string literal replacement | Y    |
| 3 | No new interfaces        | No new exports, APIs, or contracts                                              | Y    |
| 4 | Deterministic from spec  | Design lists exact files and exact old/new strings                              | Y    |
| 5 | Independently verifiable | Each file's header change is self-contained                                     | Y    |
| 6 | Small total delta        | 8 lines: grepped the header string, 1 match per file across 8 files             | Y    |

Classification: SIMPLE
Justification: Identical string replacement across 8 independent files with zero logic changes.
```

## Worked Example: COMPLEX on One Criterion

Renaming the environment variable `API_TIMEOUT` to `API_TIMEOUT_MS` across 9 files looks like the same shape of work as the example above, and five criteria agree. Reading the files is what separates them.

```
Complexity Triage

| # | Criterion                | Evidence                                                                             | Pass |
|---|--------------------------|--------------------------------------------------------------------------------------|------|
| 1 | Uniform change type      | All 9 files: replace the literal "API_TIMEOUT" with "API_TIMEOUT_MS"                 | Y    |
| 2 | No new logic             | Zero new functions or control flow; every change is a string literal replacement     | Y    |
| 3 | No new interfaces        | No new exports or endpoints; the variable itself already exists under the old name   | Y    |
| 4 | Deterministic from spec  | Design lists all 9 files and the exact old and new names                             | Y    |
| 5 | Independently verifiable | deploy/env.template declares the name and src/config.ts reads it; either change      | N    |
|   |                          | alone leaves config reading undefined at boot, so neither verifies in isolation      |      |
| 6 | Small total delta        | 9 lines: grepped the identifier, 1 match per file across 9 files                     | Y    |

Classification: COMPLEX
Justification: Criterion 5 fails; the declaration and the read must land together, so no single change can be verified on its own.
```

This is the case the skill exists for. The work is small, mechanical, and fully specified, and it still belongs on the full path because a coupled pair of changes is exactly what a single batched review is worst at catching. Five passes is not a score, and there is no partial credit.

## Red Flags

Every thought below means stop:

- "This is mostly uniform" or any other qualifier attached to a verdict rather than a measurement
- You want SIMPLE because the full path feels like a lot of ceremony for this change
- You are defaulting to SIMPLE. COMPLEX is the default; SIMPLE must be earned.

## Common Mistakes

| Mistake                                                     | Why it is wrong                                                                                                                                          |
|-------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Classifying from the design text without opening a file     | Criterion 6 needs a count, and a skip-mode design carries no file detail at all. A verdict reachable without reading code is a guess dressed as a table. |
| Re-running triage on each task after a COMPLEX verdict      | The verdict covers the whole change set. Criterion 1 already asked whether it is one uniform batch; decomposition answers that, it does not re-open it.  |
| Rounding a 48-line estimate down to pass criterion 6        | The estimate's error bar is wider than the margin, so the count is not what decided the verdict. The band exists to keep guesswork out of the boundary.  |
| Treating the reviewer's `TRIAGE_INVALID` as advisory        | The reviewer read the diff; this skill only predicted it. The stronger evidence wins, and it arrives before anything is committed.                       |
| Rewriting a failing row to agree with a user's SIMPLE call  | The override is the user's to make, but erasing the failure hides it from the reviewer who could still catch it. Carry the row; record the override.     |
| Presenting the table after the implementer is already going | The user's chance to redirect is worth nothing once the work is under way. Presentation is a step in the procedure, not a report afterwards.             |
