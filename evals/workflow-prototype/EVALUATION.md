# Workflow Prototype Evaluation

The evaluation ticket (#21) asked whether `orchestrated-implementation`'s prose protocol can be ported to a Workflow script, which of its invariants a script enforces mechanically, and whether the user checkpoint survives. This file records what was actually run and what it showed. `prototype-workflow.js` is the exact script as last executed; the fixture it ran against was a fresh git repository holding an empty Node project.

## Method

Three file-disjoint tasks implementing a small text-utils library: `t1` (word extraction, no dependencies), `t2` (slug generation, `blockedBy: [t1]`) and `t3` (word-boundary truncation, `blockedBy: [t1]`). Each task owned exactly two files, one source module and one test file. The script enforced, in code: a pre-flight pairwise-disjointness assertion that throws; a ready-set scheduler that dispatches every ready task in one `parallel()` call and treats a dependency as satisfied only on `verified`, never on a completion claim; per-task review before verification with every fix re-entering at review; an integer fix budget of two counted across both gates; schema-validated agent returns; and an end-of-run reconciliation that asserts every changed path in the real tree belongs to some task's declared set. Implementers and verifiers ran on Haiku, reviewers on Sonnet, respecting the reviewer tier floor.

Separately, two probe agents were dispatched with `isolation: "worktree"` and told to write conflicting content to the same path.

## What Ran

| Run                            | Agents   | Subagent tokens   | Wall clock   | Outcome                                                              |
|--------------------------------|----------|-------------------|--------------|----------------------------------------------------------------------|
| Main pipeline (run 1)          | 10       | 338,098           | 229s         | All 3 tasks verified, 0 fix rounds, reconcile flagged a real gap     |
| Resume (run 2, stopped)        | 4        | small             | ~40s         | Cache replay confirmed for the unchanged prefix                      |
| Feature-level review, direct   | 1        | 52,712            | 103s         | APPROVED, 3 Minor cross-boundary findings                            |
| Worktree probes                | 2        | 59,434            | 13s          | Same-path writes fully isolated, main tree untouched                 |

The main pipeline ran two waves: `t1` alone, then `t2` and `t3` genuinely in parallel. Every review returned APPROVED (one Minor deferred), every verification passed, and after the run the lead drained the checkpoint queue in board order with three commits each scoped to its task's files. The full suite passed 24/24 against the merged tree.

## Invariant Disposition

The question the ticket asked: which invariants were load-bearing, and which were compensating for prose being an unreliable execution substrate.

| Invariant (prose home)                                                                     | Disposition in the script                                                                                                                                                                                                                         |
|--------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Pre-flight file-disjointness (SKILL.md)                                                    | Enforced in code: an assertion that throws before any dispatch                                                                                                                                                                                    |
| Ready when dependencies verified, not merely completed (SKILL.md)                          | Enforced in code: the scheduler reads a `verified` flag only the gate sequence can set                                                                                                                                                            |
| Fix budget of two across both gates (SKILL.md)                                             | Enforced in code: an integer                                                                                                                                                                                                                      |
| Review before verification; fixes re-enter at review (SKILL.md)                            | Enforced in code: control-flow ordering cannot be skipped                                                                                                                                                                                         |
| `completed` is a claim, only `verified` is done (task-board.md)                            | Structural: the claim is a schema field in the agent's return; `verified` is script state no agent can write                                                                                                                                      |
| Lead-only write authority on `files`, `verified`, `base_sha`, `commit_sha` (task-board.md) | Structural: agents have no write path into script state at all, so the authority split needs no rule                                                                                                                                              |
| `base_sha` recorded once, never rewritten (teammate-protocol.md)                           | Structural: a `const` from args with no rewrite site                                                                                                                                                                                              |
| Stall detection, two scheduling moments, three conjuncts (teammate-protocol.md)            | Obsolete: `agent()` resolves or returns `null`; a dead or hung dispatch is a value the script handles, not a state the lead remembers to look for                                                                                                 |
| Mailbox delivery semantics, send-failure retry (teammate-protocol.md)                      | Obsolete: schema-validated returns; a malformed report is retried at the tool-call layer before the script ever sees it                                                                                                                           |
| Board-lag reconciliation via `TaskGet` (teammate-protocol.md)                              | Obsolete as stated: scheduler state cannot lag itself. The tree-level residue survives as one reconcile phase, and it earned its keep (see below)                                                                                                 |
| Purge recovery via out-of-board ownership record (task-board.md)                           | Replaced: args and `journal.jsonl` persist outside context, and `resumeFromRunId` replays completed agents from cache, demonstrated in run 2                                                                                                      |
| No concurrent writers to one file (teammates.md)                                           | Claim-level subset check per task plus authoritative end-of-run tree check, both in code. Worktree isolation closes it structurally where sources must overlap                                                                                    |
| One teammate holds its task through the gate window (teammate-protocol.md)                 | Retired with a recorded trade: fix rounds go to a fresh agent carrying the findings and spec rather than a warm context. Zero fix rounds were needed here, so the cost was unobserved; it is bounded either way by the schema and the scoped diff |
| Run only your own tests (implementer-prompt.md)                                            | Prose residue in the dispatched prompt while the tree is shared; unnecessary under worktree isolation                                                                                                                                             |
| Reviewer tier floor (subagent-dispatch.md)                                                 | Enforced in code: `model` is pinned per dispatch site in the script                                                                                                                                                                               |

What remains prose, irreducibly: decomposition judgement (granularity, naming shared mutable artefacts as edges), the sizing decision, prompt content quality, checkpoint conduct, and the lead's own final verification. That is a skill's worth of judgement, not a protocol's worth of bookkeeping.

## The User-Checkpoint Question

Answered concretely: nothing inside a workflow can reach `AskUserQuestion`; the tool belongs to the main loop, and the workflow runs in the background until it returns. The checkpoint flow survives by moving to the run boundary. The commit preference is asked once before launch, exactly as today. The workflow implements, reviews and verifies but never commits; it returns per-task evidence (TDD RED to GREEN, review verdicts with deferred Minors, verification commands with exit codes and counts). The lead then drains the queue in board order, presenting each task's evidence and scoped diff, and commits scoped to the task's files. This was performed against the fixture and the evidence returned was sufficient to do it without re-deriving anything except the diffs themselves, which the lead reads from the tree it owns.

The consequence worth stating: checkpoints coarsen from mid-run to run-boundary. Under "ask me each time", the user answers after the workflow completes rather than while later tasks are still running. Where mid-run checkpoints matter, the lead can launch one workflow per wave and drain between launches; that is a decomposition choice, not new machinery. "Adjust first" becomes a follow-up single-task launch against the same script.

## The Worktree Probe

Two agents dispatched with `isolation: "worktree"` and instructed to write conflicting content to the same path each received their own checkout under `.claude/worktrees/agent-<id>` on their own branch. Both wrote their file; neither saw the other; the main tree recorded no change. Merging is the lead's, and for file-disjoint tasks it is trivial. The iron law "no concurrent writers to one file, ever" exists because teammates shared one tree; isolation makes the collision structurally impossible rather than behaviourally forbidden. Where source sets genuinely overlap, serialisation via `blockedBy` remains the honest answer, because isolation converts a write collision into a merge conflict rather than removing it. The unconditional worktree ban in `rules/common/subagents.md` predates this evidence.

## Failures Observed, All Instructive

- `args` arrived as a JSON string rather than an object on the first launch. A script must tolerate both encodings.
- `git status --porcelain` collapses untracked directories; the reconcile agent reported `src/` and `tests/` and the mechanical rogue-path check refused to run the feature review over unaccountable paths. That refusal is the correct behaviour, and the fix is `-uall`. A prose lead would likely have shrugged past the same gap.
- `node --test tests/` mishandles a bare directory argument on Node 26; bare `node --test` is correct. The verification prompt, not the agent, was wrong.
- Hand-rebuilding args for a resume corrupted one task's spec through a quoting error, and the cache correctly treated the changed prompt as new work. Lesson: construct the args value once, keep the canonical copy in a file, and paste it verbatim on every reuse.
- Reviewer prompts must state that new files are untracked and invisible to `git diff`, mirroring the range law in `requesting-code-review`.

## Recommendation

Port. Not as prose instructing a lead to imitate a scheduler, and not as a script re-authored from scratch each run, but as a fixed script shipped alongside the skill, with the skill retaining exactly the judgement the table above leaves as prose: sizing, decomposition into the args structure, prompt content, the checkpoint drain, and the final feature-level review and verification in the main loop. The protocol files (`teammate-protocol.md`, `task-board.md`) retire: eleven of their fifteen invariants become code or become structurally unnecessary, and the four that remain are single sentences in the skill or the dispatched prompts.

Observed cost for calibration, per `evals/baseline/BASELINE.md`: roughly 391k subagent tokens and under six minutes wall clock for a three-task feature including per-task review, verification and the feature-level review, with wave two genuinely concurrent. No comparison run against the prose protocol was made; the figures are recorded as the first data point, not as a verdict on relative cost.
