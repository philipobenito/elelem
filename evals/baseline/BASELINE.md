# Corpus Measurement Baseline

This is the baseline definition required by issue #16 of epic #11. Every other ticket in that epic ends in a judgement about the rule and skill corpus; this file records what "better" means before anything is cut, which measures are in, which were rejected and why, and how a future session re-runs the captures.

The corpus this baseline describes is the tree at the commit named in each capture file. Captures are snapshots of a moving corpus, so unlike ordinary eval run outputs (which `evals/README.md` correctly calls regenerable) they are not reproducible later and belong in version control.

## Chosen Measures

### Static Corpus Metrics

Captured by `./measure.sh`, which prints to stdout; a capture is the output redirected to a dated file in this directory. Every section is sorted, so two runs against the same tree are byte-identical and a diff between two captures is itself a measurement.

The sections, and the epic tickets they evidence:

| Section                            | What it measures                                             | Evidence for  |
|------------------------------------|--------------------------------------------------------------|---------------|
| Volume by file class               | Words always on versus loaded on demand                      | #17, #28      |
| Words per skill                    | Where the 46,000 skill words actually sit                    | #17, #21, #25 |
| Words per always-on rule file      | What each always-on file costs per session turn              | #27, #28      |
| RFC 2119 directive density         | How many `MUST` tokens compete for attention, and where      | #28           |
| Rationalisation-prevention files   | Spread of the defensive-framing pattern                      | #28           |
| Trigger eval coverage              | Which skills have a description eval set and which do not    | #16 itself    |
| Harness feature references         | Which 2026 harness primitives the corpus names at all        | #21, #29      |

Chosen because it is cheap, deterministic, needs no model access, and directly evidences the epic's two systemic observations (volume and defensive framing). It measures cost, not benefit; the benefit side is the trigger accuracy measure below.

Known limitation: the harness feature section counts raw string occurrences. The single `Workflow` hit in the 2026-08-03 capture is the H1 of `../../rules/common/workflow.md`, not a reference to the Workflow tool, so the epic's finding that the tool is referenced nowhere stands. Read that section's counts with the source greppable one command away.

One correction to the epic's audit, found while building the coverage section: 9 skills lack trigger eval sets, not 10 as the epic states. There are 17 skills (18 directories including `_shared`, which is not a skill) and 8 sets.

### Trigger Accuracy

Whether each skill's `description` fires when it should and stays quiet when it should not, measured over the query sets in `../` (see `../README.md` for what each set discriminates against). This is the only behavioural measure of the corpus that is mechanically capturable today: the `skill-creator` plugin's `run_eval.py` performs a measure-only pass, with no optimisation loop, and reports per-query trigger rates as JSON.

Status: **in the baseline, capture sequenced after the restructure.** The initial 2026-08-03 decision recorded this as a cost deferral; on reflection the sequencing is the substance, for two reasons:

- Trigger accuracy is an absolute measure, not a relative one. The acceptance bar is that positives fire and negatives stay quiet, and a post-restructure description is evaluated against that bar directly. No before-number is needed to interpret the after-number, so a pre-restructure capture is not the prerequisite it would be for a performance benchmark.
- Most of the measured boundaries will not survive #17. Five of the eight sets discriminate against skills the epic names as cut or merge candidates; rates for boundaries about to stop existing inform nothing.

What survives a restructure is the query sets themselves, especially the near-miss negatives, which encode routing judgement independent of any particular corpus shape and SHOULD be transferred to whatever skills replace their subjects.

The one capture with forward value today is the pair whose skills and mutual boundary the epic marks keep verbatim: `requesting-code-review` and `receiving-code-review`, identical vocabulary discriminated only by direction of travel. Capturing those two sets now (38 queries, roughly 114 invocations at 3 runs per query) measures the future corpus and MAY be done at any time. The full capture is 153 queries times 3 runs, roughly 460 invocations, and SHOULD wait until the post-#17 descriptions exist; that capture, not this one's date, is the true behavioural baseline.

Extending coverage to the 9 skills without sets is deferred on the same reasoning until #17 decides the target shape. Several uncovered skills (`brainstorming-committee`, `complexity-triage`, `orchestrated-implementation` among them) are named cut candidates in the epic; authoring trigger sets for skills about to be deleted is waste. The coverage section of the static capture keeps the gap visible until then.

## Rejected Measures

### Token Cost of Full Workflow Versus Direct

Rejected as a baseline measure. It requires paired live runs of a representative task, once through the full router-triage-orchestration path and once direct, and a single pair is dominated by variance in what the model happens to do. Enough repetitions to be meaningful is exactly the benchmark harness the ticket warns will be abandoned. The claim it would test (that `orchestrated-implementation` earns its cost) is better evidenced inside #21, where porting the skill to a Workflow script forces the cost accounting anyway; #21 SHOULD record the token figures it observes.

### Wall-Clock to First Commit

Rejected for the same live-run cost, plus a worse confound: wall-clock in an interactive session measures the machine, the model tier, queueing and the human as much as the corpus. Not reproducible by a future session in any useful sense.

### Defect Escape Rate

Rejected as a baseline. Findings that feature-level review catches but per-task reviews missed only exist as data after weeks of real usage, and no historical record of past reviews exists to mine. There is nothing to capture today. If the review layer survives #17, a lightweight tally kept from that point forward would be the successor to this measure.

## Captures

| Date       | Commit    | Artefact                | Measure               |
|------------|-----------|-------------------------|-----------------------|
| 2026-08-03 | `2a1486a` | `2026-08-03-static.txt` | Static corpus metrics |

## Re-Running

### Static Metrics

From the repository root:

```sh
evals/baseline/measure.sh > evals/baseline/<date>-static.txt
```

Commit the output and add a row to the Captures table. The script has no options and no non-deterministic output; if a diff against the previous capture shows a change, the corpus changed.

### Trigger Accuracy

From the `skill-creator` plugin's `skills/skill-creator/` directory (installed under `~/.claude/plugins/cache/`), once per eval set:

```sh
mkdir -p <repo>/evals/baseline/<date>-trigger
python -m scripts.run_eval \
  --eval-set <repo>/evals/<skill>-trigger.json \
  --skill-path <repo>/skills/<skill> \
  --runs-per-query 3 \
  --verbose > <repo>/evals/baseline/<date>-trigger/<skill>.json
```

Omit `--model` to measure against the operator's configured default model, and record which model that was alongside the capture, because trigger rates are model-specific and a rate change between captures under different models measures the model, not the description. Commit the JSON output and add a row to the Captures table.
