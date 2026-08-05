# Triggering Evals

Query sets for measuring whether a skill's `description` fires when it should, and stays quiet when it should not. A skill's description is the only thing the model sees before deciding to load it, so description quality is what decides which skill wins when several could plausibly apply.

This directory sits outside `skills/` on purpose. `install.sh` installs every file it finds under `skills/` with no extension filter, so anything placed inside a skill folder ships to the user's `~/.claude/skills/`. Eval fixtures are development artefacts and must not be installed.

The same applies to run outputs, and more urgently, because a run creates them without being asked. `skill-creator` defaults to writing results into `<skill-name>-workspace/` as a sibling of the skill directory, which here would resolve to `skills/design-dialogue-workspace/` and put a full transcript archive into the install payload. Always point runs at `evals/workspace/` instead. That path and any `*-workspace/` directory are gitignored.

The query sets (`evals/*.json`) are source and belong in version control. Everything a run generates (transcripts, `benchmark.json`, `feedback.json`, per-iteration output directories) is regenerable and does not.

## Format

Each file is a JSON array consumed by the `skill-creator` plugin's description optimiser:

```json
[
  {"query": "what a user would actually type", "should_trigger": true}
]
```

Aim for 8 to 10 of each polarity. The useful negatives are near-misses, queries that share vocabulary or intent with the skill but should route elsewhere, because those are what the description has to discriminate against. Obviously irrelevant negatives measure nothing.

## Running an Optimisation Pass

From the `skill-creator` plugin directory, with the model ID of the session you want to match:

```sh
python -m scripts.run_loop \
  --eval-set <repo>/evals/design-dialogue-trigger.json \
  --skill-path <repo>/skills/design-dialogue \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

It splits the set 60/40 into train and held-out test, runs each query three times for a stable trigger rate, and selects the winning description by test score rather than train score. Take `best_description` from the JSON output into the skill's frontmatter.

## Current Sets

Every skill in `skills/` has a set.

| File                               | Skill                 | Discriminates against                                                                                                              |
|------------------------------------|-----------------------|------------------------------------------------------------------------------------------------------------------------------------|
| `debug-investigation-trigger.json` | `debug-investigation` | `design-dialogue`, `work-review-receive`, `work-tdd` mid-cycle, `work-verification`, ticket pickup, mechanical dependency bumps    |
| `design-dialogue-trigger.json`     | `design-dialogue`     | `debug-investigation`, `design-recovery`, `design-committee`, below-threshold trivial edits, read-only questions                   |
| `design-committee-trigger.json`    | `design-committee`    | `design-dialogue`, `debug-investigation`, `design-recovery`, hands-off phrasing on trivial work, "committee" as feature vocabulary |
| `design-review-trigger.json`       | `design-review`       | `work-review-request`, visual and UI design critique, ADR review, `design-dialogue` itself                                         |
| `design-handoff-trigger.json`      | `design-handoff`      | `design-recovery`, `work-swarm`, tracker housekeeping, "ticketing system" as feature vocabulary                                    |
| `design-recovery-trigger.json`     | `design-recovery`     | `design-handoff`, `work-swarm`, `debug-investigation` via bug tickets, triage questions, design-less tickets                       |
| `work-swarm-trigger.json`          | `work-swarm`          | `design-dialogue`, `design-recovery`, `design-handoff`, `debug-investigation`, "fast path" as code vocabulary                      |
| `work-review-request-trigger.json` | `work-review-request` | `work-review-receive`, reviewing somebody else's PR, `design-review`, `debug-investigation`, reading unfamiliar code               |
| `work-review-receive-trigger.json` | `work-review-receive` | `work-review-request`, `debug-investigation` a red PR, code review as a process question, "review" and "feedback" outside code     |
| `work-tdd-trigger.json`            | `work-tdd`            | `work-verification`, `debug-investigation`, test tooling set-up, explicit TDD opt-outs, reviewing tests                            |
| `work-verification-trigger.json`   | `work-verification`   | `work-review-request`, `work-tdd`, `work-review-receive`'s own item verification, "verify" as feature vocabulary                   |

## Boundary Notes

Both design sets trigger on explicit vocabulary rather than on the shape of the work, because a plain statement of design work now earns the routing ask defined in the always-on rules rather than a skill. `design-dialogue` fires when the user asks for the interactive mode by name or by substance: designing it together, being walked through the area while deciding, having a proposal grilled or pressure-tested, being pushed back on. Its hardest negatives are therefore the plain design-work statements it used to claim, which the routing ask now owns. `design-committee` fires when the user has explicitly asked to be hands-off, and its hardest negatives are hands-off phrasing attached to work that is not a design ("fix it however you see fit" attached to a defect is `debug-investigation`, and the same phrasing appears as a positive in that set). `design-committee` also carries the pure vocabulary collision every distinctive name earns: a feature about approval committees must not summon a deliberation.

`design-review` inverts the polarity: it is a step inside a design mode with no standing on its own, because it needs a consolidated summary a caller produced and a caller to return its verdict to. Its positives are therefore all mid-flow, and its hardest negatives are the two collisions its name invites: visual critique belongs to `frontend-design`, and a hand-written ADR nobody consolidated belongs to `design-dialogue`. One behavioural negative asks for a fourth dispatch after the three-dispatch budget is spent, which the Return Contract forbids.

Two pairs discriminate against each other on direction of travel rather than vocabulary, and each carries the other's positives as its hardest negatives. The review pair splits on whether the change is awaiting a look (`work-review-request`) or somebody has already looked and said something (`work-review-receive`). The ticket pair splits on whether an approved design is being persisted (`design-handoff`) or picked back up from an artefact (`design-recovery`); `design-recovery` additionally refuses two artefact-shaped near-misses, a bug-report ticket that belongs behind `debug-investigation`'s gate and a one-line ticket carrying no design at all, which is a fresh design conversation.

`debug-investigation` appears as a hard negative in nearly every other set, so its own set works the other way around: its negatives are the rest of the corpus. The queries the description most has to hold against are the failing test that is TDD RED rather than a defect, the reviewer comment that arrives as feedback rather than a bug, and the feature request dressed in defect language ("deliveries just vanish, that's by design today but it shouldn't be"). Its positives include the obvious-typo one-liner and the hands-off "fix it however you see fit", because the hard gate applies regardless of how simple the fix looks and hands-off phrasing on a bug is not a committee ask.

`work-swarm` fires on an explicit orchestration request with an approved design in hand, so its positives all pair approval with an ask to swarm the work, parallelise the build, fan it out across agents, or run the orchestrated implementation process with its reviews. Its negatives are the plain build instructions that now earn the routing ask instead, plus the surrounding lifecycle: no design yet, design on a ticket, design being ticketed, and the defect path. It inherits the retired fast-path set's vocabulary collisions (a code-level hot-path optimisation, and a security review of one) and its behavioural case with the polarity inverted: "this is dead simple, skip the ceremony" with an approved design is now a negative, because the routing ask decides the vehicle rather than the user's assertion of simplicity.

`work-tdd` and `work-verification` sit a step apart in the same flow: writing the failing test first against proving the finished work. Each holds the other as a near-miss, and `work-verification` additionally holds `work-review-receive`'s item-by-item verification of reviewer claims, the closest vocabulary collision it has. Both sets include a process-question negative, because asking why the discipline exists is not an invocation of it.
