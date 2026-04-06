---
name: complexity-triage
description: Classifies a unit of implementation work as SIMPLE or COMPLEX against six strict binary criteria with mandatory evidence. Defaults to COMPLEX; SIMPLE must be proven with specific observations from the design.
---

# Complexity Triage

Classify a defined unit of work as SIMPLE or COMPLEX so downstream skills know which implementation path to take. The default classification is COMPLEX. SIMPLE is not a shortcut; it is a conclusion you reach only after every criterion passes with specific evidence.

## When to Run

Before dispatching implementation work through `subagent-driven-development` or any other orchestrator that offers a fast path. The input is an approved design or a well-defined change request. The output is a classification plus the evidence table, presented to the user.

## The Criteria

**ALL** criteria must be true for the classification to be SIMPLE. A single failure means COMPLEX, no exceptions.

| # | Criterion                    | Definition                                                                             | Fails if                                                                                                     |
|---|------------------------------|----------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| 1 | **Uniform change type**      | Every change is the same kind of edit applied across locations                         | Changes mix different concerns (e.g. docs + feature code, config + new logic)                                |
| 2 | **No new logic**             | Zero new functions, classes, conditionals, loops, error handling, or business rules    | Any new control flow or callable unit is introduced                                                          |
| 3 | **No new interfaces**        | No new exports, API endpoints, contracts, events, or public surface area               | Any new public-facing surface is created                                                                     |
| 4 | **Deterministic from spec**  | The correct change at each location is fully specified with no room for interpretation | Any change requires a design decision, judgement call, or contextual understanding beyond the immediate edit |
| 5 | **Independently verifiable** | Each change can be verified by reading it in isolation                                 | Correctness of one change depends on another change in a different file                                      |
| 6 | **Small total delta**        | Under roughly 50 lines of meaningful content change across all files                   | More than roughly 50 lines of substantive change                                                             |

## Presenting the Evidence

You **MUST** present the triage table before proceeding. The user needs to see the reasoning and can override the classification.

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
| 6 | Small total delta        | [line count estimate with method] | Y/N  |

Classification: SIMPLE / COMPLEX
Justification: [one sentence]
```

## Evidence Standards

The evidence column **MUST** contain specific observations from the design, not restatements of the criterion.

Rejected as insufficient evidence (the criterion fails):

- "Changes are uniform" (restates the criterion, says nothing specific)
- "No significant new logic" (the qualifier "significant" reveals ambiguity)
- "Scope is small" (no numbers, no reasoning)

Acceptable:

- "All 6 files: replace version string '2.3.0' with '2.4.0' in the module docstring header"
- "Zero new functions, conditionals, or loops; each change is a string literal replacement"
- "Approximately 18 lines total: 6 files x 3 lines each (version, date, changelog link)"

If a criterion needs qualifying language ("mostly", "generally", "essentially", "largely", "primarily") to pass, the criterion fails. The fast path exists for work that is unambiguously simple.

## Override During Execution

If during implementation (fast path or otherwise) it becomes clear the work is more complex than the triage concluded, stop immediately and reclassify as COMPLEX. Downstream reviewers recognise this as a `TRIAGE_INVALID` signal and hand the work back for re-decomposition. The sunk cost of the interrupted attempt is negligible compared to pushing through poorly reviewed complex work.

## Worked Example

```
Complexity Triage

| # | Criterion                | Evidence                                                                        | Pass |
|---|--------------------------|---------------------------------------------------------------------------------|------|
| 1 | Uniform change type      | All 8 files: replace "Copyright 2025" with "Copyright 2026" in file header      | Y    |
| 2 | No new logic             | Zero new functions or control flow; each change is a string literal replacement | Y    |
| 3 | No new interfaces        | No new exports, APIs, or contracts                                              | Y    |
| 4 | Deterministic from spec  | Design lists exact files and exact old/new strings                              | Y    |
| 5 | Independently verifiable | Each file's header change is self-contained                                     | Y    |
| 6 | Small total delta        | Approximately 8 lines total (1 line per file x 8 files)                         | Y    |

Classification: SIMPLE
Justification: Identical string replacement across 8 independent files with zero logic changes.
```

## Red Flags

Stop and reclassify (or refuse to classify) if any of the following is true:

- You are about to classify work as SIMPLE without filling in every row of the evidence table
- You are using qualifying language ("mostly", "largely", "primarily", "essentially") in any evidence cell
- You are classifying work as SIMPLE because you want to save time, not because the evidence supports it
- A reviewer has reported `TRIAGE_INVALID` and you are tempted to continue the fast path anyway
- You are defaulting to SIMPLE. COMPLEX is the default. SIMPLE must be earned.
