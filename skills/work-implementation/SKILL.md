---
name: work-implementation
description: Implements an approved design by sizing it against six evidence criteria, decomposing it into file-disjoint tasks, and running implementation, per-task review and verification concurrently through the workflow script shipped with this skill, with the lead keeping sole authority over commits, the checkpoint drain and the final feature-level review. Use this once a design is approved and it is time to build it, whether the user points at a committed specification, a design settled earlier in the conversation, or one recovered from a ticket, and asks to implement, build, or start on it. Covers everything from a uniformly simple batch of edits to a multi-task feature; without an approved design, capture one first. Stops and reports when a required capability is unavailable.
---

# Orchestrated Implementation

Coordination is code, not conduct: `./implementation-workflow.js` enforces the pre-flight file-disjointness check, ready-set scheduling over `blockedBy` edges, review-before-verification with an integer fix budget of two, and the seam between an agent's completion claim and a verified task, all as control flow. This file holds the judgement the script cannot: sizing, decomposition, the content of the args, the checkpoint drain, and the final gates.

## When to Run

You need an approved design: a committed specification, a design settled and approved earlier in the conversation, or one recovered from a ticket. If the design is incomplete, stop and capture the design first; decomposition cannot invent requirements the design never settled.

Coupled and strictly ordered work runs here too. Order is expressed as `blockedBy` edges between tasks, not as a reason to work some other way.

## Capability Gate

Confirm the `Workflow` tool is available before anything else. If it is not, run the same per-task pipeline sequentially through one-shot `Agent` dispatches, implement, review, verify per task in dependency order, using the prompts embedded in the script as the briefs and holding the fix budget as a counted number in your response text. What is lost is concurrency, not safety. If `Agent` is also unavailable, stop: name the missing capability, state that nothing has been written to the tree, and say what would make the run possible.

## Commit Preference

Ask the user once, with `AskUserQuestion`, how commits should be handled. The choice is session-wide.

- **Auto-commit at the drain**: each verified task is committed as it drains, in board order, with its summary, scoped diff and verification evidence shown but no confirmation sought.
- **Ask me each time**: each drained task waits for the user's answer before committing.

State inside the option text that the drain happens after the workflow completes, not while it runs: implementation, review and verification proceed concurrently in the background either way.

## Sizing

Size the whole design once, before decomposing, by reading the affected code and filling every row of this table with specific observations. The default is COMPLEX; SIMPLE is earned, never assumed.

| #   | Criterion                      | Definition                                                                               | Fails if                                                                                                         |
|-----|--------------------------------|------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|
| 1   | **Uniform change type**        | Every change is the same kind of edit applied across locations                           | Changes mix different concerns (e.g. docs + feature code, config + new logic)                                    |
| 2   | **No new logic**               | Zero new functions, classes, conditionals, loops, error handling, or business rules      | Any new control flow or callable unit is introduced                                                              |
| 3   | **No new interfaces**          | No new exports, API endpoints, contracts, events, or public surface area                 | Any new public-facing surface is created                                                                         |
| 4   | **Deterministic from spec**    | The correct change at each location is fully specified with no room for interpretation   | Any change requires a design decision, judgement call, or contextual understanding beyond the immediate edit     |
| 5   | **Independently verifiable**   | Each change can be verified by reading it in isolation                                   | Correctness of one change depends on another change elsewhere in the change set                                  |
| 6   | **Small total delta**          | 39 lines or fewer of substantive change across all files, counted rather than felt       | The count is 40 or more, or cannot be produced at all                                                            |

Count each changed line once rather than once per diff side: a one-line string replacement is 1 line, not 2, though `git diff --stat` reports it as 2. Where a contiguous run of changed lines is replaced by a run of a different size, count the larger of the two sides, and sum those counts across every such run in every file. Whitespace-only and comment-only lines are not substantive. The threshold is 39 rather than a round 50 because the 40 to 50 band is rejected deliberately: estimation error at a boundary that close exceeds the margin it decides, so push it to COMPLEX and lose nothing.

Evidence discipline: a row passes on a specific observation from code you read ("all 6 files: replace version string '2.3.0' with '2.4.0' in the docstring header"), never on a restatement of the criterion. A qualifier attached to a verdict ("mostly uniform") is a failure; a qualifier attached to a measurement ("approximately 18 lines") is evidence with stated precision. If classifying takes investigation, tracing call graphs rather than counting edits, that difficulty is the verdict: COMPLEX.

Present the table to the user, then act on it without pausing for approval; the user outranks the verdict and an override is honoured whenever stated. Overriding COMPLEX to SIMPLE carries the risk, so the failing rows travel intact into the task's spec, where the reviewer's sizing re-check can still catch them.

- **All six pass: SIMPLE.** The run is a single task holding the whole batch, with `simple: true` in the args. The script swaps the test-first requirement for a carve-out (criterion 2 means no observable behaviour, so there is nothing for a new test to cover), requires the implementer to state outright whether behaviour was introduced, and has the reviewer re-check the sizing against the real diff, which is stronger evidence than the prediction.
- **Any failure: COMPLEX.** Decompose below, with `simple: false`. Do not re-size the resulting tasks; the verdict covers the whole change set once.

If the run later reports `sizingFalsified`, the prediction was wrong and the falsification is the stronger evidence: re-enter at Decomposition with COMPLEX fixed, and settle the partial work first per Failure Handling below.

## Decomposition

Map out which files will be created or modified and what each is responsible for before writing any args. Each task is a self-contained unit producing working, testable code: a focused set of files, ideally one to three, each with one clear responsibility; acceptance criteria derivable from the design; verifiable independently of every other task.

Express every ordering constraint as a `blockedBy` edge. Two tasks need an edge whenever they share anything mutable, not only source files: a shared port, a test database, a generated artefact, a lockfile or a cache is as much a collision as a shared file, and the script's disjointness assertion cannot see any of them. Name shared and aggregator files explicitly, a barrel export, an index, a shared config, and assign each to exactly one task's `files` set; a task that only reads a shared file does not own it.

**Isolation instead of serialisation.** Where two source-disjoint tasks would need an edge only because they contend on a shared mutable artefact, mark them `isolated: true` instead. The script dispatches an isolated task's implementer into its own git worktree, and its reviewer and verifier follow it there, so the contention disappears and the tasks run concurrently. The cost lands on you at the drain: an isolated task's changes sit in its worktree until you bring its owned files into the main tree, and the reconcile sweep legitimately does not see them. Isolation requires the target repository to be the session repository, and it converts a collision into merge work rather than removing it, so genuinely overlapping source sets still take an edge.

Record `HEAD` at launch as `baseSha` in the args. It is the commit the whole feature is measured against and the final review's range start; it is never rewritten, whatever is re-queued or relaunched.

## Constructing the Args

The args are the entire world each agent sees; the script pastes them into prompts and nothing else reaches a dispatched agent. Construct them once, write the canonical copy to a scratch file, and pass that content verbatim on every launch and resume: rebuilding args by hand is how a quoting slip silently changes a spec and re-runs finished work. The field list and each field's meaning are documented at the top of `./implementation-workflow.js`; read it there rather than from a summary here.

Two fields carry judgement:

- **Each task's `spec`** is the full text the implementer works from: scene-setting for where it fits, the responsibility of each file, and the acceptance criteria as prose. Paste content, never a file reference. `verifyCommand` is the task-scoped test command, checked against how the project actually invokes its runner: a plausible-looking but wrong invocation fails every verification it gates.
- **The three model fields** name concrete models confirmed to exist in the current environment (enumerate what the harness exposes; never construct an identifier from a remembered pattern). Implementers start at the tier the task signal names: clearly specified few-file work low, multi-file integration mid. The reviewer **MUST NOT** run at a lower tier than the work it reviews, because a reviewer that misses a real defect is the most expensive failure this pipeline can produce. Verifiers run commands and report facts; the low tier is enough.

## Launch and Results

Launch with `Workflow`, passing `scriptPath` pointing at `./implementation-workflow.js` beside this file, and the args. The run is background work; continue only when its result returns.

Read the result mechanically: `state[id].verified` is true only when both gates passed; `results[id].failure` names what stopped a failed task; `unreachedTasks` lists tasks quarantined behind a failure, which is the scheduler working, not an error to route around; `rogueChanges` lists changed paths owned by no task and **MUST** be empty, or explained to the user, before anything commits. Resuming with `resumeFromRunId` and the verbatim args replays completed agents from cache and re-runs only what changed.

## The Drain

Verified tasks drain through the user checkpoint one at a time, in board order: topological by `blockedBy`, ties broken by index in the decomposition. The order is deterministic so the same design produces the same sequence of questions regardless of which task finished first.

For each drained task present: what was implemented and what the reviewer found, including deferred Minor findings; the verification evidence with commands, exit codes and counts; the RED to GREEN evidence, or the behaviour statement on a SIMPLE run; and a `git diff` scoped to the task's `files`, because an unscoped diff would show other tasks' work as though it were this one's. For an isolated task, first bring its owned files from the worktree named in its result into the main tree, then present and commit as normal, and remove the worktree once its task has committed.

Then commit scoped to the task's `files`, or ask first under "ask me each time" with options "Commit", "Adjust first" and "Skip commit":

- **Adjust first.** Take the user's change and run it as a follow-up single-task launch of the same script against the same `baseSha`, on a fresh budget: a user adjustment is a new instruction, not a failed fix. Tasks not behind it keep draining.
- **Skip commit.** Every task transitively `blockedBy` the skipped one is named at that moment and held out of the drain permanently; the rest drain, then the run stops with the Stop Report.

## Failure Handling

- **The script throws at pre-flight.** The decomposition contains an ownership overlap; fix the decomposition. Nothing was dispatched.
- **A task failed on its fix budget.** Two round-trips were spent and the gate still failed. Do not relaunch for a third round, and do not repair the files yourself: a lead patching a delegated agent's output destroys the isolation that makes the review evidence trustworthy. Drain what verified, then stop and report.
- **A dispatch died** (`failure` says so). Resume with `resumeFromRunId` and the verbatim args; only the dead call and its dependents re-run.
- **`sizingFalsified` is true.** The SIMPLE prediction was wrong. The implementer's partial edits are uncommitted in the tree, and discarding changes to tracked files is destructive, so the decision is the user's: ask with options "Keep the changes and decompose around them", "Discard the changes and start clean" and "Show me the diff first", then re-enter at Decomposition with COMPLEX fixed.
- **Every stop reports the same five things**: which tasks committed, with SHAs; which verified but did not commit; which failed, and how; what is quarantined behind them, including unreviewed edits still in the tree or in worktrees; and whether anything remains uncommitted. Never phrase a stop report in an agent's claimed terms; only a verified task with a commit is done.

## Final Feature-Level Review

Once every task has drained and `rogueChanges` came back empty:

1. **Request a code review of the feature as a whole**, over the range starting at `baseSha`. The per-task reviewers each saw one task; integration gaps, drifting names and inconsistent error handling only appear across task boundaries, so this review finds what no earlier gate could. Fix and re-review until no Critical or Important issue remains.
2. **Verify completion yourself, in the message that claims it**: the full suite, the linter, the build, and anything the design called out, with the output cited.
3. **Report completion**: tasks, review verdict, verification evidence, deferred Minor findings.

You **MUST NOT** report the feature complete without steps 1 and 2 having run, with step 1 ending Approved.

## Common Mistakes

| Mistake                                                          | Why it is wrong                                                                                                            |
|------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| Re-authoring the control flow per run instead of passing args    | The shipped script is the tested invariant carrier; a fresh script is untested control flow with none of its guarantees.   |
| Referencing files in a spec instead of pasting content           | The args are the whole world an agent sees; a reference points at nothing it can be assumed to read.                       |
| Hand-rebuilding args for a resume                                | A quoting slip silently changes a prompt, and the cache correctly treats it as new work. Pass the canonical copy.          |
| Committing with `rogueChanges` non-empty                         | Those paths belong to no task: unowned, unreviewed edits would ride along inside a scoped commit's blast radius.           |
| Draining out of board order                                      | The question sequence becomes a race on which agent finished first, and a dependent can commit before its dependency.      |
| Patching a failed task's files in the lead context               | It destroys the isolation that makes the review evidence trustworthy, and hides the failure the stop report must name.     |
