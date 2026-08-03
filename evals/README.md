# Triggering Evals

Query sets for measuring whether a skill's `description` fires when it should, and stays quiet when it should not. A skill's description is the only thing the model sees before deciding to load it, so description quality is what decides which skill wins when several could plausibly apply.

This directory sits outside `skills/` on purpose. `install.sh` installs every file it finds under `skills/` with no extension filter, so anything placed inside a skill folder ships to the user's `~/.claude/skills/`. Eval fixtures are development artefacts and must not be installed.

The same applies to run outputs, and more urgently, because a run creates them without being asked. `skill-creator` defaults to writing results into `<skill-name>-workspace/` as a sibling of the skill directory, which here would resolve to `skills/design-grill-me-workspace/` and put a full transcript archive into the install payload. Always point runs at `evals/workspace/` instead. That path and any `*-workspace/` directory are gitignored.

The query sets (`evals/*.json`) are source and belong in version control. Everything a run generates (transcripts, `benchmark.json`, `feedback.json`, per-iteration output directories) is regenerable and does not. The one exception is `baseline/`, which holds dated corpus measurement captures defined in `./baseline/BASELINE.md`; those are snapshots of a moving corpus, not regenerable later, and are committed deliberately.

## Format

Each file is a JSON array consumed by the `skill-creator` plugin's description optimiser:

```json
[
  {"query": "what a user would actually type", "should_trigger": true}
]
```

Aim for 8 to 10 of each polarity. The useful negatives are near-misses, queries that share vocabulary or intent with the skill but should route elsewhere, because those are what the description has to discriminate against. Obviously irrelevant negatives measure nothing.

## Running an optimisation pass

From the `skill-creator` plugin directory, with the model ID of the session you want to match:

```sh
python -m scripts.run_loop \
  --eval-set <repo>/evals/design-grill-me-trigger.json \
  --skill-path <repo>/skills/design-grill-me \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

It splits the set 60/40 into train and held-out test, runs each query three times for a stable trigger rate, and selects the winning description by test score rather than train score. Take `best_description` from the JSON output into the skill's frontmatter.

## Current sets

| File                                  | Skill                    | Discriminates against                                                                                                                                      |
|---------------------------------------|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `design-grill-me-trigger.json`        | `design-grill-me`        | `debugging`, `design-recovery`, `design-committee`, below-threshold trivial edits, read-only questions                                                     |
| `design-committee-trigger.json`       | `design-committee`       | `design-grill-me`, `debugging`, `design-recovery`, hands-off phrasing on trivial work, "committee" as feature vocabulary                                   |
| `design-review-trigger.json`          | `design-review`          | `requesting-code-review`, visual and UI design critique, ADR review, `design-grill-me` itself                                                              |
| `requesting-code-review-trigger.json` | `requesting-code-review` | `receiving-code-review`, reviewing somebody else's PR, `design-review`, `debugging`, reading unfamiliar code                                               |
| `receiving-code-review-trigger.json`  | `receiving-code-review`  | `requesting-code-review`, `debugging` a red PR, code review as a process question, "review" and "feedback" outside code                                    |
| `skill-review-trigger.json`           | `skill-review`           | `requesting-code-review`, `design-review`, `design-grill-me` on a skill change, `debugging` a misbehaving skill, the `skill-creator` description optimiser |

The two design sets discriminate against each other on involvement rather than vocabulary. `design-grill-me` is the default, so its positives include users who know exactly what they want and users who want a walkthrough alike; `design-committee` fires only when the user has asked to be hands-off, and its hardest negatives are hands-off phrasing attached to work that is not a design ("fix it however you see fit" is `debugging`, "you decide where this helper lives" is below the design threshold). `design-committee` also carries the pure vocabulary collision every distinctive name earns: a feature about approval committees must not summon a deliberation.

`design-review` inverts the polarity for a different reason: it is a step inside a design mode and has no standing on its own, because it needs a consolidated summary a caller produced and a caller to return its verdict to. Its positives are therefore all mid-flow, and its hardest negatives are the two collisions its name invites. "Give the checkout flow a design review" is visual critique and belongs to `frontend-design`; "review this ADR I wrote" is a design nobody consolidated through a design skill, so it belongs to `design-grill-me`. The set also carries one behavioural negative: a user asking for a fourth dispatch after the three-dispatch budget is spent must not reach the skill, because the Return Contract forbids exactly that re-invocation.

The `fast-path-implementation` set was retired when that skill and `complexity-triage` folded into `orchestrated-implementation` as its sizing step; the set is recoverable from git history. Its most valuable negatives transfer to the `orchestrated-implementation` set when that set is authored: the "fast path" vocabulary collisions (a code-level hot path optimisation, and a security review of one), and the behavioural negative where a user asserting "this is dead simple, skip the ceremony" is claiming the very verdict the sizing criteria exist to earn from evidence.

The three `brainstorming` sets (router, standard, skip) were retired with the router itself, when the four modes collapsed into `design-grill-me` and `design-committee`; they too are recoverable from git history. Their durable negatives moved into the new sets rather than being lost: the debugging, ticket-pickup, and already-approved-design collisions carried into `design-grill-me-trigger.json`, and the skip set's below-threshold one-liners became `design-grill-me` negatives, because a change with no open decision now takes the inline design path in `rules/common/workflow.md` and should summon no skill at all. The inverted-polarity technique those sets pioneered, positives only where the user *names* the thing, survives in `design-committee-trigger.json`, whose positives all contain an explicit hands-off ask.

The two code review sets are the only pair in this directory that have to discriminate against each other, and the boundary between them is not the vocabulary, which is identical, but the direction of travel. `requesting-code-review` fires when a change is finished and needs looking at; `receiving-code-review` fires when somebody has already looked and said something. Each therefore carries the other's positives as its hardest negatives, phrased as closely as they realistically get: "can you review my branch before I open the PR" against "the reviewer left six comments, work through them".

Their other negatives split three ways. Reviewing code that is not the user's change is the first: somebody else's pull request belongs to the `review` command, a candidate's take-home is a hiring judgement, and a dependency's source is an adoption question. The second is the surrounding process, where asking how to speed up review turnaround or how to reply to an inline comment from the CLI is a question about the practice rather than a request to perform it. The third is pure vocabulary collision, which is why both sets carry a performance review and a design doc: "review" and "feedback" are among the most overloaded words a user can type, and a description matching on them alone will fire on a conversation about somebody's manager.

`requesting-code-review` also carries two behavioural positives that no keyword would catch. "Task 4 is implemented and committed, moving on to task 5" names no review at all, but `rules/common/code-review.md` makes one mandatory at exactly that point, and a description that waits to be asked hands the user an unreviewed task. "Nothing committed yet because I wasn't sure about the approach" is the uncommitted-work case the skill's range handling exists for, and it has to reach the skill rather than be turned away for having no commit to point at.

`skill-review` is the only set whose skill audits an artefact rather than moving work through the delivery flow, and it collides with almost everything that shares the word "review". Its negatives split three ways. Direction of artefact is the first: a diff belongs to `requesting-code-review` and a consolidated summary to `design-review`, and both are phrased here as closely to a skill audit as they realistically get. Tooling is the second, because the `skill-creator` plugin owns description optimisation and benchmark comparison, and a user asking for either is not asking for this skill however much the vocabulary overlaps.

The third is the lifecycle boundary, and it carries the hardest negative in the set. Changing a skill is a code edit and goes through the design step like any other; auditing one does not. The case that separates them most sharply is a user reporting that a skill loops forever. The artefact is a skill and the defect is exactly what criterion C5 exists to find, but the user has reported observed broken behaviour, which `rules/common/debugging.md` puts behind the reproduce-and-root-cause gate. It has to reach `debugging`, and a description matching on "skill" plus a defect word will take it.
